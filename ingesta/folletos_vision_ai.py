#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
folletos_vision_ai.py
---------------------
Módulo de Visión IA en Cascada y Pre-optimización WebP para catálogos y folletos
de supermercados en Argentina (CompraMas).

Orden de Cascada:
1. Google Gemini Flash-Lite (models/gemini-2.5-flash-lite)
2. OpenRouter API (meta-llama/llama-3.2-11b-vision-instruct o qwen/qwen-2.5-vl-72b-instruct)
3. Google Gemini Flash estándar (models/gemini-2.5-flash)
* Sin uso de modelos Gemini Pro.
"""

import os
import io
import re
import json
import time
import base64
import requests
from typing import List, Dict, Optional, Any
from pathlib import Path

from PIL import Image
from config import GEMINI_API_KEY, OPENROUTER_API_KEY, SUPABASE_URL, SUPABASE_KEY

PROMPT_EXTRACCION = """Analiza la siguiente página de catálogo/folleto de supermercado.
Extrae rigurosamente todos los productos individuales con ofertas, promociones o precios visibles.

REGLAS DE DOMINIO FMCG (SUPERMERCADO):
- INCLUIR ÚNICAMENTE: Alimentos, Bebidas, Artículos de Limpieza, Perfumería/Cuidado personal y Librería/Papelería escolar.
- DESCARTAR E IGNORAR TOTALMENTE:
  * Juguetes, juegos infantiles y cotillón.
  * Muebles, colchones y sommiers.
  * Jardinería, macetas, plantas y herramientas de jardín.
  * Electrodomésticos, televisores, celulares y electrónica.
  * Indumentaria, ropa, calzado, marroquinería y bazar pesado.
  * Medicamentos de farmacia con receta.

