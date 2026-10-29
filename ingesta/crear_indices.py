#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
crear_indices.py
----------------
Crea índices optimizados en Supabase / PostgreSQL para acelerar las consultas
frecuentes de la aplicación CompraMas:
1. Clústeres y Productos Hermanos (producto_clusters y producto_cluster_items)
2. Búsqueda y Cobertura de Precios por Producto (precios)
3. Mejor Precio Mínimo Estimado para Listas de Compra (precios)
4. Resolución Instantánea de Sucursales (sucursales)
"""

import time
import psycopg2
from config import SUPABASE_DB_URL

INDEX_STATEMENTS = [
    # 1. Búsqueda instantánea de hermanos en un clúster (Covering Index)
    (
        "idx_cluster_items_cluster_covering",
        """
        CREATE INDEX IF NOT EXISTS idx_cluster_items_cluster_covering
        ON public.producto_cluster_items (cluster_id)
        INCLUDE (id_producto, contenido_neto, unidad_referencia);
        """
    ),
    # 1b. Búsqueda difusa y directa por marca en ítems de clúster (Flutter _searchClustersByBrand)
    (
        "idx_cluster_items_marca",
        """
        CREATE INDEX IF NOT EXISTS idx_cluster_items_marca
        ON public.producto_cluster_items USING gin (marca gin_trgm_ops);
        """
    ),
    # 2. Búsqueda por categoría en clústeres canónicos
    (
        "idx_producto_clusters_categoria",
        """
        CREATE INDEX IF NOT EXISTS idx_producto_clusters_categoria
        ON public.producto_clusters (categoria);
        """
    ),
    # 3. Búsqueda difusa / autocompletado en nombre canónico de clústeres
    (
        "idx_producto_clusters_nombre_trgm",
        """
        CREATE INDEX IF NOT EXISTS idx_producto_clusters_nombre_trgm
        ON public.producto_clusters USING gin (nombre_canonico gin_trgm_ops);
        """
    ),
    # 4. Obtención directa del mejor precio para listas de compra (sin Sort en memoria)
    (
        "idx_precios_producto_precio",
        """
        CREATE INDEX IF NOT EXISTS idx_precios_producto_precio
        ON public.precios (id_producto, productos_precio_lista ASC);
        """
    ),
    # 4b. Búsqueda instantánea y ordenamiento de precios online (Flutter pestaña Online)
    (
        "idx_precios_online_lookup",
        """
        CREATE INDEX IF NOT EXISTS idx_precios_online_lookup
        ON public.precios_online (id_producto, precio ASC);
        """
    ),
    # 4c. Búsqueda instantánea y ordenamiento de precios mayoristas (Flutter pestaña Mayorista)
    (
        "idx_precios_mayoristas_lookup",
        """
        CREATE INDEX IF NOT EXISTS idx_precios_mayoristas_lookup
        ON public.precios_mayoristas (id_producto, precio_unitario ASC);
        """
    ),
    # 5. Resolución de sucursales con cobertura de datos geográficos y nombre
    (
        "idx_sucursales_lookup",
        """
        CREATE INDEX IF NOT EXISTS idx_sucursales_lookup
        ON public.sucursales (id_entidad, id_sucursal)
        INCLUDE (sucursales_nombre, sucursales_domicilio_completo, sucursales_latitud, sucursales_longitud);
        """
    ),
    # 6. Búsqueda ultra-rápida de combustibles por coordenadas geográficas
    (
        "idx_combustibles_coords",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_coords
        ON public.combustibles (latitud, longitud);
        """
    ),
    # 7. Deduplicación y vigencia de precios de combustibles por estación
    (
        "idx_combustibles_dedup",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_dedup
        ON public.combustibles (idempresa, direccion, producto, fecha_vigencia DESC);
        """
    ),
    # 8. Filtro por tipo de producto y precio en combustibles
    (
        "idx_combustibles_prod_precio",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_prod_precio
        ON public.combustibles (producto, precio);
        """
    ),
    # 9. Filtro por bandera comercial (YPF, Shell, Axion, etc.)
    (
        "idx_combustibles_bandera",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_bandera
        ON public.combustibles (empresabandera);
        """
    ),
    # 10. Filtro geográfico por provincia y localidad
    (
        "idx_combustibles_loc_prov",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_loc_prov
        ON public.combustibles (provincia, localidad);
        """
    ),
    # 11. Ordenamiento por fecha de vigencia más reciente
    (
        "idx_combustibles_fecha_vigencia",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_fecha_vigencia
        ON public.combustibles (fecha_vigencia DESC);
        """
    ),
    # 12. Índice espacial funcional GiST para consultas PostGIS
    (
        "idx_combustibles_gist_point",
        """
        CREATE INDEX IF NOT EXISTS idx_combustibles_gist_point 
        ON public.combustibles USING GIST (ST_SetSRID(ST_MakePoint(longitud::double precision, latitud::double precision), 4326)) 
        WHERE latitud IS NOT NULL AND longitud IS NOT NULL;
        """
    ),
]

def aplicar_indices():
    if not SUPABASE_DB_URL:
        print("[-] Error: SUPABASE_DB_URL no configurada.")
        return

    print("[*] Conectando a Supabase PostgreSQL...")
    conn = psycopg2.connect(SUPABASE_DB_URL)
    conn.autocommit = True
    cur = conn.cursor()

    # Asegurar extensión pg_trgm y postgis
    try:
        cur.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        print("[OK] Extensiones pg_trgm y postgis verificadas.")
    except Exception as e:
        print(f"[-] Aviso al verificar extensiones: {e}")

    print(f"[*] Aplicando {len(INDEX_STATEMENTS)} índices de aceleración...")
    for name, sql in INDEX_STATEMENTS:
        t0 = time.time()
        print(f"  -> Creando índice '{name}'...", end=" ", flush=True)
        try:
            cur.execute(sql)
            dt = time.time() - t0
            print(f"[OK] ({dt:.2f}s)")
        except Exception as e:
            print(f"[ERROR]: {e}")

    # Ejecutar ANALYZE para actualizar las estadísticas del planificador
    print("[*] Ejecutando ANALYZE en tablas afectadas...")
    for t in ['producto_clusters', 'producto_cluster_items', 'precios', 'sucursales', 'productos', 'combustibles']:
        cur.execute(f"ANALYZE public.{t};")
        print(f"  -> ANALYZE {t} completado.")

    cur.close()
    conn.close()
    print("\n[OK] Todos los índices fueron creados y optimizados exitosamente.")

if __name__ == "__main__":
    aplicar_indices()
