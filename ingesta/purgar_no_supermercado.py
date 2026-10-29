#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
purgar_no_supermercado.py
-------------------------
Purga de raíz todos los artículos y clústeres ajenos al supermercado:
- Libros y papelería escolar
- Indumentaria, calzado y textil
- Marroquinería y bolsos
- Electrónica y telefonía
- Bazar pesado y muebles

Afecta:
1. data/clusters/producto_clusters.csv
2. data/clusters/producto_cluster_items.csv
3. data/processed/catalogo_productos.csv
4. data/processed/precios.csv
5. data/processed/precios_online.csv
"""

import sys
import shutil
import pandas as pd
from pathlib import Path
from datetime import datetime

# Rutas
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
CLUSTERS_DIR = DATA_DIR / "clusters"

from filtro_fmcg import es_producto_supermercado

def ejecutar_purga():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    print("=" * 65)
    print(" PURGA DE PRODUCTOS NO-SUPERMERCADO (LIBROS, ROPA, ELECTRO, ETC.)")
    print("=" * 65)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 1. Purga en Catálogo de Productos
    cat_csv = PROCESSED_DIR / "catalogo_productos.csv"
    eans_validos = set()
    if cat_csv.exists():
        print("[*] Purgando catalogo_productos.csv...")
        df_cat = pd.read_csv(cat_csv, dtype=str)
        cant_inicial = len(df_cat)
        
        # Backup
        shutil.copy2(cat_csv, PROCESSED_DIR / f"catalogo_productos_pre_purga_{timestamp}.csv")
        
        # Filtro FMCG
        mask_valido = df_cat.apply(
            lambda r: es_producto_supermercado(r.get("productos_descripcion", ""), r.get("productos_marca", "")),
            axis=1
        )
        df_cat_limpio = df_cat[mask_valido].copy()
        descartados_cat = cant_inicial - len(df_cat_limpio)
        
        eans_validos = set(df_cat_limpio["id_producto"].dropna().unique())
        df_cat_limpio.to_csv(cat_csv, index=False, encoding="utf-8")
        print(f"[OK] catalogo_productos.csv purgado:")
        print(f"     - Eliminados: {descartados_cat:,} artículos ajenos")
        print(f"     - Conservados: {len(df_cat_limpio):,} productos legítimos de supermercado")

    # 2. Purga en Clústeres e Items de Clúster
    clusters_csv = CLUSTERS_DIR / "producto_clusters.csv"
    items_csv = CLUSTERS_DIR / "producto_cluster_items.csv"

    if clusters_csv.exists() and items_csv.exists():
        print("\n[*] Purgando producto_clusters.csv y producto_cluster_items.csv...")
        df_c = pd.read_csv(clusters_csv, dtype=str)
        df_i = pd.read_csv(items_csv, dtype=str)

        # Backup
        shutil.copy2(clusters_csv, CLUSTERS_DIR / f"producto_clusters_pre_purga_{timestamp}.csv")
        shutil.copy2(items_csv, CLUSTERS_DIR / f"producto_cluster_items_pre_purga_{timestamp}.csv")

        # 1. Filtrar clústeres por nombre canónico
        mask_c = df_c.apply(
            lambda r: es_producto_supermercado(r.get("nombre_canonico", ""), ""),
            axis=1
        )
        df_c_limpio = df_c[mask_c].copy()

        # 2. Filtrar items: solo los que pertenecen al catálogo válido y a clústeres válidos
        cids_validos = set(df_c_limpio["cluster_id"].unique())
        
        if eans_validos:
            mask_i = df_i["cluster_id"].isin(cids_validos) & df_i["id_producto"].isin(eans_validos)
        else:
            mask_i = df_i["cluster_id"].isin(cids_validos)
            
        df_i_limpio = df_i[mask_i].copy()

        # 3. Eliminar clústeres que se quedaron sin items
        cids_con_items = set(df_i_limpio["cluster_id"].unique())
        df_c_limpio = df_c_limpio[df_c_limpio["cluster_id"].isin(cids_con_items)].copy()

        # Guardar
        df_c_limpio.to_csv(clusters_csv, index=False, encoding="utf-8")
        df_i_limpio.to_csv(items_csv, index=False, encoding="utf-8")

        print(f"[OK] Clústeres purgados:")
        print(f"     - Clústeres eliminados: {len(df_c) - len(df_c_limpio):,}")
        print(f"     - Clústeres conservados: {len(df_c_limpio):,}")
        print(f"     - Asociaciones eliminadas: {len(df_i) - len(df_i_limpio):,}")
        print(f"     - Asociaciones conservadas: {len(df_i_limpio):,}")

    # 3. Purga en Precios (Físicos y Online) para mantener integridad
    for nom_precios in ["precios.csv", "precios_online.csv"]:
        f_p = PROCESSED_DIR / nom_precios
        if f_p.exists() and eans_validos:
            print(f"\n[*] Sincronizando integridad en {nom_precios}...")
            df_p = pd.read_csv(f_p, dtype=str)
            p_ini = len(df_p)
            df_p_limpio = df_p[df_p["id_producto"].isin(eans_validos)].copy()
            df_p_limpio.to_csv(f_p, index=False, encoding="utf-8")
            print(f"[OK] {nom_precios}: {p_ini - len(df_p_limpio):,} registros no-supermercado purgados. {len(df_p_limpio):,} conservados.")

    print("\n" + "=" * 65)
    print(" PURGA COMPLETADA: La base de datos es ahora 100% Supermercado (FMCG).")
    print("=" * 65)

if __name__ == "__main__":
    ejecutar_purga()
