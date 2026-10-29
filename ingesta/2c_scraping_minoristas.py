#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2c_scraping_minoristas.py
-------------------------
Lee los EANs del catálogo (catalogo_productos.csv) y utiliza los scrapers (VTEX y Coto)
para obtener precios online en tiempo real de cadenas minoristas (Carrefour, Coto, Jumbo, Disco, Vea, MásOnline, Farmacity, Simplicity).
Aplica:
1. Estrategia 1: Filtrado de categorías de supermercado para auto-incorporar nuevos productos al catálogo maestro.
2. Polinización Cruzada: Todo producto nuevo descubierto en cualquier supermercado es consultado
   automáticamente en TODOS los demás supermercados para maximizar la comparación de precios.
3. Monitoreo y Expansión de Coto Digital con concurrencia multihilo.
Genera y actualiza incrementalmente data/processed/precios_online.csv
"""

import sys
import time
import argparse
import pandas as pd
from pathlib import Path

# Asegurar ruta local para importaciones dinámicas
sys.path.insert(0, str(Path(__file__).resolve().parent))

from concurrent.futures import ThreadPoolExecutor, as_completed
from config import PROCESSED_DIR, ZENROWS_API_KEY
from scrapers.vtex_client import VtexClient
from scrapers.coto_client import CotoClient

OUTPUT_FILE = PROCESSED_DIR / "precios_online.csv"
COLS_PRECIOS_ONLINE = ["id_producto", "id_entidad", "precio", "stock", "url", "fecha_captura", "nombre_scraper"]

# Lista blanca de categorías de supermercado (Estrategia 1)
CATEGORIAS_SUPERMERCADO = [
    "almacen", "lacteos", "quesos", "leches", "yogures", "frescos",
    "frutas", "verduras", "verduleria", "carnes", "carniceria", "aves", "pescados", "fiambreria",
    "bebidas", "gaseosas", "aguas", "cervezas", "vinos", "jugos", "aperitivos", "sidras", "espumantes",
    "limpieza", "higiene", "cuidado personal", "perfumeria", "farmacia", "salud",
    "congelados", "comidas preparadas", "panaderia", "panificados", "reposteria", "pastas frescas",
    "desayuno", "meriendas", "golosinas", "chocolates", "galletitas", "snacks", "infusiones", "cafe", "te", "yerba",
    "mascotas", "alimento para mascotas", "alimentos",
    "bebes", "panales", "infantil"
]

# Categorías excluidas expresamente para no ensuciar el catálogo
CATEGORIAS_EXCLUIDAS = [
    "electro", "tecnologia", "telefonia", "audio", "video", "tv", "smart tv", "informatica", "computacion",
    "climatizacion", "heladeras", "lavarropas", "cocinas", "pequenos electrodomesticos",
    "hogar y textil", "muebles", "colchones", "sabanas", "toallas", "bazar", "vajilla", "decoracion",
    "indumentaria", "calzado", "ropa", "moda", "textil",
    "ferreteria", "herramientas", "jardin", "pintureria",
    "automotor", "neumaticos", "rodados", "bicicletas",
    "jugueteria", "juegos de mesa", "libreria", "papeleria", "deportes", "fitness", "camping"
]

def normalizar_texto_categoria(texto: str) -> str:
    texto = texto.lower()
    for a, b in [("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n")]:
        texto = texto.replace(a, b)
    return texto

def es_categoria_supermercado(categorias: list) -> bool:
    if not categorias or not isinstance(categorias, list):
        return False
    texto = normalizar_texto_categoria(" ".join([str(c) for c in categorias]))
    
    # 1. Si contiene alguna categoría excluida explícita, descartar
    for exc in CATEGORIAS_EXCLUIDAS:
        if exc in texto:
            return False
            
    # 2. Debe contener al menos una categoría válida de supermercado
    for inc in CATEGORIAS_SUPERMERCADO:
        if inc in texto:
            return True
            
    return False

def es_ean_valido(ean: str) -> bool:
    if not ean or not isinstance(ean, str):
        return False
    clean = ean.strip()
    return clean.isdigit() and len(clean) in (8, 12, 13, 14)

def auto_incorporar_productos_al_catalogo(productos: list, cat_file: Path) -> tuple:
    """
    Identifica productos nuevos de VTEX que no están en catalogo_productos.csv,
    valida que correspondan a categorías de supermercado (Estrategia 1) y tengan EAN válido,
    y los agrega de manera incremental al catálogo maestro antes del clustering IA.
    Retorna (cantidad_agregada, lista_nuevos_eans).
    """
    if not cat_file.exists():
        return 0, []
    try:
        df_cat = pd.read_csv(cat_file, dtype=str)
    except Exception as e:
        print(f"[-] Error leyendo {cat_file}: {e}")
        return 0, []

    eans_existentes = set(df_cat["id_producto"].dropna().astype(str).str.strip().tolist())
    nuevos_items = []
    eans_vistos = set()

    for p in productos:
        ean = str(p.get("id_producto", "")).strip()
        if not ean or ean in eans_existentes or ean in eans_vistos:
            continue
        
        if not es_ean_valido(ean):
            continue

        categorias = p.get("categorias", [])
        if not es_categoria_supermercado(categorias):
            continue

        nombre = str(p.get("nombre_scraper", "")).strip()
        if not nombre or len(nombre) < 3:
            continue

        marca = str(p.get("marca", "")).strip()
        if not marca or marca.lower() in ("generic", "generico", "sin marca"):
            marca = "SIN MARCA"
        else:
            marca = marca.upper()

        imagen = str(p.get("imagen_url", "")).strip()
        cat_str = " / ".join(categorias) if isinstance(categorias, list) else str(categorias)

        cant = str(p.get("multiplicador_unidad", 1.0) or 1.0)
        um = str(p.get("unidad_medida", "un") or "un").strip().lower()

        nuevos_items.append({
            "id_producto": ean,
            "productos_ean": "true",
            "productos_descripcion": nombre,
            "productos_marca": marca,
            "productos_cantidad_presentacion": cant,
            "productos_unidad_medida_presentacion": um,
            "off_nombre": "",
            "off_marca": "",
            "off_cantidad_str": "",
            "off_cantidad_num": "",
            "off_imagen": imagen,
            "off_nutriscore": "",
            "off_categorias": cat_str,
        })
        eans_vistos.add(ean)

    if nuevos_items:
        df_nuevos = pd.DataFrame(nuevos_items)
        df_total = pd.concat([df_cat, df_nuevos], ignore_index=True)
        df_total = df_total.drop_duplicates(subset=["id_producto"], keep="first")
        df_total.to_csv(cat_file, index=False, encoding="utf-8")
        print(f"[+] [AUTO-INCORPORACIÓN] Se sumaron {len(nuevos_items):,} productos NUEVOS de supermercado a {cat_file.name}.")
        return len(nuevos_items), list(eans_vistos)
    return 0, []

# Clientes oficiales de supermercados y farmacias minoristas
MINORISTAS = {
    "dia": VtexClient("https://diaonline.supermercadosdia.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "carrefour": VtexClient("https://www.carrefour.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "jumbo": VtexClient("https://www.jumbo.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "disco": VtexClient("https://www.disco.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "vea": VtexClient("https://www.vea.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "masonline": VtexClient("https://www.masonline.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "farmacity": VtexClient("https://www.farmacity.com", zenrows_api_key=ZENROWS_API_KEY),
    "simplicity": VtexClient("https://www.simplicity.com.ar", zenrows_api_key=ZENROWS_API_KEY),
    "coto": CotoClient(zenrows_api_key=ZENROWS_API_KEY)
}

def guardar_precios_incremental(nuevos_precios: list):
    """
    Guarda los precios acumulados en precios_online.csv preservando datos existentes
    (incluyendo los de SEPA virtual DIA y La Anónima) y actualizando duplicados.
    """
    if not nuevos_precios:
        return
    df_nuevos = pd.DataFrame(nuevos_precios)
    # Conservar únicamente las columnas oficiales para precios_online.csv
    cols_existentes = [c for c in COLS_PRECIOS_ONLINE if c in df_nuevos.columns]
    df_nuevos = df_nuevos[cols_existentes]

    if OUTPUT_FILE.exists():
        try:
            df_existente = pd.read_csv(OUTPUT_FILE, dtype=str)
            df_total = pd.concat([df_existente, df_nuevos], ignore_index=True)
            df_total = df_total.drop_duplicates(subset=["id_producto", "id_entidad"], keep="last")
        except Exception:
            df_total = df_nuevos
    else:
        df_total = df_nuevos
    df_total.to_csv(OUTPUT_FILE, index=False, encoding="utf-8")

def polinizar_precios_cruzados(eans_nuevos: list, target_stores: list, workers: int = 4):
    """
    POLINIZACIÓN CRUZADA:
    Toma los EANs nuevos descubiertos en cualquier comercio y los consulta por código de barras
    directo en TODOS los demás supermercados para maximizar la comparación de precios.
    """
    eans_unicos = list(dict.fromkeys(eans_nuevos))
    if not eans_unicos:
        return

    print(f"\n========================================================")
    print(f"[*] POLINIZACIÓN CRUZADA: Revisando {len(eans_unicos):,} productos nuevos en todas las cadenas...")
    print(f"========================================================")

    # Identificar qué precios ya tenemos guardados para evitar peticiones redundantes
    precios_existentes = set()
    if OUTPUT_FILE.exists():
        try:
            df_ex = pd.read_csv(OUTPUT_FILE, dtype=str)
            for _, row in df_ex.iterrows():
                p_id = str(row.get("id_producto", "")).strip()
                e_id = str(row.get("id_entidad", "")).strip()
                if p_id and e_id:
                    precios_existentes.add((p_id, e_id))
        except Exception:
            pass

    precios_cruzados_totales = []

    for store_id in target_stores:
        client = MINORISTAS.get(store_id)
        if not client or not hasattr(client, "fetch_price_by_ean"):
            continue

        eans_pendientes = [e for e in eans_unicos if (e, store_id) not in precios_existentes]
        if not eans_pendientes:
            continue

        print(f"[*] Cruzando {len(eans_pendientes):,} EANs en {store_id.upper()}...")
        t0 = time.time()
        encontrados_tienda = []
        num_workers = 3 if store_id == "coto" else (workers or 4)

        with ThreadPoolExecutor(max_workers=num_workers) as executor:
            future_to_ean = {executor.submit(client.fetch_price_by_ean, ean): ean for ean in eans_pendientes}
            total_pend = len(eans_pendientes)
            for i, future in enumerate(as_completed(future_to_ean), 1):
                ean = future_to_ean[future]
                try:
                    res = future.result()
                    if res:
                        res["id_entidad"] = store_id
                        encontrados_tienda.append(res)
                        precios_existentes.add((ean, store_id))
                except Exception:
                    pass
                if i % 50 == 0 or i == total_pend:
                    sys.stdout.write(f"\r    {store_id.upper()}: {i}/{total_pend} | Coincidencias encontradas: {len(encontrados_tienda)}")
                    sys.stdout.flush()

        elapsed = time.time() - t0
        print(f"\n[OK] {store_id.upper()}: {len(encontrados_tienda)} precios coincidentes registrados en {elapsed:.1f}s.")
        if encontrados_tienda:
            guardar_precios_incremental(encontrados_tienda)
            precios_cruzados_totales.extend(encontrados_tienda)

    print(f"[OK] Polinización cruzada finalizada: {len(precios_cruzados_totales):,} precios adicionales comparables sumados.")

def ejecutar_scraping(limit: int = None, retailer: str = None, workers: int = 4, coto_explorar: int = 1000):
    cat_file = PROCESSED_DIR / "catalogo_productos.csv"
    if not cat_file.exists():
        print(f"[-] No se encontró {cat_file}. Ejecuta primero refactorizar_tablas.")
        return

    # Lista completa de cadenas minoristas soportadas
    todas_las_cadenas = ["dia", "carrefour", "jumbo", "disco", "vea", "masonline", "farmacity", "simplicity", "coto"]
    vtex_stores = ["dia", "carrefour", "jumbo", "disco", "vea", "masonline", "farmacity", "simplicity"]
    
    if retailer:
        ret_clean = retailer.lower().strip()
        vtex_stores = [s for s in vtex_stores if s == ret_clean]
        todas_las_cadenas = [s for s in todas_las_cadenas if s == ret_clean]
    
    # 1. Scraping masivo ultra-rápido a costo $0 para VTEX
    limite_vtex = limit if (limit is not None and limit > 0) else None
    nuevos_eans_incorporados = []

    for store_id in vtex_stores:
        client = MINORISTAS.get(store_id)
        if not client or not hasattr(client, "crawl_catalog"):
            continue
        tope_str = f"{limite_vtex:,}" if limite_vtex else "TOTAL ILIMITADO"
        print(f"\n[*] Extrayendo catálogo masivo de {store_id.upper()} (lotes de 50 a costo $0, tope: {tope_str})...")
        t0 = time.time()
        productos_vtex = client.crawl_catalog(limit=limite_vtex, step=50)
        
        # Asignar id_entidad
        precios_formateados = []
        for p in productos_vtex:
            p["id_entidad"] = store_id
            precios_formateados.append(p)
            
        print(f"[OK] {store_id.upper()}: {len(precios_formateados)} productos obtenidos en {time.time() - t0:.1f}s.")
        
        # Auto-incorporar al catálogo maestro los productos nuevos de categorías permitidas
        _, eans_nuevos = auto_incorporar_productos_al_catalogo(precios_formateados, cat_file)
        nuevos_eans_incorporados.extend(eans_nuevos)
        
        # Guardar en precios_online.csv
        guardar_precios_incremental(precios_formateados)

    # 1.1 ENRIQUECIMIENTO OFF AUTOMÁTICO: Consultar Open Food Facts para los productos nuevos descubiertos por VTEX
    if nuevos_eans_incorporados:
        eans_unicos_nuevos = list(dict.fromkeys(nuevos_eans_incorporados))
        print(f"\n[*] [OFF] Consultando Open Food Facts para {len(eans_unicos_nuevos):,} nuevos productos descubiertos por VTEX...")
        try:
            from importlib import import_module
            mod_off = import_module("2b_enriquecer_off")
            mod_off.enriquecer_catalogo(eans_especificos=eans_unicos_nuevos)
        except Exception as e_off:
            print(f"[!] No se pudo enriquecer con OFF automáticamente: {e_off}")

    # 2. POLINIZACIÓN CRUZADA: Consultar los productos nuevos descubiertos en TODOS los demás supermercados
    if nuevos_eans_incorporados and not retailer:
        polinizar_precios_cruzados(nuevos_eans_incorporados, target_stores=todas_las_cadenas, workers=workers)

    # 3. Monitoreo y Expansión habitual de COTO DIGITAL
    if not retailer or retailer.lower().strip() == "coto":
        coto_client = MINORISTAS.get("coto")
        if coto_client:
            print("\n[*] Actualizando y expandiendo precios de COTO DIGITAL...")
            
            # EANs que ya sabemos que existen en Coto (históricos confirmados)
            eans_coto_confirmados = []
            if OUTPUT_FILE.exists():
                try:
                    df_ex = pd.read_csv(OUTPUT_FILE, dtype=str)
                    eans_coto_confirmados = df_ex[df_ex["id_entidad"] == "coto"]["id_producto"].dropna().unique().tolist()
                except Exception:
                    pass

            # Lote exploratorio del catálogo maestro de productos de supermercado
            eans_ya_evaluados = set(eans_coto_confirmados + nuevos_eans_incorporados)
            df_cat_actual = pd.read_csv(cat_file, dtype=str)
            candidatos_catalogo = df_cat_actual[~df_cat_actual["id_producto"].isin(eans_ya_evaluados)]["id_producto"].dropna().tolist()
            
            tope_exploratorio = coto_explorar if coto_explorar is not None else 1000
            eans_exploratorios = candidatos_catalogo[:tope_exploratorio] if tope_exploratorio > 0 else []

            # Consolidar cola de consulta de Coto
            eans_coto_totales = list(dict.fromkeys(eans_coto_confirmados + eans_exploratorios))
            if limit and limit > 0:
                eans_coto_totales = eans_coto_totales[:limit]

            print(f"[*] Total a consultar en COTO: {len(eans_coto_totales):,} productos")
            print(f"    - {len(eans_coto_confirmados):,} confirmados previamente")
            if eans_exploratorios:
                print(f"    - {len(eans_exploratorios):,} del catálogo maestro para descubrimiento continuo")

            # Ejecutar con concurrencia controlada para máxima velocidad sin bloqueos
            coto_precios = []
            t_coto = time.time()
            max_workers = 3
            
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                future_to_ean = {executor.submit(coto_client.fetch_price_by_ean, ean): ean for ean in eans_coto_totales}
                total_coto = len(eans_coto_totales)
                for i, future in enumerate(as_completed(future_to_ean), 1):
                    ean = future_to_ean[future]
                    try:
                        res = future.result()
                        if res:
                            res["id_entidad"] = "coto"
                            coto_precios.append(res)
                    except Exception:
                        pass
                    if i % 25 == 0 or i == total_coto:
                        elapsed = time.time() - t_coto
                        rate = i / elapsed if elapsed > 0 else 0
                        sys.stdout.write(f"\r    Progreso Coto: {i}/{total_coto} | Encontrados: {len(coto_precios)} ({rate:.1f} req/s)")
                        sys.stdout.flush()

            print(f"\n[OK] COTO: {len(coto_precios)} precios actualizados y consolidados en {time.time() - t_coto:.1f}s.")
            guardar_precios_incremental(coto_precios)

    if OUTPUT_FILE.exists():
        df_final = pd.read_csv(OUTPUT_FILE, dtype=str)
        print(f"\n[OK] {OUTPUT_FILE.name} consolidado con {len(df_final):,} registros en total.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scraper minorista optimizado con Polinización Cruzada y auto-incorporación de catálogo")
    parser.add_argument("--limit", type=int, help="Límite de productos por cadena (ej: --limit 20000; 0 o sin valor = ILIMITADO)", default=None)
    parser.add_argument("--retailer", type=str, help="Cadena específica: carrefour, coto, jumbo, disco, vea, masonline, farmacity, simplicity", default=None)
    parser.add_argument("--workers", type=int, help="Concurrencia de workers para peticiones (default: 4)", default=4)
    parser.add_argument("--coto-explorar", type=int, help="Cantidad de nuevos EANs del catálogo a sondear en Coto (default: 1000)", default=1000)
    args = parser.parse_args()
    
    ejecutar_scraping(
        limit=args.limit,
        retailer=args.retailer,
        workers=args.workers,
        coto_explorar=args.coto_explorar
    )
