#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cluster_canonico_builder.py
----------------------------
Motor determinista de generación de clústeres canónicos basado en los 5 Elementos:
  a) producto      (ej. 'Harina de Trigo', 'Leche', 'Aceite', 'Arroz')
  b) variedad      (ej. '000', '0000', 'Leudante', 'Entera', 'Descremada', 'Girasol')
  c) marca         (ej. 'Morixe', 'Favorita', 'Coto', 'La Serenísima')
  d) envase        (ej. 'Sachet', 'Tetrabrick', 'Botella', 'Doypack', 'Lata', o '')
  e) presentacion  (ej. '1 kg', '500 g', '1 L', '900 ml')

Regla de Agrupación:
  - El Clúster se define EXCLUSIVAMENTE por: (a) Producto + (b) Variedad + (e) Presentación.
  - Todas las Marcas (c) y todos los Envases (d) se integran dentro del mismo clúster.
"""

import re
import unicodedata
from typing import Dict, Any, Tuple, Optional

# Marcas que bajo ninguna circunstancia pueden filtrarse en producto, variedad o cluster_id
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
    "pergola", "onza_de_oro", "onza de oro", "cindor", "exquisita", "royal", "fleischmann",
    "kapac", "dicomere", "schar", "epicos", "natural_pop", "le_fit", "sturla", "don_ubaldo", "mama_cocina"
}

# Diccionario de detección y normalización de envases
ENVASES_MAP = {
    "sachet": "Sachet",
    "tetrabrick": "Tetrabrick",
    "tetra brik": "Tetrabrick",
    "tetrabrik": "Tetrabrick",
    "tetra": "Tetrabrick",
    "brik": "Tetrabrick",
    "brick": "Tetrabrick",
    "botella": "Botella",
    "pet": "Botella PET",
    "retornable": "Retornable",
    "lata": "Lata",
    "doypack": "Doypack",
    "doy pack": "Doypack",
    "pouch": "Doypack",
    "frasco": "Frasco",
    "vidrio": "Frasco",
    "bidon": "Bidón",
    "pote": "Pote",
    "bandeja": "Bandeja",
    "paquete": "Paquete",
    "bolsa": "Bolsa",
    "caja": "Caja",
    "estuche": "Caja",
    "aerosol": "Aerosol",
    "erosol": "Aerosol",
    "barra": "Barra",
    "tableta": "Tableta",
    "sobre": "Sobre",
    "repuesto": "Repuesto",
}

PALABRAS_ENVASE_REMOVER = {
    "sachet", "tetrabrick", "tetrabrik", "tetra", "brik", "brick", "botella", "pet",
    "retornable", "descartable", "lata", "doypack", "doy", "pouch", "frasco", "vidrio",
    "bidon", "pote", "bandeja", "paquete", "paq", "bolsa", "caja", "estuche", "aerosol",
    "erosol", "sobre", "envase", "familiar", "economico", "formato", "pack"
}


def normalizar_texto(texto: str) -> str:
    """Quita tildes, caracteres especiales y convierte a minúsculas limpias."""
    if not texto:
        return ""
    texto = str(texto).strip().lower()
    texto = "".join(
        c for c in unicodedata.normalize("NFD", texto)
        if unicodedata.category(c) != "Mn"
    )
    texto = re.sub(r"[^a-z0-9\s]", " ", texto)
    return re.sub(r"\s+", " ", texto).strip()


def extraer_envase(texto_completo: str, envase_sugerido: Optional[str] = None) -> str:
    """Extrae el tipo de envase normalizado a partir de la descripción o sugerencia."""
    combinado = normalizar_texto(f"{envase_sugerido or ''} {texto_completo or ''}")
    if not combinado:
        return ""
    # Buscar coincidencias de palabras completas
    tokens = set(combinado.split())
    for k, val in ENVASES_MAP.items():
        if " " in k and k in combinado:
            return val
        elif k in tokens:
            return val
    return ""


def limpiar_tokens_envase_y_marca(texto: str, marca: Optional[str] = None) -> str:
    """Elimina menciones al envase, unidades sueltas o a la marca dentro de un texto."""
    norm = normalizar_texto(texto)
    if not norm:
        return ""
    marca_tokens = set(normalizar_texto(marca or "").split())
    # Quitar patrones de unidades como 1kg, 1000g, 500gr, 1lt, 900ml, x1kg
    norm = re.sub(r"\b(x\s*)?\d+([.,]\d+)?\s*(kg|kilo|kilos|g|gr|grs|gramos|l|lt|lts|litros|ml|cc|cm3|u|un|unid|unidades)\b", " ", norm)
    tokens = []
    for t in norm.split():
        if t in PALABRAS_ENVASE_REMOVER:
            continue
        if t in MARCAS_CONOCIDAS or (marca_tokens and t in marca_tokens and len(t) > 2):
            continue
        tokens.append(t)
    return " ".join(tokens).strip()


def slugificar(texto: str) -> str:
    """Convierte texto en un slug snake_case limpio sin palabras vacías ni marcas."""
    norm = normalizar_texto(texto)
    stop_words = {"de", "del", "la", "las", "el", "los", "en", "y", "o", "con", "sin", "para", "por", "un", "una", "al", "x"}
    palabras = [
        p for p in norm.split()
        if p and p not in stop_words and p not in MARCAS_CONOCIDAS and p not in PALABRAS_ENVASE_REMOVER
    ]
    return "_".join(palabras) if palabras else "clasico"


def formatear_tamano(contenido: float, unidad: str, pack: int = 1) -> Tuple[str, str, float, str]:
    """
    Convierte contenido numérico y unidad a escala comercial única sin duplicidades:
    - Peso: < 1 kg en gramos ('500g', '500 g'); >= 1 kg en kilos ('1kg', '1 kg', '1.5kg', '1.5 kg')
    - Volumen: < 1 L en mililitros ('900ml', '900 ml'); >= 1 L en litros ('1l', '1 L', '1.5l', '1.5 L')
    - Unidades: ('1u', '1 u', '6u', '6 u')
    """
    u = (unidad or "kg").strip().lower()
    try:
        c = float(contenido or 1.0)
        if c != c or c <= 0:  # c != c detecta NaN
            c = 1.0
    except (ValueError, TypeError):
        c = 1.0

    # Si viene en gramos o mililitros (ej. 500 g o 1000 g o 0.5 kg mal etiquetado)
    if u in ("g", "gr", "grs", "gramos"):
        if c >= 10.0:
            c = c / 1000.0
        u = "kg"
    elif u in ("ml", "cm3", "cc", "mililitros"):
        if c >= 10.0:
            c = c / 1000.0
        u = "l"
    elif u in ("kg", "kilo", "kilos") and c >= 50.0:
        # Si dice 500 kg por error de unidad en catálogo, son 500 g (0.5 kg)
        c = c / 1000.0
    elif u in ("l", "lt", "lts", "litros") and c >= 50.0:
        c = c / 1000.0

    try:
        p = int(float(pack or 1)) if (pack and pack == pack) else 1
    except (ValueError, TypeError):
        p = 1
    if p < 1:
        p = 1

    # 1. Caso Unidades (u)
    if u in ("u", "un", "unid", "unidades"):
        cant_u = p if p > 1 else max(1, int(round(c)))
        return f"{cant_u}u", f"{cant_u} u", float(cant_u), "u"

    # 2. Caso Líquidos (l / ml)
    if u in ("l", "lt", "lts", "litros"):
        if abs(c - 1.0) < 0.03:
            return "1l", "1 L", 1.0, "l"
        elif c < 1.0:
            val_ml = int(round(c * 1000))
            return f"{val_ml}ml", f"{val_ml} ml", round(val_ml / 1000.0, 4), "l"
        else:
            val_str = f"{c:.2f}".rstrip("0").rstrip(".")
            return f"{val_str}l", f"{val_str} L", round(c, 3), "l"

    # 3. Caso Peso (kg / g) -> >= 1 kg SIEMPRE '1kg' / '1 kg' (nunca '1000g')
    if abs(c - 1.0) < 0.03:
        return "1kg", "1 kg", 1.0, "kg"
    elif c < 1.0:
        val_g = int(round(c * 1000))
        return f"{val_g}g", f"{val_g} g", round(val_g / 1000.0, 4), "kg"
    else:
        val_kg_str = f"{c:.2f}".rstrip("0").rstrip(".")
        return f"{val_kg_str}kg", f"{val_kg_str} kg", round(c, 3), "kg"


def capitalizar_frase(texto: str) -> str:
    """Capitaliza en formato Título respetando conectores en español."""
    conectores = {"de", "del", "la", "las", "el", "los", "en", "y", "o", "con", "sin", "para", "por", "al", "a"}
    palabras = texto.strip().split()
    if not palabras:
        return ""
    resultado = []
    for i, p in enumerate(palabras):
        if p in ("000", "0000", "uht", "pet", "x"):
            resultado.append(p.upper() if p in ("uht", "pet") else p)
        elif i > 0 and p.lower() in conectores:
            resultado.append(p.lower())
        else:
            resultado.append(p.capitalize())
    return " ".join(resultado)


def construir_cluster_canonico(
    nombre_base: str,
    variedad_sabor: str,
    marca: str,
    contenido_neto: float,
    unidad_medida: str,
    pack_unidades: int = 1,
    categoria: str = "Almacén",
    envase: Optional[str] = None,
    descripcion_original: Optional[str] = None
) -> Dict[str, Any]:
    """
    Construye de manera 100% determinista los 5 elementos y el clúster:
      - producto (a)
      - variedad (b)
      - marca (c)
      - envase (d)
      - presentacion (e)
      - cluster_id = slug(producto) + slug(variedad) + slug(presentacion)
      - nombre_canonico = "{producto} {variedad} {presentacion}"
    """
    texto_contexto = f"{nombre_base or ''} {variedad_sabor or ''} {descripcion_original or ''}"
    envase_limpio = extraer_envase(texto_contexto, envase)
    marca_limpia = capitalizar_frase(normalizar_texto(marca or "")) or "Genérico"

    nb_clean = limpiar_tokens_envase_y_marca(nombre_base or "producto", marca)
    vs_clean = limpiar_tokens_envase_y_marca(variedad_sabor or "clasico", marca)
    combinado = f"{nb_clean} {vs_clean}".strip()

    slug_tam, txt_tam, cn_norm, um_norm = formatear_tamano(contenido_neto, unidad_medida, pack_unidades)
    cat_final = (categoria or "Almacén").strip().title()

    # -----------------------------------------------------------------
    # REGLAS DE ORO CANÓNICAS PARA SEPARACIÓN DE PRODUCTO Y VARIEDAD
    # -----------------------------------------------------------------
    prod_title = ""
    prod_slug = ""
    var_title = ""
    var_slug = ""

    # 0. PREMEZCLAS (Separa Premezclas de Harinas de trigo)
    if any(k in combinado for k in ["premezcla", "pre mezcla", "prep para", "preparado para", "blend de harina", "blend harina"]):
        prod_title = "Premezcla"
        prod_slug = "premezcla"
        cat_final = "Almacén"
        is_sin_tacc = any(k in combinado for k in ["sin tacc", "s tacc", "sin gluten", "s glu", "s/glu", "s/tacc", "libre de gluten"])
        
        if "bizcochuelo" in combinado or "bizcocho" in combinado:
            sub = "Chocolate" if "chocolate" in combinado else ("Vainilla" if "vainilla" in combinado else "")
            var_title = f"Bizcochuelo {sub}".strip()
        elif "pizza" in combinado:
            var_title = "Pizza"
        elif "panaderia" in combinado or "pan " in combinado or "panes" in combinado:
            var_title = "Panadería"
        elif "chipa" in combinado:
            var_title = "Chipa"
        elif "brownie" in combinado:
            var_title = "Brownie"
        elif "reposteria" in combinado:
            var_title = "Repostería"
        elif "masa madre" in combinado:
            var_title = "Masa Madre"
        else:
            var_title = "Universal"
            
        if is_sin_tacc and "Sin TACC" not in var_title:
            var_title = f"{var_title} Sin TACC".strip()
        var_slug = slugificar(var_title)

    # 1A. HARINAS ALTERNATIVAS (No son trigo)
    elif ("harina" in nb_clean or "harina" in combinado) and any(
        k in combinado for k in ["algarroba", "almendra", "amaranto", "arroz", "arveja", "avena", "caju", "centeno", "chia", "coco", "garbanzo", "lino", "mani", "quinoa", "soja", "tapioca"]
    ):
        cat_final = "Almacén"
        es_stacc = any(k in combinado for k in ["sin tacc", "s tacc", "sin gluten", "s glu", "s/glu", "s/tacc", "libre de gluten"])
        var_title = "Sin TACC" if es_stacc else ("Integral" if "integral" in combinado else "Clásico")
        
        if "algarroba" in combinado:
            prod_title, prod_slug = "Harina de Algarroba", "harina_de_algarroba"
        elif "almendra" in combinado:
            prod_title, prod_slug = "Harina de Almendras", "harina_de_almendras"
        elif "amaranto" in combinado:
            prod_title, prod_slug = "Harina de Amaranto", "harina_de_amaranto"
        elif "arroz" in combinado:
            prod_title, prod_slug = "Harina de Arroz", "harina_de_arroz"
        elif "arveja" in combinado:
            prod_title, prod_slug = "Harina de Arvejas", "harina_de_arvejas"
        elif "avena" in combinado:
            prod_title, prod_slug = "Harina de Avena", "harina_de_avena"
        elif "caju" in combinado or "castana" in combinado:
            prod_title, prod_slug = "Harina de Castañas de Cajú", "harina_de_castanas_de_caju"
        elif "centeno" in combinado:
            prod_title, prod_slug = "Harina de Centeno", "harina_de_centeno"
        elif "chia" in combinado:
            prod_title, prod_slug = "Harina de Chía", "harina_de_chia"
        elif "coco" in combinado:
            prod_title, prod_slug = "Harina de Coco", "harina_de_coco"
        elif "garbanzo" in combinado:
            prod_title, prod_slug = "Harina de Garbanzo", "harina_de_garbanzo"
        elif "lino" in combinado:
            prod_title, prod_slug = "Harina de Lino", "harina_de_lino"
        elif "mani" in combinado:
            prod_title, prod_slug = "Harina de Maní", "harina_de_mani"
        elif "quinoa" in combinado:
            prod_title, prod_slug = "Harina de Quinoa", "harina_de_quinoa"
        elif "soja" in combinado:
            prod_title, prod_slug = "Harina de Soja", "harina_de_soja"
        elif "tapioca" in combinado:
            prod_title, prod_slug = "Harina de Tapioca", "harina_de_tapioca"
        var_slug = slugificar(var_title)

    # 1B. HARINA DE MAÍZ / POLENTA
    elif ("harina" in nb_clean or "harina" in combinado) and ("maiz" in combinado or "polenta" in combinado):
        prod_title = "Harina de Maíz"
        prod_slug = "harina_de_maiz"
        cat_final = "Almacén"
        if "precocida" in combinado or "instantanea" in combinado or "rapida" in combinado:
            var_title, var_slug = "Precocida", "precocida"
        elif "blanca" in combinado:
            var_title, var_slug = "Blanca", "blanca"
        else:
            var_title, var_slug = "Tradicional", "tradicional"

    # 1C. HARINA DE TRIGO (0000, 000, 00, Leudante, Integral, Pizzera)
    elif ("harina" in nb_clean or "harina" in combinado) and not any(
        k in combinado for k in ["hueso", "carne", "pescado"]
    ):
        prod_title = "Harina de Trigo"
        prod_slug = "harina_de_trigo"
        cat_final = "Almacén"
        todo_harina = normalizar_texto(texto_contexto)
        if "0000" in todo_harina or "cuatro ceros" in todo_harina:
            var_title, var_slug = "0000", "0000"
        elif "000" in todo_harina or "tres ceros" in todo_harina:
            var_title, var_slug = "000", "000"
        elif "leudante" in todo_harina:
            var_title, var_slug = "Leudante", "leudante"
        elif "integral" in todo_harina:
            var_title, var_slug = "Integral", "integral"
        elif "pizza" in todo_harina or "pizzera" in todo_harina:
            var_title, var_slug = "Pizzera", "pizzera"
        elif "00 napolitana" in todo_harina:
            var_title, var_slug = "00 Napolitana", "00_napolitana"
        elif "00" in todo_harina:
            var_title, var_slug = "00", "00"
        elif "levadura" in todo_harina or "pan casero" in todo_harina:
            var_title, var_slug = "Con Levadura", "con_levadura"
        else:
            var_title, var_slug = "000", "000"

    # 2. LECHE FLUIDA (Unifica sachet, tetrabrick y botella bajo 'Leche')
    elif (nb_clean.startswith("leche") or "cindor" in combinado) and not any(
        k in combinado for k in ["polvo", "condensada", "evaporada", "coco", "almendra", "soja", "soya", "avena", "vegetal", "formula", "infantil", "postre", "dulce de leche", "crema de leche"]
    ):
        prod_title = "Leche"
        prod_slug = "leche"
        cat_final = "Lácteos y Frescos"
        if "cindor" in combinado:
            marca_limpia = "Cindor"
            var_title, var_slug = "Chocolatada", "chocolatada"
        elif "deslactosada" in combinado or "cero lactosa" in combinado or "sin lactosa" in combinado:
            var_title, var_slug = "Deslactosada", "deslactosada"
        elif "chocolatada" in combinado or "chocolate" in combinado or "cacao" in combinado:
            var_title, var_slug = "Chocolatada", "chocolatada"
        elif "descremada" in combinado or "parcialmente descremada" in combinado or "liviana" in combinado:
            var_title, var_slug = "Descremada", "descremada"
        elif "proteina" in combinado or "protein" in combinado:
            var_title, var_slug = "Protein", "protein"
        else:
            var_title, var_slug = "Entera", "entera"

    # 3. ACEITES COMESTIBLES
    elif nb_clean.startswith("aceite") and not any(
        k in combinado for k in ["corporal", "bebe", "cabello", "motor", "esencial", "coco", "lino", "sesamo", "palta", "canola"]
    ):
        prod_title = "Aceite"
        prod_slug = "aceite"
        cat_final = "Almacén"
        if "oliva" in combinado:
            if "extra virgen" in combinado or "virgen extra" in combinado:
                var_title, var_slug = "Oliva Extra Virgen", "oliva_extra_virgen"
            else:
                var_title, var_slug = "Oliva", "oliva"
        elif "girasol" in combinado:
            if "alto oleico" in combinado:
                var_title, var_slug = "Girasol Alto Oleico", "girasol_alto_oleico"
            else:
                var_title, var_slug = "Girasol", "girasol"
        elif "maiz" in combinado:
            var_title, var_slug = "Maíz", "maiz"
        elif "soja" in combinado:
            var_title, var_slug = "Soja", "soja"
        elif "mezcla" in combinado:
            var_title, var_slug = "Mezcla", "mezcla"
        else:
            var_title = capitalizar_frase(vs_clean) or "Clásico"
            var_slug = slugificar(var_title)

    # 4. ARROZ
    elif nb_clean.startswith("arroz") and not any(
        k in combinado for k in ["galleta", "tostada", "leche", "inflado", "harina", "vinagre", "papel"]
    ):
        prod_title = "Arroz"
        prod_slug = "arroz"
        cat_final = "Almacén"
        if "parboil" in combinado or "no se pasa" in combinado:
            var_title, var_slug = "Parboil", "parboil"
        elif "doble carolina" in combinado or "carolina" in combinado:
            var_title, var_slug = "Doble Carolina", "doble_carolina"
        elif "largo fino" in combinado:
            var_title, var_slug = "Largo Fino", "largo_fino"
        elif "integral" in combinado:
            var_title, var_slug = "Integral", "integral"
        elif "carnaroli" in combinado:
            var_title, var_slug = "Carnaroli", "carnaroli"
        elif "arborio" in combinado:
            var_title, var_slug = "Arborio", "arborio"
        elif "yamani" in combinado:
            var_title, var_slug = "Yamaní", "yamani"
        elif "sushi" in combinado or "koshihikari" in combinado:
            var_title, var_slug = "Sushi", "sushi"
        else:
            var_title, var_slug = "Largo Fino", "largo_fino"

    # 5. AZÚCAR
    elif nb_clean.startswith("azucar"):
        prod_title = "Azúcar"
        prod_slug = "azucar"
        cat_final = "Almacén"
        if "impalpable" in combinado or "glase" in combinado:
            var_title, var_slug = "Impalpable", "impalpable"
        elif "mascabo" in combinado or "integral" in combinado:
            var_title, var_slug = "Mascabo", "mascabo"
        elif "negra" in combinado:
            var_title, var_slug = "Negra", "negra"
        elif "rubia" in combinado or "morena" in combinado:
            var_title, var_slug = "Rubia", "rubia"
        elif "light" in combinado or "stevia" in combinado:
            var_title, var_slug = "Light", "light"
        else:
            var_title, var_slug = "Blanca Común Tipo A", "blanca_comun_tipo_a"

    # 6. DULCE DE LECHE
    elif "dulce" in nb_clean and "leche" in nb_clean:
        prod_title = "Dulce de Leche"
        prod_slug = "dulce_de_leche"
        cat_final = "Lácteos y Frescos"
        if "repostero" in combinado or "pastelero" in combinado:
            var_title, var_slug = "Repostero", "repostero"
        elif "light" in combinado or "reducido" in combinado or "descremado" in combinado:
            var_title, var_slug = "Light", "light"
        elif "colonial" in combinado or "estilo colonial" in combinado:
            var_title, var_slug = "Colonial", "colonial"
        else:
            var_title, var_slug = "Clásico", "clasico"

    # 7. PURÉ DE TOMATE
    elif "pure" in nb_clean and "tomate" in nb_clean:
        prod_title = "Puré de Tomate"
        prod_slug = "pure_de_tomate"
        cat_final = "Almacén"
        if "albahaca" in combinado:
            var_title, var_slug = "Con Albahaca", "albahaca"
        elif "pizzero" in combinado or "pizza" in combinado:
            var_title, var_slug = "Pizzero", "pizzero"
        elif "cebolla" in combinado:
            var_title, var_slug = "Con Cebolla", "cebolla"
        else:
            var_title, var_slug = "Clásico", "clasico"

    # 8. YERBA MATE
    elif "yerba" in nb_clean:
        prod_title = "Yerba Mate"
        prod_slug = "yerba_mate"
        cat_final = "Almacén"
        if "despalada" in combinado or "sin palo" in combinado:
            var_title, var_slug = "Despalada Sin Palo", "despalada"
        elif "suave" in combinado:
            var_title, var_slug = "Suave", "suave"
        elif "hierbas" in combinado or "serrana" in combinado or "compuesta" in combinado:
            var_title, var_slug = "Con Hierbas", "con_hierbas"
        elif "naranja" in combinado or "limon" in combinado or "pomelo" in combinado or "citrus" in combinado:
            var_title, var_slug = "Saborizada Cítricos", "citricos"
        elif "organica" in combinado:
            var_title, var_slug = "Orgánica", "organica"
        elif "barbacua" in combinado:
            var_title, var_slug = "Barbacuá", "barbacua"
        else:
            var_title, var_slug = "Tradicional Con Palo", "tradicional_con_palo"

    # 9. MANTECA
    elif nb_clean.startswith("manteca") and "mani" not in combinado and "cacao" not in combinado:
        prod_title = "Manteca"
        prod_slug = "manteca"
        cat_final = "Lácteos y Frescos"
        if "sin sal" in combinado:
            var_title, var_slug = "Sin Sal", "sin_sal"
        elif "light" in combinado:
            var_title, var_slug = "Light", "light"
        else:
            var_title, var_slug = "Clásica", "clasica"

    # 10. CASO GENERAL:Separación limpia de Producto (a) y Variedad (b)
    else:
        if not nb_clean:
            nb_clean = "producto"
        prod_title = capitalizar_frase(nb_clean)
        prod_slug = slugificar(nb_clean)

        # Quitar palabras de producto repetidas dentro de la variedad
        prod_words = set(nb_clean.split())
        vs_words = [w for w in vs_clean.split() if w not in prod_words]
        vs_filtrado = " ".join(vs_words).strip()

        if not vs_filtrado or vs_filtrado in ("comun", "tradicional", "estandar", "regular", "clasico", "clasica", "original"):
            var_title = "Clásico"
            var_slug = "clasico"
        else:
            var_title = capitalizar_frase(vs_filtrado)
            var_slug = slugificar(vs_filtrado)

    # Saneamiento universal: La variedad NUNCA debe contener el producto básico ni marcas
    if var_title and var_title != "Clásico":
        prod_tokens = set(w.lower() for w in re.findall(r'\b[a-zA-ZáéíóúÁÉÍÓÚñÑ]{3,}\b', prod_title))
        tokens_finales = []
        for vt in var_title.split():
            vt_low = vt.lower()
            vt_sin_s = vt_low.rstrip("s")
            if vt_low in prod_tokens or vt_sin_s in prod_tokens or vt_low in MARCAS_CONOCIDAS:
                continue
            tokens_finales.append(vt)
        var_saneado = " ".join(tokens_finales).strip()
        if not var_saneado or var_saneado.lower() in ("clasico", "clasica", "comun", "estandar"):
            var_title = "Clásico"
            var_slug = "clasico"
        else:
            var_title = var_saneado
            var_slug = slugificar(var_saneado)

    # Ensamblar cluster_id = producto + variedad + presentacion
    if var_slug and var_slug != "clasico":
        cluster_id_final = f"{prod_slug}_{var_slug}_{slug_tam}"
        nombre_canonico_final = f"{prod_title} {var_title} {txt_tam}"
    else:
        cluster_id_final = f"{prod_slug}_{slug_tam}"
        nombre_canonico_final = f"{prod_title} {txt_tam}"
        if not var_title:
            var_title = "Clásico"

    return {
        "cluster_id": cluster_id_final,
        "producto": prod_title,
        "variedad": var_title,
        "marca": marca_limpia,
        "envase": envase_limpio,
        "presentacion": txt_tam,
        "nombre_canonico": nombre_canonico_final,
        "categoria": cat_final,
        "contenido_neto": cn_norm,
        "unidad_referencia": um_norm,
    }
