import re
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
CLUSTERS_DIR = BASE_DIR / "data" / "clusters"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"

MARCAS_LISTA = [
    "carrefour", "classic", "dia", "coto", "jumbo", "disco", "vea", "changomas",
    "la_serenisima", "serenisima", "sancor", "marolio", "arcor", "molto",
    "gallo", "lucchetti", "matarazzo", "canale", "morixe", "favorita", "pureza",
    "natura", "cocinero", "canuelas", "primor", "taragui", "rosamonte", "playadito",
    "nobleza_gaucha", "amanda", "chamigo", "cbse", "la_merced", "unilever",
    "knorr", "hellmanns", "ades", "dove", "sedal", "rexona", "lux", "cif", "ala",
    "skip", "vivere", "drive", "comfort", "colgate", "palmolive", "protex",
    "crest", "oral_b", "pantene", "head_shoulders", "gillette", "pampers", "huggies",
    "great_value", "cuisine_co", "la_lacteo", "gandara", "ilolay"
]

def sanitizar_slug(c_id: str) -> str:
    original = str(c_id).strip().lower().replace(" ", "_")
    slug = original
    for m in MARCAS_LISTA:
        slug = re.sub(rf'_{m}(?=_|$)', '', slug)
        slug = re.sub(rf'^{m}_', '', slug)
    
    # Limpiar dobles guiones bajos
    slug = re.sub(r'__+', '_', slug).strip('_')
    return slug or original

def sanitizar_catalogo():
    print("[*] Iniciando saneamiento global de clusters de productos...")
    if not ITEMS_CSV.exists():
        print(f"[!] No existe {ITEMS_CSV}")
        return

    df_items = pd.read_csv(ITEMS_CSV)
    print(f"[*] Total items leídos: {len(df_items):,}")

    modificados = 0
    nuevos_slugs = []

    for idx, row in df_items.iterrows():
        antiguo = str(row['cluster_id'])
        limpio = sanitizar_slug(antiguo)
        if limpio != antiguo:
            modificados += 1
            nuevos_slugs.append(limpio)
        else:
            nuevos_slugs.append(antiguo)

    df_items['cluster_id'] = nuevos_slugs
    print(f"[OK] Slugs corregidos en memoria: {modificados:,}")

    df_items.to_csv(ITEMS_CSV, index=False)
    print(f"[OK] Archivo guardado: {ITEMS_CSV}")

    # Sincronizar en Supabase
    try:
        from config import SUPABASE_DB_URL
        if SUPABASE_DB_URL:
            import psycopg2
            print("[*] Sincronizando clusters limpios con Supabase PostgreSQL...")
            conn = psycopg2.connect(SUPABASE_DB_URL)
            with conn.cursor() as cur:
                # Actualizar los items que cambiaron
                cambiados = df_items[df_items['cluster_id'] != nuevos_slugs].to_dict(orient='records')
                # Enfoque batch: actualizar directamente en SQL con regex masivo
                for m in MARCAS_LISTA:
                    cur.execute(f"""
                        UPDATE producto_cluster_items
                        SET cluster_id = regexp_replace(
                            regexp_replace(cluster_id, '_{m}(?=_|$)', '', 'gi'),
                            '^{m}_', '', 'gi'
                        )
                        WHERE cluster_id ILIKE '%{m}%';
                    """)
                conn.commit()
            conn.close()
            print("[OK] Sincronización en Supabase exitosa.")
    except Exception as e:
        print(f"[!] Aviso sobre sincronización en Supabase: {e}")

if __name__ == "__main__":
    sanitizar_catalogo()
