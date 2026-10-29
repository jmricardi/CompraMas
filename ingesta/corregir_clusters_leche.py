import sys
import re
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
CLUSTERS_DIR = BASE_DIR / "data" / "clusters"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"
CATALOG_CSV = BASE_DIR / "data" / "processed" / "catalogo_productos.csv"

def corregir_clusters():
    print("[*] Iniciando corrección y consolidación de clusters de Leche...")
    
    if not ITEMS_CSV.exists():
        print(f"[!] No existe {ITEMS_CSV}")
        return

    df_items = pd.read_csv(ITEMS_CSV)
    print(f"[*] Total items cargados: {len(df_items):,}")

    # Asegurar tipos
    df_items['id_producto'] = df_items['id_producto'].astype(str).str.strip()
    df_items['cluster_id'] = df_items['cluster_id'].astype(str).str.strip()

    cambios = 0

    # 1. Mapeo específico para productos clave de Carrefour Classic y otras marcas
    eans_entera_1l = [
        "7791720029466", # Leche Entera UAT Carrefour Classic
        "7791720029404", # Leche UAT Entera Carrefour Classic
        "7791720029749", # Leche Ultra Entera Carrefour Classic
    ]
    eans_descremada_1l = [
        "7791720029473", # Leche Parc. Descre UAT Carrefour Classic
        "7791720029411", # Leche UAT Parc Descremada Carrefour Classic
        "7791720029756", # Leche Ultra Parc Descremada Sachetx1lt Carrefour Classic
    ]

    for ean in eans_entera_1l:
        mask = df_items['id_producto'] == ean
        if mask.any():
            antiguo = df_items.loc[mask, 'cluster_id'].values[0]
            if antiguo != 'leche_entera_1l':
                df_items.loc[mask, 'cluster_id'] = 'leche_entera_1l'
                df_items.loc[mask, 'contenido_neto'] = 1.0
                df_items.loc[mask, 'unidad_referencia'] = 'l'
                print(f"  -> EAN {ean} reasignado: '{antiguo}' => 'leche_entera_1l'")
                cambios += 1
        else:
            # Si no estaba en el archivo, agregarlo
            new_row = pd.DataFrame([{
                'id_producto': ean,
                'cluster_id': 'leche_entera_1l',
                'contenido_neto': 1.0,
                'unidad_referencia': 'l',
                'confianza': 1.0,
                'modelo_ia': 'correccion_reglas'
            }])
            df_items = pd.concat([df_items, new_row], ignore_index=True)
            print(f"  -> EAN {ean} añadido a 'leche_entera_1l'")
            cambios += 1

    for ean in eans_descremada_1l:
        mask = df_items['id_producto'] == ean
        if mask.any():
            antiguo = df_items.loc[mask, 'cluster_id'].values[0]
            if antiguo != 'leche_descremada_1l':
                df_items.loc[mask, 'cluster_id'] = 'leche_descremada_1l'
                df_items.loc[mask, 'contenido_neto'] = 1.0
                df_items.loc[mask, 'unidad_referencia'] = 'l'
                print(f"  -> EAN {ean} reasignado: '{antiguo}' => 'leche_descremada_1l'")
                cambios += 1
        else:
            new_row = pd.DataFrame([{
                'id_producto': ean,
                'cluster_id': 'leche_descremada_1l',
                'contenido_neto': 1.0,
                'unidad_referencia': 'l',
                'confianza': 1.0,
                'modelo_ia': 'correccion_reglas'
            }])
            df_items = pd.concat([df_items, new_row], ignore_index=True)
            print(f"  -> EAN {ean} añadido a 'leche_descremada_1l'")
            cambios += 1

    # 2. Reasignación sistemática de clusters dispersos de leche líquida 1L
    clusters_a_entera_1l = {
        'leche_entera_carrefour_1l',
        'leche_uat_entera_la_lacteo_1l',
        'leche_entera_sachet_1l',
        'leche_larga_vida_1l',
    }
    clusters_a_descremada_1l = {
        'leche_descremada_carrefour_1l',
        'leche_uat_descremada_1l',
        'leche_parcialmente_descremada_1l',
        'leche_descremada_sachet_1l',
    }

    mask_e = df_items['cluster_id'].isin(clusters_a_entera_1l)
    if mask_e.any():
        n = mask_e.sum()
        df_items.loc[mask_e, 'cluster_id'] = 'leche_entera_1l'
        df_items.loc[mask_e, 'contenido_neto'] = 1.0
        df_items.loc[mask_e, 'unidad_referencia'] = 'l'
        print(f"[*] {n} items unificados a 'leche_entera_1l'")
        cambios += n

    mask_d = df_items['cluster_id'].isin(clusters_a_descremada_1l)
    if mask_d.any():
        n = mask_d.sum()
        df_items.loc[mask_d, 'cluster_id'] = 'leche_descremada_1l'
        df_items.loc[mask_d, 'contenido_neto'] = 1.0
        df_items.loc[mask_d, 'unidad_referencia'] = 'l'
        print(f"[*] {n} items unificados a 'leche_descremada_1l'")
        cambios += n

    # Guardar items actualizados
    df_items.to_csv(ITEMS_CSV, index=False)
    print(f"[OK] Archivo guardado: {ITEMS_CSV} (cambios: {cambios})")

    # 3. Asegurar clusters canónicos en producto_clusters.csv
    if CLUSTERS_CSV.exists():
        df_clusters = pd.read_csv(CLUSTERS_CSV)
        df_clusters['cluster_id'] = df_clusters['cluster_id'].astype(str).str.strip()
    else:
        df_clusters = pd.DataFrame(columns=['cluster_id', 'nombre_canonico', 'categoria'])

    canonicos = [
        {
            'cluster_id': 'leche_entera_1l',
            'nombre_canonico': 'Leche Entera 1 L',
            'categoria': 'Lácteos'
        },
        {
            'cluster_id': 'leche_descremada_1l',
            'nombre_canonico': 'Leche Descremada 1 L',
            'categoria': 'Lácteos'
        },
        {
            'cluster_id': 'leche_deslactosada_1l',
            'nombre_canonico': 'Leche Deslactosada 1 L',
            'categoria': 'Lácteos'
        }
    ]

    for c in canonicos:
        mask_c = df_clusters['cluster_id'] == c['cluster_id']
        if not mask_c.any():
            df_clusters = pd.concat([df_clusters, pd.DataFrame([c])], ignore_index=True)
            print(f"[*] Cluster canónico creado: {c['cluster_id']}")
        else:
            df_clusters.loc[mask_c, 'nombre_canonico'] = c['nombre_canonico']
            df_clusters.loc[mask_c, 'categoria'] = c['categoria']

    df_clusters.to_csv(CLUSTERS_CSV, index=False)
    print(f"[OK] Archivo guardado: {CLUSTERS_CSV}")

    # 4. Actualizar en Supabase si hay credenciales configuradas
    try:
        from config import SUPABASE_DB_URL
        if SUPABASE_DB_URL:
            import psycopg2
            from psycopg2.extras import execute_values
            print("[*] Sincronizando con Supabase PostgreSQL...")
            conn = psycopg2.connect(SUPABASE_DB_URL)
            with conn.cursor() as cur:
                # Upsert clusters canónicos
                for c in canonicos:
                    cur.execute("""
                        INSERT INTO producto_clusters (cluster_id, nombre_canonico, categoria)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (cluster_id) DO UPDATE SET
                            nombre_canonico = EXCLUDED.nombre_canonico,
                            categoria = EXCLUDED.categoria;
                    """, (c['cluster_id'], c['nombre_canonico'], c['categoria']))

                # Upsert items modificados
                all_updated_eans = eans_entera_1l + eans_descremada_1l
                items_to_sync = df_items[df_items['id_producto'].isin(all_updated_eans)].to_dict(orient='records')
                for it in items_to_sync:
                    cur.execute("""
                        INSERT INTO producto_cluster_items (id_producto, cluster_id, contenido_neto, unidad_referencia, confianza, modelo_ia)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id_producto) DO UPDATE SET
                            cluster_id = EXCLUDED.cluster_id,
                            contenido_neto = EXCLUDED.contenido_neto,
                            unidad_referencia = EXCLUDED.unidad_referencia;
                    """, (
                        it['id_producto'],
                        it['cluster_id'],
                        it['contenido_neto'],
                        it['unidad_referencia'],
                        it.get('confianza', 1.0),
                        it.get('modelo_ia', 'reglas')
                    ))
                conn.commit()
            conn.close()
            print("[OK] Sincronización en Supabase finalizada con éxito.")
    except Exception as e:
        print(f"[!] Aviso sobre sincronización en Supabase: {e}")

if __name__ == "__main__":
    corregir_clusters()
