#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scrapers/coto_client.py
-----------------------
Cliente para buscar precios por código de barras (EAN) en Coto Digital.
Utiliza la API JSON de Oracle Endeca con la interfaz `Ntk=product.eanPrincipal`
para búsquedas directas y ultra-precisas por código de barras.
"""

import sys
import requests
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict

INGESTA_DIR = Path(__file__).resolve().parent.parent
if str(INGESTA_DIR) not in sys.path:
    sys.path.insert(0, str(INGESTA_DIR))

try:
    from config import ZENROWS_API_KEY
except ImportError:
    ZENROWS_API_KEY = ""

DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "X-Requested-With": "XMLHttpRequest",
    "Referer": "https://www.cotodigital3.com.ar/sitios/cdigi/"
}

class CotoClient:
    def __init__(self, zenrows_api_key: str = None):
        self.base_url = "https://www.cotodigital3.com.ar"
        self.search_url = f"{self.base_url}/sitios/cdigi/categoria"
        self.session = requests.Session()
        self.session.headers.update(DEFAULT_HEADERS)
        self.zenrows_api_key = zenrows_api_key or ZENROWS_API_KEY

    def fetch_price_by_ean(self, ean: str) -> Optional[Dict]:
        """
        Busca el EAN exacto en Coto utilizando la interfaz Endeca product.eanPrincipal.
        Intenta localmente primero y commuta a ZenRows ante cualquier bloqueo o falla.
        """
        clean_ean = str(ean).strip()
        if not clean_ean:
            return None

        params = {
            "Ntk": "product.eanPrincipal",
            "Ntt": clean_ean,
            "format": "json"
        }
        
        data = None

        # 1. Intentar localmente
        full_target_url = requests.Request('GET', self.search_url, params=params).prepare().url
        try:
            res = self.session.get(self.search_url, params=params, timeout=10)
            if res.status_code == 200:
                data = res.json()
            elif res.status_code in (403, 429, 500, 502, 503):
                from scrapers.zenrows_queue import registrar_url_bloqueada
                registrar_url_bloqueada(full_target_url, clean_ean, "coto", motivo=f"HTTP_{res.status_code}")
        except Exception as e:
            from scrapers.zenrows_queue import registrar_url_bloqueada
            registrar_url_bloqueada(full_target_url, clean_ean, "coto", motivo=str(e)[:50])

        if data:
            return self._parse_endeca_response(data, clean_ean)
        return None

    def _parse_endeca_response(self, data: dict, ean: str) -> Optional[Dict]:
        try:
            contents = data.get("contents", [{}])[0]
            main_slots = [i for i in contents.get("Main", []) if i.get("@type") == "Main_Slot"]
            if not main_slots:
                return None
                
            slot_contents = main_slots[0].get("contents", [])
            if not slot_contents:
                return None
                
            records = slot_contents[0].get("records", [])
            if not records:
                return None
                
            # Cada record tiene un array de sub-records (SKUs)
            for rec in records:
                sub_records = rec.get("records", [])
                for sub in sub_records:
                    attrs = sub.get("attributes", {})
                    price_list = attrs.get("sku.activePrice", [])
                    if not price_list:
                        price_list = attrs.get("sku.referencePrice", [])
                        
                    if price_list:
                        try:
                            price = float(price_list[0])
                            if price > 0:
                                name_list = attrs.get("product.displayName", [""])
                                name = name_list[0] if name_list else ""
                                
                                url = ""
                                url_list = attrs.get("product.url", [])
                                if url_list:
                                    url = f"{self.base_url}{url_list[0]}"

                                return {
                                    "id_producto": ean,
                                    "precio": price,
                                    "stock": True,
                                    "url": url,
                                    "fecha_captura": datetime.now().isoformat(),
                                    "nombre_scraper": name
                                }
                        except (ValueError, TypeError):
                            continue
            return None
        except Exception:
            return None

if __name__ == "__main__":
    c = CotoClient()
    # Coca-Cola Zero 354ml
    print("Prueba Coto:", c.fetch_price_by_ean("7790895067587"))
