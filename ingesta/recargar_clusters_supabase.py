#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
recargar_clusters_supabase.py
------------------------------
Ejecuta el Método 2:
1. Trunca las tablas de clústeres en Supabase (producto_clusters y producto_cluster_items).
2. Recarga masivamente las versiones limpias 100% FMCG de:
   - data/clusters/producto_clusters.csv (75.442 filas)
   - data/clusters/producto_cluster_items.csv (92.311 filas)
3. Purga de la tabla 'productos' los artículos huérfanos que ya no pertenecen al supermercado
   (libros, ropa, telefonía, etc.).
"""

import sys
import time
import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values
import pandas as pd
from pathlib import Path

# Rutas
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
CLUSTERS_DIR = DATA_DIR / "clusters"

CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CATALOGO_CSV = PROCESSED_DIR / "catalogo_productos.csv"

from config import SUPABASE_DB_URL

def ejecutar_recarga_metodo_2():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    print("=" * 65)
    print(" MÉTODO 2: TRUNCADO Y RECARGA PURIFICADA EN SUPABASE")
    print("=" * 65)

    if not CLUSTERS_CSV.exists() or not ITEMS_CSV.exists():
        print("[-] No se encontraron los archivos locales en data/clusters/")
        return

    if not SUPABASE_DB_URL:
        print("[-] No se encontró SUPABASE_DB_URL en config.json")
        return

    print("[*] Conectando a Supabase PostgreSQL...")
    t0 = time.time()
    try:
        conn = psycopg2.connect(SUPABASE_DB_URL)
    except Exception as e:
        print(f"[-] Error conectando a Supabase: {e}")
        return

    try:
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '300s';")

            # -------------------------------------------------------------
            # PASO 1: Asegurar columnas de 5 elementos y truncar tablas
            # -------------------------------------------------------------
            print("\n[*] [1/4] Preparando esquema de 5 elementos y vaciando clústeres en Supabase...")
            cur.execute("ALTER TABLE public.producto_clusters ADD COLUMN IF NOT EXISTS producto TEXT;")
            cur.execute("ALTER TABLE public.producto_clusters ADD COLUMN IF NOT EXISTS variedad TEXT;")
            cur.execute("ALTER TABLE public.producto_clusters ADD COLUMN IF NOT EXISTS presentacion TEXT;")
            cur.execute("ALTER TABLE public.producto_cluster_items ADD COLUMN IF NOT EXISTS marca TEXT;")
            cur.execute("ALTER TABLE public.producto_cluster_items ADD COLUMN IF NOT EXISTS envase TEXT;")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_producto_clusters_producto ON public.producto_clusters (producto);")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_producto_clusters_prod_var ON public.producto_clusters (producto, variedad);")
            cur.execute("TRUNCATE TABLE producto_clusters CASCADE;")
            conn.commit()
            print("[OK] Esquema de 5 elementos listo y tablas 'producto_clusters' / 'producto_cluster_items' vaciadas.")

            # -------------------------------------------------------------
            # PASO 2: Recarga masiva de producto_clusters
            # -------------------------------------------------------------
            df_c = pd.read_csv(CLUSTERS_CSV, dtype=str)
            print(f"\n[*] [2/4] Recargando 'producto_clusters' ({len(df_c):,} registros)...")
            records_c = [
                (
                    str(r["cluster_id"]).strip(),
                    str(r["nombre_canonico"]).strip(),
                    str(r.get("categoria", "General")).strip() if pd.notna(r.get("categoria")) else "General",
                    str(r.get("producto", "")).strip() if pd.notna(r.get("producto")) else None,
                    str(r.get("variedad", "")).strip() if pd.notna(r.get("variedad")) else None,
                    str(r.get("presentacion", "")).strip() if pd.notna(r.get("presentacion")) else None,
                )
                for _, r in df_c.iterrows()
            ]
            
            chunk_size = 5000
            for i in range(0, len(records_c), chunk_size):
                chunk = records_c[i : i + chunk_size]
                execute_values(
                    cur,
                    "INSERT INTO producto_clusters (cluster_id, nombre_canonico, categoria, producto, variedad, presentacion) VALUES %s;",
                    chunk,
                    page_size=len(chunk)
                )
                sys.stdout.write(f"\r    -> {min(i + chunk_size, len(records_c)):,}/{len(records_c):,} clústeres insertados...")
                sys.stdout.flush()
            conn.commit()
            print(f"\n[OK] 'producto_clusters' recargada al 100% ({len(records_c):,} clústeres).")

            # -------------------------------------------------------------
            # PASO 3: Recarga masiva de producto_cluster_items
            # -------------------------------------------------------------
            df_i = pd.read_csv(ITEMS_CSV, dtype=str)
            print(f"\n[*] [3/4] Recargando 'producto_cluster_items' ({len(df_i):,} registros)...")
            records_i = []
            for _, r in df_i.iterrows():
                cn_raw = r.get("contenido_neto")
                try:
                    cn = float(cn_raw) if pd.notna(cn_raw) and str(cn_raw).strip() != "" else None
                except (ValueError, TypeError):
                    cn = None

                conf_raw = r.get("confianza", 1.0)
                try:
                    conf = float(conf_raw) if pd.notna(conf_raw) else 1.0
                except (ValueError, TypeError):
                    conf = 1.0

                marca_val = str(r.get("marca", "")).strip() if pd.notna(r.get("marca")) and str(r.get("marca")).strip() != "" else None
                envase_val = str(r.get("envase", "")).strip() if pd.notna(r.get("envase")) and str(r.get("envase")).strip() != "" else None

                records_i.append((
                    str(r["id_producto"]).strip(),
                    str(r["cluster_id"]).strip(),
                    marca_val,
                    envase_val,
                    cn,
                    str(r.get("unidad_referencia", "kg")).strip(),
                    conf,
                    str(r.get("modelo_ia", "deterministic-5-elements")).strip()
                ))

            for i in range(0, len(records_i), chunk_size):
                chunk = records_i[i : i + chunk_size]
                execute_values(
                    cur,
                    """INSERT INTO producto_cluster_items 
                       (id_producto, cluster_id, marca, envase, contenido_neto, unidad_referencia, confianza, modelo_ia) 
                       VALUES %s;""",
                    chunk,
                    page_size=len(chunk)
                )
                sys.stdout.write(f"\r    -> {min(i + chunk_size, len(records_i)):,}/{len(records_i):,} asociaciones insertadas...")
                sys.stdout.flush()
            conn.commit()
            print(f"\n[OK] 'producto_cluster_items' recargada al 100% ({len(records_i):,} productos asociados).")

            # -------------------------------------------------------------
            # PASO 4: Purgar artículos no-supermercado de la tabla 'productos'
            # -------------------------------------------------------------
            print("\n[*] [4/4] Purgando artículos no-supermercado de la tabla 'productos'...")
            
            # Identificar EANs descartados comparando con el backup previo a la purga
            backups_cat = sorted(list(PROCESSED_DIR.glob("catalogo_productos_pre_purga_*.csv")), reverse=True)
            eans_a_eliminar = []
            if backups_cat:
                df_pre = pd.read_csv(backups_cat[0], dtype=str, usecols=["id_producto"])
                df_post = pd.read_csv(CATALOGO_CSV, dtype=str, usecols=["id_producto"])
                set_pre = set(df_pre["id_producto"].dropna().str.strip().unique())
                set_post = set(df_post["id_producto"].dropna().str.strip().unique())
                eans_a_eliminar = list(set_pre - set_post)
                print(f"    -> Se identificaron {len(eans_a_eliminar):,} EANs específicos a purgar de 'productos'.")

            eliminados = 0
            if eans_a_eliminar:
                chunk_del = 1000
                for i in range(0, len(eans_a_eliminar), chunk_del):
                    c_eans = eans_a_eliminar[i : i + chunk_del]
                    cur.execute("DELETE FROM productos WHERE id_producto = ANY(%s);", (c_eans,))
                    eliminados += cur.rowcount
                    sys.stdout.write(f"\r    -> {min(i + chunk_del, len(eans_a_eliminar)):,}/{len(eans_a_eliminar):,} eliminados...")
                    sys.stdout.flush()
                conn.commit()
                print(f"\n[OK] {eliminados:,} artículos ajenos eliminados de la tabla 'productos' por clave primaria.")
            else:
                print("    [*] No se detectaron EANs pendientes de eliminación.")

            # Estadísticas finales de verificación
            cur.execute("SELECT COUNT(*) FROM producto_clusters;")
            total_c_remoto = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM producto_cluster_items;")
            total_i_remoto = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM productos;")
            total_p_remoto = cur.fetchone()[0]

    finally:
        conn.close()

    duracion = time.time() - t0
    print("\n" + "=" * 65)
    print(f" SUPABASE SINCRONIZADO Y PURIFICADO EN {duracion:.1f}s")
    print(f" - producto_clusters:      {total_c_remoto:,} clústeres legítimos")
    print(f" - producto_cluster_items: {total_i_remoto:,} productos clasificados")
    print(f" - productos en catálogo:  {total_p_remoto:,} productos activos de supermercado")
    print("=" * 65)

if __name__ == "__main__":
    ejecutar_recarga_metodo_2()
