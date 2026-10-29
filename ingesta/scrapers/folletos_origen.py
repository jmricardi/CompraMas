#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
folletos_origen.py
-------------------
Scrapers de ORIGEN OFICIAL para descargar revistas y folletos completos
directamente desde los portales de los supermercados y mayoristas:
- COTO: Todas las páginas en alta resolución vía CDN de Coto.
- CARREFOUR: Todas las páginas en alta resolución vía folletos.carrefour.com.ar.
- VITAL: Folletos completos en PDF descargables vía vital.com.ar.
- MAKRO: Folletos completos en PDF descargables vía CDN de Makro.
"""

import re
import json
import time
import uuid
import requests
from pathlib import Path
from bs4 import BeautifulSoup
from typing import List, Dict, Optional, Tuple

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

def descargar_recurso(url: str, destino: Path, timeout: int = 15) -> bool:
    """Descarga una imagen o PDF asegurando que no se corte."""
    if not url or not url.startswith("http"):
        return False
    destino.parent.mkdir(parents=True, exist_ok=True)
    if destino.exists() and destino.stat().st_size > 1000:
        return True
    try:
        r = requests.get(url, headers=HEADERS, timeout=timeout, stream=True)
        if r.status_code == 200:
            with open(destino, "wb") as f:
                for chunk in r.iter_content(chunk_size=16384):
                    if chunk:
                        f.write(chunk)
            if destino.stat().st_size > 1000:
                return True
            else:
                destino.unlink(missing_ok=True)
    except Exception as e:
        print(f"    [!] Error descargando {url[:60]}: {e}")
        destino.unlink(missing_ok=True)
    return False

def scrapear_coto_oficial(destino_dir: Path) -> List[Dict]:
    """
    Descarga los catálogos y todas las páginas oficiales de Coto.
    Fuente: https://www.coto.com.ar/institucional/carrousel.json
    """
    folletos = []
    print("\n[*] [ORIGEN COTO] Consultando catálogo oficial...")
    url_json = "https://www.coto.com.ar/institucional/carrousel.json"
    try:
        r = requests.get(url_json, headers=HEADERS, timeout=12)
        if r.status_code != 200:
            print("  [!] Error al obtener carrousel.json de Coto")
            return []
        items = r.json()
    except Exception as e:
        print(f"  [!] Excepción consultando Coto: {e}")
        return []

    # Extraer las revistas semanales
    revistas_procesadas = set()
    for item in items:
        img_path = item.get("imgPath", "")
        # Ejemplo: ../../images/catalogos/revistas/semanal-alimentos/pages/semanal-alimentos-1-121026.jpg
        match = re.search(r"revistas/([^/]+)/pages/([a-z0-9\-]+)-1-([0-9]+)\.jpg", img_path)
        if not match:
            continue
        
        tipo_revista = match.group(1) # ej. semanal-alimentos
        prefijo_pag = match.group(2)  # ej. semanal-alimentos
        fecha_cod = match.group(3)    # ej. 121026
        
        clave = f"coto_{tipo_revista}_{fecha_cod}"
        if clave in revistas_procesadas:
            continue
        revistas_procesadas.add(clave)
        
        # Mapear títulos amigables
        nombres_titulos = {
            "semanal-alimentos": "Coto - Revista Semanal Alimentos",
            "semanal-frescos": "Coto - Revista Semanal Frescos",
            "semanal-perfumeria": "Coto - Revista Semanal Perfumería y Limpieza",
            "semanal-hogar": "Coto - Revista Semanal Hogar y Bazar",
        }
        titulo = nombres_titulos.get(tipo_revista, f"Coto - {tipo_revista.replace('-', ' ').title()}")
        folleto_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, clave))

        print(f"  [+] Detectado: {titulo} (Fecha: {fecha_cod})")
        paginas_locales = []
        portada_nombre = None
        base_url = f"https://www.coto.com.ar/images/catalogos/revistas/{tipo_revista}/pages/{prefijo_pag}-{{}}-{fecha_cod}.jpg"
        
        # Escaneo de páginas de la revista completa
        for p in range(1, 35):
            url_pag = base_url.format(p)
            nom_archivo = f"coto_{tipo_revista}_{fecha_cod}_pag_{p}.jpg"
            dest_file = destino_dir / nom_archivo
            
            # Verificar si existe en el servidor
            r_head = requests.head(url_pag, headers=HEADERS, timeout=4)
            if r_head.status_code == 200:
                ok = descargar_recurso(url_pag, dest_file)
                if ok:
                    paginas_locales.append(nom_archivo)
                    if p == 1:
                        portada_nombre = nom_archivo
            else:
                break
                
        if paginas_locales:
            print(f"      -> Descargadas {len(paginas_locales)} páginas completas en alta resolución.")
            folletos.append({
                "id": folleto_id,
                "cadena": "Coto",
                "tipo_comercio": "minorista",
                "titulo": titulo,
                "fecha_desde": time.strftime("%Y-%m-%d"),
                "fecha_hasta": None,
                "portada_origen_url": base_url.format(1),
                "archivo_portada_local": portada_nombre,
                "paginas_locales": json.dumps(paginas_locales),
                "visor_url": "https://www.coto.com.ar/catalogos/index.asp",
                "activo": True
            })

    return folletos

def scrapear_carrefour_oficial(destino_dir: Path) -> List[Dict]:
    """
    Descarga los catálogos y todas las páginas oficiales de Carrefour.
    Fuente: https://folletos.carrefour.com.ar/metadata/catalogs.json
    """
    folletos = []
    print("\n[*] [ORIGEN CARREFOUR] Consultando catálogo oficial...")
    url_json = "https://folletos.carrefour.com.ar/metadata/catalogs.json"
    try:
        r = requests.get(url_json, headers=HEADERS, timeout=12)
        if r.status_code != 200:
            print("  [!] Error al obtener catalogs.json de Carrefour")
            return []
        data = r.json()
    except Exception as e:
        print(f"  [!] Excepción consultando Carrefour: {e}")
        return []

    # Priorizar CABA y BsAs
    catalogos_candidatos = data.get("caba", []) + data.get("bsas", [])
    vistos = set()
    hoy_str = time.strftime("%Y-%m-%d")

    for cat in catalogos_candidatos:
        link = cat.get("link", "")
        # Ejemplo link: ./assets/app_bsas_221024/
        clean_link = link.strip("./").strip("/")
        if not clean_link or clean_link in vistos:
            continue
        vistos.add(clean_link)
        
        # Validar fechas o tomar los más recientes
        to_date = cat.get("to", "")[:10]
        # Si el catálogo tiene fecha válida o es de los primeros 3 candidatos más recientes
        if len(folletos) >= 3 and to_date and to_date < hoy_str:
            continue
            
        titulo = f"Carrefour - {cat.get('title', 'Folleto Semanal')}"
        thumb = cat.get("thumb", "")
        # Ejemplo thumb: ./assets/app_bsas_221024/docs/FOLLETO-AHORRO-BUENOS-AIRES-22-10-24.pdf_1_thumb.jpg
        match_pdf = re.search(r"docs/([^/]+)\.pdf_1_thumb\.jpg", thumb)
        if not match_pdf:
            continue
        nombre_doc = match_pdf.group(1)
        
        folleto_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"carrefour_{clean_link}"))
        print(f"  [+] Detectado: {titulo}")
        
        paginas_locales = []
        portada_nombre = None
        base_url = f"https://folletos.carrefour.com.ar/{clean_link}/docs/{nombre_doc}.pdf_{{}}.jpg"
        
        # Escaneo de páginas completas
        slug_link = clean_link.replace("/", "_").replace("\\", "_")
        for p in range(1, 40):
            url_pag = base_url.format(p)
            nom_archivo = f"carrefour_{slug_link}_pag_{p}.jpg"
            dest_file = destino_dir / nom_archivo
            
            r_head = requests.head(url_pag, headers=HEADERS, timeout=4)
            if r_head.status_code == 200:
                ok = descargar_recurso(url_pag, dest_file)
                if ok:
                    paginas_locales.append(nom_archivo)
                    if p == 1:
                        portada_nombre = nom_archivo
            else:
                break
                
        if paginas_locales:
            print(f"      -> Descargadas {len(paginas_locales)} páginas completas en alta resolución.")
            folletos.append({
                "id": folleto_id,
                "cadena": "Carrefour",
                "tipo_comercio": "minorista",
                "titulo": titulo,
                "fecha_desde": cat.get("from", "")[:10] or hoy_str,
                "fecha_hasta": cat.get("to", "")[:10] or None,
                "portada_origen_url": base_url.format(1),
                "archivo_portada_local": portada_nombre,
                "paginas_locales": json.dumps(paginas_locales),
                "visor_url": f"https://folletos.carrefour.com.ar/{clean_link}/",
                "activo": True
            })

    return folletos

def scrapear_vital_oficial(destino_dir: Path) -> List[Dict]:
    """
    Descarga los folletos completos oficiales en PDF de Supermayorista Vital.
    Fuente: https://www.vital.com.ar/
    """
    folletos = []
    print("\n[*] [ORIGEN VITAL] Consultando catálogo oficial...")
    try:
        r = requests.get("https://www.vital.com.ar/", headers=HEADERS, timeout=12)
        if r.status_code != 200:
            return []
        soup = BeautifulSoup(r.text, "html.parser")
    except Exception as e:
        print(f"  [!] Excepción consultando Vital: {e}")
        return []

    pdfs_encontrados = set()
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if ".pdf" in href.lower() and "folletos" in href.lower():
            clean_pdf = href.split("?")[0]
            pdfs_encontrados.add(clean_pdf)

    hoy_str = time.strftime("%Y-%m-%d")
    for idx, pdf_url in enumerate(pdfs_encontrados, 1):
        nombre_pdf = Path(pdf_url).name
        nom_local = f"vital_folleto_{nombre_pdf}"
        dest_file = destino_dir / nom_local
        
        titulo = f"Vital - Folleto Mayorista #{idx}"
        print(f"  [+] Descargando PDF completo: {titulo} ({nombre_pdf})...")
        ok = descargar_recurso(pdf_url, dest_file, timeout=25)
        
        folleto_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"vital_{nombre_pdf}"))
        folletos.append({
            "id": folleto_id,
            "cadena": "Vital",
            "tipo_comercio": "mayorista",
            "titulo": titulo,
            "fecha_desde": hoy_str,
            "fecha_hasta": None,
            "portada_origen_url": pdf_url,
            "archivo_portada_local": nom_local if ok else None,
            "paginas_locales": json.dumps([nom_local]) if ok else json.dumps([]),
            "visor_url": pdf_url,
            "activo": True
        })

    return folletos

def scrapear_makro_oficial(destino_dir: Path) -> List[Dict]:
    """
    Descarga los folletos completos oficiales en PDF de Mayorista Makro.
    Fuente: https://makro.com.ar/ofertas/
    """
    folletos = []
    print("\n[*] [ORIGEN MAKRO] Consultando catálogo oficial...")
    try:
        r = requests.get("https://makro.com.ar/ofertas/", headers=HEADERS, timeout=12)
        if r.status_code != 200:
            return []
        soup = BeautifulSoup(r.text, "html.parser")
    except Exception as e:
        print(f"  [!] Excepción consultando Makro: {e}")
        return []

    vistos = set()
    hoy_str = time.strftime("%Y-%m-%d")

    for a in soup.find_all("a", href=True):
        href = a["href"]
        if ".pdf" in href.lower() and href not in vistos:
            vistos.add(href)
            texto = a.text.strip()
            titulo = f"Makro - {texto}" if texto else f"Makro - Folleto Mayorista"
            
            nombre_pdf = Path(href).name
            nom_local = f"makro_{nombre_pdf}"
            dest_file = destino_dir / nom_local
            
            print(f"  [+] Descargando PDF completo: {titulo} ({nombre_pdf})...")
            ok = descargar_recurso(href, dest_file, timeout=25)
            
            folleto_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"makro_{nombre_pdf}"))
            folletos.append({
                "id": folleto_id,
                "cadena": "Makro",
                "tipo_comercio": "mayorista",
                "titulo": titulo,
                "fecha_desde": hoy_str,
                "fecha_hasta": None,
                "portada_origen_url": href,
                "archivo_portada_local": nom_local if ok else None,
                "paginas_locales": json.dumps([nom_local]) if ok else json.dumps([]),
                "visor_url": href,
                "activo": True
            })

    return folletos
