#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sincronizar_off_parquet.py
--------------------------
Procesa 'data/raw/food.parquet' de Open Food Facts de forma 100% local,
cruza los EANs contra los productos de SEPA (catalogo_productos.csv o master_productos.csv),
extrae metadatos (nombre, marca, fotos, nutriscore, categorías) y genera:
  - data/processed/off_metadata.csv
  - data/processed/off_cache.json
  - Actualiza data/processed/catalogo_productos.csv con las nuevas columnas OFF.
"""

import sys
import time
import json
import re
import pandas as pd
import pyarrow.parquet as pq
from pathlib import Path
from config import RAW_DIR, PROCESSED_DIR

PARQUET_FILE = RAW_DIR / "food.parquet"
CATALOGO_FILE = PROCESSED_DIR / "catalogo_productos.csv"
OFF_METADATA_FILE = PROCESSED_DIR / "off_metadata.csv"
OFF_CACHE_FILE = PROCESSED_DIR / "off_cache.json"

def limpiar_codigo(val) -> str:
    if pd.isna(val):
        return ""
    s = str(val).strip()
    if s.endswith(".0"):
        s = s[:-2]
    return s

def construir_url_imagen(code: str, images_arr) -> str:
    """
    Construye la URL pública de la imagen de portada de Open Food Facts.
    Ej: https://images.openfoodfacts.org/images/products/779/123/456/7890/front_es.3.400.jpg
    """
    if not code:
        return ""
    clean_code = str(code).strip()
    if len(clean_code) <= 8:
        base_path = clean_code
    else:
        m = re.match(r"^(\d{3})(\d{3})(\d{3})(.*)$", clean_code)
        if m:
            base_path = f"{m.group(1)}/{m.group(2)}/{m.group(3)}/{m.group(4)}"
        else:
            base_path = clean_code

    if images_arr is None or len(images_arr) == 0:
        return f"https://images.openfoodfacts.org/images/products/{base_path}/1.400.jpg"

    # Buscar key con 'front_es', 'front_en', 'front'
    selected = None
    for im in images_arr:
        if isinstance(im, dict):
            k = str(im.get("key", ""))
            if k == "front_es":
                selected = im
                break
            elif k.startswith("front") and not selected:
                selected = im

    if selected:
        k = selected.get("key")
        rev = selected.get("rev")
        if rev and not pd.isna(rev):
            return f"https://images.openfoodfacts.org/images/products/{base_path}/{k}.{int(rev)}.400.jpg"
        imgid = selected.get("imgid")
        if imgid and not pd.isna(imgid):
            return f"https://images.openfoodfacts.org/images/products/{base_path}/{int(imgid)}.400.jpg"

    return f"https://images.openfoodfacts.org/images/products/{base_path}/1.400.jpg"

def extraer_nombre(product_name_arr) -> str:
    if product_name_arr is None or len(product_name_arr) == 0:
        return ""
    
    # Si viene como string directo
    if isinstance(product_name_arr, str):
        return product_name_arr.strip()

    # Si viene como array de dicts con 'lang' y 'text'
    candidatos = {}
    if hasattr(product_name_arr, "__iter__"):
        for item in product_name_arr:
            if isinstance(item, dict):
                lang = item.get("lang", "")
                text = item.get("text", "")
                if text:
                    candidatos[lang] = str(text).strip()

    if "es" in candidatos:
        return candidatos["es"]
    if "main" in candidatos:
        return candidatos["main"]
    if "en" in candidatos:
        return candidatos["en"]
    if candidatos:
        return next(iter(candidatos.values()))
    
    return ""

def extraer_categorias(cat_arr) -> str:
    if cat_arr is None or len(cat_arr) == 0:
        return ""
    if isinstance(cat_arr, str):
        return cat_arr
    if hasattr(cat_arr, "__iter__"):
        cats = [str(c).replace("en:", "").replace("es:", "") for c in cat_arr if c]
        return ", ".join(cats[:5])
    return ""

def sincronizar(eans_objetivo: set = None):
    if not PARQUET_FILE.exists():
        print(f"[-] No se encontró el archivo: {PARQUET_FILE}")
        return {}

    print("========================================================")
    print(" SINCRONIZACIÓN LOCAL DE OPEN FOOD FACTS (PARQUET)")
    print("========================================================")
    
    # 1. Obtener EANs objetivos
    if eans_objetivo is not None and len(eans_objetivo) > 0:
        eans_sepa = set(limpiar_codigo(e) for e in eans_objetivo if limpiar_codigo(e))
        print(f"[*] Filtrando {len(eans_sepa):,} EANs específicos contra Parquet...")
        df_cat_orig = pd.read_csv(CATALOGO_FILE, dtype=str) if CATALOGO_FILE.exists() else None
    elif CATALOGO_FILE.exists():
        print(f"[*] Leyendo catálogo de productos de {CATALOGO_FILE.name}...")
        df_cat_orig = pd.read_csv(CATALOGO_FILE, dtype=str)
        df_cat_orig["id_producto"] = df_cat_orig["id_producto"].apply(limpiar_codigo)
        eans_sepa = set(df_cat_orig["id_producto"].dropna().unique())
    else:
        master_file = RAW_DIR / "master_productos.csv"
        if master_file.exists():
            print(f"[*] Leyendo EANs de {master_file.name}...")
            for ch in pd.read_csv(master_file, sep="|", encoding="utf-8-sig", chunksize=500000, usecols=["id_producto"], dtype=str):
                ch.columns = [c.strip().lstrip("\ufeff") for c in ch.columns]
                cleaned = ch["id_producto"].apply(limpiar_codigo)
                eans_sepa.update(cleaned[cleaned != ""].unique())
        df_cat_orig = None

    print(f"[+] Total EANs a cruzar contra Parquet: {len(eans_sepa):,}")

    # 2. Escanear Parquet
    t0 = time.time()
    parquet_cols = [
        "code", "product_name", "brands", "quantity", 
        "product_quantity", "nutriscore_grade", "categories_tags", "images"
    ]
    
    print(f"[*] Procesando {PARQUET_FILE.name} en bloques...")
    f_pq = pq.ParquetFile(PARQUET_FILE)
    total_filas_pq = f_pq.metadata.num_rows
    print(f"    -> Filas totales en Parquet: {total_filas_pq:,}")

    filas_enriquecidas = []
    cache_dict = {}
    if OFF_CACHE_FILE.exists():
        try:
            with open(OFF_CACHE_FILE, "r", encoding="utf-8") as f:
                cache_dict = json.load(f)
        except Exception:
            cache_dict = {}

    batch_idx = 0
    filas_procesadas = 0
    for batch in f_pq.iter_batches(columns=parquet_cols, batch_size=250000):
        batch_idx += 1
        filas_procesadas += len(batch)
        df_b = batch.to_pandas()
        df_b["code_clean"] = df_b["code"].apply(limpiar_codigo)
        
        # Filtrar solo coincidencias con SEPA
        matches = df_b[df_b["code_clean"].isin(eans_sepa)]
        if not matches.empty:
            for _, row in matches.iterrows():
                ean = row["code_clean"]
                if ean in cache_dict:
                    continue
                
                nombre = extraer_nombre(row.get("product_name"))
                marca = str(row.get("brands", "")).strip() if pd.notna(row.get("brands")) else ""
                cant_str = str(row.get("quantity", "")).strip() if pd.notna(row.get("quantity")) else ""
                cant_num = str(row.get("product_quantity", "")).strip() if pd.notna(row.get("product_quantity")) else ""
                nutri = str(row.get("nutriscore_grade", "")).strip().lower() if pd.notna(row.get("nutriscore_grade")) else ""
                if nutri in ["not-applicable", "unknown"]:
                    nutri = ""
                cats = extraer_categorias(row.get("categories_tags"))
                img_url = construir_url_imagen(ean, row.get("images"))

                info = {
                    "id_producto": ean,
                    "off_nombre": nombre,
                    "off_marca": marca,
                    "off_cantidad_str": cant_str,
                    "off_cantidad_num": cant_num,
                    "off_imagen": img_url,
                    "off_nutriscore": nutri,
                    "off_categorias": cats
                }
                filas_enriquecidas.append(info)
                cache_dict[ean] = {
                    "encontrado": True,
                    **{k: v for k, v in info.items() if k != "id_producto"}
                }

        sys.stdout.write(f"\r    Bloque {batch_idx} ({filas_procesadas:,}/{total_filas_pq:,}) | Coincidencias SEPA: {len(filas_enriquecidas):,}")
        sys.stdout.flush()

    print(f"\n[OK] Escaneo completado en {time.time() - t0:.1f}s.")
    print(f"[+] Total productos de SEPA enriquecidos con OFF: {len(filas_enriquecidas):,}")

    if not filas_enriquecidas:
        print("[-] No se encontraron coincidencias.")
        return

    # 3. Guardar off_metadata.csv y off_cache.json
    df_off = pd.DataFrame(filas_enriquecidas)
    df_off.to_csv(OFF_METADATA_FILE, index=False, encoding="utf-8")
    print(f"[OK] {OFF_METADATA_FILE.name} generado: {len(df_off):,} registros.")

    # Marcar los EANs que no tuvieron match en el Parquet para no reconsultarlos online
    eans_no_encontrados = eans_sepa - set(cache_dict.keys())
    for ean in eans_no_encontrados:
        cache_dict[ean] = {"encontrado": False, "motivo": "parquet_no_match"}

    with open(OFF_CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache_dict, f, ensure_ascii=False)
    print(f"[OK] {OFF_CACHE_FILE.name} actualizado con {len(cache_dict):,} productos ({len(filas_enriquecidas):,} encontrados, {len(eans_no_encontrados):,} sin match en parquet).")

    # 4. Actualizar catalogo_productos.csv directamente
    if df_cat_orig is not None:
        print(f"[*] Fusionando metadatos en {CATALOGO_FILE.name}...")
        # Eliminar columnas off existentes previas si existían
        cols_off = ["off_nombre", "off_marca", "off_cantidad_str", "off_cantidad_num", "off_imagen", "off_nutriscore", "off_categorias"]
        df_cat_limpio = df_cat_orig.drop(columns=[c for c in cols_off if c in df_cat_orig.columns])
        
        df_cat_final = pd.merge(df_cat_limpio, df_off, on="id_producto", how="left")
        df_cat_final.to_csv(CATALOGO_FILE, index=False, encoding="utf-8")
        con_off = df_cat_final["off_nombre"].notna() & (df_cat_final["off_nombre"] != "")
        print(f"[OK] {CATALOGO_FILE.name} actualizado con éxito: {con_off.sum():,} productos enriquecidos listos para Supabase.")

    return cache_dict

if __name__ == "__main__":
    sincronizar()
