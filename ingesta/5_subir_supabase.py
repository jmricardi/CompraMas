#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
5_subir_supabase.py
-------------------
Carga y sincroniza las tablas procesadas y los clústeres de IA en Supabase:
- Crea las tablas de clústeres si no existen.
- Carga incrementalmente producto_clusters y producto_cluster_items.
- Carga o actualiza comercio, sucursales, productos y precios.
"""

import os
import sys
import io
import csv
import json
import argparse
import time
import requests
import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values
import pandas as pd
from pathlib import Path
from config import (
    SUPABASE_DB_URL,
    SUPABASE_URL,
    SUPABASE_KEY,
    RAW_DIR,
    PROCESSED_DIR,
    CLUSTERS_DIR,
)

DDL_CLUSTERS = """
CREATE TABLE IF NOT EXISTS producto_clusters (
    cluster_id TEXT PRIMARY KEY,
    nombre_canonico TEXT NOT NULL,
    categoria TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS producto_cluster_items (
    id_producto TEXT PRIMARY KEY,
    cluster_id TEXT NOT NULL REFERENCES producto_clusters(cluster_id) ON DELETE CASCADE,
    contenido_neto NUMERIC,
    unidad_referencia TEXT,
    confianza NUMERIC(3,2) DEFAULT 1.0,
    modelo_ia TEXT DEFAULT 'gemini-3.5-flash-lite',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cluster_items_cluster_id ON producto_cluster_items(cluster_id);
"""

def obtener_conexion():
    if not SUPABASE_DB_URL:
        raise ValueError("No se encontró cadena de conexión a Supabase en config.json")
    return psycopg2.connect(SUPABASE_DB_URL)

def inicializar_tablas_clusters(conn):
    print("[*] Verificando tablas y schema extendido en Supabase...")
    with conn.cursor() as cur:
        # Clústeres
        cur.execute(DDL_CLUSTERS)
        cur.execute("ALTER TABLE producto_cluster_items ADD COLUMN IF NOT EXISTS contenido_neto NUMERIC;")
        cur.execute("ALTER TABLE producto_cluster_items ADD COLUMN IF NOT EXISTS unidad_referencia TEXT;")
        cur.execute("ALTER TABLE producto_cluster_items ADD COLUMN IF NOT EXISTS modelo_ia TEXT DEFAULT 'gemini-3.5-flash-lite';")
        
        # Productos (nuevas columnas OFF)
        cur.execute("ALTER TABLE productos ADD COLUMN IF NOT EXISTS imagen_url TEXT;")
        cur.execute("ALTER TABLE productos ADD COLUMN IF NOT EXISTS marca_oficial TEXT;")
        cur.execute("ALTER TABLE productos ADD COLUMN IF NOT EXISTS nutriscore TEXT;")
        cur.execute("ALTER TABLE productos ADD COLUMN IF NOT EXISTS origen_datos TEXT DEFAULT 'sepa';")
        
        # Precios Online
        cur.execute("""
            CREATE TABLE IF NOT EXISTS precios_online (
                id SERIAL PRIMARY KEY,
                id_producto TEXT,
                id_entidad TEXT,
                precio NUMERIC(10,2),
                stock BOOLEAN DEFAULT TRUE,
                url TEXT,
                fecha_captura TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                nombre_scraper TEXT,
                UNIQUE(id_producto, id_entidad, fecha_captura)
            );
        """)
        
        # Precios Mayoristas
        cur.execute("""
            CREATE TABLE IF NOT EXISTS precios_mayoristas (
                id SERIAL PRIMARY KEY,
                id_producto TEXT,
                id_entidad TEXT,
                precio_unitario NUMERIC(10,2),
                precio_bulto NUMERIC(10,2),
                cantidad_bulto NUMERIC,
                stock BOOLEAN DEFAULT TRUE,
                url TEXT,
                fecha_captura TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                nombre_scraper TEXT,
                UNIQUE(id_producto, id_entidad, fecha_captura)
            );
        """)
        
        # Sucursales Rectificadas (Maestro inmutable de coordenadas verificadas)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS sucursales_rectificadas (
                id_entidad TEXT NOT NULL,
                id_sucursal TEXT NOT NULL,
                sucursales_nombre TEXT,
                sucursales_domicilio TEXT,
                latitud_original NUMERIC,
                longitud_original NUMERIC,
                latitud_rectificada NUMERIC NOT NULL,
                longitud_rectificada NUMERIC NOT NULL,
                distancia_ajuste_metros NUMERIC,
                fuente_rectificacion TEXT NOT NULL,
                fecha_rectificacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                PRIMARY KEY (id_entidad, id_sucursal)
            );
            CREATE INDEX IF NOT EXISTS idx_sucursales_rectificadas_pk ON sucursales_rectificadas(id_entidad, id_sucursal);
        """)

        # Tabla Combustibles (Precios en surtidor Secretaría de Energía Res. 314/2016)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS combustibles (
                id SERIAL PRIMARY KEY,
                idempresa INTEGER,
                cuit VARCHAR(30),
                empresa TEXT,
                direccion TEXT,
                localidad TEXT,
                provincia TEXT,
                region TEXT,
                idproducto INTEGER,
                producto TEXT,
                idtipohorario INTEGER,
                tipohorario VARCHAR(50),
                precio NUMERIC(10,2),
                fecha_vigencia TIMESTAMP WITH TIME ZONE,
                idempresabandera INTEGER,
                empresabandera TEXT,
                latitud NUMERIC(10,6),
                longitud NUMERIC(10,6),
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_combustibles_coords ON combustibles(latitud, longitud);
            CREATE INDEX IF NOT EXISTS idx_combustibles_producto ON combustibles(idproducto);
            CREATE INDEX IF NOT EXISTS idx_combustibles_bandera ON combustibles(empresabandera);
        """)

        # Tabla Folletos y Catálogos Semanales
        cur.execute("""
            CREATE TABLE IF NOT EXISTS folletos (
                id TEXT PRIMARY KEY,
                cadena TEXT NOT NULL,
                tipo_comercio TEXT DEFAULT 'minorista',
                titulo TEXT NOT NULL,
                fecha_desde DATE,
                fecha_hasta DATE,
                portada_url TEXT NOT NULL,
                visor_url TEXT,
                activo BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_folletos_activo ON folletos(activo);
            CREATE INDEX IF NOT EXISTS idx_folletos_cadena ON folletos(cadena);
            CREATE INDEX IF NOT EXISTS idx_folletos_fechas ON folletos(fecha_desde, fecha_hasta);
            ALTER TABLE folletos ADD COLUMN IF NOT EXISTS paginas_urls JSONB DEFAULT '[]'::jsonb;
        """)

        # Tabla Ofertas Semanales Individuales
        cur.execute("""
            CREATE TABLE IF NOT EXISTS ofertas_semanales (
                id TEXT PRIMARY KEY,
                folleto_id TEXT REFERENCES folletos(id) ON DELETE CASCADE,
                cadena TEXT NOT NULL,
                titulo TEXT NOT NULL,
                marca TEXT,
                presentacion TEXT,
                precio_oferta NUMERIC(10,2) NOT NULL,
                precio_anterior NUMERIC(10,2),
                descuento_porcentaje INTEGER,
                numero_pagina INTEGER,
                imagen_recorte_url TEXT,
                valido_desde DATE,
                valido_hasta DATE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_ofertas_semanales_cadena ON ofertas_semanales(cadena);
            CREATE INDEX IF NOT EXISTS idx_ofertas_semanales_validez ON ofertas_semanales(valido_hasta);
            CREATE INDEX IF NOT EXISTS idx_ofertas_semanales_descuento ON ofertas_semanales(descuento_porcentaje DESC);
        """)

        # Bucket de Storage para portadas de folletos
        cur.execute("""
            INSERT INTO storage.buckets (id, name, public)
            VALUES ('folletos', 'folletos', true)
            ON CONFLICT (id) DO UPDATE SET public = true;
        """)

        # Función RPC de cálculo geográfico de sucursales con distancia y código postal
        cur.execute("""
            CREATE OR REPLACE FUNCTION get_branches_with_distance(
                p_lat double precision, 
                p_lon double precision, 
                p_suc_ids text[]
            ) 
            RETURNS TABLE(
                id_sucursal text, 
                id_entidad text, 
                sucursales_nombre text, 
                sucursales_domicilio_completo text, 
                sucursales_latitud numeric, 
                sucursales_longitud numeric, 
                distance_meters double precision,
                codigo_postal text
            ) 
            LANGUAGE plpgsql 
            AS $$
            BEGIN
                IF p_lat IS NOT NULL AND p_lon IS NOT NULL THEN
                    RETURN QUERY
                    SELECT 
                        s.id_sucursal::text,
                        s.id_entidad::text,
                        s.sucursales_nombre,
                        s.sucursales_domicilio_completo,
                        s.sucursales_latitud,
                        s.sucursales_longitud,
                        (6371000.0 * acos(
                            least(1.0, greatest(-1.0,
                                cos(radians(p_lat)) * cos(radians(s.sucursales_latitud::double precision)) * 
                                cos(radians(s.sucursales_longitud::double precision) - radians(p_lon)) + 
                                sin(radians(p_lat)) * sin(radians(s.sucursales_latitud::double precision))
                            ))
                        )) AS distance_meters,
                        s.codigo_postal::text
                    FROM public.sucursales s
                    WHERE (p_suc_ids IS NULL OR cardinality(p_suc_ids) = 0 OR s.id_sucursal = ANY(p_suc_ids))
                      AND s.sucursales_latitud IS NOT NULL
                      AND s.sucursales_longitud IS NOT NULL
                    ORDER BY distance_meters ASC;
                ELSE
                    RETURN QUERY
                    SELECT 
                        s.id_sucursal::text,
                        s.id_entidad::text,
                        s.sucursales_nombre,
                        s.sucursales_domicilio_completo,
                        s.sucursales_latitud,
                        s.sucursales_longitud,
                        NULL::double precision AS distance_meters,
                        s.codigo_postal::text
                    FROM public.sucursales s
                    WHERE (p_suc_ids IS NULL OR cardinality(p_suc_ids) = 0 OR s.id_sucursal = ANY(p_suc_ids));
                END IF;
            END;
            $$;
        """)

        # Habilitar RLS y Políticas de lectura pública
        cur.execute("ALTER TABLE precios_online ENABLE ROW LEVEL SECURITY;")
        cur.execute("ALTER TABLE precios_mayoristas ENABLE ROW LEVEL SECURITY;")
        cur.execute("ALTER TABLE sucursales_rectificadas ENABLE ROW LEVEL SECURITY;")
        cur.execute("ALTER TABLE combustibles ENABLE ROW LEVEL SECURITY;")
        cur.execute("ALTER TABLE folletos ENABLE ROW LEVEL SECURITY;")
        cur.execute("ALTER TABLE ofertas_semanales ENABLE ROW LEVEL SECURITY;")
        cur.execute("""
            DO $$ 
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = 'precios_online' AND policyname = 'Lectura publica precios online'
                ) THEN
                    CREATE POLICY "Lectura publica precios online" 
                    ON precios_online FOR SELECT TO public USING (true);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = 'precios_mayoristas' AND policyname = 'Lectura publica precios mayoristas'
                ) THEN
                    CREATE POLICY "Lectura publica precios mayoristas" 
                    ON precios_mayoristas FOR SELECT TO public USING (true);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = 'sucursales_rectificadas' AND policyname = 'Lectura publica sucursales rectificadas'
                ) THEN
                    CREATE POLICY "Lectura publica sucursales rectificadas" 
                    ON sucursales_rectificadas FOR SELECT TO public USING (true);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = 'combustibles' AND policyname = 'Lectura publica combustibles'
                ) THEN
                    CREATE POLICY "Lectura publica combustibles" 
                    ON combustibles FOR SELECT TO public USING (true);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = 'folletos' AND policyname = 'Lectura publica folletos'
                ) THEN
                    CREATE POLICY "Lectura publica folletos" 
                    ON folletos FOR SELECT TO public USING (true);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = 'ofertas_semanales' AND policyname = 'Lectura publica ofertas semanales'
                ) THEN
                    CREATE POLICY "Lectura publica ofertas semanales" 
                    ON ofertas_semanales FOR SELECT TO public USING (true);
                END IF;
                IF NOT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir upload publico en folletos'
                ) THEN
                    CREATE POLICY "Permitir upload publico en folletos" ON storage.objects
                    FOR ALL TO public
                    USING (bucket_id = 'folletos')
                    WITH CHECK (bucket_id = 'folletos');
                END IF;
            END $$;
        """)

        f_rpc = Path(__file__).resolve().parent / "crear_rpc_combustibles.sql"
        if f_rpc.exists():
            with open(f_rpc, "r", encoding="utf-8") as f:
                cur.execute(f.read())
    conn.commit()
    print("[OK] Esquema extendido, RLS y RPC get_combustibles_cercanos verificados.")

def subir_clusters(conn, clusters_dir: Path, truncar: bool = True):
    print("[*] Subiendo clústeres a Supabase vía lotes optimizados (execute_values)...")
    t0 = time.time()
    f_clusters = clusters_dir / "producto_clusters.csv"
    f_items = clusters_dir / "producto_cluster_items.csv"
    
    if not f_clusters.exists() or not f_items.exists():
        print("[-] No se encontraron archivos de clústeres en data/clusters/")
        return
        
    chunk_size = 2000

    # 1. Upsert masivo producto_clusters
    print("    [1/2] Sincronizando producto_clusters...")
    df_c = pd.read_csv(f_clusters, dtype=str)
    records_c = [
        (
            str(row["cluster_id"]).strip(),
            str(row["nombre_canonico"]).strip(),
            str(row.get("categoria", "General")).strip() if pd.notna(row.get("categoria")) else "General",
            str(row.get("producto", "")).strip() if pd.notna(row.get("producto")) else None,
            str(row.get("variedad", "")).strip() if pd.notna(row.get("variedad")) else None,
            str(row.get("presentacion", "")).strip() if pd.notna(row.get("presentacion")) else None,
        )
        for _, row in df_c.iterrows()
    ]
    total_c = len(records_c)

    with conn.cursor() as cur:
        cur.execute("SET statement_timeout = '120s';")
        cur.execute("ALTER TABLE public.producto_clusters ADD COLUMN IF NOT EXISTS producto TEXT;")
        cur.execute("ALTER TABLE public.producto_clusters ADD COLUMN IF NOT EXISTS variedad TEXT;")
        cur.execute("ALTER TABLE public.producto_clusters ADD COLUMN IF NOT EXISTS presentacion TEXT;")
        cur.execute("ALTER TABLE public.producto_cluster_items ADD COLUMN IF NOT EXISTS marca TEXT;")
        cur.execute("ALTER TABLE public.producto_cluster_items ADD COLUMN IF NOT EXISTS envase TEXT;")
        if truncar:
            print("    [!] Truncando tablas de clústeres obsoletos para carga limpia...")
            cur.execute("TRUNCATE TABLE public.producto_cluster_items, public.producto_clusters CASCADE;")
    conn.commit()
    
    query_c = """
        INSERT INTO producto_clusters (cluster_id, nombre_canonico, categoria, producto, variedad, presentacion)
        VALUES %s
        ON CONFLICT (cluster_id) DO UPDATE SET
            nombre_canonico = EXCLUDED.nombre_canonico,
            categoria = EXCLUDED.categoria,
            producto = EXCLUDED.producto,
            variedad = EXCLUDED.variedad,
            presentacion = EXCLUDED.presentacion
        WHERE producto_clusters.nombre_canonico IS DISTINCT FROM EXCLUDED.nombre_canonico
           OR producto_clusters.categoria IS DISTINCT FROM EXCLUDED.categoria
           OR producto_clusters.producto IS DISTINCT FROM EXCLUDED.producto
           OR producto_clusters.variedad IS DISTINCT FROM EXCLUDED.variedad
           OR producto_clusters.presentacion IS DISTINCT FROM EXCLUDED.presentacion;
    """
    
    for i in range(0, total_c, chunk_size):
        chunk = records_c[i:i + chunk_size]
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '120s';")
            execute_values(cur, query_c, chunk, page_size=len(chunk))
        conn.commit()
        print(f"\r        -> {min(i + chunk_size, total_c):,}/{total_c:,} clústeres procesados...", end="", flush=True)
    print("\n    [OK] Clústeres sincronizados.")

    # 2. Upsert masivo producto_cluster_items
    print("    [2/2] Sincronizando producto_cluster_items...")
    df_i = pd.read_csv(f_items, dtype=str)
    records_i = [
        (
            str(row["id_producto"]).strip(),
            str(row["cluster_id"]).strip(),
            str(row.get("marca", "")).strip() if pd.notna(row.get("marca")) and str(row.get("marca")).strip() != "" else None,
            str(row.get("envase", "")).strip() if pd.notna(row.get("envase")) and str(row.get("envase")).strip() != "" else None,
            float(row["contenido_neto"]) if pd.notna(row.get("contenido_neto")) and str(row.get("contenido_neto")).strip() != "" else None,
            str(row.get("unidad_referencia", "kg")).strip(),
            float(row.get("confianza", 1.0)) if pd.notna(row.get("confianza")) else 1.0,
            str(row.get("modelo_ia", "deterministic-5-elements")).strip()
        )
        for _, row in df_i.iterrows()
    ]
    total_i = len(records_i)
    
    query_i = """
        INSERT INTO producto_cluster_items (
            id_producto, cluster_id, marca, envase, contenido_neto, unidad_referencia, confianza, modelo_ia
        )
        VALUES %s
        ON CONFLICT (id_producto) DO UPDATE SET
            cluster_id = EXCLUDED.cluster_id,
            marca = EXCLUDED.marca,
            envase = EXCLUDED.envase,
            contenido_neto = EXCLUDED.contenido_neto,
            unidad_referencia = EXCLUDED.unidad_referencia,
            confianza = EXCLUDED.confianza,
            modelo_ia = EXCLUDED.modelo_ia
        WHERE producto_cluster_items.cluster_id IS DISTINCT FROM EXCLUDED.cluster_id
           OR producto_cluster_items.marca IS DISTINCT FROM EXCLUDED.marca
           OR producto_cluster_items.envase IS DISTINCT FROM EXCLUDED.envase
           OR producto_cluster_items.contenido_neto IS DISTINCT FROM EXCLUDED.contenido_neto
           OR producto_cluster_items.unidad_referencia IS DISTINCT FROM EXCLUDED.unidad_referencia;
    """
    
    for i in range(0, total_i, chunk_size):
        chunk = records_i[i:i + chunk_size]
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '120s';")
            execute_values(cur, query_i, chunk, page_size=len(chunk))
        conn.commit()
        print(f"\r        -> {min(i + chunk_size, total_i):,}/{total_i:,} productos asociados...", end="", flush=True)
    print("\n    [OK] Asociaciones de productos sincronizadas.")
    
    elapsed = time.time() - t0
    print(f"[OK] Clústeres y asociaciones subidos en {elapsed:.1f}s.")

def subir_productos_incremental(conn, csv_path: Path):
    """Sube productos a Supabase mediante UPSERT vía execute_values por bloques para preservar histórico y evitar timeouts."""
    if not csv_path.exists():
        print(f"[-] Archivo no encontrado: {csv_path}")
        return
        
    print(f"[*] Sincronizando {csv_path.name} en tabla 'productos' (UPSERT incremental por bloques)...")
    t0 = time.time()
    chunk_size = 2000
    
    def parse_numeric(val):
        if pd.isna(val):
            return None
        s = str(val).strip().replace(",", ".")
        if not s:
            return None
        try:
            return float(s)
        except ValueError:
            return None

    df_p = pd.read_csv(csv_path, dtype=str)

    def sanitizar_descripcion(row):
        d = str(row.get("productos_descripcion", "")).strip() if pd.notna(row.get("productos_descripcion")) else ""
        if d and d != "nan":
            return d
        off_n = str(row.get("off_nombre", "")).strip() if pd.notna(row.get("off_nombre")) else ""
        if off_n and off_n != "nan":
            return off_n
        marca = str(row.get("productos_marca", "")).strip() if pd.notna(row.get("productos_marca")) else ""
        if marca and marca != "nan":
            return marca
        return f"Producto {str(row.get('id_producto', '')).strip()}"

    records_p = [
        (
            str(row["id_producto"]).strip(),
            bool(str(row["productos_ean"]).strip() == "1") if pd.notna(row.get("productos_ean")) else False,
            sanitizar_descripcion(row),
            str(row["productos_marca"]).strip() if pd.notna(row.get("productos_marca")) and str(row.get("productos_marca")).strip() not in ("", "nan") else None,
            parse_numeric(row.get("productos_cantidad_presentacion")),
            str(row["productos_unidad_medida_presentacion"]).strip() if pd.notna(row.get("productos_unidad_medida_presentacion")) and str(row.get("productos_unidad_medida_presentacion")).strip() not in ("", "nan") else None,
            str(row.get("off_imagen")).strip() if pd.notna(row.get("off_imagen")) and str(row.get("off_imagen")).strip() not in ("", "nan") else None,
            str(row.get("off_marca")).strip() if pd.notna(row.get("off_marca")) and str(row.get("off_marca")).strip() not in ("", "nan") else None,
            str(row.get("off_nutriscore")).strip() if pd.notna(row.get("off_nutriscore")) and str(row.get("off_nutriscore")).strip() not in ("", "nan") else None,
            'sepa+off' if pd.notna(row.get("off_nombre")) and str(row.get("off_nombre")).strip() not in ("", "nan") else 'sepa'
        )
        for _, row in df_p.iterrows()
    ]
    total_p = len(records_p)
    
    query_p = """
        INSERT INTO productos (
            id_producto, productos_ean, productos_descripcion, productos_marca,
            productos_cantidad_presentacion, productos_unidad_medida_presentacion,
            imagen_url, marca_oficial, nutriscore, origen_datos
        )
        VALUES %s
        ON CONFLICT (id_producto) DO UPDATE SET
            productos_ean = COALESCE(EXCLUDED.productos_ean, productos.productos_ean),
            productos_descripcion = COALESCE(EXCLUDED.productos_descripcion, productos.productos_descripcion),
            productos_marca = COALESCE(EXCLUDED.productos_marca, productos.productos_marca),
            productos_cantidad_presentacion = COALESCE(EXCLUDED.productos_cantidad_presentacion, productos.productos_cantidad_presentacion),
            productos_unidad_medida_presentacion = COALESCE(EXCLUDED.productos_unidad_medida_presentacion, productos.productos_unidad_medida_presentacion),
            imagen_url = COALESCE(EXCLUDED.imagen_url, productos.imagen_url),
            marca_oficial = COALESCE(EXCLUDED.marca_oficial, productos.marca_oficial),
            nutriscore = COALESCE(EXCLUDED.nutriscore, productos.nutriscore),
            origen_datos = EXCLUDED.origen_datos
        WHERE productos.productos_descripcion IS DISTINCT FROM EXCLUDED.productos_descripcion
           OR productos.productos_marca IS DISTINCT FROM EXCLUDED.productos_marca
           OR productos.productos_ean IS DISTINCT FROM EXCLUDED.productos_ean
           OR productos.productos_cantidad_presentacion IS DISTINCT FROM EXCLUDED.productos_cantidad_presentacion
           OR productos.imagen_url IS DISTINCT FROM EXCLUDED.imagen_url;
    """

    for i in range(0, total_p, chunk_size):
        chunk = records_p[i:i + chunk_size]
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '120s';")
            execute_values(cur, query_p, chunk, page_size=len(chunk))
        conn.commit()
        print(f"\r        -> {min(i + chunk_size, total_p):,}/{total_p:,} productos sincronizados...", end="", flush=True)
    print()
    elapsed = time.time() - t0
    print(f"[OK] Tabla 'productos' sincronizada incrementalmente en {elapsed:.1f}s (sin borrar productos históricos).")

def subir_tabla_csv(conn, csv_path: Path, tabla_destino: str, columnas: list = None, truncar: bool = False):
    if not csv_path.exists():
        print(f"[-] Archivo no encontrado: {csv_path}")
        return
        
    print(f"[*] Subiendo {csv_path.name} a tabla '{tabla_destino}'...")
    t0 = time.time()
    
    with conn.cursor() as cur:
        # statement_timeout a 900s (15 min) para cargas masivas de precios
        cur.execute("SET statement_timeout = '900s';")
        if tabla_destino == "sucursales":
            cur.execute("ALTER TABLE public.sucursales ADD COLUMN IF NOT EXISTS codigo_georeferencia VARCHAR(50) DEFAULT 'COORDENADA_EXACTA';")
            cur.execute("ALTER TABLE public.sucursales ADD COLUMN IF NOT EXISTS codigo_postal VARCHAR(10);")
        if truncar:
            print(f"    [!] Truncando tabla {tabla_destino}...")
            cur.execute(sql.SQL("TRUNCATE TABLE {} CASCADE;").format(sql.Identifier(tabla_destino)))
            
        with open(csv_path, "r", encoding="utf-8") as f:
            header = f.readline().strip().split(",")
            cols_to_copy = columnas or header
            f.seek(0)

            # Blindaje de integridad referencial para tablas con FK
            # Nota: 'precios' tiene FK a 'productos' y 'comercio'.
            # 'precios_online' y 'precios_mayoristas' tienen FK solo a 'productos', mientras que su 'id_entidad'
            # usa identificadores de canal e-commerce ('carrefour', 'dia', 'coto', 'maxiconsumo', etc.).
            if tabla_destino in ("precios", "precios_online", "precios_mayoristas"):
                cur.execute("SELECT id_producto FROM productos;")
                productos_validos = set(r[0] for r in cur.fetchall())
                
                comercios_validos = None
                if tabla_destino == "precios":
                    cur.execute("SELECT id_entidad FROM comercio;")
                    comercios_validos = set(r[0] for r in cur.fetchall())
                
                reader = csv.reader(f)
                hdr = next(reader)
                id_prod_idx = hdr.index("id_producto") if "id_producto" in hdr else -1
                id_ent_idx = hdr.index("id_entidad") if "id_entidad" in hdr else -1
                
                s_buf = io.StringIO()
                writer = csv.writer(s_buf)
                writer.writerow(hdr)
                
                descartados_prod = 0
                descartados_com = 0
                for row in reader:
                    if not row:
                        continue
                    if id_prod_idx != -1 and len(row) > id_prod_idx:
                        if row[id_prod_idx].strip() not in productos_validos:
                            descartados_prod += 1
                            continue
                    if comercios_validos is not None and id_ent_idx != -1 and len(row) > id_ent_idx:
                        if row[id_ent_idx].strip() not in comercios_validos:
                            descartados_com += 1
                            continue
                    writer.writerow(row)
                
                if descartados_prod > 0 or descartados_com > 0:
                    detalles = []
                    if descartados_prod > 0:
                        detalles.append(f"{descartados_prod:,} por producto inexistente")
                    if descartados_com > 0:
                        detalles.append(f"{descartados_com:,} por comercio inexistente")
                    print(f"    [!] Integridad referencial: {', '.join(detalles)}.")
                
                # Optimización de carga masiva para la tabla 'precios' (>800k registros):
                # 1. Quitar índices secundarios y FKs para que COPY sea ultrarrápido y no verifique fila por fila
                # 2. Recrear índices y FKs al finalizar la carga
                if tabla_destino == "precios":
                    print("    [*] Desactivando temporalmente índices y FKs de 'precios' para carga ultrarrápida...")
                    cur.execute("ALTER TABLE public.precios DROP CONSTRAINT IF EXISTS fk_precios_producto;")
                    cur.execute("ALTER TABLE public.precios DROP CONSTRAINT IF EXISTS fk_precios_comercio;")
                    cur.execute("DROP INDEX IF EXISTS idx_precios_id_entidad;")
                    cur.execute("DROP INDEX IF EXISTS idx_precios_producto_precio;")

                s_buf.seek(0)
                cur.copy_expert(
                    sql.SQL("COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');").format(
                        sql.Identifier(tabla_destino),
                        sql.SQL(", ").join([sql.Identifier(c) for c in cols_to_copy])
                    ),
                    s_buf
                )

                if tabla_destino == "precios":
                    print("    [*] Reconstruyendo índices y restricciones de clave foránea en 'precios'...")
                    cur.execute("""
                        ALTER TABLE public.precios 
                        ADD CONSTRAINT fk_precios_comercio 
                        FOREIGN KEY (id_entidad) REFERENCES comercio(id_entidad) ON DELETE CASCADE;
                    """)
                    cur.execute("""
                        ALTER TABLE public.precios 
                        ADD CONSTRAINT fk_precios_producto 
                        FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE;
                    """)
                    cur.execute("CREATE INDEX IF NOT EXISTS idx_precios_id_entidad ON public.precios USING btree (id_entidad);")
                    cur.execute("CREATE INDEX IF NOT EXISTS idx_precios_producto_precio ON public.precios USING btree (id_producto, productos_precio_lista);")
            else:
                cur.copy_expert(
                    sql.SQL("COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');").format(
                        sql.Identifier(tabla_destino),
                        sql.SQL(", ").join([sql.Identifier(c) for c in cols_to_copy])
                    ),
                    f
                )
    conn.commit()
    elapsed = time.time() - t0
    print(f"[OK] {tabla_destino} actualizado en {elapsed:.1f}s.")

def subir_folletos_y_ofertas(conn):
    print("\n[*] Sincronizando Folletos y Ofertas Semanales en Supabase...")
    t0 = time.time()
    f_folletos = PROCESSED_DIR / "folletos.csv"
    f_ofertas = PROCESSED_DIR / "ofertas_semanales.csv"
    dir_portadas = RAW_DIR / "folletos"

    if not f_folletos.exists():
        print("[-] No se encontró data/processed/folletos.csv")
        return

    df_folletos = pd.read_csv(f_folletos)
    
    def optimizar_archivo_folleto(archivo: Path) -> tuple:
        """
        Optimiza imágenes a WebP (resolución retina max 1400px, 82% quality)
        para acceso fluido y ligero en Flutter, y retorna (archivo_final, content_type).
        """
        ext = archivo.suffix.lower()
        if ext in (".jpg", ".jpeg", ".png"):
            webp_path = archivo.with_suffix(".webp")
            if not webp_path.exists() or webp_path.stat().st_size < 1000:
                try:
                    from PIL import Image
                    with Image.open(archivo) as im:
                        im_rgb = im.convert("RGB")
                        im_rgb.thumbnail((1400, 2000), Image.Resampling.LANCZOS)
                        im_rgb.save(webp_path, "WEBP", quality=82, method=6)
                except Exception:
                    return archivo, "image/jpeg"
            return webp_path, "image/webp"
        elif ext == ".webp":
            return archivo, "image/webp"
        elif ext == ".pdf":
            return archivo, "application/pdf"
        return archivo, "application/octet-stream"

    cache_storage_urls = {}

    # Sesión HTTP persistente con reintentos para evitar microcortes SSL
    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util.retry import Retry

    session_storage = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["POST", "PUT"]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session_storage.mount("https://", adapter)
    session_storage.mount("http://", adapter)

    def subir_recurso_storage(file_path: Path) -> str:
        if file_path.name in cache_storage_urls:
            return cache_storage_urls[file_path.name]
        archivo_opt, content_type = optimizar_archivo_folleto(file_path)
        storage_url = f"{SUPABASE_URL}/storage/v1/object/folletos/{archivo_opt.name}"
        h_st = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": content_type,
            "x-upsert": "true",
        }
        
        # Intentos con reintento explícito ante microcortes SSL/red
        datos_bytes = archivo_opt.read_bytes()
        for intento in range(3):
            try:
                r_up = session_storage.post(storage_url, headers=h_st, data=datos_bytes, timeout=45)
                if r_up.status_code in (200, 201):
                    pub_url = f"{SUPABASE_URL}/storage/v1/object/public/folletos/{archivo_opt.name}"
                    cache_storage_urls[file_path.name] = pub_url
                    return pub_url
                elif r_up.status_code == 400 and "Duplicate" in r_up.text:
                    pub_url = f"{SUPABASE_URL}/storage/v1/object/public/folletos/{archivo_opt.name}"
                    cache_storage_urls[file_path.name] = pub_url
                    return pub_url
            except Exception as e:
                if intento < 2:
                    time.sleep(1.5 * (intento + 1))
                    continue
                print(f"      [!] Error subiendo {archivo_opt.name} tras 3 intentos: {e}")
        return ""

    print("    [1/3] Optimizando y subiendo folletos y páginas a Supabase Storage (bucket 'folletos')...")
    archivos_subidos = 0
    records_folletos = []

    for _, row in df_folletos.iterrows():
        f_id = str(row["id"]).strip()
        local_filename = row.get("archivo_portada_local")
        portada_final_url = str(row.get("portada_origen_url") or "")
        visor_final_url = str(row.get("visor_url") or "")

        # 1. Subir portada
        if pd.notna(local_filename) and str(local_filename).strip():
            local_path = dir_portadas / str(local_filename).strip()
            if local_path.exists():
                url_subida = subir_recurso_storage(local_path)
                if url_subida:
                    portada_final_url = url_subida
                    archivos_subidos += 1
                    # Si la portada era un PDF (Vital/Makro), la URL pública es también el visor directo
                    if local_path.suffix.lower() == ".pdf":
                        visor_final_url = url_subida

        # 2. Subir páginas adicionales locales si existen
        paginas_list = []
        if pd.notna(row.get("paginas_locales")):
            try:
                nombres_pags = json.loads(str(row.get("paginas_locales")))
                for nom_pag in nombres_pags:
                    p_path = dir_portadas / str(nom_pag).strip()
                    if p_path.exists():
                        url_p = subir_recurso_storage(p_path)
                        if url_p:
                            paginas_list.append(url_p)
                            archivos_subidos += 1
            except Exception:
                pass

        if not paginas_list and pd.notna(row.get("paginas_urls")):
            val_p = row.get("paginas_urls")
            if isinstance(val_p, str) and val_p.startswith("["):
                try:
                    paginas_list = json.loads(val_p)
                except Exception:
                    paginas_list = [portada_final_url]
            elif isinstance(val_p, list):
                paginas_list = val_p

        if not paginas_list and portada_final_url:
            paginas_list = [portada_final_url]

        records_folletos.append((
            f_id,
            str(row["cadena"]).strip(),
            str(row.get("tipo_comercio") or "minorista").strip(),
            str(row["titulo"]).strip(),
            str(row["fecha_desde"])[:10] if pd.notna(row.get("fecha_desde")) else None,
            str(row["fecha_hasta"])[:10] if pd.notna(row.get("fecha_hasta")) else None,
            portada_final_url,
            visor_final_url,
            json.dumps(paginas_list),
            True
        ))
    print(f"    -> {archivos_subidos} páginas y portadas optimizadas y sincronizadas en Supabase Storage.")
    
    print("    [2/3] Sincronizando tabla 'folletos'...")
    sql_upsert_folletos = """
        INSERT INTO folletos (id, cadena, tipo_comercio, titulo, fecha_desde, fecha_hasta, portada_url, visor_url, paginas_urls, activo)
        VALUES %s
        ON CONFLICT (id) DO UPDATE SET
            cadena = EXCLUDED.cadena,
            tipo_comercio = EXCLUDED.tipo_comercio,
            titulo = EXCLUDED.titulo,
            fecha_desde = EXCLUDED.fecha_desde,
            fecha_hasta = EXCLUDED.fecha_hasta,
            portada_url = EXCLUDED.portada_url,
            visor_url = EXCLUDED.visor_url,
            paginas_urls = EXCLUDED.paginas_urls,
            activo = EXCLUDED.activo;
    """
    with conn.cursor() as cur:
        execute_values(cur, sql_upsert_folletos, records_folletos)
        # 1. Desactivar folletos caducados hoy
        cur.execute("UPDATE folletos SET activo = FALSE WHERE fecha_hasta < CURRENT_DATE;")
        # 2. Purgar físicamente folletos con más de 14 días de vencidos (elimina en cascada ofertas_semanales)
        cur.execute("DELETE FROM folletos WHERE fecha_hasta < CURRENT_DATE - INTERVAL '14 days';")
    conn.commit()
    print(f"    -> {len(records_folletos)} registros actualizados en 'folletos'.")

    if f_ofertas.exists():
        print("    [3/3] Sincronizando tabla 'ofertas_semanales' y recortes en Supabase...")
        df_ofertas = pd.read_csv(f_ofertas)
        records_ofertas = []
        for _, r in df_ofertas.iterrows():
            item_id = str(r["id"]).strip()
            recorte_final_url = str(r["imagen_recorte_url"]).strip() if pd.notna(r.get("imagen_recorte_url")) else None
            local_crop = r.get("archivo_recorte_local")
            if pd.notna(local_crop) and str(local_crop).strip():
                crop_path = dir_portadas / str(local_crop).strip()
                if crop_path.exists():
                    try:
                        c_url = f"{SUPABASE_URL}/storage/v1/object/folletos/{crop_path.name}"
                        r_c = requests.post(c_url, headers=headers_storage, data=crop_path.read_bytes(), timeout=15)
                        if r_c.status_code in (200, 201):
                            recorte_final_url = f"{SUPABASE_URL}/storage/v1/object/public/folletos/{crop_path.name}"
                    except Exception:
                        pass

            records_ofertas.append((
                item_id,
                str(r["folleto_id"]).strip(),
                str(r["cadena"]).strip(),
                str(r["titulo"]).strip(),
                str(r["marca"]).strip() if pd.notna(r.get("marca")) else None,
                str(r["presentacion"]).strip() if pd.notna(r.get("presentacion")) else None,
                float(r["precio_oferta"]),
                float(r["precio_anterior"]) if pd.notna(r.get("precio_anterior")) else None,
                int(r["descuento_porcentaje"]) if pd.notna(r.get("descuento_porcentaje")) else None,
                int(r["numero_pagina"]) if pd.notna(r.get("numero_pagina")) else None,
                recorte_final_url,
                str(r["valido_desde"])[:10] if pd.notna(r.get("valido_desde")) else None,
                str(r["valido_hasta"])[:10] if pd.notna(r.get("valido_hasta")) else None,
            ))
            
        sql_upsert_ofertas = """
            INSERT INTO ofertas_semanales (
                id, folleto_id, cadena, titulo, marca, presentacion,
                precio_oferta, precio_anterior, descuento_porcentaje,
                numero_pagina, imagen_recorte_url, valido_desde, valido_hasta
            ) VALUES %s
            ON CONFLICT (id) DO UPDATE SET
                precio_oferta = EXCLUDED.precio_oferta,
                precio_anterior = EXCLUDED.precio_anterior,
                descuento_porcentaje = EXCLUDED.descuento_porcentaje,
                numero_pagina = EXCLUDED.numero_pagina,
                imagen_recorte_url = EXCLUDED.imagen_recorte_url,
                valido_desde = EXCLUDED.valido_desde,
                valido_hasta = EXCLUDED.valido_hasta;
        """
        with conn.cursor() as cur:
            execute_values(cur, sql_upsert_ofertas, records_ofertas, page_size=2000)
        conn.commit()
        print(f"    -> {len(records_ofertas)} ofertas estructuradas sincronizadas.")
        
    print(f"[OK] Folletos y ofertas actualizadas en Supabase en {time.time() - t0:.1f}s.")

def ejecutar_mantenimiento_db(conn):
    """
    Rutina permanente de mantenimiento, purga y optimización de base de datos:
    1. Asegura y actualiza todos los índices de alto rendimiento.
    2. Purga productos huérfanos sin precios ni clústeres.
    3. Purga precios online obsoletos de más de 30 días.
    4. Compacta las tablas físicas y actualiza las estadísticas del optimizador (VACUUM ANALYZE).
    """
    print("\n========================================================")
    print(" MANTENIMIENTO, PURGA Y OPTIMIZACIÓN PERMANENTE")
    print("========================================================")
    
    # 1. Asegurar índices requeridos por Flutter
    try:
        import crear_indices
        print("[*] Verificando y aplicando índices de alta velocidad...")
        crear_indices.aplicar_indices()
    except Exception as e_idx:
        print(f"[-] Aviso al aplicar índices automáticos: {e_idx}")

    # 2. Purgas y compactación
    try:
        print("[*] Ejecutando purgas de registros obsoletos y compactación (VACUUM ANALYZE)...")
        with conn.cursor() as cur_maint:
            # Purgar productos huérfanos residuales que hayan quedado sin referencias
            cur_maint.execute("""
                DELETE FROM public.productos p
                WHERE NOT EXISTS (SELECT 1 FROM public.precios pr WHERE pr.id_producto = p.id_producto)
                  AND NOT EXISTS (SELECT 1 FROM public.precios_online po WHERE po.id_producto = p.id_producto)
                  AND NOT EXISTS (SELECT 1 FROM public.precios_mayoristas pm WHERE pm.id_producto = p.id_producto)
                  AND NOT EXISTS (SELECT 1 FROM public.producto_cluster_items pci WHERE pci.id_producto = p.id_producto);
            """)
            filas_purgadas = cur_maint.rowcount
            if filas_purgadas > 0:
                print(f"    -> {filas_purgadas} productos huérfanos purgados del catálogo.")
            
            # Limpiar precios online de más de 30 días
            cur_maint.execute("DELETE FROM public.precios_online WHERE fecha_captura < NOW() - INTERVAL '30 days';")
            filas_online = cur_maint.rowcount
            if filas_online > 0:
                print(f"    -> {filas_online} precios online obsoletos purgados.")
        
        # Confirmar la transacción de los DELETE antes de ejecutar VACUUM
        conn.commit()

        # VACUUM en PostgreSQL requiere ejecutarse fuera de cualquier bloque de transacción (autocommit = True)
        autocommit_previo = conn.autocommit
        conn.autocommit = True
        try:
            with conn.cursor() as cur_vac:
                for t in ['precios', 'productos', 'precios_online', 'precios_mayoristas', 'producto_clusters', 'producto_cluster_items', 'combustibles', 'sucursales']:
                    cur_vac.execute(f"VACUUM ANALYZE public.{t};")
            print("[OK] Base de datos compactada, sin tuplas muertas y con estadísticas actualizadas.")
        finally:
            conn.autocommit = autocommit_previo
    except Exception as e_vac:
        print(f"[-] Aviso en compactación automática: {e_vac}")


def ejecutar_subida(
    solo_clusters: bool = False,
    confirmar_truncate: bool = False,
    solo_combustibles: bool = False,
    solo_mayoristas: bool = False,
    solo_sucursales: bool = False,
    solo_online: bool = False,
    solo_precios: bool = False,
    solo_folletos: bool = False,
    solo_productos: bool = False,
    solo_mantenimiento: bool = False,
):
    t0 = time.time()
    try:
        conn = obtener_conexion()
        print("[+] Conectado exitosamente a Supabase.")
    except Exception as e:
        print(f"[-] Error de conexión a Supabase: {e}")
        return
        
    try:
        if solo_mantenimiento:
            ejecutar_mantenimiento_db(conn)
            return

        inicializar_tablas_clusters(conn)
        
        if solo_folletos:
            subir_folletos_y_ofertas(conn)
            return

        if solo_combustibles:
            f_comb = PROCESSED_DIR / "combustibles.csv"
            if f_comb.exists():
                subir_tabla_csv(conn, f_comb, "combustibles", truncar=True)
            else:
                print("[-] No se encontró data/processed/combustibles.csv. Ejecute primero el paso de descarga.")
            return

        if solo_mayoristas:
            f_may = PROCESSED_DIR / "precios_mayoristas.csv"
            if f_may.exists():
                subir_tabla_csv(conn, f_may, "precios_mayoristas", truncar=True)
            else:
                print("[-] No se encontró data/processed/precios_mayoristas.csv.")
            return

        if solo_online:
            f_onl = PROCESSED_DIR / "precios_online.csv"
            if f_onl.exists():
                subir_tabla_csv(conn, f_onl, "precios_online", truncar=True)
            else:
                print("[-] No se encontró data/processed/precios_online.csv.")
            return

        if solo_sucursales:
            subir_tabla_csv(conn, PROCESSED_DIR / "comercio_opt.csv", "comercio", truncar=True)
            subir_tabla_csv(conn, PROCESSED_DIR / "sucursales_opt.csv", "sucursales", truncar=True)
            return

        if solo_productos:
            subir_productos_incremental(conn, PROCESSED_DIR / "catalogo_productos.csv")
            return

        if solo_precios:
            # Garantizar que cualquier producto nuevo en el catálogo se incorpore antes de insertar precios
            f_cat = PROCESSED_DIR / "catalogo_productos.csv"
            if f_cat.exists():
                subir_productos_incremental(conn, f_cat)
            subir_tabla_csv(conn, PROCESSED_DIR / "precios.csv", "precios", truncar=True)
            return

        subir_clusters(conn, CLUSTERS_DIR)
        
        if not solo_clusters:
            if not confirmar_truncate:
                print("\n[!] AVISO DE SEGURIDAD:")
                print("    Para reemplazar las tablas base (comercio, sucursales, precios)")
                print("    debe ejecutarse con el parámetro --confirm-truncate.")
                print("    Solo se sincronizaron las tablas de clústeres IA.")
            else:
                # Subir tablas principales de SEPA
                subir_tabla_csv(conn, PROCESSED_DIR / "comercio_opt.csv", "comercio", truncar=True)
                subir_tabla_csv(conn, PROCESSED_DIR / "sucursales_opt.csv", "sucursales", truncar=True)
                subir_productos_incremental(conn, PROCESSED_DIR / "catalogo_productos.csv")
                subir_tabla_csv(conn, PROCESSED_DIR / "precios.csv", "precios", truncar=True)
                
                # Subir nuevos precios online y mayoristas
                subir_tabla_csv(conn, PROCESSED_DIR / "precios_online.csv", "precios_online", truncar=True)
                subir_tabla_csv(conn, PROCESSED_DIR / "precios_mayoristas.csv", "precios_mayoristas", truncar=True)
                
                # Subir folletos si está disponible
                f_fol = PROCESSED_DIR / "folletos.csv"
                if f_fol.exists():
                    subir_folletos_y_ofertas(conn)

                # Subir combustibles si está disponible
                f_comb = PROCESSED_DIR / "combustibles.csv"
                if f_comb.exists():
                    subir_tabla_csv(conn, f_comb, "combustibles", truncar=True)

                # Mantenimiento automático post-ingesta (índices, purga de huérfanos y VACUUM)
                ejecutar_mantenimiento_db(conn)
    finally:
        conn.close()
        
    elapsed = time.time() - t0
    print(f"\n[OK] Carga en Supabase completada en {elapsed:.1f}s.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sube datos y clústeres a Supabase")
    parser.add_argument("--clusters-only", action="store_true", help="Sube solo las tablas de clústeres de IA")
    parser.add_argument("--combustibles", action="store_true", help="Sube solo la tabla de precios de combustibles")
    parser.add_argument("--mayoristas", action="store_true", help="Sube solo la tabla de precios mayoristas")
    parser.add_argument("--sucursales", action="store_true", help="Sube tablas comercio y sucursales")
    parser.add_argument("--productos", action="store_true", help="Sube de forma incremental los productos de catalogo_productos.csv")
    parser.add_argument("--online", action="store_true", help="Sube solo la tabla de precios online")
    parser.add_argument("--precios", action="store_true", help="Sube solo la tabla de precios físicos (e incorpora productos nuevos automáticamente)")
    parser.add_argument("--folletos", action="store_true", help="Sube portadas a Storage y tablas folletos y ofertas")
    parser.add_argument("--confirm-truncate", action="store_true", help="Confirma el truncado y recarga de tablas base")
    parser.add_argument("--mantenimiento", action="store_true", help="Ejecuta solo la rutina de mantenimiento, purga de huérfanos, índices y VACUUM")
    args = parser.parse_args()
    
    ejecutar_subida(
        solo_clusters=args.clusters_only,
        confirmar_truncate=args.confirm_truncate,
        solo_combustibles=args.combustibles,
        solo_mayoristas=args.mayoristas,
        solo_sucursales=args.sucursales,
        solo_online=args.online,
        solo_precios=args.precios,
        solo_folletos=args.folletos,
        solo_productos=args.productos,
        solo_mantenimiento=args.mantenimiento,
    )
