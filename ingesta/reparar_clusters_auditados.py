#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
reparar_clusters_auditados.py
------------------------------
Aplica las correcciones dictaminadas por el Auditor de Calidad IA (reporte_auditoria.json):
1. Desasocia intrusos identificados por la IA de sus clústeres incompatibles.
2. Disuelve clústeres calificados como HETEROGÉNEOS no sustituibles (libros, indumentaria genérica, etc.).
3. Corrige nombres canónicos que contenían marcas adheridas.
4. Reclasifica los productos alimenticios expulsados con el motor de 5 dimensiones atómicas.
5. Limpia clústeres huérfanos y actualiza los CSVs oficiales.
"""

import os
import sys
import json
import shutil
import pandas as pd
from pathlib import Path
from datetime import datetime

# Rutas
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
CLUSTERS_DIR = DATA_DIR / "clusters"

REPORTE_JSON = CLUSTERS_DIR / "reporte_auditoria.json"
CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CATALOGO_CSV = PROCESSED_DIR / "catalogo_productos.csv"

from cluster_canonico_builder import construir_cluster_canonico

def ejecutar_reparacion(recluster_expulsados: bool = True):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    print("=" * 65)
    print(" REPARACIÓN Y PURIFICACIÓN DE CLÚSTERES SEGÚN AUDITORÍA IA")
    print("=" * 65)

    if not REPORTE_JSON.exists():
        print(f"[-] No se encontró el archivo de auditoría: {REPORTE_JSON}")
        return

    print("[*] Leyendo reporte de auditoría y tablas de clústeres...")
    with open(REPORTE_JSON, "r", encoding="utf-8") as f:
        reporte = json.load(f)

    df_clusters = pd.read_csv(CLUSTERS_CSV, dtype=str)
    df_items = pd.read_csv(ITEMS_CSV, dtype=str)
    
    df_cat = pd.DataFrame()
    if CATALOGO_CSV.exists():
        df_cat = pd.read_csv(CATALOGO_CSV, dtype=str).set_index("id_producto")

    # Crear copias de seguridad de seguridad
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_clusters = CLUSTERS_DIR / f"producto_clusters_pre_reparacion_{timestamp}.csv"
    backup_items = CLUSTERS_DIR / f"producto_cluster_items_pre_reparacion_{timestamp}.csv"
    shutil.copy2(CLUSTERS_CSV, backup_clusters)
    shutil.copy2(ITEMS_CSV, backup_items)
    print(f"[+] Backup de seguridad creado en: {backup_clusters.name}")

    intrusos_a_remover = set()
    clusters_a_disolver = set()
    renombres_clusters = {}

    for item in reporte:
        cid = item.get("cluster_id")
        estado = item.get("estado")
        score = item.get("coherencia_score", 10)
        tiene_marca = item.get("tiene_marca_en_nombre", False)
        sug_nombre = item.get("sugerencia_nombre")

        # 1. Renombrar si tiene marca en nombre
        if tiene_marca and sug_nombre and sug_nombre.strip():
            renombres_clusters[cid] = sug_nombre.strip()

        # 2. Clústeres heterogéneos insalvables (ej. libros de diferentes títulos, prendas dispares)
        if estado == "HETEROGENEO" and score <= 3 and any(k in cid for k in ["libro", "bandolera", "ropa_prenda", "tintura"]):
            clusters_a_disolver.add(cid)
            continue

        # 3. Remover intrusos específicos
        for intr in item.get("intrusos", []):
            pid = str(intr.get("id_producto", "")).strip()
            if pid:
                intrusos_a_remover.add((cid, pid))

    print(f"[*] Clústeres heterogéneos a disolver:   {len(clusters_a_disolver)}")
    print(f"[*] Intrusos individuales a desasociar: {len(intrusos_a_remover)}")
    print(f"[*] Clústeres a renombrar (sin marca):   {len(renombres_clusters)}")

    # 1. Aplicar renombres de nombres canónicos
    if renombres_clusters:
        for cid, nuevo_nombre in renombres_clusters.items():
            mask = df_clusters["cluster_id"] == cid
            if mask.any():
                df_clusters.loc[mask, "nombre_canonico"] = nuevo_nombre
                print(f"    [Renombrado] Clúster '{cid}' -> '{nuevo_nombre}'")

    # 2. Disolver clústeres heterogéneos
    expulsados_pids = set()
    if clusters_a_disolver:
        mask_items_disolver = df_items["cluster_id"].isin(clusters_a_disolver)
        expulsados_pids.update(df_items.loc[mask_items_disolver, "id_producto"].tolist())
        df_items = df_items[~mask_items_disolver].copy()
        df_clusters = df_clusters[~df_clusters["cluster_id"].isin(clusters_a_disolver)].copy()

    # 3. Remover intrusos específicos
    items_removidos_count = 0
    for cid, pid in intrusos_a_remover:
        mask_item = (df_items["cluster_id"] == cid) & (df_items["id_producto"] == pid)
        if mask_item.any():
            df_items = df_items[~mask_item].copy()
            items_removidos_count += 1
            expulsados_pids.add(pid)

    print(f"[OK] Se removieron {items_removidos_count} asignaciones erróneas de productos intrusos.")

    # 4. Reclasificar productos expulsados con el motor atómico de 5 dimensiones
    nuevos_items = []
    nuevos_clusters = {}

    if recluster_expulsados and expulsados_pids:
        print(f"\n[*] Reclasificando {len(expulsados_pids)} productos con el motor determinista de 5 dimensiones...")
        for pid in expulsados_pids:
            if pid not in df_cat.index:
                continue
            cat_row = df_cat.loc[pid]
            if isinstance(cat_row, pd.DataFrame): cat_row = cat_row.iloc[0]
            
            desc = str(cat_row.get("productos_descripcion") or "").strip()
            marca = str(cat_row.get("productos_marca") or "").strip()
            if not desc:
                continue

            cant_raw = cat_row.get("productos_cantidad_presentacion")
            try:
                cant = float(cant_raw) if cant_raw is not None and str(cant_raw).strip() != "" else 1.0
            except (ValueError, TypeError):
                cant = 1.0

            um = str(cat_row.get("productos_unidad_medida_presentacion") or "un").strip().lower()

            # Extracción y construcción atómica
            canon = construir_cluster_canonico(
                nombre_base=desc,
                variedad_sabor="",
                marca=marca,
                contenido_neto=cant,
                unidad_medida=um,
                pack_unidades=1,
                categoria="Almacén"
            )

            cid_nuevo = canon["cluster_id"]
            if cid_nuevo in clusters_a_disolver:
                # Evitar recrear el clúster disuelto genérico
                cid_nuevo = f"{cid_nuevo}_{pid[:6]}"
                canon["cluster_id"] = cid_nuevo

            nuevos_clusters[cid_nuevo] = {
                "cluster_id": cid_nuevo,
                "nombre_canonico": canon["nombre_canonico"],
                "categoria": canon["categoria"]
            }

            nuevos_items.append({
                "id_producto": pid,
                "cluster_id": cid_nuevo,
                "contenido_neto": canon["contenido_neto"],
                "unidad_referencia": canon["unidad_referencia"],
                "confianza": "0.95",
                "modelo_ia": "reparador-determinista"
            })

    # Integrar nuevos clústeres e items generados
    if nuevos_clusters:
        df_nuevos_c = pd.DataFrame(list(nuevos_clusters.values()))
        df_clusters = pd.concat([df_clusters, df_nuevos_c]).drop_duplicates(subset=["cluster_id"], keep="last")
        print(f"[+] Nuevos clústeres específicos creados: {len(nuevos_clusters)}")

    if nuevos_items:
        df_nuevos_i = pd.DataFrame(nuevos_items)
        df_items = pd.concat([df_items, df_nuevos_i]).drop_duplicates(subset=["id_producto"], keep="last")
        print(f"[+] Productos reasociados limpiamente: {len(nuevos_items)}")

    # 5. Limpiar clústeres huérfanos que hayan quedado sin productos
    cids_con_items = set(df_items["cluster_id"].unique())
    cl_antes = len(df_clusters)
    df_clusters = df_clusters[df_clusters["cluster_id"].isin(cids_con_items)].copy()
    huerfanos = cl_antes - len(df_clusters)
    if huerfanos > 0:
        print(f"[OK] Se depuraron {huerfanos} clústeres huérfanos sin productos asociados.")

    # 6. Guardar CSVs purificados
    df_clusters.to_csv(CLUSTERS_CSV, index=False, encoding="utf-8")
    df_items.to_csv(ITEMS_CSV, index=False, encoding="utf-8")

    print("\n" + "=" * 65)
    print(" PURIFICACIÓN FINALIZADA CON ÉXITO")
    print(f" - Clústeres activos totales: {len(df_clusters):,}")
    print(f" - Productos asociados:       {len(df_items):,}")
    print(f" - Archivos actualizados en:  {CLUSTERS_DIR}")
    print("=" * 65)

if __name__ == "__main__":
    ejecutar_reparacion()
