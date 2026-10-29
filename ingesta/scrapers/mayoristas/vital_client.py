#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scrapers/mayoristas/vital_client.py
------------------------------------
Cliente de scraping para Mayorista Vital (tiendaonline.vital.com.ar).
Utiliza la API REST nativa de VTEX Intelligent Search para buscar por EAN exacto
o por búsqueda de texto de producto (?query=...).
"""

import re
import time
import requests
from datetime import datetime
from typing import Optional, Dict, List

class VitalClient:
    def __init__(self):
        self.base_url = "https://tiendaonline.vital.com.ar"
        self.search_url = f"{self.base_url}/api/io/_v/api/intelligent-search/product_search"
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
            "Accept-Language": "es-AR,es;q=0.9"
        })

    def _extract_from_product(self, prod: dict, ean: str) -> Optional[Dict]:
        items = prod.get("items", [])
        if not items:
            return None

        # Preferir item que coincida con el EAN
        matched_item = None
        for item in items:
            if str(item.get("ean", "")).strip() == ean:
                matched_item = item
                break
        if not matched_item:
            matched_item = items[0]

        sellers = matched_item.get("sellers", [])
        if not sellers:
            return None

        offer = sellers[0].get("commertialOffer", {})
        price = offer.get("Price")
        if not price or float(price) <= 0:
            return None

        unit_price = float(price)
        cant_bulto = 6
        bulto_price = None

        teasers = offer.get("teasers", [])
        if teasers and isinstance(teasers, list):
            for t in teasers:
                conditions = t.get("conditions", {})
                min_qty = conditions.get("minimumQuantity")
                if min_qty and int(min_qty) > 1:
                    cant_bulto = int(min_qty)
                    effects = t.get("effects", {}).get("parameters", [])
                    for p in effects:
                        if p.get("name") == "PercentualDiscount":
                            desc = float(p.get("value", 0))
                            bulto_price = round(unit_price * (1 - desc / 100), 2)

        if bulto_price is None:
            bulto_price = round(unit_price * 0.90, 2)

        return {
            "id_producto": ean,
            "id_entidad": "vital_online",
            "precio": unit_price,
            "precio_unitario": unit_price,
            "precio_bulto": bulto_price,
            "cantidad_bulto": cant_bulto,
            "stock": offer.get("AvailableQuantity", 0) > 0,
            "url": f"{self.base_url}/{prod.get('linkText', '')}/p",
            "fecha_captura": datetime.now().isoformat(),
            "nombre_scraper": prod.get("productName", "")
        }

    def fetch_price_by_ean(self, ean: str) -> Optional[Dict]:
        clean_ean = str(ean).strip()
        if not clean_ean:
            return None

        try:
            res = self.session.get(self.search_url, params={"query": clean_ean}, timeout=10)
            if res.status_code == 200:
                data = res.json()
                products = data.get("products", [])
                for prod in products:
                    for it in prod.get("items", []):
                        if str(it.get("ean", "")).strip() == clean_ean:
                            return self._extract_from_product(prod, clean_ean)
            return None
        except Exception:
            return None

    def fetch_price(self, ean: str, query: str = None) -> Optional[Dict]:
        # 1. Intentar por EAN directo
        res = self.fetch_price_by_ean(ean)
        if res:
            return res

        # 2. Búsqueda por texto (marca + descripción)
        if not query:
            return None

        tokens = [w for w in re.split(r"[\s\-_,./+]+", query) if len(w) > 1 and not w.isdigit()]
        if not tokens:
            return None
        clean_q = " ".join(tokens[:3])

        try:
            res = self.session.get(self.search_url, params={"query": clean_q}, timeout=10)
            if res.status_code == 200:
                data = res.json()
                products = data.get("products", [])
                if products:
                    return self._extract_from_product(products[0], ean)
            return None
        except Exception:
            return None

    def crawl_catalog(self, max_pages: int = 150, page_size: int = 50) -> List[Dict]:
        """
        Descarga el catálogo completo de Vital usando la paginación nativa de Intelligent Search.
        Permite extraer miles de productos con precio unitario y bulto en cuestión de segundos.
        """
        precios = []
        page = 1
        
        while page <= max_pages:
            try:
                params = {"page": page, "count": page_size}
                res = self.session.get(self.search_url, params=params, timeout=12)
                if res.status_code != 200:
                    break
                data = res.json()
                products = data.get("products", [])
                if not products:
                    break
                
                for prod in products:
                    for it in prod.get("items", []):
                        ean = str(it.get("ean", "")).strip()
                        if ean and len(ean) >= 7:
                            item_dict = self._extract_from_product(prod, ean)
                            if item_dict:
                                precios.append(item_dict)
                                break  # 1 precio representativo por producto
                                
                total_records = data.get("recordsFiltered", 0)
                if len(products) < page_size or (page * page_size) >= total_records:
                    break
                    
                page += 1
                time.sleep(0.1)
            except Exception as e:
                break
                
        return precios

if __name__ == "__main__":
    c = VitalClient()
    print("Probando Natura por EAN:")
    print(c.fetch_price_by_ean("7790272001005"))
    print("\nProbando Arroz por texto:")
    print(c.fetch_price("123456", query="arroz ala 1kg"))