Devuelve ÚNICAMENTE un array JSON válido (sin explicaciones adicionales, sin markdown envolvente) donde cada elemento tenga:
- "producto": Nombre claro del producto con marca y contenido neto si está visible (ej: "Leche Entera La Serenísima 1L", "Café Dolca 170g")
- "precio_oferta": Precio numérico final en pesos argentinos (ej: 1850.00)
- "precio_regular": Precio anterior tachado si aparece (numérico o null)
- "descuento_porcentaje": Porcentaje de ahorro numérico (ej: 25 o null)
- "unidad": Unidad de medida indicada (ej: "un", "kg", "pack", "litro")
- "bounding_box": [ymin, xmin, ymax, xmax] coordenadas relativas del producto en la página entre 0 y 1000
"""

def optimizar_imagen_bytes(image_bytes: bytes, max_width: int = 1080, quality: int = 80) -> bytes:
    """Convierte y optimiza cualquier imagen a formato WebP conservando relación de aspecto."""
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        if img.width > max_width:
            ratio = max_width / float(img.width)
            new_height = int(float(img.height) * ratio)
            img = img.resize((max_width, new_height), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        img.save(out, format="WEBP", quality=quality, method=6)
        return out.getvalue()
    except Exception as e:
        print(f"    [!] Error al optimizar imagen: {e}")
        return image_bytes

def rasterizar_pdf_a_webp(pdf_path_or_bytes: Any, max_width: int = 1080, quality: int = 80) -> List[bytes]:
    """Convierte todas las páginas de un archivo PDF a una lista de bytes de imágenes WebP optimizadas."""
    paginas_webp = []
    try:
        import pypdfium2 as pdfium
        pdf = pdfium.PdfDocument(pdf_path_or_bytes)
        for i, page in enumerate(pdf):
            image = page.render(scale=2).to_pil()
            img_rgb = image.convert("RGB")
            if img_rgb.width > max_width:
                ratio = max_width / float(img_rgb.width)
                new_height = int(float(img_rgb.height) * ratio)
                img_rgb = img_rgb.resize((max_width, new_height), Image.Resampling.LANCZOS)
            out = io.BytesIO()
            img_rgb.save(out, format="WEBP", quality=quality, method=6)
            paginas_webp.append(out.getvalue())
        print(f"    [OK] PDF rasterizado exitosamente: {len(paginas_webp)} páginas WebP generadas.")
    except ImportError:
        print("    [!] pypdfium2 no instalado. Instalar con: pip install pypdfium2")
    except Exception as e:
        print(f"    [!] Error al rasterizar PDF: {e}")
    return paginas_webp

def _extraer_con_gemini(image_bytes: bytes, model_name: str) -> Optional[List[Dict]]:
    """Consulta la API de Google Gemini enviando la imagen en Base64."""
    if not GEMINI_API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/{model_name}:generateContent?key={GEMINI_API_KEY}"
    b64_img = base64.b64encode(image_bytes).decode("utf-8")
    
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": PROMPT_EXTRACCION},
                    {
                        "inline_data": {
                            "mime_type": "image/webp",
                            "data": b64_img
                        }
                    }
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json"
        }
    }

    try:
        r = requests.post(url, json=payload, timeout=25)
        if r.status_code == 200:
            data = r.json()
            candidates = data.get("candidates", [])
            if candidates:
                content = candidates[0].get("content", {})
                parts = content.get("parts", [])
                if parts:
                    raw_text = parts[0].get("text", "").strip()
                    # Limpiar markdown si viene envuelto
                    raw_text = re.sub(r"^```json\s*", "", raw_text, flags=re.MULTILINE)
                    raw_text = re.sub(r"^```\s*$", "", raw_text, flags=re.MULTILINE)
                    parsed = json.loads(raw_text)
                    if isinstance(parsed, list):
                        return parsed
        elif r.status_code in (429, 503):
            print(f"    [!] Gemini {model_name} rate limit / cuota agotada ({r.status_code}). Pasando a fallback...")
        else:
            print(f"    [!] Gemini {model_name} HTTP {r.status_code}: {r.text[:120]}")
    except Exception as e:
        print(f"    [!] Error en Gemini {model_name}: {e}")
    return None

def _extraer_con_openrouter(image_bytes: bytes, model_name: str = "meta-llama/llama-3.2-11b-vision-instruct:free") -> Optional[List[Dict]]:
    """Consulta la API de OpenRouter con modelos de visión alternativos."""
    if not OPENROUTER_API_KEY:
        return None
    url = "https://openrouter.ai/api/v1/chat/completions"
    b64_img = base64.b64encode(image_bytes).decode("utf-8")
    
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://compramas.app",
        "X-Title": "CompraMas Folletos Ingest"
    }

    payload = {
        "model": model_name,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": PROMPT_EXTRACCION},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/webp;base64,{b64_img}"
                        }
                    }
                ]
            }
        ],
        "temperature": 0.1
    }

    try:
        r = requests.post(url, headers=headers, json=payload, timeout=30)
        if r.status_code == 200:
            data = r.json()
            choices = data.get("choices", [])
            if choices:
                raw_text = choices[0].get("message", {}).get("content", "").strip()
                raw_text = re.sub(r"^```json\s*", "", raw_text, flags=re.MULTILINE)
                raw_text = re.sub(r"^```\s*$", "", raw_text, flags=re.MULTILINE)
                match = re.search(r"\[.*\]", raw_text, re.DOTALL)
                if match:
                    parsed = json.loads(match.group(0))
                    if isinstance(parsed, list):
                        return parsed
        else:
            print(f"    [!] OpenRouter {model_name} HTTP {r.status_code}: {r.text[:120]}")
    except Exception as e:
        print(f"    [!] Error en OpenRouter {model_name}: {e}")
    return None

def extraer_ofertas_vision_cascada(
    image_bytes: bytes,
    cadena: str = "",
    folleto_id: str = "",
    numero_pagina: int = 1
) -> List[Dict]:
    """
    Ejecuta el pipeline de Visión IA en cascada:
    1. Gemini 2.5 Flash-Lite
    2. OpenRouter (Llama 3.2 Vision / Qwen 2.5 VL)
    3. Gemini 2.5 Flash tradicional
    """
    opt_bytes = optimizar_imagen_bytes(image_bytes)

    # Nivel 1: Gemini Flash-Lite
    print(f"    [*] Procesando pág. {numero_pagina} con Nivel 1: gemini-2.5-flash-lite...")
    res = _extraer_con_gemini(opt_bytes, "models/gemini-2.5-flash-lite")
    if res is not None:
        print(f"    [OK] Nivel 1 exitoso: {len(res)} ofertas detectadas.")
        return _sanitizar_ofertas(res, cadena, folleto_id, numero_pagina)

    # Nivel 2: OpenRouter (Fallback)
    if OPENROUTER_API_KEY:
        print(f"    [*] Activando Nivel 2: OpenRouter (Llama 3.2 Vision)...")
        res = _extraer_con_openrouter(opt_bytes, "meta-llama/llama-3.2-11b-vision-instruct:free")
        if res is None:
            res = _extraer_con_openrouter(opt_bytes, "qwen/qwen-2.5-vl-72b-instruct")
        if res is not None:
            print(f"    [OK] Nivel 2 exitoso: {len(res)} ofertas detectadas.")
            return _sanitizar_ofertas(res, cadena, folleto_id, numero_pagina)

    # Nivel 3: Gemini Flash estándar (Fallback final)
    print(f"    [*] Activando Nivel 3: gemini-2.5-flash...")
    res = _extraer_con_gemini(opt_bytes, "models/gemini-2.5-flash")
    if res is not None:
        print(f"    [OK] Nivel 3 exitoso: {len(res)} ofertas detectadas.")
        return _sanitizar_ofertas(res, cadena, folleto_id, numero_pagina)

    print(f"    [!] No se pudieron extraer ofertas para la pág. {numero_pagina}.")
    return []

def _sanitizar_ofertas(
    raw_list: List[Dict],
    cadena: str,
    folleto_id: str,
    numero_pagina: int
) -> List[Dict]:
    """Limpia y tipifica los campos devueltos por la IA."""
    sanitized = []
    from filtro_fmcg import es_producto_supermercado

    for item in raw_list:
        prod_name = str(item.get("producto") or "").strip()
        if not prod_name or len(prod_name) < 3:
            continue

        if not es_producto_supermercado(prod_name):
            continue
        
        po = item.get("precio_oferta")
        try:
            precio_oferta = float(po) if po is not None else 0.0
        except (ValueError, TypeError):
            precio_oferta = 0.0

        pr = item.get("precio_regular")
        try:
            precio_regular = float(pr) if pr is not None else None
        except (ValueError, TypeError):
            precio_regular = None

        desc = item.get("descuento_porcentaje")
        try:
            descuento = float(desc) if desc is not None else None
        except (ValueError, TypeError):
            descuento = None

        if precio_regular and precio_oferta and precio_regular > precio_oferta and not descuento:
            descuento = round(((precio_regular - precio_oferta) / precio_regular) * 100.0, 1)

        sanitized.append({
            "folleto_id": folleto_id,
            "numero_pagina": numero_pagina,
            "cadena": cadena,
            "producto": prod_name,
            "precio_oferta": precio_oferta,
            "precio_regular": precio_regular,
            "descuento_porcentaje": descuento,
            "unidad": str(item.get("unidad") or "un").strip(),
            "coordenadas": item.get("bounding_box")
        })
    return sanitized
