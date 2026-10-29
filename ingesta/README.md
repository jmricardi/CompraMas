# 🛒 Pipeline de Ingesta SEPA, Scraping, Clustering IA y Supabase

Este módulo (`/ingesta/`) es un entorno aislado en Python (independiente de Flutter) diseñado para la descarga oficial diaria de **Precios Claros (SEPA)** y **Combustibles**, scraping de precios minoristas (VTEX y Coto) y mayoristas (Vital y Maxiconsumo), catalogación canónica de 5 dimensiones atómicas con **IA (OpenRouter Free / Gemini)**, auditoría de calidad y sincronización en **Supabase**.

---

## 🚀 1. Ejecución Rápida (Cheatsheet de Comandos)

### A. Pipeline Diario Completo (Recomendado)
Ejecuta todo el flujo de punta a punta, omitiendo la lenta API pública de Open Food Facts y reemplazando limpiamente las tablas de precios del día:
```powershell
cd D:\GoogleAntigravity\CompraMas\ingesta
python pipeline.py --all --confirm-truncate --skip-off
```

### B. Modo Express (~5 a 10 minutos)
Ideal para actualizar únicamente precios de SEPA y combustibles sin esperar el scraping web ni la IA:
```powershell
python pipeline.py --express
```

### C. Si ya tienes el ZIP descargado (Ahorro de descarga)
```powershell
python pipeline.py --all --local-zip "data/raw/sepa_latest.zip" --confirm-truncate --skip-off
```

### D. Modo Profundo (`--deep`)
Scraping de folletos, minoristas (VTEX/Coto), mayoristas (Vital/Maxiconsumo) y clustering IA:
```powershell
python pipeline.py --deep
```

---

## 🧭 2. Ejecución Paso a Paso (`--step`)

Puedes ejecutar cada etapa de manera independiente para supervisar su progreso:

| Paso | Comando | Qué realiza |
| :--- | :--- | :--- |
| **Paso 1** | `python pipeline.py --step 1` | Descarga el archivo diario oficial de SEPA (~300 MB) vía API CKAN a `data/raw/sepa_latest.zip`. |
| **Paso 1B** | `python pipeline.py --step 1b` | Descarga precios en surtidor (nafta, gasoil, GNC) de la Secretaría de Energía. |
| **Paso 2** | `python pipeline.py --step 2` | Descomprime los 15 comercios de SEPA y consolida en `master_productos.csv`, `master_sucursales.csv` y `master_comercio.csv`. |
| **Paso 2B** | `python pipeline.py --step 2b --off-limit 50` | Enriquecimiento con Open Food Facts (nutriscore, fotos). *Opcional: lenta por rate-limits.* |
| **Paso 2E** | `python pipeline.py --step 2e` | Scraping de folletos digitales y recortes de ofertas semanales vigentes. |
| **Paso 3** | `python pipeline.py --step 3` | Refactoriza, sanitiza títulos, deduplica y aplica el **Filtro FMCG** (elimina libros, ropa y electro). Genera `catalogo_productos.csv`, `precios.csv` y `precios_online.csv`. |
| **Paso 3B** | `python pipeline.py --step 3b` | Scraping masivo en e-commerce minoristas: Dia, Carrefour, Jumbo, Disco, Vea y Coto. |
| **Paso 3C** | `python pipeline.py --step 3c` | Scraping mayorista de Vital (API VTEX nativa) y Maxiconsumo (Modo Monitoreo). |
| **Paso 4** | `python pipeline.py --step 4` | Clustering IA incremental con el motor determinista de 5 dimensiones atómicas. |
| **Paso 5** | `python pipeline.py --step 5 --confirm-truncate` | Impacta y sincroniza las tablas procesadas en la base de datos de producción de Supabase. |

---

## 🔍 3. Opciones y Parámetros Especiales

### Scraping Mayorista (Paso 3C)
* **Modo Monitoreo (Por defecto, rápido):**
  ```powershell
  python pipeline.py --step 3c
  ```
  Consolida los ~2.500 productos de Vital en vivo y reutiliza instantáneamente los 21.500+ precios confirmados en caché de Maxiconsumo.
* **Modo Exploración (`--buscar-nuevos`):**
  ```powershell
  python pipeline.py --step 3c --buscar-nuevos --test-lotes 300
  ```
  Busca en la web de Maxiconsumo productos nuevos del catálogo que nunca fueron testeados.
* **Pausar y Reanudar:**
  Si cancelas con `Ctrl + C`, reanuda exactamente donde quedó con:
  ```powershell
  python pipeline.py --step 3c --buscar-nuevos --resume
  ```

### Clustering IA (Paso 4)
* **Probar sobre una categoría o término específico:**
  ```powershell
  python pipeline.py --step 4 --filtro "tomate" --lotes 2
  ```
