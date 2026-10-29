#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sanitizar_catalogo_canonica.py
--------------------------------
Sanea integralmente el catálogo y árbol de clústeres de CompraMás:
1. Erradica la redundancia Producto-Variedad (el producto básico jamás forma parte de la variedad).
2. Separa rigurosamente Premezclas de Harinas de Trigo.
3. Separa Harinas no-trigo (algarroba, almendras, arroz, avena, centeno, garbanzo, etc.).
4. Erradica marcas comerciales (Pérgola, Onza de Oro, Morixe, etc.) de los nombres de producto y variedades.
5. Reclasifica marcas como Cindor en Producto: Leche, Variedad: Chocolatada.
6. Fusiona atómicamente variedades y clústeres homónimos para evitar nodos paralelos duplicados.
7. Aplica el filtro estricto de FMCG (descarta fertilizantes como harina de hueso, pérgolas de jardín, etc.).
8. Sincroniza 'arbol_clusters_depurado.json', 'producto_clusters.csv' y 'producto_cluster_items.csv'.
"""

import os
import re
import sys
import json
import shutil
import pandas as pd
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Set, Tuple

# Rutas
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
CLUSTERS_DIR = DATA_DIR / "clusters"
PROCESSED_DIR = DATA_DIR / "processed"

INPUT_AUDITORIA_JSON = CLUSTERS_DIR / "arbol_clusters_auditoria.json"
REPORTE_AUDITORIA_JSON = CLUSTERS_DIR / "reporte_auditoria.json"
OUTPUT_DEPURADO_JSON = CLUSTERS_DIR / "arbol_clusters_depurado.json"
CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CATALOGO_CSV = PROCESSED_DIR / "catalogo_productos.csv"

# Importar filtro FMCG oficial
sys.path.append(str(BASE_DIR))
from filtro_fmcg import es_producto_supermercado

# Marcas comerciales que NUNCA deben formar parte del producto básico ni de la variedad
MARCAS_CONOCIDAS = {
    "arcor", "marolio", "morixe", "la_serenisima", "serenisima", "sancor", "ilolay",
    "dia", "carrefour", "coto", "great_value", "cuisine_co", "vea", "jumbo", "disco",
    "la_campagnola", "campagnola", "knorr", "hellmanns", "natura", "canuelas", "cañuelas", "molinos",
    "lucchetti", "matarazzo", "gallo", "dos_hermanos", "pureza", "favorita", "chango",
    "ledesma", "taragui", "playadito", "nobleza_gaucha", "amanda", "cruz_de_malta",
    "coca_cola", "pepsi", "sprite", "fanta", "quilmes", "brahma", "stella_artois", "heineken",
    "villavicencio", "villa_del_sur", "eco_de_los_andes", "glaciar", "ser", "danonino",
    "ala", "skip", "ariel", "zorro", "magistral", "cif", "ayudin", "clorox",
    "higienol", "elite", "elegante", "sussex", "campanita", "scott", "colgate", "sedal",
    "dove", "rexona", "pantene", "plusbelle", "nivea", "huggies", "pampers", "babysec",
    "blancaflor", "chacabuco", "carlos_casado", "tregar", "milkaut", "veronica", "manfrey",
    "tonadita", "la_paulina", "danica", "paty", "swift", "paladini", "fargo", "bimbo", "lactal",
    "bagley", "terrabusi", "oreo", "milka", "cofler", "aguila", "bonafide", "cabrales",
    "la_virginia", "neste", "nestle", "nescafe", "dolca", "bc", "tang", "clight", "cepita",
    "baggio", "citric", "levite", "villamanaos", "manaos", "secco", "pritty", "schneider",
    "imperial", "patagonia", "corona", "budweiser", "miller", "andes", "gancia", "fernet_branca",
    "pergola", "onza_de_oro", "onza de oro", "onza", "cindor", "exquisita", "royal", "fleischmann",
    "kapac", "dicomere", "schar", "epicos", "natural_pop", "le_fit", "sturla", "don_ubaldo", "mama_cocina",
    "bulnez", "caserita", "celestial", "grhesa", "parque", "ricafina"
}

def capitalizar_titulo(texto: str) -> str:
    """Capitaliza estilo título preservando conectores menores y siglas en mayúsculas."""
    conectores = {"de", "del", "la", "las", "el", "los", "en", "y", "o", "con", "sin", "para", "por", "al", "a"}
    palabras = texto.strip().split()
    if not palabras:
        return ""
    resultado = []
    for i, p in enumerate(palabras):
        p_up = p.upper()
        if p_up in ("TACC", "UHT", "PET", "000", "0000", "00", "KG", "GR", "ML", "CC", "L", "LT", "XL", "XXL"):
            resultado.append(p_up)
        elif i > 0 and p.lower() in conectores:
            resultado.append(p.lower())
        else:
            resultado.append(p.capitalize())
    return " ".join(resultado)

def limpiar_variedad_redundante(variedad_raw: str, producto_basico: str) -> str:
    """
    Elimina cualquier token del producto básico (en singular o plural) y marcas comerciales
    de la variedad.
    """
    if not variedad_raw or str(variedad_raw).strip() in ("nan", "None", "null", ""):
        return "Clásico"

    var = str(variedad_raw).strip()
    # Extraer palabras del producto para buscar coincidencias
    pb_tokens = [w.lower() for w in re.findall(r'\b[a-zA-ZáéíóúÁÉÍÓÚñÑ]{3,}\b', producto_basico)]
    
    # Quitar menciones a marcas conocidas
    for m in MARCAS_CONOCIDAS:
        pat = r'\b' + re.escape(m.replace("_", " ")) + r'\b'
        var = re.sub(pat, " ", var, flags=re.IGNORECASE)

    # Quitar palabras del producto básico (singular y plural con s/es)
    for pt in pb_tokens:
        if pt in ["con", "sin", "para", "del", "los", "las", "una"]:
            continue
        # Eliminar token en plural o singular
        pat = r'\b' + re.escape(pt) + r'(?:es|s)?\b'
        var = re.sub(pat, " ", var, flags=re.IGNORECASE)

    # Limpiar conectores iniciales huérfanos (ej: "De Frutas" -> "Frutas", "Con Gas" se mantiene)
    var = re.sub(r'^(?:de|del|la|el|los|las)\s+', '', var.strip(), flags=re.IGNORECASE)
    var = re.sub(r'\s+', ' ', var).strip()

    if not var or var.lower() in ("clasico", "clasica", "comun", "estandar", "regular", "original"):
        return "Clásico"

    return capitalizar_titulo(var)

def parsear_contenido_neto(contenido_neto_val: Any, unidad_ref: Any, presentacion_raw: str = "") -> Tuple[float, str]:
    """Extrae valor numérico y unidad de medida estandarizada."""
    try:
        val = float(contenido_neto_val)
        if val > 0:
            und = str(unidad_ref or "").strip().lower()
            if und in ("kg", "kilo", "kilos"):
                if val < 1.0:
                    return round(val * 1000, 1), "g"
                return val, "kg"
            if und in ("l", "lt", "litro", "litros"):
                if val < 1.0:
                    return round(val * 1000, 1), "ml"
                return val, "litro"
            if und:
                return val, und
    except (ValueError, TypeError):
        pass

    # Fallback: parsear desde presentacion_raw (ej. '1 L', '500 g', '200 ml')
    s = str(presentacion_raw or "").strip()
    m = re.search(r"([\d.,]+)\s*(kg|g|gr|l|lt|ml|cc|un)", s, re.IGNORECASE)
    if m:
        num_str = m.group(1).replace(",", ".")
        und_str = m.group(2).lower()
        try:
            val = float(num_str)
            if und_str in ("l", "lt"):
                return val, "litro"
            if und_str in ("gr", "g"):
                return val, "g"
            if und_str in ("cc", "ml"):
                return val, "ml"
            return val, und_str
        except ValueError:
            pass

    return 1.0, "litro" if "leche" in str(presentacion_raw).lower() else "un"

# Fotos e información canónica verificada para representantes líderes oficiales de Leche
FOTOS_OFICIALES_LECHE = {
    ("Entera", "Cartón (Tetra Brik)"): {
        "ean": "7790742335500",
        "marca": "La Serenísima",
        "nombre_comercial": "Leche Entera UAT Fortificada La Serenísima 1 L",
        "imagen_url": "https://images.openfoodfacts.org/images/products/779/074/233/5500/front_es.16.400.jpg"
    },
    ("Entera", "Sachet"): {
        "ean": "7790742448309",
        "marca": "La Serenísima",
        "nombre_comercial": "Leche Entera Clásica Sachet La Serenísima 1 L",
        "imagen_url": "https://images.openfoodfacts.org/images/products/779/074/244/8309/front_es.16.400.jpg"
    },
    ("Descremada", "Cartón (Tetra Brik)"): {
        "ean": "7790742335609",
        "marca": "La Serenísima",
        "nombre_comercial": "Leche Parcialmente Descremada UAT La Serenísima 1 L",
        "imagen_url": "https://images.openfoodfacts.org/images/products/779/074/233/5609/front_es.16.400.jpg"
    },
    ("Descremada", "Sachet"): {
        "ean": "7790742448408",
        "marca": "La Serenísima",
        "nombre_comercial": "Leche Parcialmente Descremada Sachet La Serenísima 1 L",
        "imagen_url": "https://images.openfoodfacts.org/images/products/779/074/244/8408/front_es.16.400.jpg"
    },
    ("Deslactosada", "Cartón (Tetra Brik)"): {
        "ean": "7790787960767",
        "marca": "Ilolay",
        "nombre_comercial": "Leche Lv Fortificada 0% Lactosa Ilolay 1 L",
        "imagen_url": "https://images.openfoodfacts.org/images/products/779/078/796/0767/front_es.14.400.jpg"
    }
}

def limpiar_ingredientes(ingredientes: str, prod_basico: str, variedad: str) -> str:
    """Limpia ingredientes descartando leyendas legales y regulatorias de la Ley 27.642."""
    if not ingredientes or not isinstance(ingredientes, str):
        return f"{prod_basico} {variedad}".strip()
    s = ingredientes.strip()
    if any(k in s.lower() for k in [
        "ley 27.642", "ley 27642", "conforme a la ley", "declaración", "resolución", "artículo",
        "sellos de advertencia", "exento según", "rotulado nutricional", "ministerio de salud"
    ]):
        if prod_basico.lower() == "leche":
            if "entera" in variedad.lower():
                return "Leche entera, vitaminas A y D"
            elif "descremada" in variedad.lower():
                return "Leche descremada, vitaminas A y D"
            elif "deslactosada" in variedad.lower():
                return "Leche, enzima lactasa, vitaminas A y D"
            elif "chocolatada" in variedad.lower():
                return "Leche parcialmente descremada, azúcar, cacao, vitaminas A y D"
        return f"{prod_basico} {variedad}".strip()
    return s

def _obtener_perfil_leche(var_dest: str) -> Dict[str, Any]:
    v_low = var_dest.lower()
    if "entera" in v_low:
        return {
            "fuente": "argenfoods",
            "ingredientes": "Leche entera, vitaminas A y D",
            "sellos_ley_27642": "Exento de sellos de advertencia (Ley 27.642)",
            "argenfoods_datos": {
                "id_oficial": "arg_leche_entera_fluida",
                "nombre_oficial": "Leche entera fluida",
                "tabla": "Tabla Oficial de Composición de Alimentos (República Argentina)",
                "exento_ley_27642": True
            },
            "open_food_facts_datos": None
        }
    elif "descremada" in v_low:
        return {
            "fuente": "argenfoods",
            "ingredientes": "Leche descremada, vitaminas A y D",
            "sellos_ley_27642": "Exento de sellos de advertencia (Ley 27.642)",
            "argenfoods_datos": {
                "id_oficial": "arg_leche_descremada_fluida",
                "nombre_oficial": "Leche descremada fluida",
                "tabla": "Tabla Oficial de Composición de Alimentos (República Argentina)",
                "exento_ley_27642": True
            },
            "open_food_facts_datos": None
        }
    elif "deslactosada" in v_low:
        return {
            "fuente": "argenfoods",
            "ingredientes": "Leche, enzima lactasa, vitaminas A y D",
            "sellos_ley_27642": "Exento de sellos de advertencia (Ley 27.642)",
            "argenfoods_datos": {
                "id_oficial": "arg_leche_deslactosada_fluida",
                "nombre_oficial": "Leche deslactosada fluida",
                "tabla": "Tabla Oficial de Composición de Alimentos (República Argentina)",
                "exento_ley_27642": True
            },
            "open_food_facts_datos": None
        }
    elif "chocolatada" in v_low:
        return {
            "fuente": "argenfoods",
            "ingredientes": "Leche parcialmente descremada, azúcar, cacao, vitaminas A y D",
            "sellos_ley_27642": "Exceso en azúcares",
            "argenfoods_datos": None,
            "open_food_facts_datos": None
        }
    else:
        return {
            "fuente": "argenfoods",
            "ingredientes": "Leche, vitaminas A y D",
            "sellos_ley_27642": "Exento de sellos de advertencia (Ley 27.642)",
            "argenfoods_datos": {"exento_ley_27642": True},
            "open_food_facts_datos": None
        }

def es_producto_anomalo(pb: str) -> bool:
    """Detecta si un producto básico es numérico, dimensión, abreviatura espuria o ruido."""
    pb_s = str(pb or "").strip()
    if pb_s.lower() == "te":
        return False
    if re.match(r'^[0-9]', pb_s):
        return True
    if len(pb_s) <= 2:
        return True
    if re.search(r'[0-9]x[0-9]|[0-9]cm|[0-9]sob|[0-9]saq|[0-9]cub', pb_s, re.IGNORECASE):
        return True
    return False

def inferir_producto_real(desc: str, marca: str) -> Tuple[Any, Any, Any]:
    """
    Infiere el producto básico, variedad y categoría legítimos de FMCG a partir de la descripción.
    Retorna (producto, variedad, categoria) o (None, None, None) si debe descartarse.
    """
    s = f"{desc} {marca}".lower()

    # Descartar medicamentos / fármacos
    if any(k in s for k in ['oxazepam', 'b-alanina', 'b-sitosterol', 'l-carnitina', 'l-cistina', 'ampolla', 'medicamento', 'comprimido', 'comp ']):
        return None, None, None

    # Descartar juguetes / bazar / electrodomésticos / textil / ferretería
    if any(k in s for k in [
        'domino', 'loteria', 'puzzle', 'juego de mesa', '4 en linea', 'persianero', 'bandeja',
        'frasco vidrio', 'lata 12cm', 'capsula lata', 'v.techo', 'ventilador', 'zueco', 'zoquete',
        'zalea', 'zombie kittens'
    ]):
        return None, None, None

    if 'harina' in s or '4/0' in s:
        v = '0000' if '0000' in s or '4/0' in s else '000'
        return 'Harina de Trigo', v, 'Almacén'
    if any(k in s for k in ['leche en polvo', 'vital 1', 'vital 2', 'vital 3', 'profutura', 'crecer plus', 'nutrilon', 'infantil']):
        v = 'Etapa 1' if '1' in s else ('Etapa 2' if '2' in s else ('Etapa 3' if '3' in s else ('Etapa 4' if '4' in s else 'Clásico')))
        return 'Leche Infantil', v, 'Bebés y Maternidad'
    if 'pollo' in s:
        return 'Pollo', 'Fresco', 'Frescos'
    if 'papel hig' in s or 'higienol' in s:
        v = 'Hoja Simple' if 'simple' in s else 'Doble Hoja'
        return 'Papel Higiénico', v, 'Limpieza'
    if 'chocolate' in s:
        v = 'Amargo' if any(k in s for k in ['70', '80', 'cacao', 'amargo']) else 'Con Leche'
        return 'Chocolate', v, 'Almacén'
    if any(k in s for k in ['7 up', '7up', 'seven up']):
        return 'Gaseosa', 'Lima Limón', 'Bebidas'
    if 'bizcocho' in s or '9 de oro' in s:
        v = 'Agridulces' if 'agridulce' in s else 'Grasa'
        return 'Bizcochos', v, 'Almacén'
    if 'o.b' in s or 'tampon' in s:
        return 'Tampones', 'Regular', 'Cuidado Personal'
    if 'roll-on' in s or 'desodorante' in s:
        return 'Desodorante', 'Roll-on', 'Cuidado Personal'
    if 'pampers' in s or 'panal' in s or 'pañal' in s:
        v = 'Recién Nacido' if any(k in s for k in ['rn', 'nacido']) else 'Clásico'
        return 'Pañales', v, 'Bebés y Maternidad'
    if 'caldo' in s or '12 cub' in s:
        return 'Caldo', 'En Cubos', 'Almacén'
    if 'sweet' in s or 'edulcorante' in s:
        return 'Edulcorante', 'En Sobres', 'Almacén'
    if 'mayonesa' in s:
        return 'Mayonesa', 'Clásica', 'Almacén'
    if 'ketchup' in s:
        return 'Ketchup', 'Clásico', 'Almacén'
    if 'cafe' in s or 'café' in s:
        v = 'En Cápsulas' if 'capsula' in s else 'Molido'
        return 'Café', v, 'Almacén'
    if 'te' in s or 'saq' in s or 'sobres' in s:
        return 'Té', 'Clásico', 'Almacén'
    if 'shampoo' in s:
        return 'Shampoo', 'Nutrición', 'Cuidado Personal'
    if 'jabon' in s or 'jab' in s:
        return 'Jabón', 'Tocador', 'Cuidado Personal'
    if 't-bone' in s or 'bife' in s:
        return 'Carne Vacuna', 'T-Bone', 'Frescos'
    if 'bolsa' in s and any(k in s for k in ['30x40', '45x40', '45x55', '50x22', 'residuo']):
        return 'Bolsas de Residuos', 'Consorcio', 'Limpieza'
    if 'ablandador de canas' in s:
        return 'Tintura', 'Ablandador de Canas', 'Cuidado Personal'
    if any(k in s for k in ['edt', 'edp', 'eau de toilette', 'her secret temptation']):
        return 'Perfume', 'Femenino', 'Cuidado Personal'

    return None, None, None

def _registrar_item_en_catalogo(
    catalogo_map: Dict[str, Dict[str, Any]],
    pb_dest: str,
    cat_dest: str,
    var_dest: str,
    env_dest: str,
    c_neto_val: float,
    c_neto_uni: str,
    m: Dict[str, Any],
    cat_info: Dict[str, Any] = None
):
    """Registra y ubica un ítem en su clúster canónico correspondiente."""
    cat_info = cat_info or {}
    ean = str(m.get("ean", "")).strip()
    marca = str(m.get("marca") or cat_info.get("marca") or "Sin Marca").strip()
    nombre_comercial = str(m.get("nombre_comercial") or cat_info.get("descripcion") or f"{pb_dest} {var_dest} {marca}").strip()
    imagen_url = str(cat_info.get("off_imagen") or m.get("imagen_url") or "").strip()

    if pb_dest not in catalogo_map:
        catalogo_map[pb_dest] = {
            "producto_basico": pb_dest,
            "categoria": cat_dest,
            "variedades": []
        }

    prod_entry = catalogo_map[pb_dest]

    # Buscar variedad
    var_entry = None
    for v in prod_entry["variedades"]:
        if v.get("variedad", "").lower() == var_dest.lower():
            var_entry = v
            break
    if not var_entry:
        var_entry = {"variedad": var_dest, "presentaciones": []}
        prod_entry["variedades"].append(var_entry)

    # Buscar presentación (envase)
    pres_entry = None
    for p in var_entry["presentaciones"]:
        if p.get("presentacion", "").lower() == env_dest.lower():
            pres_entry = p
            break
    if not pres_entry:
        pres_entry = {"presentacion": env_dest, "contenidos": []}
        var_entry["presentaciones"].append(pres_entry)

    # Buscar contenido neto
    cont_entry = None
    for c in pres_entry["contenidos"]:
        cn = c.get("contenido_neto", {})
        if cn.get("valor") == c_neto_val and cn.get("unidad") == c_neto_uni:
            cont_entry = c
            break

    if not cont_entry:
        if pb_dest.lower() == "leche":
            perfil = _obtener_perfil_leche(var_dest)
        else:
            perfil = {
                "fuente": "argenfoods",
                "ingredientes": f"{pb_dest} {var_dest}".strip(),
                "sellos_ley_27642": "Exento de sellos de advertencia (Ley 27.642)",
                "argenfoods_datos": {"exento_ley_27642": True},
                "open_food_facts_datos": None
            }

        lider_oficial = FOTOS_OFICIALES_LECHE.get((var_dest, env_dest))
        if lider_oficial:
            rep_lider = {
                "marca": lider_oficial["marca"],
                "ean": lider_oficial["ean"],
                "nombre_comercial": lider_oficial["nombre_comercial"],
                "imagen_url": lider_oficial["imagen_url"],
                "precio_referencia": m.get("precio_referencia")
            }
        else:
            rep_lider = {
                "marca": marca,
                "ean": ean,
                "nombre_comercial": nombre_comercial,
                "imagen_url": imagen_url,
                "precio_referencia": m.get("precio_referencia")
            }

        cont_entry = {
            "contenido_neto": {
                "valor": c_neto_val,
                "unidad": c_neto_uni,
                "texto_original": f"{c_neto_val} {c_neto_uni}"
            },
            "representante_lider": rep_lider,
            "perfil_nutricional": perfil,
            "marcas_miembros": []
        }
        pres_entry["contenidos"].append(cont_entry)
    else:
        # Asegurar foto coherente en el líder
        if pb_dest.lower() == "leche" and var_dest.lower() == "entera":
            lider_oficial = FOTOS_OFICIALES_LECHE.get(("Entera", env_dest))
            if lider_oficial:
                rep = cont_entry.get("representante_lider", {})
                cont_entry["representante_lider"] = {
                    "marca": lider_oficial["marca"],
                    "ean": lider_oficial["ean"],
                    "nombre_comercial": lider_oficial["nombre_comercial"],
                    "imagen_url": lider_oficial["imagen_url"],
                    "precio_referencia": rep.get("precio_referencia") or m.get("precio_referencia")
                }
        elif not cont_entry.get("representante_lider", {}).get("imagen_url") and imagen_url:
            if not (var_dest.lower() == "entera" and any(k in nombre_comercial.lower() for k in ["0% lactosa", "deslactosada", "descremada"])):
                cont_entry["representante_lider"]["imagen_url"] = imagen_url
                cont_entry["representante_lider"]["ean"] = ean
                cont_entry["representante_lider"]["marca"] = marca
                cont_entry["representante_lider"]["nombre_comercial"] = nombre_comercial

    # Agregar miembro evitando duplicados
    eans_existentes = {mb.get("ean") for mb in cont_entry["marcas_miembros"]}
    if ean not in eans_existentes:
        cont_entry["marcas_miembros"].append({
            "marca": marca,
            "ean": ean,
            "nombre_comercial": nombre_comercial
        })

def ejecutar_sanitizacion_canonica():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    print("=" * 70)
    print(" SANEAMIENTO Y CONSOLIDACIÓN CANÓNICA INTEGRAL DEL CATÁLOGO")
    print("=" * 70)

    if not INPUT_AUDITORIA_JSON.exists():
        print(f"[!] Archivo no encontrado: {INPUT_AUDITORIA_JSON}")
        return

    print(f"[*] Leyendo catálogo maestro: {INPUT_AUDITORIA_JSON.name}...")
    with open(INPUT_AUDITORIA_JSON, "r", encoding="utf-8") as f:
        catalogo_auditoria = json.load(f)

    reporte = {}
    if REPORTE_AUDITORIA_JSON.exists():
        with open(REPORTE_AUDITORIA_JSON, "r", encoding="utf-8") as f:
            reporte = json.load(f)

    # Cargar metadatos de productos desde catalogo_productos.csv
    cat_dict = {}
    if CATALOGO_CSV.exists():
        print(f"[*] Cargando catálogo de productos: {CATALOGO_CSV.name}...")
        df_catalogo = pd.read_csv(CATALOGO_CSV, dtype=str)
        for _, row in df_catalogo.iterrows():
            id_p = str(row.get("id_producto", "")).strip()
            cat_dict[id_p] = {
                "descripcion": str(row.get("productos_descripcion") or "").strip(),
                "marca": str(row.get("productos_marca") or "").strip(),
                "off_imagen": str(row.get("off_imagen") or "").strip(),
                "off_nutriscore": str(row.get("off_nutriscore") or "").strip()
            }

    # Backup de archivos
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    if OUTPUT_DEPURADO_JSON.exists():
        shutil.copy2(OUTPUT_DEPURADO_JSON, CLUSTERS_DIR / f"arbol_clusters_depurado_pre_canonica_{ts}.json")

    nuevo_catalogo_map: Dict[str, Dict[str, Any]] = {}

    stats = {
        "descartados_fmcg": 0,
        "premezclas_reclasificadas": 0,
        "harinas_alternativas_separadas": 0,
        "cindor_reubicado": 0,
        "variedades_redundantes_limpiadas": 0,
        "variedades_fusionadas": 0
    }

    for prod_item in catalogo_auditoria:
        pb_orig = prod_item.get("producto_basico", "").strip()

        # 1. Filtro FMCG
        if not es_producto_supermercado(pb_orig):
            stats["descartados_fmcg"] += 1
            continue

        # 2. Descarte por reporte de auditoría (medicamentos, etc.)
        regla = reporte.get(pb_orig)
        if regla and (regla.get("accion") == "descartar" or "electrodomest" in str(regla).lower()):
            stats["descartados_fmcg"] += 1
            continue

        # 1B. Tratamiento de productos anómalos (números, dimensiones, abreviaturas de 1 o 2 letras)
        if es_producto_anomalo(pb_orig):
            for var_item in prod_item.get("variedades", []):
                for pres_orig in var_item.get("presentaciones", []):
                    for cont_orig in pres_orig.get("contenidos", []):
                        for m in cont_orig.get("marcas_miembros", []):
                            ean = str(m.get("ean", "")).strip()
                            cat_info = cat_dict.get(ean, {})
                            desc_m = str(m.get("nombre_comercial") or cat_info.get("descripcion") or m.get("descripcion") or "")
                            marca_m = str(m.get("marca") or cat_info.get("marca") or "")

                            pb_real, var_real, cat_real = inferir_producto_real(desc_m, marca_m)
                            if pb_real and es_producto_supermercado(desc_m, marca_m):
                                c_val = cont_orig.get("contenido_neto", {}).get("valor", 1.0)
                                c_uni = cont_orig.get("contenido_neto", {}).get("unidad", "u")
                                c_val_c, c_uni_c = parsear_contenido_neto(c_val, c_uni, desc_m)
                                env_m = pres_orig.get("presentacion", "Paquete")
                                if env_m in ("Estándar", "Estandar", ""):
                                    env_m = "Paquete"
                                _registrar_item_en_catalogo(nuevo_catalogo_map, pb_real, cat_real, var_real, env_m, c_val_c, c_uni_c, m, cat_info)
                            else:
                                stats["descartados_fmcg"] += 1
            continue

        # 1C. Filtro FMCG profundo: verificar que los miembros contengan productos legítimos de supermercado
        todos_miembros = [
            (str(m.get("nombre_comercial") or cat_dict.get(str(m.get("ean")), {}).get("descripcion") or m.get("descripcion") or ""),
             str(m.get("marca") or cat_dict.get(str(m.get("ean")), {}).get("marca") or ""))
            for var_it in prod_item.get("variedades", [])
            for pr_it in var_it.get("presentaciones", [])
            for co_it in pr_it.get("contenidos", [])
            for m in co_it.get("marcas_miembros", [])
        ]
        if not todos_miembros or all(not es_producto_supermercado(d, mk) for d, mk in todos_miembros):
            stats["descartados_fmcg"] += 1
            continue

        # 3. Caso especial: LECHE (Clasificación atómica ítem por ítem: envases reales, fotos coherentes e ingredientes)
        if pb_orig.lower() in ("leche", "cindor"):
            for var_item in prod_item.get("variedades", []):
                for pres_orig in var_item.get("presentaciones", []):
                    for cont_orig in pres_orig.get("contenidos", []):
                        c_val_orig = cont_orig.get("contenido_neto", {}).get("valor", 1.0)
                        c_uni_orig = cont_orig.get("contenido_neto", {}).get("unidad", "litro")

                        for m in cont_orig.get("marcas_miembros", []):
                            ean = str(m.get("ean", "")).strip()
                            if not ean:
                                continue
                            marca = m.get("marca", "")
                            if pb_orig.lower() == "cindor":
                                m["marca"] = "Cindor"

                            cat_info = cat_dict.get(ean, {})
                            desc_m = f"{m.get('nombre_comercial') or ''} {cat_info.get('descripcion') or ''} {m.get('descripcion') or ''}".lower()
                            marca_low = str(marca).lower()

                            # Purgar cosméticos, depilatorios, golosinas y yogures intrusos
                            if any(k in desc_m or k in marca_low for k in [
                                "depimiel", "veganis", "la roche", "vichy", "caviahue", "siscom", "xercom",
                                "cera", "facial", "corporal", "limpiadora", "desmaquillante", "solar",
                                "nugaton", "oblea", "chocolate con leche", "actimel", "yogur", "fermentada", "maliandi",
                                "botella vidrio dec", "bazar", "decorad"
                            ]) and "chocolatada" not in desc_m and "cindor" not in desc_m:
                                stats["descartados_fmcg"] += 1
                                continue

                            # 1. ¿Es Bebida Vegetal (almendra, avena, coco, soja, etc.)?
                            if any(k in desc_m for k in ["almendra", "almend", "avena", "coco", "soja", "arroz", "mani", "not milk", "vegetal", "adez", "ades", "silk"]):
                                pb_dest = "Bebida Vegetal"
                                cat_dest = "Almacén"
                                if "almend" in desc_m:
                                    var_dest = "Almendras"
                                elif "avena" in desc_m:
                                    var_dest = "Avena"
                                elif "coco" in desc_m:
                                    var_dest = "Coco"
                                elif "soja" in desc_m:
                                    var_dest = "Soja"
                                else:
                                    var_dest = "Clásico"
                                env_dest = "Cartón (Tetra Brik)"
                            # 2. ¿Es leche en polvo?
                            elif "polvo" in desc_m:
                                pb_dest = "Leche en Polvo"
                                cat_dest = "Lácteos y Frescos"
                                var_dest = "Descremada" if any(k in desc_m for k in ["descrem", "descr", "desnatada", "liviana", "0%"]) else ("Entera" if any(k in desc_m for k in ["entera", "clasica", "clásica", "3%"]) else "Clásico")
                                env_dest = "Lata" if "lata" in desc_m else "Paquete"
                            # 3. ¿Es leche infantil / fórmula?
                            elif any(k in desc_m for k in ["infantil", "bebe", "bebé", "formula", "etapa", "vital", "nutrilon", "nan", "enfagrow", "similac"]):
                                pb_dest = "Leche Infantil"
                                cat_dest = "Bebés y Maternidad"
                                var_dest = "Etapa 1" if "etapa 1" in desc_m or " 1" in desc_m else (
                                    "Etapa 2" if "etapa 2" in desc_m or " 2" in desc_m else (
                                    "Etapa 3" if "etapa 3" in desc_m or " 3" in desc_m else "Clásico"
                                ))
                                env_dest = "Lata" if "lata" in desc_m else ("Cartón (Tetra Brik)" if any(k in desc_m for k in ["tetra", "brik", "brick"]) else "Botella")
                            # 4. Leche fluida comestible
                            else:
                                pb_dest = "Leche"
                                cat_dest = "Lácteos y Frescos"

                                # Variedad real
                                if any(k in desc_m for k in ["0% lactosa", "0%lactosa", "0 lac", "0%lac", "cero lactosa", "sin lactosa", "deslactosada", "deslact", "deslac", "reducida en lactosa", "s/lac"]):
                                    var_dest = "Deslactosada"
                                elif any(k in desc_m for k in ["chocolatada", "cindor", "cacao", "chocolate", "choc", "choco", "nesquik"]):
                                    var_dest = "Chocolatada"
                                elif any(k in desc_m for k in ["descremada", "parcialmente descremada", "descrem", "descre", "descr", "des.lv", "semidesc", "descrema", "liviana", "desnatada", "0% grasa", "1%", "2%", "1 %", "2 %", "ultra p 1", "ultra p 2"]):
                                    var_dest = "Descremada"
                                else:
                                    var_dest = "Entera"

                                # Envase real (Sachet vs Cartón vs Botella)
                                es_larga_vida = any(k in desc_m for k in ["uat", "uht", "tetra", "brik", "brick", "larga vida", "lv", "des.lv", "carton", "cartón"])
                                if ean in ("7790742448309", "7790742448408"):
                                    env_dest = "Sachet"
                                elif any(k in desc_m for k in ["sachet", "sache", "sach", " sch", "bolsa"]):
                                    env_dest = "Sachet"
                                elif any(k in desc_m for k in ["botella", "pet"]):
                                    env_dest = "Botella"
                                elif not es_larga_vida and any(k in desc_m for k in ["ultra", "pasteurizada", "fresca", "3 %", "3%", "2 %", "2%", "1 %", "1%"]):
                                    env_dest = "Sachet"
                                else:
                                    env_dest = "Cartón (Tetra Brik)"

                            c_neto_val, c_neto_uni = parsear_contenido_neto(c_val_orig, c_uni_orig, desc_m)
                            _registrar_item_en_catalogo(nuevo_catalogo_map, pb_dest, cat_dest, var_dest, env_dest, c_neto_val, c_neto_uni, m, cat_info)

            continue

        # 4. Caso especial: HARINA DE TRIGO o HARINA (Separar Premezclas y Harinas Alternativas)
        if pb_orig.lower() in ("harina de trigo", "harina"):
            variedades_trigo = []

            for var_item in prod_item.get("variedades", []):
                v_nombre_orig = var_item.get("variedad", "")
                v_low = v_nombre_orig.lower()

                # Descarte de Harina de Hueso (fertilizante)
                if "hueso" in v_low:
                    stats["descartados_fmcg"] += 1
                    continue

                # 4A. ¿Es PREMEZCLA o MIX?
                if any(k in v_low for k in ["premezcla", "blend", "s/glu", "s tacc", "sin tacc", "masa madre sin tacc", "pergola", "mix", "universal clasica"]):
                    stats["premezclas_reclasificadas"] += 1
                    pb_destino = "Premezcla"
                    # Determinar variedad limpia de la premezcla
                    if "masa madre" in v_low:
                        var_destino = "Masa Madre Sin TACC"
                    elif "pizza" in v_low:
                        var_destino = "Pizza Sin TACC"
                    elif "bizcoch" in v_low:
                        var_destino = "Bizcochuelo Sin TACC"
                    elif "panaderia" in v_low or "pan" in v_low:
                        var_destino = "Panadería Sin TACC"
                    elif "reposteria" in v_low:
                        var_destino = "Repostería Sin TACC"
                    elif "universal" in v_low:
                        var_destino = "Universal Sin TACC"
                    else:
                        var_destino = "Sin TACC"

                    # Agregar a Premezcla
                    _agregar_variedad_a_producto(nuevo_catalogo_map, pb_destino, "Almacén", var_destino, var_item)
                    continue

                # 4B. ¿Es HARINA ALTERNATIVA (no trigo)?
                harina_alt = None
                if "algarroba" in v_low:
                    harina_alt = "Harina de Algarroba"
                elif "almendra" in v_low:
                    harina_alt = "Harina de Almendras"
                elif "amaranto" in v_low:
                    harina_alt = "Harina de Amaranto"
                elif "arroz" in v_low:
                    harina_alt = "Harina de Arroz"
                elif "arveja" in v_low:
                    harina_alt = "Harina de Arvejas"
                elif "avena" in v_low:
                    harina_alt = "Harina de Avena"
                elif "caju" in v_low or "castana" in v_low:
                    harina_alt = "Harina de Castañas de Cajú"
                elif "centeno" in v_low:
                    harina_alt = "Harina de Centeno"
                elif "chia" in v_low:
                    harina_alt = "Harina de Chía"
                elif "coco" in v_low:
                    harina_alt = "Harina de Coco"
                elif "garbanzo" in v_low or "faina" in v_low:
                    harina_alt = "Harina de Garbanzo"
                elif "lino" in v_low:
                    harina_alt = "Harina de Lino"
                elif "mani" in v_low:
                    harina_alt = "Harina de Maní"
                elif "quinoa" in v_low:
                    harina_alt = "Harina de Quinoa"
                elif "soja" in v_low:
                    harina_alt = "Harina de Soja"
                elif "tapioca" in v_low:
                    harina_alt = "Harina de Tapioca"
                elif "sarraceno" in v_low:
                    harina_alt = "Harina de Trigo Sarraceno"
                elif "girasol" in v_low:
                    harina_alt = "Harina de Girasol"
                elif "pecan" in v_low:
                    harina_alt = "Harina de Nuez Pecán"

                if harina_alt:
                    stats["harinas_alternativas_separadas"] += 1
                    var_alt = "Sin TACC" if "tacc" in v_low or "gluten" in v_low else ("Integral" if "integral" in v_low else "Clásico")
                    _agregar_variedad_a_producto(nuevo_catalogo_map, harina_alt, "Almacén", var_alt, var_item)
                    continue

                # 4C. Harina de Trigo legítima: normalizar variedad
                if "0000" in v_low or "cuatro ceros" in v_low:
                    v_limpia = "0000"
                elif "000" in v_low or "tres ceros" in v_low:
                    v_limpia = "000"
                elif "00 napolitana" in v_low:
                    v_limpia = "00 Napolitana"
                elif "00" in v_low:
                    v_limpia = "00"
                elif "leudante" in v_low or v_low.strip() == "le":
                    v_limpia = "Leudante"
                elif "integral" in v_low:
                    v_limpia = "Integral"
                elif "pizza" in v_low or "pizzera" in v_low:
                    v_limpia = "Pizzera"
                elif "levadura" in v_low or "pan casero" in v_low or "panes caseros" in v_low:
                    v_limpia = "Con Levadura"
                elif v_low.strip() in ("clasico", "comun", "clasica"):
                    v_limpia = "000"
                else:
                    v_limpia = limpiar_variedad_redundante(v_nombre_orig, "Harina de Trigo")

                _agregar_variedad_a_producto(nuevo_catalogo_map, "Harina de Trigo", "Almacén", v_limpia, var_item)

            continue  # Harina ya fue procesada exhaustivamente

        # 5. Tratamiento General para todos los demás productos
        pb_canonico = capitalizar_titulo(pb_orig)
        cat_prod = prod_item.get("categoria", "Almacén")

        for var_item in prod_item.get("variedades", []):
            v_nombre_orig = var_item.get("variedad", "")
            v_limpia = limpiar_variedad_redundante(v_nombre_orig, pb_canonico)

            if v_limpia != v_nombre_orig:
                stats["variedades_redundantes_limpiadas"] += 1

            _agregar_variedad_a_producto(nuevo_catalogo_map, pb_canonico, cat_prod, v_limpia, var_item)

    # Podar presentaciones, variedades y productos que hayan quedado vacíos tras filtros FMCG
    for p in list(nuevo_catalogo_map.values()):
        for v in p.get("variedades", []):
            v["presentaciones"] = [pr for pr in v.get("presentaciones", []) if pr.get("contenidos")]
        p["variedades"] = [v for v in p.get("variedades", []) if v.get("presentaciones")]

    nuevo_catalogo_map = {k: v for k, v in nuevo_catalogo_map.items() if v.get("variedades")}

    # Convertir mapa a lista y ordenar
    catalogo_final = list(nuevo_catalogo_map.values())
    catalogo_final.sort(key=lambda x: x.get("producto_basico", "").lower())

    # Contar métricas de fusión
    total_variedades_final = sum(len(p.get("variedades", [])) for p in catalogo_final)
    total_clusters_final = 0
    total_eans_final = 0

    for p in catalogo_final:
        for v in p.get("variedades", []):
            for pr in v.get("presentaciones", []):
                for c in pr.get("contenidos", []):
                    total_clusters_final += 1
                    total_eans_final += len(c.get("marcas_miembros", []))

    print(f"\n[OK] Saneamiento completado con éxito:")
    print(f" - Productos FMCG descartados (no-supermercado):  {stats['descartados_fmcg']}")
    print(f" - Premezclas reclasificadas a 'Premezcla':        {stats['premezclas_reclasificadas']}")
    print(f" - Harinas alternativas separadas de Trigo:        {stats['harinas_alternativas_separadas']}")
    print(f" - Reubicaciones de Cindor a Leche Chocolatada:    {stats['cindor_reubicado']}")
    print(f" - Variedades redundantes o con marcas limpiadas:  {stats['variedades_redundantes_limpiadas']}")
    print(f" - Total Productos Básicos limpios:                {len(catalogo_final)}")
    print(f" - Total Variedades canónicas consolidadas:        {total_variedades_final}")
    print(f" - Total Clústeres activos:                        {total_clusters_final}")
    print(f" - Total EANs/Ítems preservados:                   {total_eans_final}")

    # Guardar arbol_clusters_depurado.json
    with open(OUTPUT_DEPURADO_JSON, "w", encoding="utf-8") as f:
        json.dump(catalogo_final, f, ensure_ascii=False, indent=2)
    print(f"\n[OK] Árbol depurado guardado en: {OUTPUT_DEPURADO_JSON}")

    # Sincronizar producto_clusters.csv y producto_cluster_items.csv
    sincronizar_tablas_csv(catalogo_final)

def _agregar_variedad_a_producto(
    catalogo_map: Dict[str, Dict[str, Any]],
    pb_nombre: str,
    categoria: str,
    var_nombre: str,
    var_data: Dict[str, Any]
):
    """Agrega y fusiona atómicamente una variedad en el producto básico correspondiente."""
    if pb_nombre not in catalogo_map:
        catalogo_map[pb_nombre] = {
            "producto_basico": pb_nombre,
            "categoria": categoria,
            "variedades": []
        }

    prod_entry = catalogo_map[pb_nombre]

    # Buscar si ya existe la variedad en este producto para FUSIONAR
    var_existente = None
    for v in prod_entry["variedades"]:
        if v.get("variedad", "").lower() == var_nombre.lower():
            var_existente = v
            break

    if not var_existente:
        var_existente = {
            "variedad": var_nombre,
            "presentaciones": []
        }
        prod_entry["variedades"].append(var_existente)

    pb_low = pb_nombre.lower()
    es_producto_liquido = any(k in pb_low for k in [
        "bebida", "gaseosa", "agua", "jugo", "soda", "cerveza", "vino",
        "aceite", "vinagre", "aperitivo", "licor", "fernet", "energizante",
        "isotónica", "isotonica", "sidra", "champagne", "espumante", "jarabe"
    ])

    # Fusionar presentaciones y contenidos netos ubicando cada uno en su envase canónico
    for pres_nueva in var_data.get("presentaciones", []):
        p_tipo_base = pres_nueva.get("presentacion", "Estándar").strip().title()

        for cont_nuevo in pres_nueva.get("contenidos", []):
            # Filtrar miembros no-supermercado (bazar, vajilla, recipientes, etc.)
            miembros_validos = []
            for m in cont_nuevo.get("marcas_miembros", []):
                d_m = str(m.get("nombre_comercial") or m.get("descripcion") or "")
                mk_m = str(m.get("marca") or "")
                if not es_producto_supermercado(d_m, mk_m):
                    continue
                # Si el producto básico es Azúcar, descartar cereales azucarados o recipientes de bazar
                if pb_low in ("azúcar", "azucar"):
                    d_m_low = d_m.lower()
                    if any(k in d_m_low for k in ["copos", "cereal", "azucarera", "lata hava", "pico vertedor", "matero", "glitter", "daysal"]):
                        continue
                miembros_validos.append(m)

            if not miembros_validos:
                continue

            cont_nuevo["marcas_miembros"] = miembros_validos

            # Validar y reemplazar líder si correspondía a un producto descartado
            rep_lider = cont_nuevo.get("representante_lider", {})
            rep_desc = str(rep_lider.get("nombre_comercial") or "")
            if not es_producto_supermercado(rep_desc, rep_lider.get("marca", "")) or (pb_low in ("azúcar", "azucar") and any(k in rep_desc.lower() for k in ["copos", "cereal", "azucarera", "lata hava", "pico vertedor"])):
                primer_m = miembros_validos[0]
                cont_nuevo["representante_lider"] = {
                    "marca": primer_m.get("marca", ""),
                    "ean": primer_m.get("ean", ""),
                    "nombre_comercial": primer_m.get("nombre_comercial", ""),
                    "imagen_url": primer_m.get("imagen_url", ""),
                    "precio_referencia": primer_m.get("precio_referencia")
                }

            c_neto_val = cont_nuevo.get("contenido_neto", {}).get("valor")
            c_neto_uni = cont_nuevo.get("contenido_neto", {}).get("unidad")

            # Corregir contenidos con unidad Estándar o texto corrupto
            if not c_neto_val or c_neto_uni in ("estandar", "Estándar", "None", None, ""):
                txt = cont_nuevo.get("contenido_neto", {}).get("texto_original", "")
                c_neto_val, c_neto_uni = parsear_contenido_neto(c_neto_val, c_neto_uni, txt)
                cont_nuevo["contenido_neto"]["valor"] = c_neto_val
                cont_nuevo["contenido_neto"]["unidad"] = c_neto_uni
                cont_nuevo["contenido_neto"]["texto_original"] = f"{c_neto_val} {c_neto_uni}"

            es_unidad_liquida = str(c_neto_uni).lower() in ("ml", "cc", "litro", "litros", "l")

            # Determinar tipo de envase específico para este contenido
            p_tipo = p_tipo_base
            cont_desc = " ".join(str(m.get("nombre_comercial") or m.get("descripcion") or "") for m in miembros_validos).lower()

            if pb_low in ("azúcar", "azucar", "harina", "harina de trigo", "arroz", "polenta", "sal", "yerba", "yerba mate", "legumbres", "fideos", "premezcla"):
                if any(k in cont_desc for k in ["frasco", "vidrio"]):
                    p_tipo = "Frasco"
                elif any(k in cont_desc for k in ["caja", "estuche"]):
                    p_tipo = "Caja"
                elif any(k in cont_desc for k in ["doypack", "zipper"]):
                    p_tipo = "Doypack"
                elif any(k in cont_desc for k in ["bolsa"]):
                    p_tipo = "Bolsa"
                else:
                    p_tipo = "Paquete"
            elif pb_low == "leche":
                if any(k in cont_desc for k in ["sachet", "sach", " sch", "bolsa"]):
                    p_tipo = "Sachet"
                elif "botella" in cont_desc or "pet" in cont_desc:
                    p_tipo = "Botella"
                else:
                    p_tipo = "Cartón (Tetra Brik)"
            elif es_producto_liquido:
                if any(k in cont_desc for k in ["lata", "latita"]):
                    p_tipo = "Lata"
                elif any(k in cont_desc for k in ["tetra", "brik", "brick", "carton", "cartón"]):
                    p_tipo = "Cartón (Tetra Brik)"
                elif any(k in cont_desc for k in ["sachet", "sach", " sch"]):
                    p_tipo = "Sachet"
                elif any(k in cont_desc for k in ["doypack", "pouch"]):
                    p_tipo = "Doypack"
                elif any(k in cont_desc for k in ["bidon", "bidón"]):
                    p_tipo = "Bidón"
                elif p_tipo.lower() in ("paquete", "estándar", "estandar", ""):
                    p_tipo = "Botella"
            elif p_tipo in ("Estándar", "Estandar", ""):
                if any(k in cont_desc for k in ["sachet", "pouch"]):
                    p_tipo = "Doypack"
                elif any(k in cont_desc for k in ["lata", "latita"]):
                    p_tipo = "Lata"
                elif any(k in cont_desc for k in ["botella", "pet"]):
                    p_tipo = "Botella"
                elif any(k in cont_desc for k in ["frasco", "vidrio"]):
                    p_tipo = "Frasco"
                elif any(k in cont_desc for k in ["tetra", "brik", "brick", "carton", "cartón"]):
                    p_tipo = "Cartón (Tetra Brik)"
                elif any(k in cont_desc for k in ["pote", "pote plástico"]):
                    p_tipo = "Pote"
                elif any(k in cont_desc for k in ["caja", "estuche"]):
                    p_tipo = "Caja"
                else:
                    p_tipo = "Paquete"

            pres_existente = None
            for pr in var_existente["presentaciones"]:
                if pr.get("presentacion", "").lower() == p_tipo.lower():
                    pres_existente = pr
                    break

            if not pres_existente:
                pres_existente = {
                    "presentacion": p_tipo,
                    "contenidos": []
                }
                var_existente["presentaciones"].append(pres_existente)

            # Limpiar ingredientes de discursos regulatorios
            if "perfil_nutricional" in cont_nuevo and isinstance(cont_nuevo["perfil_nutricional"], dict):
                pn = cont_nuevo["perfil_nutricional"]
                pn["ingredientes"] = limpiar_ingredientes(pn.get("ingredientes", ""), pb_nombre, var_nombre)

            cont_existente = None
            for c in pres_existente["contenidos"]:
                c_val = c.get("contenido_neto", {}).get("valor")
                c_uni = c.get("contenido_neto", {}).get("unidad")
                if c_val == c_neto_val and c_uni == c_neto_uni:
                    cont_existente = c
                    break

            if not cont_existente:
                pres_existente["contenidos"].append(cont_nuevo)
            else:
                # Si el existente tiene ingredientes desactualizados, actualizar
                if "perfil_nutricional" in cont_existente and isinstance(cont_existente["perfil_nutricional"], dict):
                    pn_e = cont_existente["perfil_nutricional"]
                    pn_e["ingredientes"] = limpiar_ingredientes(pn_e.get("ingredientes", ""), pb_nombre, var_nombre)

                # Unificar marcas miembros sin duplicar EANs
                eans_existentes = {m.get("ean") for m in cont_existente.get("marcas_miembros", [])}
                for m_nueva in cont_nuevo.get("marcas_miembros", []):
                    ean = m_nueva.get("ean")
                    if ean and ean not in eans_existentes:
                        cont_existente.setdefault("marcas_miembros", []).append(m_nueva)
                        eans_existentes.add(ean)

def _agregar_contenido_a_producto(
    catalogo_map: Dict[str, Dict[str, Any]],
    pb_nombre: str,
    categoria: str,
    var_nombre: str,
    envase_nombre: str,
    cont_data: Dict[str, Any]
):
    """Agrega o fusiona un contenido directamente en su producto, variedad y envase canónico."""
    if pb_nombre not in catalogo_map:
        catalogo_map[pb_nombre] = {
            "producto_basico": pb_nombre,
            "categoria": categoria,
            "variedades": []
        }

    prod_entry = catalogo_map[pb_nombre]

    var_existente = None
    for v in prod_entry["variedades"]:
        if v.get("variedad", "").lower() == var_nombre.lower():
            var_existente = v
            break

    if not var_existente:
        var_existente = {
            "variedad": var_nombre,
            "presentaciones": []
        }
        prod_entry["variedades"].append(var_existente)

    pres_existente = None
    for pr in var_existente["presentaciones"]:
        if pr.get("presentacion", "").lower() == envase_nombre.lower():
            pres_existente = pr
            break

    if not pres_existente:
        pres_existente = {
            "presentacion": envase_nombre,
            "contenidos": []
        }
        var_existente["presentaciones"].append(pres_existente)

    c_neto_val = cont_data.get("contenido_neto", {}).get("valor")
    c_neto_uni = cont_data.get("contenido_neto", {}).get("unidad")

    if not c_neto_val or c_neto_uni in ("estandar", "Estándar", "None", None, ""):
        txt = cont_data.get("contenido_neto", {}).get("texto_original", "")
        c_neto_val, c_neto_uni = parsear_contenido_neto(c_neto_val, c_neto_uni, txt)
        cont_data["contenido_neto"]["valor"] = c_neto_val
        cont_data["contenido_neto"]["unidad"] = c_neto_uni
        cont_data["contenido_neto"]["texto_original"] = f"{c_neto_val} {c_neto_uni}"

    if "perfil_nutricional" in cont_data and isinstance(cont_data["perfil_nutricional"], dict):
        pn = cont_data["perfil_nutricional"]
        pn["ingredientes"] = limpiar_ingredientes(pn.get("ingredientes", ""), pb_nombre, var_nombre)

    cont_existente = None
    for c in pres_existente["contenidos"]:
        if c.get("contenido_neto", {}).get("valor") == c_neto_val and c.get("contenido_neto", {}).get("unidad") == c_neto_uni:
            cont_existente = c
            break

    if not cont_existente:
        pres_existente["contenidos"].append(cont_data)
    else:
        if cont_data.get("representante_lider", {}).get("imagen_url") and not cont_existente.get("representante_lider", {}).get("imagen_url"):
            cont_existente["representante_lider"] = cont_data["representante_lider"]

        if "perfil_nutricional" in cont_existente and isinstance(cont_existente["perfil_nutricional"], dict):
            pn_e = cont_existente["perfil_nutricional"]
            pn_e["ingredientes"] = limpiar_ingredientes(pn_e.get("ingredientes", ""), pb_nombre, var_nombre)

        eans_existentes = {m.get("ean") for m in cont_existente.get("marcas_miembros", [])}
        for m_nueva in cont_data.get("marcas_miembros", []):
            ean = m_nueva.get("ean")
            if ean and ean not in eans_existentes:
                cont_existente.setdefault("marcas_miembros", []).append(m_nueva)
                eans_existentes.add(ean)

def sincronizar_tablas_csv(catalogo: List[Dict[str, Any]]):
    """Sincroniza producto_clusters.csv y producto_cluster_items.csv."""
    print("\n[*] Sincronizando tablas CSV oficiales...")

    clusters_rows = []
    items_rows = []
    vistos_cids = set()
    vistos_eans = set()

    for prod in catalogo:
        p_basico = prod.get("producto_basico", "").strip()
        cat = prod.get("categoria", "Almacén")

        for var in prod.get("variedades", []):
            v_nombre = var.get("variedad", "Clásico").strip()

            for pres in var.get("presentaciones", []):
                pr_nombre = pres.get("presentacion", "Estándar").strip()

                for cont in pres.get("contenidos", []):
                    c_neto = cont.get("contenido_neto", {})
                    val = c_neto.get("valor", "")
                    uni = c_neto.get("unidad", "")
                    cid = cont.get("cluster_id") or ""

                    # Generar cluster_id canónico único que distinga producto, variedad, envase y tamaño
                    slug_prod = re.sub(r'[^a-z0-9]+', '_', p_basico.lower()).strip('_')
                    slug_var = re.sub(r'[^a-z0-9]+', '_', v_nombre.lower()).strip('_')
                    slug_pres = re.sub(r'[^a-z0-9]+', '_', pr_nombre.lower()).strip('_')
                    val_clean = str(val).rstrip('0').rstrip('.') if '.' in str(val) else str(val)
                    slug_tam = f"{val_clean}{uni}"

                    if slug_pres and slug_pres not in ("estandar", "est_ndar"):
                        cid = f"{slug_prod}_{slug_var}_{slug_pres}_{slug_tam}"
                    else:
                        cid = f"{slug_prod}_{slug_var}_{slug_tam}"
                    cont["cluster_id"] = cid

                    es_var_generica = v_nombre.lower() in ("clásico", "clasico", "estándar", "estandar")
                    if es_var_generica or v_nombre.lower() in p_basico.lower():
                        canonico = p_basico
                    else:
                        canonico = f"{p_basico} {v_nombre}".strip()

                    if cid and cid not in vistos_cids:
                        vistos_cids.add(cid)
                        clusters_rows.append({
                            "cluster_id": cid,
                            "producto": p_basico,
                            "variedad": v_nombre,
                            "presentacion": pr_nombre,
                            "nombre_canonico": canonico,
                            "categoria": cat
                        })

                    for m in cont.get("marcas_miembros", []):
                        ean = str(m.get("ean", "")).strip()
                        if not ean or ean in vistos_eans:
                            continue
                        vistos_eans.add(ean)

                        items_rows.append({
                            "id_producto": ean,
                            "cluster_id": cid,
                            "marca": m.get("marca", ""),
                            "envase": pr_nombre,
                            "contenido_neto": val,
                            "unidad_referencia": uni,
                            "confianza": 1.0,
                            "modelo_ia": "sanitizacion_canonica"
                        })

    df_clusters = pd.DataFrame(clusters_rows)
    df_items = pd.DataFrame(items_rows)

    df_clusters.to_csv(CLUSTERS_CSV, index=False, encoding="utf-8")
    df_items.to_csv(ITEMS_CSV, index=False, encoding="utf-8")

    print(f"[OK] Sincronizados exitosamente:")
    print(f"     - {CLUSTERS_CSV.name}: {len(df_clusters):,} clústeres canónicos.")
    print(f"     - {ITEMS_CSV.name}: {len(df_items):,} productos asociados a clústeres.")

if __name__ == "__main__":
    ejecutar_sanitizacion_canonica()
