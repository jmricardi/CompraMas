#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2d_scraping_mayoristas.py
-------------------------
Extrae precios reales desde webs mayoristas:
1. Vital: Extracción masiva ultra-rápida de catálogo completo (~6.000 productos en <35s)
   utilizando la API VTEX Intelligent Search nativa.
2. Maxiconsumo: Monitoreo enfocado por marca/descripción con caché positivo y negativo 
   (data/processed/maxiconsumo_cache.json) y punto de control automático (checkpoint).

Permite pausar y reanudar exactamente desde donde se dejó (--resume o --start-index).
Genera data/processed/precios_mayoristas.csv de forma incremental y resiliente con fsync.
"""

import os
import sys
import json
import time
import argparse
import pandas as pd
from pathlib import Path
from datetime import datetime
from config import PROCESSED_DIR
from scrapers.mayoristas.vital_client import VitalClient
from scrapers.mayoristas.maxiconsumo import MaxiconsumoClient

OUTPUT_FILE = PROCESSED_DIR / "precios_mayoristas.csv"
CACHE_FILE = PROCESSED_DIR / "maxiconsumo_cache.json"
CHECKPOINT_FILE = PROCESSED_DIR / "maxiconsumo_checkpoint.json"

COLUMNAS_ORDEN = [
    "id_producto", "id_entidad", "precio_unitario", "precio_bulto",
    "cantidad_bulto", "stock", "url", "fecha_captura", "nombre_scraper"
]

def cargar_cache_maxiconsumo() -> dict:
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"confirmed": {}, "not_found": []}

def guardar_cache_maxiconsumo(cache: dict):
    try:
        tmp_file = CACHE_FILE.with_suffix(".tmp")
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
            f.flush()
            os.fsync(f.fileno())
        tmp_file.replace(CACHE_FILE)
    except Exception as e:
        print(f"[-] Error guardando caché de Maxiconsumo: {e}")

def cargar_checkpoint() -> dict:
    if CHECKPOINT_FILE.exists():
        try:
            with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"last_index": 0, "processed_count": 0, "found_count": 0}

def guardar_checkpoint(index: int, processed: int, found: int):
    try:
        tmp_file = CHECKPOINT_FILE.with_suffix(".tmp")
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump({
                "last_index": index,
                "processed_count": processed,
                "found_count": found,
                "timestamp": datetime.now().isoformat()
            }, f, indent=2)
            f.flush()
            os.fsync(f.fileno())
        tmp_file.replace(CHECKPOINT_FILE)
    except Exception as e:
        print(f"[-] Error guardando checkpoint: {e}")

def guardar_csv_precios(precios: list):
    if not precios:
        df_vacio = pd.DataFrame(columns=COLUMNAS_ORDEN)
        df_vacio.to_csv(OUTPUT_FILE, index=False, encoding="utf-8")
        return

    df = pd.DataFrame(precios)
    for c in COLUMNAS_ORDEN:
        if c not in df.columns:
            df[c] = None
    df = df[COLUMNAS_ORDEN].drop_duplicates(subset=["id_producto", "id_entidad"], keep="last")
    
    tmp_file = OUTPUT_FILE.with_suffix(".tmp")
    df.to_csv(tmp_file, index=False, encoding="utf-8")
    tmp_file.replace(OUTPUT_FILE)

def cargar_precios_existentes() -> list:
    if OUTPUT_FILE.exists():
        try:
            df = pd.read_csv(OUTPUT_FILE, dtype=str)
            return df.to_dict("records")
        except Exception:
            pass
    return []

def ejecutar_scraping_mayorista(
    limit: int = None,
    start_index: int = None,
    resume: bool = False,
    skip_vital: bool = False,
    buscar_nuevos: bool = False
):
    print("=" * 60)
    print(" PASO 3C: SCRAPING MAYORISTA INTELIGENTE (VITAL & MAXICONSUMO)")
    print("=" * 60)

    # Cargar precios previos existentes para no sobreescribir ni perder nada
    todos_los_precios = cargar_precios_existentes()
    print(f"[*] Precios mayoristas existentes en CSV: {len(todos_los_precios)}")

    # -------------------------------------------------------------
    # 1. Mayorista Vital: Crawling masivo en segundos
    # -------------------------------------------------------------
    if not skip_vital:
        print("\n[*] [1/2] Extrayendo catálogo completo de MAYORISTA VITAL vía API nativa...")
        vital_client = VitalClient()
        t0_vital = time.time()
        try:
            max_p = 150 if not limit else max(1, limit // 50 + 1)
            precios_vital = vital_client.crawl_catalog(max_pages=max_p, page_size=50)
            print(f"[OK] Vital: {len(precios_vital)} productos y bultos obtenidos en {time.time() - t0_vital:.1f}s")
            todos_los_precios.extend(precios_vital)
            guardar_csv_precios(todos_los_precios)
        except Exception as e:
            print(f"[-] Error extrayendo Vital: {e}")
    else:
        print("\n[*] [1/2] Omitiendo Vital (--skip-vital). Se mantienen los registros existentes.")

    # -------------------------------------------------------------
    # 2. Maxiconsumo: Búsqueda focalizada con Checkpoint y Reanudación
    # -------------------------------------------------------------
    cat_file = PROCESSED_DIR / "catalogo_productos.csv"
    if not cat_file.exists():
        print(f"[-] No se encontró {cat_file} para Maxiconsumo.")
        return

    print("\n[*] [2/2] Procesando MAYORISTA MAXICONSUMO con Checkpoint y Negative Caching...")
    cache_maxi = cargar_cache_maxiconsumo()
    confirmed_cache = cache_maxi.get("confirmed", {})
    not_found_set = set(cache_maxi.get("not_found", []))

    print(f"    Caché actual: {len(confirmed_cache)} productos confirmados | {len(not_found_set)} descartados")

    # Integrar confirmados al set general
    for ean, item_data in confirmed_cache.items():
        todos_los_precios.append(item_data)

    if not buscar_nuevos:
        print(f"[OK] Modo Monitoreo activo: Se consolidan los {len(confirmed_cache):,} productos confirmados de Maxiconsumo.")
        print("     (Para explorar productos no testeados del catálogo use la bandera: --buscar-nuevos)")
        guardar_csv_precios(todos_los_precios)
        print(f"[OK] Guardado completado: {len(todos_los_precios)} precios mayoristas consolidados en {OUTPUT_FILE}")
        return

    df_cat = pd.read_csv(cat_file, dtype=str)
    total_catalogo = len(df_cat)

    # Filtrar candidatos válidos
    mask_valido = df_cat["id_producto"].notna() & df_cat["productos_descripcion"].notna()
    df_candidatos = df_cat[mask_valido].copy()

    # Priorizar alimentos básicos y marcas conocidas
    keywords = ["aceite", "arroz", "fideos", "leche", "azucar", "harina", "pure", "tomate", "galletitas", "yerba", "cafe", "jabon", "detergente"]
    patron = "|".join(keywords)
    mask_prioritarios = df_candidatos["productos_descripcion"].str.contains(patron, case=False, na=False)
    
    df_prio = df_candidatos[mask_prioritarios]
    df_resto = df_candidatos[~mask_prioritarios]
    df_ordenado = pd.concat([df_prio, df_resto]).drop_duplicates(subset=["id_producto"]).reset_index(drop=True)

    # Determinar punto de partida
    actual_start = 0
    if resume:
        ckpt = cargar_checkpoint()
        actual_start = ckpt.get("last_index", 0)
        print(f"    [Checkpoint] Reanudando automáticamente desde el índice {actual_start}...")
    elif start_index is not None and start_index > 0:
        actual_start = start_index
        print(f"    [Manual] Iniciando desde el índice indicado: {actual_start}...")

    # Recortar desde el índice de inicio
    if actual_start > 0:
        df_trabajo = df_ordenado.iloc[actual_start:].reset_index(drop=True)
    else:
        df_trabajo = df_ordenado

    # Filtrar los que ya están en confirmed o not_found
    items_a_buscar = []
    indices_originales = []
    for rel_idx, row in enumerate(df_trabajo.to_dict("records")):
        ean = str(row["id_producto"]).strip()
        if ean in confirmed_cache or ean in not_found_set:
            continue
        items_a_buscar.append(row)
        indices_originales.append(actual_start + rel_idx)

    if limit is not None and limit > 0:
        items_a_buscar = items_a_buscar[:limit]
        indices_originales = indices_originales[:limit]

    print(f"[*] Consultando {len(items_a_buscar)} productos candidatos en Maxiconsumo (de {total_catalogo} totales)...")

    maxi_client = MaxiconsumoClient()
    nuevos_encontrados = 0
    procesados = actual_start

    try:
        for loop_idx, (it, orig_idx) in enumerate(zip(items_a_buscar, indices_originales), 1):
            ean = str(it["id_producto"]).strip()
            desc = str(it.get("productos_descripcion") or "").strip()
            marca = str(it.get("productos_marca") or "").strip()
            query = f"{marca} {desc}".strip()

            try:
                res = maxi_client.fetch_price(ean=ean, query=query)
                if res:
                    confirmed_cache[ean] = res
                    todos_los_precios.append(res)
                    nuevos_encontrados += 1
                else:
                    not_found_set.add(ean)
            except Exception:
                pass

            procesados = orig_idx + 1

            if loop_idx % 5 == 0 or loop_idx == len(items_a_buscar):
                encontrados_totales = len(confirmed_cache)
                sys.stdout.write(
                    f"\r    Productos procesados: {procesados}/{total_catalogo} | "
                    f"Precios mayoristas encontrados: {encontrados_totales} (+{nuevos_encontrados} nuevos)"
                )
                sys.stdout.flush()

            # Guardado incremental y checkpoint seguro cada 10 items
            if loop_idx % 10 == 0:
                guardar_checkpoint(procesados, procesados, len(confirmed_cache))
                cache_maxi["confirmed"] = confirmed_cache
                cache_maxi["not_found"] = list(not_found_set)
                guardar_cache_maxiconsumo(cache_maxi)
                guardar_csv_precios(todos_los_precios)

    except KeyboardInterrupt:
        print(f"\n[!] Scraping pausado por el usuario en producto #{procesados}. Salvando progreso actual...")
    finally:
        # Guardado final garantizado
        guardar_checkpoint(procesados, procesados, len(confirmed_cache))
        cache_maxi["confirmed"] = confirmed_cache
        cache_maxi["not_found"] = list(not_found_set)
        guardar_cache_maxiconsumo(cache_maxi)
        guardar_csv_precios(todos_los_precios)
        print(f"\n[OK] Guardado completado: {len(todos_los_precios)} precios mayoristas en {OUTPUT_FILE}")
        print(f"[OK] Checkpoint registrado en {CHECKPOINT_FILE} (próximo inicio en {procesados})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scraping de precios mayoristas con soporte de reanudación")
    parser.add_argument("--limit", type=int, help="Límite de productos a consultar en esta tanda", default=None)
    parser.add_argument("--start-index", type=int, help="Índice de producto específico desde el que comenzar (ej. 57875)", default=None)
    parser.add_argument("--resume", action="store_true", help="Reanudar automáticamente desde el último checkpoint guardado")
    parser.add_argument("--skip-vital", action="store_true", help="Omitir Vital y enfocar el scraping solo en Maxiconsumo")
    parser.add_argument("--buscar-nuevos", action="store_true", help="Buscar productos nuevos en Maxiconsumo (en lugar del modo monitoreo rápido de confirmados)")
    args = parser.parse_args()

    ejecutar_scraping_mayorista(
        limit=args.limit,
        start_index=args.start_index,
        resume=args.resume,
        skip_vital=args.skip_vital,
        buscar_nuevos=args.buscar_nuevos,
    )
