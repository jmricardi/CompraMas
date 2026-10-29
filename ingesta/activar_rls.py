#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
activar_rls.py
--------------
Habilita Row Level Security (RLS) en las tablas producto_clusters y producto_cluster_items
y agrega las políticas de lectura pública (SELECT) para anon y authenticated,
eliminando la advertencia roja 'Unrestricted' en Supabase.
"""

import psycopg2
from config import SUPABASE_DB_URL

def activar_rls():
    if not SUPABASE_DB_URL:
        print("[-] Error: SUPABASE_DB_URL no configurada.")
        return

    conn = psycopg2.connect(SUPABASE_DB_URL)
    try:
        with conn.cursor() as cur:
            # 1. Habilitar RLS en ambas tablas
            cur.execute("ALTER TABLE producto_clusters ENABLE ROW LEVEL SECURITY;")
            cur.execute("ALTER TABLE producto_cluster_items ENABLE ROW LEVEL SECURITY;")

            # 2. Política de lectura pública para producto_clusters
            cur.execute('DROP POLICY IF EXISTS "Lectura publica clusters" ON producto_clusters;')
            cur.execute("""
                CREATE POLICY "Lectura publica clusters"
                ON producto_clusters FOR SELECT
                TO anon, authenticated
                USING (true);
            """)

            # 3. Política de lectura pública para producto_cluster_items
            cur.execute('DROP POLICY IF EXISTS "Lectura publica cluster items" ON producto_cluster_items;')
            cur.execute("""
                CREATE POLICY "Lectura publica cluster items"
                ON producto_cluster_items FOR SELECT
                TO anon, authenticated
                USING (true);
            """)

        conn.commit()
        print("[OK] RLS activado y políticas de lectura pública creadas exitosamente.")
    finally:
        conn.close()

if __name__ == "__main__":
    activar_rls()
