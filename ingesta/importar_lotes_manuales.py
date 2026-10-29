#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
importar_lotes_manuales.py
--------------------------
Importa las respuestas JSON generadas manualmente en Gemini (desde la carpeta
ingesta/respuestas/ o un archivo específico) y las sube automáticamente a Supabase:
- Actualiza producto_clusters y producto_cluster_items.
- Registra el modelo como 'gemini-3.5-flash-lite'.
- Actualiza también los archivos locales en data/clusters/.

Uso:
    python importar_lotes_manuales.py --archivo respuestas/respuesta_0001.json
    python importar_lotes_manuales.py --todos   # Procesa todos los archivos en ingesta/respuestas/
"""

import os
import sys
import json
import argparse
import psycopg2
import pandas as pd
from pathlib import Path
from config import BASE_DIR, SUPABASE_DB_URL, CLUSTERS_DIR

RESPUESTAS_DIR = BASE_DIR / "respuestas"
RESPUESTAS_DIR.mkdir(parents=True, exist_ok=True)

def cargar_json(ruta: Path):
    with open(ruta, "r", encoding="utf-8") as f:
        contenido = f.read().strip()
        # Si Gemini devolvió con markdown ```json ... ```, lo limpiamos
        if contenido.startswith("```"):
            lineas = contenido.split("\n")
            if lineas[0].startswith("```"):
                lineas = lineas[1:]
            if lineas and lineas[-1].strip() == "```":
                lineas = lineas[:-1]
            contenido = "\n".join(lineas).strip()
        return json.loads(contenido)

def guardar_local(items: list):
    CLUSTERS_DIR.mkdir(parents=True, exist_ok=True)
    f_items = CLUSTERS_DIR / "producto_cluster_items.csv"
    f_clusters = CLUSTERS_DIR / "producto_clusters.csv"
    
    clusters_dict = {}
    items_rows = []
    
    for it in items:
        cid = str(it.get("cluster_id", "")).strip()
        pid = str(it.get("id_producto", "")).strip()
        if not cid or not pid:
            continue
            
        if cid not in clusters_dict:
            clusters_dict[cid] = {
                "cluster_id": cid,
                "nombre_canonico": str(it.get("nombre_canonico", "")).strip(),
                "categoria": str(it.get("categoria", "General")).strip()
            }
            
        items_rows.append({
            "id_producto": pid,
            "cluster_id": cid,
            "contenido_neto": it.get("contenido_neto"),
            "unidad_referencia": str(it.get("unidad_referencia", "kg")).strip(),
            "confianza": it.get("confianza", 1.0),
            "modelo_ia": "gemini-3.5-flash-lite"
        })
        
    df_new_c = pd.DataFrame(list(clusters_dict.values()))
    df_new_i = pd.DataFrame(items_rows)
    
    if f_clusters.exists():
        df_old_c = pd.read_csv(f_clusters, dtype=str)
        df_new_c = pd.concat([df_old_c, df_new_c]).drop_duplicates(subset=["cluster_id"], keep="last")
    df_new_c.to_csv(f_clusters, index=False)
    
    if f_items.exists():
        df_old_i = pd.read_csv(f_items, dtype=str)
        df_new_i = pd.concat([df_old_i, df_new_i]).drop_duplicates(subset=["id_producto"], keep="last")
    df_new_i.to_csv(f_items, index=False)
    
    print(f"[+] Archivos locales actualizados en {CLUSTERS_DIR}")

def subir_a_supabase(items: list):
    if not SUPABASE_DB_URL:
        print("[-] No se encontró SUPABASE_DB_URL en config.json")
        return
        
    conn = psycopg2.connect(SUPABASE_DB_URL)
    try:
        with conn.cursor() as cur:
            # 1. Upsert producto_clusters
            query_c = """
                INSERT INTO producto_clusters (cluster_id, nombre_canonico, categoria)
                VALUES (%s, %s, %s)
                ON CONFLICT (cluster_id) DO UPDATE SET
                    nombre_canonico = EXCLUDED.nombre_canonico,
                    categoria = EXCLUDED.categoria;
            """
            clusters_vistos = set()
            for it in items:
                cid = str(it.get("cluster_id", "")).strip()
                n_can = str(it.get("nombre_canonico", "")).strip()
                cat = str(it.get("categoria", "General")).strip()
                if cid and cid not in clusters_vistos:
                    cur.execute(query_c, (cid, n_can, cat))
                    clusters_vistos.add(cid)
                    
            # 2. Upsert producto_cluster_items
            query_i = """
                INSERT INTO producto_cluster_items 
                (id_producto, cluster_id, contenido_neto, unidad_referencia, confianza, modelo_ia)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (id_producto) DO UPDATE SET
                    cluster_id = EXCLUDED.cluster_id,
                    contenido_neto = EXCLUDED.contenido_neto,
                    unidad_referencia = EXCLUDED.unidad_referencia,
                    confianza = EXCLUDED.confianza,
                    modelo_ia = EXCLUDED.modelo_ia;
            """
            for it in items:
                pid = str(it.get("id_producto", "")).strip()
                cid = str(it.get("cluster_id", "")).strip()
                c_neto = it.get("contenido_neto")
                u_ref = str(it.get("unidad_referencia", "kg")).strip()
                conf = float(it.get("confianza", 1.0))
                if pid and cid:
                    cur.execute(query_i, (pid, cid, c_neto, u_ref, conf, "gemini-3.5-flash-lite"))
                    
        conn.commit()
        print(f"[OK] {len(items)} productos sincronizados exitosamente en Supabase.")
    finally:
        conn.close()

def procesar_archivo(ruta: Path):
    print(f"\n[*] Procesando respuesta: {ruta.name}...")
    items = cargar_json(ruta)
    if not isinstance(items, list):
        print(f"[-] Formato inválido en {ruta.name}, se esperaba una lista JSON.")
        return
    guardar_local(items)
    subir_a_supabase(items)

def main():
    parser = argparse.ArgumentParser(description="Importa respuestas de Gemini y las sube a Supabase")
    parser.add_argument("--archivo", help="Ruta a un archivo JSON específico de respuesta")
    parser.add_argument("--todos", action="store_true", help="Procesa todos los archivos en ingesta/respuestas/")
    args = parser.parse_args()

    if args.archivo:
        procesar_archivo(Path(args.archivo))
    elif args.todos:
        archivos = sorted(RESPUESTAS_DIR.glob("*.json"))
        if not archivos:
            print(f"[-] No se encontraron archivos .json en {RESPUESTAS_DIR}")
            return
        for f in archivos:
            procesar_archivo(f)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
