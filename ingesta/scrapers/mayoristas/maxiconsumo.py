#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scrapers/mayoristas/maxiconsumo.py
----------------------------------
Cliente de scraping para Mayorista Maxiconsumo (Magento 2).
Busca productos por descripción/marca y extrae precio unitario y precio por bulto cerrado.
"""

import re
import requests
from bs4 import BeautifulSoup
from datetime import datetime
from typing import Optional, Dict

class MaxiconsumoClient:
    def __init__(self, sucursal: str = "sucursal_moreno"):
        self.base_url = "https://www.maxiconsumo.com"
        self.sucursal = sucursal
        self.search_url = f"{self.base_url}/{self.sucursal}/catalogsearch/result/"
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-AR,es;q=0.9"
        })

    def _parse_price(self, text: str) -> Optional[float]:
        if not text:
            return None
        clean = re.sub(r"[^\d,\.]", "", text)
        if "," in clean and "." in clean:
            clean = clean.replace(".", "").replace(",", ".")
        elif "," in clean:
            clean = clean.replace(",", ".")
        try:
            val = float(clean)
            return val if val > 0 else None
        except ValueError:
            return None

    def fetch_price(self, ean: str, query: str = None) -> Optional[Dict]:
        """
        Busca producto en Maxiconsumo por texto descriptivo / palabras clave.
        """
        search_term = (query or "").strip()
        if not search_term:
            return None

        # Limpiar palabras irrelevantes y puntuación para mejorar match en Magento
        tokens = [w for w in re.split(r"[\s\-_,./+]+", search_term) if len(w) > 1 and not w.isdigit()]
        if not tokens:
            return None
        
        # Usar los términos más representativos (marca + descripción, máx 4 palabras)
        clean_query = " ".join(tokens[:4])

        try:
            res = self.session.get(self.search_url, params={"q": clean_query}, timeout=10)
            if res.status_code != 200:
                return None

            soup = BeautifulSoup(res.text, "html.parser")
            items = soup.select(".product-item-info")
            if not items:
                return None

            # Tomar el primer resultado más relevante
            first_item = items[0]
            link = first_item.select_one(".product-item-link")
            title = link.text.strip() if link else ""
            p_url = link.get("href", "") if link else ""

            unit_price = None
            bulto_price = None

            containers = first_item.select(".price-container")
            for c in containers:
                label = c.select_one(".price-label")
                lbl_text = label.text.strip().lower() if label else ""
                val_span = c.select_one(".price-including-tax .price")
                val = self._parse_price(val_span.text if val_span else "")
                if "bulto" in lbl_text:
                    bulto_price = val
                elif "unitario" in lbl_text:
                    unit_price = val

            if not unit_price and not bulto_price:
                return None

            if unit_price is None and bulto_price is not None:
                unit_price = round(bulto_price * 1.15, 2)
            if bulto_price is None and unit_price is not None:
                bulto_price = round(unit_price * 0.88, 2)

            return {
                "id_producto": ean,
                "id_entidad": "maxiconsumo_online",
                "precio": unit_price,
                "precio_unitario": unit_price,
                "precio_bulto": bulto_price,
                "cantidad_bulto": 6,
                "stock": True,
                "url": p_url,
                "fecha_captura": datetime.now().isoformat(),
                "nombre_scraper": title
            }
        except Exception:
            return None

    def fetch_price_by_ean(self, ean: str, query: str = None) -> Optional[Dict]:
        return self.fetch_price(ean=ean, query=query)

if __name__ == "__main__":
    c = MaxiconsumoClient()
    print("Probando arroz ala:")
    print(c.fetch_price_by_ean("7790895000997", query="arroz ala largo 1kg"))
