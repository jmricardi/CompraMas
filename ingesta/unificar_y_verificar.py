#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
unificar_y_verificar.py
------------------------
1. Lee los 100 lotes originales (lote_0001 a lote_0100) y extrae los 5.000 id_producto esperados.
2. Lee y parsea los 100 archivos de respuesta (respuesta_0001 a respuesta_0100).
3. Valida faltantes, duplicados o errores de estructura.
4. Unifica en data/clusters/producto_clusters.csv y producto_cluster_items.csv.
5. Sube todo a Supabase en lotes optimizados (executemany).
"""

import os
import sys
import json
import time
import psycopg2
import pandas as pd
from pathlib import Path
from config import BASE_DIR, CLUSTERS_DIR, SUPABASE_DB_URL

LOTES_DIR = BASE_DIR / "lotes"
RESPUESTAS_DIR = BASE_DIR / "respuestas"

def limpiar_json_texto(texto: str):
    t = texto.strip()
    if t.startswith("```"):
        lineas = t.split("\n")
        if lineas[0].startswith("```"):
            lineas = lineas[1:]
        if lineas and lineas[-1].strip() == "```":
            lineas = lineas[:-1]
        t = "\n".join(lineas).strip()
    return t

def ejecutar_unificacion_y_subida():
    print("==================================================================")
    print(" VERIFICACIÓN, UNIFICACIÓN Y SUBIDA A SUPABASE (100 LOTES)")
    print("==================================================================")

    # 1. Leer lotes originales esperados
    lote_files = sorted(LOTES_DIR.glob("lote_*.json"))
    if not lote_files:
        print("[-] No se encontraron archivos en lotes/")
        return

    esperados_map = {} # id_producto -> info original
    lote_por_id = {}
    for lf in lote_files:
        with open(lf, "r", encoding="utf-8") as f:
            try:
                items = json.load(f)
                for it in items:
                    pid = str(it.get("id", "")).strip()
                    if pid:
                        esperados_map[pid] = it
                        lote_por_id[pid] = lf.name
            except Exception as e:
                print(f"[-] Error leyendo {lf.name}: {e}")

    total_esperados = len(esperados_map)
    print(f"[+] Lotes fuente analizados: {len(lote_files)} archivos")
    print(f"[+] Total productos esperados: {total_esperados:,}")

    # 2. Leer archivos de respuesta
    resp_files = sorted(RESPUESTAS_DIR.glob("respuesta_*.json"))
    print(f"[+] Archivos de respuesta encontrados: {len(resp_files)} archivos")

    respuestas_items = []
    ids_en_respuestas = set()
    archivos_con_error = []
    
    for rf in resp_files:
        with open(rf, "r", encoding="utf-8") as f:
            raw = f.read()
        
        texto_limpio = limpiar_json_texto(raw)
        try:
            data = json.loads(texto_limpio)
            if not isinstance(data, list):
                print(f"[-] {rf.name} no contiene una lista JSON.")
                archivos_con_error.append(rf.name)
                continue
                
            for it in data:
                pid = str(it.get("id_producto", "")).strip()
                cid = str(it.get("cluster_id", "")).strip()
                if pid and cid:
                    respuestas_items.append(it)
                    ids_en_respuestas.add(pid)
                else:
                    print(f"    [!] Registro incompleto en {rf.name}: {it}")
        except Exception as e:
            print(f"[-] Error parseando {rf.name}: {e}")
            archivos_con_error.append(rf.name)

    print(f"\n--- REPORTE DE VERIFICACIÓN DE CÓDIGOS DE BARRA ---")
    print(f"Total registros leídos en respuestas: {len(respuestas_items):,}")
    print(f"Total códigos de barra únicos en respuestas: {len(ids_en_respuestas):,}")

    ids_esperados_set = set(esperados_map.keys())
    faltantes = ids_esperados_set - ids_en_respuestas
    sobrantes = ids_en_respuestas - ids_esperados_set

    if faltantes:
        print(f"[!] ATENCIÓN: Hay {len(faltantes)} códigos de barra esperados que NO están en las respuestas:")
        for f_id in list(faltantes)[:15]:
            l_origen = lote_por_id.get(f_id, "desconocido")
            info = esperados_map.get(f_id, {})
            print(f"    - ID: {f_id} | Lote: {l_origen} | Desc: {info.get('desc')}")
        if len(faltantes) > 15:
            print(f"    ... y {len(faltantes) - 15} más.")
    else:
        print("[OK] ¡VERIFICACIÓN EXITOSA! Todos los 5.000 códigos de barra esperados están incluidos (100% de cobertura).")

    if sobrantes:
        print(f"[i] Códigos presentes en respuestas pero no en los 100 lotes: {len(sobrantes)}")

    # 3. Unificar data local
    print(f"\n[*] Unificando datos en {CLUSTERS_DIR}...")
    CLUSTERS_DIR.mkdir(parents=True, exist_ok=True)
    f_clusters = CLUSTERS_DIR / "producto_clusters.csv"
    f_items = CLUSTERS_DIR / "producto_cluster_items.csv"

    clusters_dict = {}
    items_rows = []

    for it in respuestas_items:
        cid = str(it.get("cluster_id", "")).strip()
        pid = str(it.get("id_producto", "")).strip()
        if not cid or not pid:
            continue

        if cid not in clusters_dict:
            clusters_dict[cid] = {
                "cluster_id": cid,
                "nombre_canonico": str(it.get("nombre_canonico", "")).strip() or cid,
                "categoria": str(it.get("categoria", "General")).strip()
            }

        c_neto = it.get("contenido_neto")
        try:
            c_neto_val = float(c_neto) if c_neto is not None and str(c_neto).strip() != "" else None
        except (ValueError, TypeError):
            c_neto_val = None

        items_rows.append({
            "id_producto": pid,
            "cluster_id": cid,
            "contenido_neto": c_neto_val,
            "unidad_referencia": str(it.get("unidad_referencia", "kg")).strip(),
            "confianza": float(it.get("confianza", 1.0)),
            "modelo_ia": "gemini-3.5-flash-lite"
        })

    df_clusters = pd.DataFrame(list(clusters_dict.values())).drop_duplicates(subset=["cluster_id"], keep="last")
    df_items = pd.DataFrame(items_rows).drop_duplicates(subset=["id_producto"], keep="last")

    df_clusters.to_csv(f_clusters, index=False, encoding="utf-8")
    df_items.to_csv(f_items, index=False, encoding="utf-8")

    print(f"[OK] Archivos locales guardados:")
    print(f"     - {f_clusters.name}: {len(df_clusters):,} clústeres únicos")
    print(f"     - {f_items.name}: {len(df_items):,} productos asociados")

    # 4. Subir a Supabase
    print(f"\n[*] Conectando y subiendo a Supabase...", flush=True)
    if not SUPABASE_DB_URL:
        print("[-] Error: SUPABASE_DB_URL no configurada en config.json", flush=True)
        return

    from psycopg2.extras import execute_values

    t0 = time.time()
    conn = psycopg2.connect(SUPABASE_DB_URL)
    try:
        with conn.cursor() as cur:
            # 1. Upsert producto_clusters en batch con execute_values
            print("[*] Subiendo producto_clusters...", flush=True)
            query_c = """
                INSERT INTO producto_clusters (cluster_id, nombre_canonico, categoria)
                VALUES %s
                ON CONFLICT (cluster_id) DO UPDATE SET
                    nombre_canonico = EXCLUDED.nombre_canonico,
                    categoria = EXCLUDED.categoria;
            """
            records_c = [
                (row["cluster_id"], row["nombre_canonico"], row["categoria"])
                for _, row in df_clusters.iterrows()
            ]
            execute_values(cur, query_c, records_c, page_size=500)
            print(f"[OK] {len(records_c):,} clústeres sincronizados en producto_clusters.", flush=True)

            # 2. Upsert producto_cluster_items en batch con execute_values
            print("[*] Subiendo producto_cluster_items...", flush=True)
            query_i = """
                INSERT INTO producto_cluster_items 
                (id_producto, cluster_id, contenido_neto, unidad_referencia, confianza, modelo_ia)
                VALUES %s
                ON CONFLICT (id_producto) DO UPDATE SET
                    cluster_id = EXCLUDED.cluster_id,
                    contenido_neto = EXCLUDED.contenido_neto,
                    unidad_referencia = EXCLUDED.unidad_referencia,
                    confianza = EXCLUDED.confianza,
                    modelo_ia = EXCLUDED.modelo_ia;
            """
            records_i = [
                (
                    row["id_producto"],
                    row["cluster_id"],
                    row["contenido_neto"],
                    row["unidad_referencia"],
                    row["confianza"],
                    row["modelo_ia"]
                )
                for _, row in df_items.iterrows()
            ]
            execute_values(cur, query_i, records_i, page_size=500)
            print(f"[OK] {len(records_i):,} productos sincronizados en producto_cluster_items.", flush=True)

        conn.commit()
    finally:
        conn.close()

    elapsed = time.time() - t0
    print(f"\n==================================================================")
    print(f"[EXITO TOTAL] Sincronización con Supabase completada en {elapsed:.2f}s.")
    print(f"==================================================================")

if __name__ == "__main__":
    ejecutar_unificacion_y_subida()
