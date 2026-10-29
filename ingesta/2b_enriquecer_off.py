#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2b_enriquecer_off.py
--------------------
Toma los EANs únicos del catálogo maestro de SEPA y consulta
la API de Open Food Facts (OFF) para obtener metadatos enriquecidos:
- Marca, Nombre limpio, Gramaje, Imágenes, Categorías.

Implementa un sistema de caché local (off_cache.json) para
no consultar múltiples veces un EAN ya conocido y respetar
los rate limits de OFF.
Guarda los resultados estructurados en data/processed/off_metadata.csv.
"""

import os
import sys
import time
import json
import argparse
import requests
import pandas as pd
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from config import RAW_DIR, PROCESSED_DIR

# Archivos
INPUT_FILE = RAW_DIR / "master_productos.csv"
CACHE_FILE = PROCESSED_DIR / "off_cache.json"
OUTPUT_FILE = PROCESSED_DIR / "off_metadata.csv"

# API Config
# Documentación API v2: https://openfoodfacts.github.io/openfoodfacts-server/api/
USER_AGENT = "CompraMas-IngestaPipeline/1.0 (jmric@...)"  # Reemplazar por correo real en prod
BASE_URL = "https://world.openfoodfacts.org/api/v2/product/{}.json"
FIELDS = "code,product_name,brands,quantity,product_quantity,image_front_url,categories_tags,nutriscore_grade"
MAX_WORKERS = 1  # 1 solo hilo secuencial para cumplir con las políticas de Open Food Facts y evitar 429

def cargar_cache() -> dict:
    if CACHE_FILE.exists():
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return {}
    return {}

def guardar_cache(cache: dict):
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

def limpiar_codigo_barra(val):
    if pd.isna(val):
        return ""
    s = str(val).strip()
    if s.endswith(".0"):
        s = s[:-2]
    return s

CATALOGO_FILE = PROCESSED_DIR / "catalogo_productos.csv"

def extraer_eans_unicos() -> set:
    eans = set()
    
    # 1. Leer master_productos.csv (SEPA)
    if not INPUT_FILE.exists():
        fallback_file = RAW_DIR / "productos_final.csv"
        file_to_read = fallback_file if fallback_file.exists() else None
    else:
        file_to_read = INPUT_FILE

    if file_to_read and file_to_read.exists():
        print(f"[*] Leyendo EANs únicos de {file_to_read.name}...")
        chunksize = 500000
        for ch in pd.read_csv(file_to_read, sep="|", encoding="utf-8-sig", chunksize=chunksize, usecols=["id_producto"], dtype=str, low_memory=False):
            ch.columns = [c.strip().lstrip("\ufeff") for c in ch.columns]
            cleaned = ch["id_producto"].apply(limpiar_codigo_barra)
            eans.update(cleaned[cleaned != ""].unique())
        print(f"    -> Se encontraron {len(eans):,} EANs únicos en SEPA.")

    # 2. Leer catalogo_productos.csv (incluye productos nuevos incorporados por VTEX/Scraping)
    if CATALOGO_FILE.exists():
        try:
            print(f"[*] Leyendo EANs únicos de {CATALOGO_FILE.name} (incluye VTEX y nuevos ingresos)...")
            df_cat = pd.read_csv(CATALOGO_FILE, usecols=["id_producto"], dtype=str)
            cleaned_cat = df_cat["id_producto"].apply(limpiar_codigo_barra)
            nuevos_cat = set(cleaned_cat[cleaned_cat != ""].unique())
            diff = len(nuevos_cat - eans)
            eans.update(nuevos_cat)
            print(f"    -> Catálogo actual: {len(eans):,} EANs totales (+{diff:,} adicionales desde catálogo/VTEX).")
        except Exception as e:
            print(f"[!] Advertencia leyendo {CATALOGO_FILE.name}: {e}")

    return eans

def es_codigo_interno_o_plu(ean: str) -> bool:
    """Detecta códigos PLU de balanza o códigos internos GS1 (20-29)."""
    clean = str(ean).strip()
    if len(clean) < 8:
        return True
    if len(clean) >= 12 and clean.startswith(('20', '21', '22', '23', '24', '25', '26', '27', '28', '29')):
        return True
    return False

def consultar_off_api(ean: str) -> dict:
    """Consulta la API de Open Food Facts para un EAN dado."""
    if es_codigo_interno_o_plu(ean):
        return {"encontrado": False, "motivo": "codigo_interno_plu"}

    url = BASE_URL.format(ean)
    params = {"fields": FIELDS}
    headers = {"User-Agent": USER_AGENT}
    try:
        res = requests.get(url, params=params, headers=headers, timeout=10)
        if res.status_code == 200:
            data = res.json()
            if data.get("status") == 1: # Encontrado
                prod = data.get("product", {})
                return {
                    "encontrado": True,
                    "off_nombre": prod.get("product_name", ""),
                    "off_marca": prod.get("brands", ""),
                    "off_cantidad_str": prod.get("quantity", ""),
                    "off_cantidad_num": prod.get("product_quantity", None),
                    "off_imagen": prod.get("image_front_url", ""),
                    "off_nutriscore": prod.get("nutriscore_grade", ""),
                    "off_categorias": ",".join(prod.get("categories_tags", []))
                }
            else:
                return {"encontrado": False}
        elif res.status_code == 404:
            return {"encontrado": False}
        elif res.status_code == 429:
            print("    [!] Rate Limit (429) alcanzado. Esperando 10s...")
            time.sleep(10)
            return consultar_off_api(ean) # Reintento
        else:
            return {"error": f"HTTP {res.status_code}"}
    except Exception as e:
        return {"error": str(e)}

PARQUET_FILE = RAW_DIR / "food.parquet"

def enriquecer_catalogo(limit: int = None, eans_especificos: list = None):
    """
    Enriquece productos con Open Food Facts.
    1. Fase 1: Contrasta PRIMERO contra la base local descargada de Open Food Facts (food.parquet).
    2. Fase 2: Consulta la API online de OFF únicamente para los EANs restantes no presentes en el volcado local.
    """
    if eans_especificos is not None:
        eans = set(limpiar_codigo_barra(e) for e in eans_especificos if limpiar_codigo_barra(e))
        print(f"[*] Enriquecimiento selectivo para {len(eans):,} EANs específicos...")
    else:
        eans = extraer_eans_unicos()

    if not eans:
        return

    cache = cargar_cache()
    eans_a_consultar = list(eans - set(cache.keys()))

    # -------------------------------------------------------------
    # FASE 1: SINCRONIZACIÓN CONTRA BASE DESCARGADA LOCAL (PARQUET)
    # -------------------------------------------------------------
    if eans_a_consultar and PARQUET_FILE.exists():
        print(f"\n[*] [FASE 1: PARQUET LOCAL] Sincronizando {len(eans_a_consultar):,} EANs pendientes contra {PARQUET_FILE.name}...")
        try:
            from sincronizar_off_parquet import sincronizar as sincronizar_parquet
            cache_actualizada = sincronizar_parquet(eans_objetivo=set(eans_a_consultar))
            if cache_actualizada:
                cache = cache_actualizada
            eans_a_consultar = list(eans - set(cache.keys()))
            print(f"[OK] Fase 1 finalizada. EANs restantes para API online: {len(eans_a_consultar):,}\n")
        except Exception as e_pq:
            print(f"[!] Error sincronizando contra Parquet local: {e_pq}")

    if limit:
        eans_a_consultar = eans_a_consultar[:limit]

    print(f"[*] EANs en caché OFF: {len(cache):,}")
    print(f"[*] Nuevos EANs a consultar en API online de OFF: {len(eans_a_consultar):,}")

    if not eans_a_consultar:
        print("[OK] Todos los EANs solicitados ya están en caché. Exportando a CSV...")
        exportar_cache_a_csv(cache)
        return

    print(f"[*] Consultando API de Open Food Facts ({MAX_WORKERS} hilos)...")
    procesados = 0
    encontrados = 0
    errores = 0

    def procesar_lote_en_hilo(ean_batch):
        nonlocal procesados, encontrados, errores
        for ean in ean_batch:
            resultado = consultar_off_api(ean)
            if "error" in resultado:
                errores += 1
                # No guardamos en caché si hubo error de conexión, para reintentar luego
            else:
                cache[ean] = resultado
                if resultado.get("encontrado"):
                    encontrados += 1
                procesados += 1
                
                # Auto-guardado cada 100 exitosos para no perder progreso
                if procesados % 100 == 0:
                    guardar_cache(cache)
            
            sys.stdout.write(f"\r    Consultados: {procesados}/{len(eans_a_consultar)} | Encontrados: {encontrados} | Errores: {errores}")
            sys.stdout.flush()
            time.sleep(0.8) # Pausa de cortesía (0.8s) para no saturar la API ni recibir 429

    # Dividir eans_a_consultar en bloques para los hilos
    chunk_size = max(1, len(eans_a_consultar) // MAX_WORKERS)
    batches = [eans_a_consultar[i:i + chunk_size] for i in range(0, len(eans_a_consultar), chunk_size)]

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(procesar_lote_en_hilo, batch) for batch in batches]
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"\n[!] Error en hilo: {e}")

    print()
    print("[*] Guardando caché final...")
    guardar_cache(cache)
    exportar_cache_a_csv(cache)

def exportar_cache_a_csv(cache: dict):
    # Convertir dict a list de dicts
    filas = []
    for ean, datos in cache.items():
        if datos.get("encontrado"):
            row = {"id_producto": str(ean)}
            for k, v in datos.items():
                if k != "encontrado":
                    row[k] = v
            filas.append(row)
    
    df = pd.DataFrame(filas)
    if df.empty:
        print("[!] No hay productos enriquecidos para exportar.")
        return
        
    df.to_csv(OUTPUT_FILE, sep=",", index=False, encoding="utf-8")
    print(f"[OK] Metadatos de OFF exportados a {OUTPUT_FILE} ({len(df):,} productos encontrados en OFF).")

    # Sincronizar directamente con catalogo_productos.csv si existe
    if CATALOGO_FILE.exists():
        try:
            print(f"[*] Sincronizando columnas de Open Food Facts con {CATALOGO_FILE.name}...")
            df_cat = pd.read_csv(CATALOGO_FILE, dtype=str)
            cols_off = ["off_nombre", "off_marca", "off_cantidad_str", "off_cantidad_num", "off_imagen", "off_nutriscore", "off_categorias"]
            
            # Limpiar columnas off anteriores para no duplicar en el merge
            df_cat_limpio = df_cat.drop(columns=[c for c in cols_off if c in df_cat.columns])
            df_cat_final = pd.merge(df_cat_limpio, df, on="id_producto", how="left")
            df_cat_final.to_csv(CATALOGO_FILE, index=False, encoding="utf-8")
            
            con_off = df_cat_final["off_nombre"].notna() & (df_cat_final["off_nombre"] != "")
            print(f"[OK] {CATALOGO_FILE.name} sincronizado: {con_off.sum():,} productos con metadatos de OFF.")
        except Exception as e:
            print(f"[!] Advertencia sincronizando {CATALOGO_FILE.name}: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Enriquece EANs con Open Food Facts.")
    parser.add_argument("--limit", type=int, help="Limita la cantidad de EANs nuevos a consultar en OFF (por defecto: None, sin límite).", default=None)
    args = parser.parse_args()
    
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    enriquecer_catalogo(limit=args.limit)