* **Forzar reclustering de un grupo:**
  ```powershell
  python pipeline.py --step 4 --filtro "arroz" --recluster
  ```
* **Cascada de Modelos:** Utiliza prioritariamente **OpenRouter Free** (`thinkingmachines/inkling-small:free` a costo $0) y conmuta automáticamente a **Gemini Flash** ante cualquier fallo o cuota.

### Subida Selectiva a Supabase (Paso 5)
* **Subir solo Clústeres IA:** `python pipeline.py --step 5 --clusters-only`
* **Subir solo Precios Físicos:** `python pipeline.py --step 5 --precios-only --confirm-truncate`
* **Subir solo Precios Online:** `python pipeline.py --step 5 --online-only --confirm-truncate`
* **Subir solo Combustibles:** `python pipeline.py --step 5 --combustibles-only`
* **Subir solo Mayoristas:** `python pipeline.py --step 5 --mayoristas-only`
* **Subir solo Folletos:** `python pipeline.py --step 5 --folletos-only`

---

## 🛠️ 4. Herramientas de Auditoría, Purga y Calidad

Scripts complementarios ubicados en `ingesta/` para mantenimiento de la base:

### A. Auditoría de Calidad con IA
Audita la coherencia de los clústeres multimarca para verificar que no mezclen variedades ni gramajes diferentes:
```powershell
python auditar_clusters_ia.py --lotes 3 --tamano-lote 10
# O filtrar por producto:
python auditar_clusters_ia.py --filtro "leche"
```
Genera un dictamen estructurado en `data/clusters/reporte_auditoria.json`.

### B. Reparador Automático de Clústeres
Disuelve clústeres heterogéneos, remueve intrusos y limpia marcas en títulos según el dictamen del auditor:
```powershell
python reparar_clusters_auditados.py
```

### C. Purga de Categorías No-Supermercado (FMCG)
Garantiza que la base solo tenga Alimentos, Bebidas, Limpieza y Perfumería, purgando libros, ropa, celulares y bazar pesado:
```powershell
python purgar_no_supermercado.py
```

### D. Truncado y Recarga Limpia en Supabase (Método 2)
Vacía las tablas remotas de clústeres en Supabase y recarga el 100% de la versión limpia y purificada:
```powershell
python recargar_clusters_supabase.py
```

---

## 📂 5. Estructura de Directorios

```text
ingesta/
├── config.py                     # Credenciales y rutas compartidas
├── filtro_fmcg.py                 # Módulo de exclusión de no-supermercado
├── cluster_canonico_builder.py    # Generador determinista de 5 dimensiones
├── 1_descargar_sepa.py           # Descarga SEPA (Precios Claros)
├── 1b_descargar_combustibles.py   # Descarga Combustibles Nación
├── 2_consolidar_sepa.py          # Descompresión y unión de CSVs
├── 2b_enriquecer_off.py          # Enriquecimiento con Open Food Facts
├── 2c_scraping_minoristas.py     # Scraper VTEX (Dia, Carrefour, Jumbo, etc.) y Coto
├── 2d_scraping_mayoristas.py     # Scraper Vital y Maxiconsumo
├── 2e_scraping_folletos.py       # Scraper de folletos digitales
├── 3_refactorizar_tablas.py      # Sanitización, deduplicación y filtro FMCG
├── 4_clustering_ia.py            # Clustering IA (OpenRouter / Gemini)
├── 5_subir_supabase.py           # Carga masiva en Supabase PostgreSQL
├── pipeline.py                   # Orquestador maestro CLI
├── auditar_clusters_ia.py        # Auditor de coherencia por IA
├── purgar_no_supermercado.py     # Limpiador de artículos ajenos
├── reparar_clusters_auditados.py # Reparador según auditoría
├── recargar_clusters_supabase.py # Recarga limpia en Supabase
└── data/
    ├── raw/                      # Zips y volcados crudos
    ├── processed/                # Tablas listas (catalogo, precios, etc.)
    └── clusters/                 # producto_clusters y cluster_items
```

---

## 🔒 6. Seguridad y Protección de Datos

1. **`--confirm-truncate` obligatorio:** El Paso 5 **NUNCA** vaciará tablas maestras en Supabase a menos que incluyas explícitamente esta bandera, evitando borrados accidentales en producción.
2. **Backups automáticos:** Los scripts de purga y reparación crean automáticamente una copia de respaldo con fecha y hora (`.csv` fechado) antes de sobreescribir cualquier archivo local.
3. **Clustering Incremental:** El Paso 4 respeta las asociaciones existentes y solo envía a la IA los productos nuevos, optimizando costos y tiempos.
