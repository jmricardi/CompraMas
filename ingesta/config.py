import os
import json
from pathlib import Path

# Rutas base
BASE_DIR = Path(__file__).resolve().parent
ROOT_DIR = BASE_DIR.parent
CONFIG_JSON_PATH = ROOT_DIR / "config.json"

# Directorios de trabajo
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
CLUSTERS_DIR = DATA_DIR / "clusters"
GEOREF_DIR = DATA_DIR / "georef"

# Asegurar directorios
RAW_DIR.mkdir(parents=True, exist_ok=True)
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
CLUSTERS_DIR.mkdir(parents=True, exist_ok=True)
GEOREF_DIR.mkdir(parents=True, exist_ok=True)

# Carga de credenciales desde config.json
CONFIG = {}
if CONFIG_JSON_PATH.exists():
    with open(CONFIG_JSON_PATH, "r", encoding="utf-8") as f:
        CONFIG = json.load(f)
else:
    print(f"[ADVERTENCIA] No se encontró config.json en {CONFIG_JSON_PATH}")

GEMINI_API_KEY = CONFIG.get("GEMINI_API_KEY", "")
OPENROUTER_API_KEY = CONFIG.get("OPENROUTER_API_KEY", "")
MISTRAL_API_KEY = CONFIG.get("MISTRAL_API_KEY", "")
ZENROWS_API_KEY = CONFIG.get("ZENROWS_API_KEY", "")
CLOUDFLARE_CONFIG = CONFIG.get("cloudflare", {})
SUPABASE_CONFIG = CONFIG.get("supabase", {})
SUPABASE_URL = SUPABASE_CONFIG.get("project_url", "")
SUPABASE_KEY = SUPABASE_CONFIG.get("public_key", "")
SUPABASE_DB_URL = (
    SUPABASE_CONFIG.get("pooler_connection_string")
    or SUPABASE_CONFIG.get("direct_connection_string")
    or ""
)

# Endpoint oficial de CKAN para SEPA (Precios Claros)
CKAN_DATASET_API_URL = "https://datos.produccion.gob.ar/api/3/action/package_show?id=sepa-precios"
