#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scrapers/vtex_client.py
-----------------------
Cliente para buscar precios por código de barras (EAN)
en supermercados que utilizan VTEX (Carrefour, Dia, Jumbo, Disco, Vea, MasOnline, Makro).

Utiliza la API REST nativa de VTEX Catalog System (`/api/catalog_system/pub/products/search?fq=alternateIds_Ean:{ean}`),
la cual es 100% estable y no sufre de expiración de hashes GraphQL (PersistedQueryNotFound).
"""

import sys
import time
import requests
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, List

INGESTA_DIR = Path(__file__).resolve().parent.parent
if str(INGESTA_DIR) not in sys.path:
    sys.path.insert(0, str(INGESTA_DIR))

try:
    from config import ZENROWS_API_KEY
except ImportError:
    ZENROWS_API_KEY = ""

DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json",
    "Accept-Language": "es-AR,es;q=0.9"
}

class VtexClient:
    def __init__(self, base_url: str, zenrows_api_key: str = None):
        """
        :param base_url: URL base de la tienda, ej: "https://www.carrefour.com.ar"
        """
        self.base_url = base_url.rstrip("/")
        self.search_url = f"{self.base_url}/api/catalog_system/pub/products/search"
        self.session = requests.Session()
        headers = dict(DEFAULT_HEADERS)
        headers["Referer"] = f"{self.base_url}/"
        self.session.headers.update(headers)
        self.zenrows_api_key = zenrows_api_key or ZENROWS_API_KEY
        self.fallback_active = False

    def _execute_request(self, params: dict) -> Optional[list]:
        full_target_url = requests.Request('GET', self.search_url, params=params).prepare().url
        # 1. Intentar localmente
        try:
            res = self.session.get(self.search_url, params=params, timeout=10)
            if res.status_code in (200, 206):
                data = res.json()
                if isinstance(data, list):
                    return data
                return None
            elif res.status_code in (403, 429, 500, 502, 503):
                from scrapers.zenrows_queue import registrar_url_bloqueada
                registrar_url_bloqueada(full_target_url, params.get("fq", ""), self.base_url, motivo=f"HTTP_{res.status_code}")
        except Exception as e:
            from scrapers.zenrows_queue import registrar_url_bloqueada
            registrar_url_bloqueada(full_target_url, params.get("fq", ""), self.base_url, motivo=str(e)[:50])

        return None

    def fetch_price_by_ean(self, ean: str) -> Optional[Dict]:
        """
        Busca el producto por EAN directo. Retorna un diccionario con precio, stock y metadatos.
        """
        clean_ean = str(ean).strip()
        if not clean_ean:
            return None

        params = {"fq": f"alternateIds_Ean:{clean_ean}"}

        try:
            data = self._execute_request(params)
            if not data or not isinstance(data, list):
                return None
            
            prod = data[0]
            items = prod.get("items", [])
            if not items:
                return None
            
            # Buscar el item correspondiente al EAN
            matched_item = None
            for it in items:
                if str(it.get("ean", "")) == clean_ean:
                    matched_item = it
                    break
            
            # Fallback al primer item si no coincide exactamente el string
            if not matched_item:
                matched_item = items[0]

            sellers = matched_item.get("sellers", [])
            if not sellers:
                return None

            offer = sellers[0].get("commertialOffer", {})
            price = offer.get("Price")
            if not price or float(price) <= 0:
                return None

            images = matched_item.get("images", [])
            image_url = images[0].get("imageUrl") if images else ""

            return {
                "id_producto": clean_ean,
                "precio": float(price),
                "stock": offer.get("AvailableQuantity", 0) > 0,
                "url": f"{self.base_url}/{prod.get('linkText', '')}/p",
                "fecha_captura": datetime.now().isoformat(),
                "nombre_scraper": prod.get("productName", ""),
                "marca": prod.get("brand", ""),
                "categorias": prod.get("categories", []),
                "imagen_url": image_url,
                "unidad_medida": matched_item.get("measurementUnit", ""),
                "multiplicador_unidad": matched_item.get("unitMultiplier", 1.0)
            }
        except Exception:
            return None

    def get_supermarket_category_paths(self) -> List[tuple]:
        """
        Obtiene las subcategorías de nivel 2 (o nivel 1 si no tienen hijos)
        filtradas por categorías de supermercado y farmacia, excluyendo electro, bazar, moda, etc.
        Retorna una lista de tuplas: (path_fq, nombre_descriptivo)
        Ejemplo: [("161/162/", "Almacén > Aceites y vinagres"), ...]
        """
        keywords_excluidas = [
            "electro", "tecnolog", "telefon", "audio", "video", "tv", "smart", "informati", "computa",
            "climatiza", "heladera", "lavarropa", "mueble", "colchon", "sabana", "toalla", "bazar", "vajilla",
            "decorac", "indumentaria", "calzado", "ropa", "moda", "textil", "ferreter", "herramient", "jardin",
            "pinturer", "automotor", "neumatic", "rodado", "bicicleta", "juguet", "librer", "papeler", "deporte", "fitness", "camping",
            "test category", "integraciones", "category"
        ]
        keywords_supermercado = [
            "almac", "lacte", "lcteo", "queso", "leche", "yogur", "fresco", "fruta", "verdura", "carne", "ave", "pescad",
            "fiambr", "bebid", "gaseos", "agua", "cervez", "vino", "jugo", "aperitiv", "sidra", "espumant",
            "limpiez", "higien", "cuidado", "perfum", "farmac", "salud", "dermo", "congelad", "comida", "panader", "panific",
            "reposter", "pasta", "desayuno", "merienda", "golosin", "chocolat", "galletit", "snack", "infus", "cafe", "te", "yerba",
            "mascota", "bebe", "panal", "infantil"
        ]

        def normalizar(s: str) -> str:
            s = s.lower()
            for a, b in [("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n")]:
                s = s.replace(a, b)
            return s

        try:
            tree_url = f"{self.base_url}/api/catalog_system/pub/category/tree/2"
            res = self.session.get(tree_url, timeout=8)
            if res.status_code != 200:
                return []
            tree = res.json()
            if not isinstance(tree, list):
                return []

            rutas = []
            for cat in tree:
                c1_name = normalizar(str(cat.get("name", "")))
                # Saltar si la categoría de nivel 1 es de electro/hogar y no es de limpieza/alimento
                if any(k in c1_name for k in keywords_excluidas) and not any(k in c1_name for k in ["limpieza", "alimento", "cuidado"]):
                    continue

                children = cat.get("children", [])
                if children:
                    for sc in children:
                        sc_name = normalizar(str(sc.get("name", "")))
                        if any(k in sc_name for k in keywords_excluidas):
                            continue
                        full_name = f"{c1_name} > {sc_name}"
                        if any(k in full_name for k in keywords_supermercado):
                            rutas.append((f"{cat['id']}/{sc['id']}/", f"{cat.get('name')} > {sc.get('name')}"))
                else:
                    if any(k in c1_name for k in keywords_supermercado):
                        rutas.append((f"{cat['id']}/", cat.get("name", "")))

            return rutas
        except Exception:
            return []

    def fetch_catalog_batch(self, from_idx: int, to_idx: int, fq: Optional[str] = None) -> List[Dict]:
        """
        Descarga un bloque de productos (hasta 50) de la API nativa de VTEX.
        URL: /api/catalog_system/pub/products/search?_from=X&_to=Y[&fq=C:X/Y/]
        """
        params = {"_from": from_idx, "_to": to_idx}
        if fq:
            params["fq"] = fq

        data = self._execute_request(params)
        if not data or not isinstance(data, list):
            return []

        resultados = []
        for prod in data:
            items = prod.get("items", [])
            if not items:
                continue
            for item in items:
                ean = str(item.get("ean", "")).strip()
                if not ean or len(ean) < 7:
                    continue
                sellers = item.get("sellers", [])
                if not sellers:
                    continue
                offer = sellers[0].get("commertialOffer", {})
                price = offer.get("Price")
                if not price or float(price) <= 0:
                    continue

                images = item.get("images", [])
                image_url = images[0].get("imageUrl") if images else ""

                resultados.append({
                    "id_producto": ean,
                    "precio": float(price),
                    "stock": offer.get("AvailableQuantity", 0) > 0,
                    "url": f"{self.base_url}/{prod.get('linkText', '')}/p",
                    "fecha_captura": datetime.now().isoformat(),
                    "nombre_scraper": prod.get("productName", ""),
                    "marca": prod.get("brand", ""),
                    "categorias": prod.get("categories", []),
                    "imagen_url": image_url,
                    "unidad_medida": item.get("measurementUnit", ""),
                    "multiplicador_unidad": item.get("unitMultiplier", 1.0)
                })
        return resultados

    def crawl_catalog(self, limit: Optional[int] = None, step: int = 50, verbose: bool = True) -> List[Dict]:
        """
        Recorre el catálogo de la tienda en bloques de 50 productos.
        Si limit is None o 0, extrae todo el catálogo disponible por subcategorías sin tope.
        Aprovecha el árbol de subcategorías para saltar el límite de 2,500 productos de VTEX.
        """
        subcats = self.get_supermarket_category_paths()
        domain_parts = self.base_url.replace("https://", "").replace("http://", "").split("/")[0].split(".")
        tienda_nombre = domain_parts[1].upper() if domain_parts[0] == "www" and len(domain_parts) > 1 else domain_parts[0].upper()

        if subcats:
            productos_por_ean = {}
            total_subcats = len(subcats)
            if verbose:
                print(f"[*] {tienda_nombre}: Barriendo {total_subcats} subcategorías de supermercado...")

            for idx, (path, desc) in enumerate(subcats, 1):
                current = 0
                fq_param = f"C:{path}"
                while True:
                    if limit and limit > 0 and len(productos_por_ean) >= limit:
                        break
                    if current >= 2500:
                        # Límite técnico máximo de VTEX por subcategoría individual
                        break

                    to_idx = current + step - 1
                    batch = self.fetch_catalog_batch(current, to_idx, fq=fq_param)
                    if not batch:
                        break

                    for item in batch:
                        ean = item["id_producto"]
                        if ean not in productos_por_ean:
                            productos_por_ean[ean] = item

                    if len(batch) < step:
                        # Se llegó al final de los productos de esta subcategoría
                        break

                    current += step
                    time.sleep(0.08)

                if verbose and (idx % 5 == 0 or idx == total_subcats):
                    sys.stdout.write(f"\r    {tienda_nombre}: Subcategorías {idx}/{total_subcats} | Total únicos: {len(productos_por_ean):,}")
                    sys.stdout.flush()

                if limit and limit > 0 and len(productos_por_ean) >= limit:
                    break

            if verbose:
                sys.stdout.write("\n")
                sys.stdout.flush()

            res_list = list(productos_por_ean.values())
            return res_list[:limit] if (limit and limit > 0) else res_list

        # Fallback a búsqueda plana global si no se pudo obtener el árbol de categorías
        precios = []
        current = 0
        max_search = min(limit, 2500) if (limit and limit > 0) else 2500
        while current < max_search:
            to_idx = min(current + step - 1, max_search - 1)
            batch = self.fetch_catalog_batch(current, to_idx)
            if not batch:
                break
            precios.extend(batch)
            current += step
            time.sleep(0.12)
        return precios

if __name__ == "__main__":
    c = VtexClient("https://www.carrefour.com.ar")
    print(c.fetch_price_by_ean("7790895000997"))
