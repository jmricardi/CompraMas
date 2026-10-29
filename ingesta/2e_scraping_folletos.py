#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2e_scraping_folletos.py
-----------------------
Scraping estructurado de catálogos y folletos de ofertas semanales de
Supermercados y Mayoristas en Argentina (Coto, Carrefour, Jumbo, Disco, Vea,
ChangoMás, Makro, Diarco, Maxiconsumo, Vital).

Genera:
- data/raw/folletos/portada_{id}.webp (imágenes de portadas optimizadas)
- data/processed/folletos.csv (metadatos de los catálogos vigentes)
- data/processed/ofertas_semanales.csv (productos individuales en oferta con precios y descuentos)
"""

import os
import sys
import re
import json
import time
import uuid
import requests
import pandas as pd
from pathlib import Path
from bs4 import BeautifulSoup
from typing import Dict, List, Optional, Any

from config import RAW_DIR, PROCESSED_DIR

# Directorio de portadas descargadas
FOLLETOS_RAW_DIR = RAW_DIR / "folletos"
FOLLETOS_RAW_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

CADENAS_CONFIG = [
    {"nombre": "Coto", "slug": "coto", "tipo": "minorista"},
    {"nombre": "Carrefour", "slug": "carrefour", "tipo": "minorista"},
    {"nombre": "Jumbo", "slug": "jumbo", "tipo": "minorista"},
    {"nombre": "Disco", "slug": "disco", "tipo": "minorista"},
    {"nombre": "Vea", "slug": "supermercados-vea", "tipo": "minorista"},
    {"nombre": "ChangoMás", "slug": "changomas", "tipo": "minorista"},
    {"nombre": "Día", "slug": "supermercados-dia", "tipo": "minorista"},
    {"nombre": "Makro", "slug": "makro", "tipo": "mayorista"},
    {"nombre": "Diarco", "slug": "diarco", "tipo": "mayorista"},
    {"nombre": "Maxiconsumo", "slug": "maxiconsumo", "tipo": "mayorista"},
    {"nombre": "Vital", "slug": "supermayorista-vital", "tipo": "mayorista"},
    {"nombre": "Yaguar", "slug": "supermercados-yaguar", "tipo": "mayorista"},
]

def limpiar_precio(valor: Any) -> Optional[float]:
    """Extrae un número flotante de una cadena de precio (ej. '$ 1689.00', '1.450,50')."""
    if valor is None:
        return None
    if isinstance(valor, (int, float)):
        return float(valor)
    
    s = str(valor).strip()
    if not s or s.lower() in ("null", "none", "nan"):
        return None
    
    # Remover símbolos monetarios y espacios
    s = re.sub(r"[^\d.,]", "", s)
    if not s:
        return None
        
    try:
        if "," in s and "." in s:
            if s.rfind(",") > s.rfind("."):
                # Formato europeo/argentino: 1.450,50
                s = s.replace(".", "").replace(",", ".")
            else:
                # Formato americano: 1,450.50
                s = s.replace(",", "")
        elif "," in s:
            s = s.replace(",", ".")
        val = float(s)
        return val if val > 0 else None
    except ValueError:
        return None

def descargar_imagen(url: str, destino: Path) -> bool:
    """Descarga una imagen WebP o JPG asegurando integridad."""
    if not url or not url.startswith("http"):
        return False
    try:
        r = requests.get(url, headers=HEADERS, timeout=12)
        if r.status_code == 200 and len(r.content) > 500:
            destino.write_bytes(r.content)
            return True
    except Exception as e:
        print(f"    [!] Error al descargar imagen {url[:60]}: {e}")
    return False

def obtener_folletos_cadena(slug: str) -> List[Dict]:
    """Obtiene los folletos vigentes de una cadena consultando Tiendeo."""
    url = f"https://www.tiendeo.com.ar/ofertas-catalogos/{slug}"
    try:
        r = requests.get(url, headers=HEADERS, timeout=10)
        if r.status_code != 200:
            return []
        soup = BeautifulSoup(r.text, "html.parser")
        nd = soup.find("script", id="__NEXT_DATA__")
        if not nd or not nd.string:
            return []
        data = json.loads(nd.string)
        flyers = (
            data.get("props", {})
            .get("pageProps", {})
            .get("apiResources", {})
            .get("flyersByRetailer", [])
        )
        return flyers
    except Exception as e:
        print(f"  [!] Error al consultar {slug}: {e}")
        return []

def obtener_ofertas_folleto(folleto_id: str) -> List[Dict]:
    """Obtiene los productos y ofertas etiquetados dentro de un folleto específico."""
    url = f"https://www.tiendeo.com.ar/Catalogos/{folleto_id}"
    try:
        r = requests.get(url, headers=HEADERS, timeout=10)
        if r.status_code != 200:
            return []
        soup = BeautifulSoup(r.text, "html.parser")
        nd = soup.find("script", id="__NEXT_DATA__")
        if not nd or not nd.string:
            return []
        data = json.loads(nd.string)
        gibs = (
            data.get("props", {})
            .get("pageProps", {})
            .get("apiResources", {})
            .get("flyerGibsData", {})
            .get("flyerGibs", [])
        )
        return gibs
    except Exception as e:
        print(f"    [!] Error al consultar detalle del catálogo {folleto_id}: {e}")
        return []

def ejecutar_scraping_folletos(limit_folletos_por_cadena: Optional[int] = None) -> None:
    print("\n========================================================")
    print(" PASO 2E: Scraping de Folletos y Ofertas Semanales")
    print("========================================================")
    
    lista_folletos = []
    lista_ofertas = []
    folletos_procesados_ids = set()

    # 1. SCRAPING DE ORIGEN DIRECTO: Coto, Carrefour, Vital y Makro
    print("\n--------------------------------------------------------")
    print(" FASE 1: DESCARGA DE FOLLETOS COMPLETOS EN ORIGEN OFICIAL")
    print("--------------------------------------------------------")
    try:
        from scrapers.folletos_origen import (
            scrapear_coto_oficial,
            scrapear_carrefour_oficial,
            scrapear_vital_oficial,
            scrapear_makro_oficial
        )
        
        folletos_coto = scrapear_coto_oficial(FOLLETOS_RAW_DIR)
        folletos_carrefour = scrapear_carrefour_oficial(FOLLETOS_RAW_DIR)
        folletos_vital = scrapear_vital_oficial(FOLLETOS_RAW_DIR)
        folletos_makro = scrapear_makro_oficial(FOLLETOS_RAW_DIR)
        
        origen_totales = folletos_coto + folletos_carrefour + folletos_vital + folletos_makro
        for f in origen_totales:
            f_id = f["id"]
            if f_id not in folletos_procesados_ids:
                folletos_procesados_ids.add(f_id)
                lista_folletos.append(f)
        print(f"\n[OK] Fase 1 finalizada: {len(origen_totales)} folletos completos descargados en origen.")
    except Exception as e_orig:
        print(f"[!] Advertencia al scrapear folletos de origen oficial: {e_orig}")

    # 2. Cargar ofertas previas en caché para no volver a consultar catálogos ya procesados
    print("\n--------------------------------------------------------")
    print(" FASE 2: CATÁLOGOS COMPLEMENTARIOS Y OFERTAS ESTRUCTURADAS")
    print("--------------------------------------------------------")
    ofertas_existentes = {}
    csv_ofertas_ant = PROCESSED_DIR / "ofertas_semanales.csv"
    if csv_ofertas_ant.exists():
        try:
            df_ant = pd.read_csv(csv_ofertas_ant)
            for f_id_key, group in df_ant.groupby("folleto_id"):
                ofertas_existentes[str(f_id_key)] = group.to_dict(orient="records")
            print(f"[*] Se cargaron ofertas cacheadas de {len(ofertas_existentes)} folletos previos.")
        except Exception:
            pass

    for item_cadena in CADENAS_CONFIG:
        nombre = item_cadena["nombre"]
        slug = item_cadena["slug"]
        tipo = item_cadena["tipo"]
        
        print(f"\n[*] Consultando catálogos de {nombre} ({slug})...")
        flyers = obtener_folletos_cadena(slug)
        if not flyers:
            print(f"  -> No se encontraron folletos activos.")
            continue
            
        print(f"  -> {len(flyers)} folleto(s) detectado(s).")
        
        if limit_folletos_por_cadena:
            flyers = flyers[:limit_folletos_por_cadena]
            
        for f in flyers:
            f_id = str(f.get("id"))
            if not f_id or f_id in folletos_procesados_ids:
                continue
            folletos_procesados_ids.add(f_id)
            
            titulo = f.get("title") or f"Folleto {nombre}"
            start_date = str(f.get("start_date", ""))[:10] or None
            end_date = str(f.get("end_date", ""))[:10] or None
            
            # Determinar URL del visor interactivo funcional (evitar Zmags roto que da error 400)
            visor_url = f"https://www.tiendeo.com.ar/Catalogos/{f_id}"
                
            # Determinar portada y páginas de alta resolución disponibles en imageAssets
            assets = f.get("imageAssets", {}) or {}
            portada_origen = (
                assets.get("firstPage")
                or assets.get("big_webp")
                or assets.get("big")
                or ""
            )
            segunda_pagina_origen = assets.get("secondPage") or ""

            # 1. Evitar re-descarga de portada y páginas si ya existen en disco
            archivo_portada_local = FOLLETOS_RAW_DIR / f"portada_{f_id}.webp"
            descarga_ok = False
            if archivo_portada_local.exists() and archivo_portada_local.stat().st_size > 500:
                descarga_ok = True
            elif portada_origen:
                descarga_ok = descargar_imagen(portada_origen, archivo_portada_local)

            paginas_locales = []
            if descarga_ok:
                paginas_locales.append(archivo_portada_local.name)

            if segunda_pagina_origen:
                archivo_pag2_local = FOLLETOS_RAW_DIR / f"pagina_{f_id}_2.webp"
                pag2_ok = False
                if archivo_pag2_local.exists() and archivo_pag2_local.stat().st_size > 500:
                    pag2_ok = True
                else:
                    pag2_ok = descargar_imagen(segunda_pagina_origen, archivo_pag2_local)
                if pag2_ok:
                    paginas_locales.append(archivo_pag2_local.name)

            lista_folletos.append({
                "id": f_id,
                "cadena": nombre,
                "tipo_comercio": tipo,
                "titulo": titulo,
                "fecha_desde": start_date,
                "fecha_hasta": end_date,
                "portada_origen_url": portada_origen,
                "archivo_portada_local": str(archivo_portada_local.name) if descarga_ok else None,
                "paginas_locales": json.dumps(paginas_locales),
                "visor_url": visor_url,
                "activo": True
            })

            print(f"  [+] Folleto: {titulo} ({start_date or 'S/F'} a {end_date or 'S/F'})")
            
            # 2. Evitar re-scraping si ya tenemos las ofertas extraídas en caché
            if f_id in ofertas_existentes and len(ofertas_existentes[f_id]) > 0:
                print(f"      -> Reutilizando {len(ofertas_existentes[f_id])} ofertas en caché (ya procesadas anteriormente).")
                lista_ofertas.extend(ofertas_existentes[f_id])
                continue

            time.sleep(0.5)
            
            # Extraer ofertas individuales del catálogo solo si es un folleto nuevo
            gibs = obtener_ofertas_folleto(f_id)
            if gibs:
                print(f"      -> Extraídas {len(gibs)} ofertas estructuradas nuevas.")
                for idx, g in enumerate(gibs):
                    settings = g.get("settings", {}) or {}
                    
                    titulo_prod = str(g.get("title") or "").strip()
                    if not titulo_prod:
                        continue
                        
                    # Descartar promociones bancarias, de billeteras virtuales o institucionales que no son productos
                    t_lower = titulo_prod.lower()
                    desc_lower = str(g.get("description") or "").lower()
                    texto_completo = f"{t_lower} {desc_lower}"
                    es_promo_financiera = any(k in texto_completo for k in [
                        "jubilad", "banco", "tarjeta", "modo", "cuenta dni", "mercado pago",
                        "cuotas sin", "cuota sin", "reintegro", "tope de reintegro", "descuento con",
                        "beneficio anses", "bna+", "visa", "mastercard", "american express", "cabal"
                    ])
                    if es_promo_financiera:
                        continue
                        
                    marca = settings.get("brand") or None
                    descrip = g.get("description") or None
                    
                    # Precios
                    precio_str = settings.get("price")
                    precio_oferta = limpiar_precio(precio_str)
                    if not precio_oferta:
                        continue
                        
                    starting_price = settings.get("starting_price")
                    precio_ant = None
                    if isinstance(starting_price, dict):
                        precio_ant = limpiar_precio(starting_price.get("digits"))
                    elif starting_price:
                        precio_ant = limpiar_precio(starting_price)
                        
                    # Descuento
                    descuento = g.get("discount")
                    descuento_num = None
                    if descuento is not None:
                        try:
                            descuento_num = abs(int(float(descuento)))
                            if descuento_num > 99:
                                if precio_ant and precio_ant > precio_oferta:
                                    descuento_num = int(round(((precio_ant - precio_oferta) / precio_ant) * 100))
                                else:
                                    descuento_num = None
                        except (ValueError, TypeError):
                            pass
                    elif precio_ant and precio_ant > precio_oferta:
                        descuento_num = int(round(((precio_ant - precio_oferta) / precio_ant) * 100))
                        
                    # Página del catálogo
                    pag_str = settings.get("flyer_page")
                    pagina_num = None
                    if pag_str:
                        try:
                            pagina_num = int(pag_str)
                        except (ValueError, TypeError):
                            pass
                            
                    # Filtrar productos no deseados (juguetes, muebles, electro, etc.)
                    from filtro_fmcg import es_producto_supermercado
                    if not es_producto_supermercado(f"{titulo_prod} {descrip}", marca):
                        continue

                    # Imagen de recorte y descarga local para alojar en Supabase Storage
                    img_recorte = g.get("image") or settings.get("image_url") or None

                    # Generar ID determinístico para el producto de la oferta
                    item_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{f_id}_{idx}_{titulo_prod}"))
                    archivo_recorte_local = None
                    if img_recorte:
                        recorte_path = FOLLETOS_RAW_DIR / f"crop_{item_id}.webp"
                        if recorte_path.exists() and recorte_path.stat().st_size > 500:
                            archivo_recorte_local = recorte_path.name
                        elif descargar_imagen(img_recorte, recorte_path):
                            archivo_recorte_local = recorte_path.name

                    lista_ofertas.append({
                        "id": item_id,
                        "folleto_id": f_id,
                        "cadena": nombre,
                        "titulo": titulo_prod,
                        "marca": marca,
                        "presentacion": descrip,
                        "precio_oferta": precio_oferta,
                        "precio_anterior": precio_ant,
                        "descuento_porcentaje": descuento_num,
                        "numero_pagina": pagina_num,
                        "imagen_recorte_url": img_recorte,
                        "archivo_recorte_local": archivo_recorte_local,
                        "valido_desde": start_date,
                        "valido_hasta": end_date
                    })
            time.sleep(0.5)

    # Guardar en CSVs procesados
    df_folletos = pd.DataFrame(lista_folletos)
    csv_folletos = PROCESSED_DIR / "folletos.csv"
    df_folletos.to_csv(csv_folletos, index=False, encoding="utf-8")
    print(f"\n[OK] Se guardaron {len(df_folletos)} folletos en {csv_folletos}")

    df_ofertas = pd.DataFrame(lista_ofertas)
    csv_ofertas = PROCESSED_DIR / "ofertas_semanales.csv"
    df_ofertas.to_csv(csv_ofertas, index=False, encoding="utf-8")
    print(f"[OK] Se guardaron {len(df_ofertas)} ofertas estructuradas en {csv_ofertas}")

    # Limpieza en disco local de portadas de folletos obsoletos
    if FOLLETOS_RAW_DIR.exists():
        eliminados = 0
        for archivo in FOLLETOS_RAW_DIR.glob("portada_*.webp"):
            match = re.search(r"portada_(\d+)\.webp", archivo.name)
            if match and match.group(1) not in folletos_procesados_ids:
                try:
                    archivo.unlink()
                    eliminados += 1
                except Exception:
                    pass
        if eliminados > 0:
            print(f"[*] Limpieza local: se eliminaron {eliminados} portadas de folletos que ya no están vigentes.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Scraping de Folletos y Ofertas Semanales")
    parser.add_argument("--limit-folletos", type=int, default=None, help="Límite de folletos por cadena para pruebas")
    args = parser.parse_args()
    
    ejecutar_scraping_folletos(limit_folletos_por_cadena=args.limit_folletos)
