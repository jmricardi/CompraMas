#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Reglas y diccionarios de normalización taxonómica para CompraMás.
Separa producto base, variedad, presentación/envase, categoría y descartes.
"""

import re
import unicodedata
from typing import Dict, Optional, Tuple


def sin_tildes(texto: str) -> str:
    """Elimina tildes/diacríticos y convierte ñ -> n para comparaciones canónicas."""
    s = str(texto).lower().strip()
    reemplazos = {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}
    for k, v in reemplazos.items():
        s = s.replace(k, v)
    return s


# 1. Patrones de descarte estricto de productos que NO pertenecen a góndola de supermercado
REGEX_DESCARTE_DESC = re.compile(
    r"\b("
    r"20w50|15w40|10w40|5w30|5w40|0w20|4t\b|2t\b|lubricante motor|aceite motor|"
    r"limpia motor|lava auto|shampoo auto|cera autobrillo auto|revividor|silicona.*auto|"
    r"parabrisa|anticongelante|refrigerante| liquido de freno|aditivo nafta|aditivo diesel|"
    r"esmalte sintetico|pintura en aerosol|pintura latex|pintura asfaltica|entonador|"
    r"aguarras|thinner|enduido|membrana liquida|cinta de teflon|cinta de enmascarar|"
    r"cinta aisladora|cinta metrica|acido muriatico|soda caustica|alguicida|"
    r"clarificador.*piscina|cloro granulado|pastillas de cloro|barrefondo|limpiafondo|"
    r"fertilizante|humus de lombriz|tierra fertil|semillas de cesped|tijera de podar|"
    r"insulina|vacuna hexaxim|ovulo vaginal|aerocamara|nebulizador|inhalador|"
    r"faja lumbar|tobillera|rodillera|munequera|collar rotuliano|protector auditivo|"
    r"protector bucal|mancuerna|pelota de futbol|pelota de basquet|pelota de voley|"
    r"pelota de rugby|antiparra|snorkel|inflador|columpio|sonajero|muneca|rompecabezas|"
    r"pantalon jean|campera|buzo|remera|camisa|corpiño|corpino|vedetina|colaless|"
    r"bombacha|ropa interior|guardapolvo|malla entera|bikini|pijama|camison|"
    r"zapatilla|ojota|sandalia|pantufla|alpargata|sabana|acolchado|frazada|cubrecama|"
    r"almohada|almohadon|cortina de bano|toalla de bano|toalla bano|toallon|"
    r"horno electrico|microondas|licuadora|batidora|tostadora|pava electrica|cafetera|"
    r"secador de pelo|secador de cabello|plancha para cabello|alisador|cortapelo|"
    r"ventilador|calefactor|estufa|parlante|auricular|cable usb|cargador celular|"
    r"protector de pantalla|conservadora|bolsa de dormir|reposera|perchero"
    r")\b",
    re.IGNORECASE,
)

PRODUCTOS_DESCARTE_EXACTO = {
    "jean", "ropa interior", "corpino", "corpiño", "vedetina", "colaless",
    "malla", "short", "guardapolvo", "faja", "tobillera", "rodillera",
    "manta", "frazada", "sabana", "sábana", "acolchado", "almohada", "almohadon",
    "toallon", "toallón", "cortina", "felpudo", "alfombra", "repasador",
    "pintura", "pintura en aerosol", "entonador", "rodillo", "aguarras",
    "silicona", "acido", "ácido", "alguicida", "alguicida de choque",
    "clarificador para piscina", "clarificador para piscinas", "cloro",
    "fertilizante", "planta", "humus", "humus de lombriz", "maceta",
    "pelota", "pesa", "mancuerna", "sonajero", "inflador", "columpio",
    "insulina", "vacuna", "inhalador", "aerocamara", "aerocámara", "ovulo", "óvulo",
    "horno", "conservadora", "parlante", "vaporizador",
    "set", "hermetico", "hermético", "contenedor", "recipiente", "fuente", "fuenton", "fuentón",
    "bowl", "copa", "vasos", "vaso", "platos", "plato", "tazon", "tazón", "taza",
    "jarra", "termo", "mate", "bombilla", "tabla", "vertedor", "dispenser", "dispensador",
    "perchas", "percha", "porta", "canasto", "organizador", "necessaire", "neceser",
    "regalo", "botella", "cuchilla", "cucharon", "cucharón", "espumadera",
}

# 2. Mapa directo de sinónimos, tildes y correcciones de Producto Básico
MAPA_PRODUCTO_CANONICO: Dict[str, str] = {
    "abrelata": "Abrelatas",
    "abrelatas": "Abrelatas",
    "aceituna": "Aceitunas",
    "aceitunas": "Aceitunas",
    "acond": "Acondicionador",
    "acondicionador": "Acondicionador",
    "aceto balsamico": "Aceto Balsámico",
    "aceto": "Aceto Balsámico",
    "agnolotis": "Agnolotti",
    "agnolotti": "Agnolotti",
    "acusay": "Akusay",
    "akusay": "Akusay",
    "aji": "Ají",
    "ají": "Ají",
    "albondigas": "Albóndigas",
    "albóndigas": "Albóndigas",
    "algodon": "Algodón",
    "algodón": "Algodón",
    "almidon": "Almidón de Maíz",
    "almidon de maiz": "Almidón de Maíz",
    "almidón de maíz": "Almidón de Maíz",
    "fecula de mandioca": "Fécula de Mandioca",
    "fecula": "Fécula de Mandioca",
    "anana": "Ananá",
    "ananá": "Ananá",
    "anana en almibar": "Ananá en Almíbar",
    "apositos": "Apósitos",
    "apósitos": "Apósitos",
    "arandanos": "Arándanos",
    "arándanos": "Arándanos",
    "aromatizante": "Aromatizante de Ambiente",
    "aromatizante de ambientes": "Aromatizante de Ambiente",
    "aromatizador": "Aromatizante de Ambiente",
    "ambientador": "Aromatizante de Ambiente",
    "desodorante de ambiente": "Aromatizante de Ambiente",
    "atun": "Atún",
    "atún": "Atún",
    "azucar": "Azúcar",
    "azúcar": "Azúcar",
    "balsamo": "Bálsamo",
    "bálsamo": "Bálsamo",
    "budin": "Budín",
    "budín": "Budín",
    "cafe": "Café",
    "café": "Café",
    "champignones": "Champiñones",
    "champinones": "Champiñones",
    "champiñones": "Champiñones",
    "coloracion": "Tintura Capilar",
    "coloración": "Tintura Capilar",
    "tintura": "Tintura Capilar",
    "tintura capilar": "Tintura Capilar",
    "tintura en crema": "Tintura Capilar",
    "tintura para cabello": "Tintura Capilar",
    "kit de coloracion": "Tintura Capilar",
    "cookies": "Galletitas",
    "galletas": "Galletitas",
    "galletita": "Galletitas",
    "galletitas": "Galletitas",
    "tostaditas": "Tostadas",
    "tostadas": "Tostadas",
    "bizcochitos": "Bizcochos",
    "bizcocho": "Bizcochos",
    "bizcochos": "Bizcochos",
    "crema dental": "Pasta Dental",
    "pasta dental": "Pasta Dental",
    "gel dental": "Pasta Dental",
    "difusor": "Difusor Aromático",
    "difusor de varillas": "Difusor Aromático",
    "eau": "Perfume",
    "eau de cologne": "Colonia",
    "eau de parfum": "Perfume",
    "eau de perfume": "Perfume",
    "eau de toilette": "Perfume",
    "fragancia": "Perfume",
    "escobillon": "Escobillón",
    "escobillón": "Escobillón",
    "esmalte": "Esmalte de Uñas",
    "esmalte de unas": "Esmalte de Uñas",
    "esmalte de uñas": "Esmalte de Uñas",
    "esmalte para unas": "Esmalte de Uñas",
    "esmalte para uñas": "Esmalte de Uñas",
    "espatula": "Espátula",
    "espátula": "Espátula",
    "jabon": "Jabón de Tocador",
    "jabón": "Jabón de Tocador",
    "jabon de tocador": "Jabón de Tocador",
    "jabón de tocador": "Jabón de Tocador",
    "jabon en barra": "Jabón de Tocador",
    "jabon de glicerina": "Jabón de Tocador",
    "jabon liquido": "Jabón Líquido",
    "jabón líquido": "Jabón Líquido",
    "jabon en polvo": "Jabón en Polvo",
    "jabón en polvo": "Jabón en Polvo",
    "jabon liquido para ropa": "Jabón Líquido para Ropa",
    "jabón líquido para ropa": "Jabón Líquido para Ropa",
    "jabon liquido para ropa fina": "Jabón Líquido para Ropa",
    "detergente para ropa": "Jabón Líquido para Ropa",
    "detergente en polvo": "Jabón en Polvo",
    "jamon": "Jamón Cocido",
    "jamón": "Jamón Cocido",
    "jamon cocido": "Jamón Cocido",
    "jamón cocido": "Jamón Cocido",
    "jamon crudo": "Jamón Crudo",
    "jamón crudo": "Jamón Crudo",
    "lapiz": "Lápiz",
    "lápiz": "Lápiz",
    "limon": "Limón",
    "limón": "Limón",
    "limpiador liquido": "Limpiador de Pisos",
    "limpiador líquido": "Limpiador de Pisos",
    "locion": "Loción Corporal",
    "loción": "Loción Corporal",
    "maiz": "Maíz",
    "maíz": "Maíz",
    "mani": "Maní",
    "maní": "Maní",
    "maquina de afeitar": "Máquina de Afeitar",
    "máquina de afeitar": "Máquina de Afeitar",
    "maquina para rasurar": "Máquina de Afeitar",
    "medallon": "Medallón",
    "medallón": "Medallón",
    "medallones": "Medallón",
    "almendras sin cascara": "Almendras",
    "mejillon": "Mejillones",
    "mejillones": "Mejillones",
    "melon": "Melón",
    "melón": "Melón",
    "morron": "Morrón",
    "morrón": "Morrón",
    "pimiento": "Morrón",
    "noquis": "Ñoquis",
    "ñoquis": "Ñoquis",
    "panal": "Pañales",
    "pañal": "Pañales",
    "panales": "Pañales",
    "pañales": "Pañales",
    "pano": "Paño de Limpieza",
    "paño": "Paño de Limpieza",
    "pano de microfibra": "Paño de Limpieza",
    "microfibra": "Paño de Limpieza",
    "panuelos": "Pañuelos Descartables",
    "pañuelos": "Pañuelos Descartables",
    "panuelos descartables": "Pañuelos Descartables",
    "pañuelos descartables": "Pañuelos Descartables",
    "panuelos de papel": "Pañuelos Descartables",
    "papel higienico": "Papel Higiénico",
    "papel higiénico": "Papel Higiénico",
    "pasas": "Pasas de Uva",
    "pasas de uva": "Pasas de Uva",
    "pate": "Paté",
    "paté": "Paté",
    "pimenton": "Pimentón",
    "pimentón": "Pimentón",
    "postre lacteo": "Postre Lácteo",
    "postre lácteo": "Postre Lácteo",
    "pure": "Puré de Papas",
    "puré": "Puré de Papas",
    "pure de papa": "Puré de Papas",
    "puré de papa": "Puré de Papas",
    "pure de papas": "Puré de Papas",
    "puré de papas": "Puré de Papas",
    "pure de tomate": "Puré de Tomate",
    "puré de tomate": "Puré de Tomate",
    "residuos": "Bolsas de Residuo",
    "bolsa de residuos": "Bolsas de Residuo",
    "bolsas de residuos": "Bolsas de Residuo",
    "bolsas de residuo": "Bolsas de Residuo",
    "rollo de residuo": "Bolsas de Residuo",
    "salamin": "Salame",
    "salamín": "Salame",
    "salame": "Salame",
    "salmon": "Salmón",
    "salmón": "Salmón",
    "semola": "Sémola",
    "sémola": "Sémola",
    "servilleta": "Servilletas de Papel",
    "servilletas": "Servilletas de Papel",
    "servilletas de papel": "Servilletas de Papel",
    "serum": "Sérum Facial",
    "sérum": "Sérum Facial",
    "sérum facial": "Sérum Facial",
    "suavizante": "Suavizante para Ropa",
    "suavizante para ropa": "Suavizante para Ropa",
    "suplemento": "Suplemento Dietario",
    "suplemento nutricional": "Suplemento Dietario",
    "suplemento deportivo": "Suplemento Dietario",
    "te": "Té",
    "té": "Té",
    "infusion": "Té",
    "infusión": "Té",
    "tempera": "Témpera",
    "témpera": "Témpera",
    "toallitas humedas": "Toallitas Húmedas",
    "toallitas húmedas": "Toallitas Húmedas",
    "trapo": "Trapo de Piso",
    "trapo de piso": "Trapo de Piso",
    "pano de piso": "Trapo de Piso",
    "pano para piso": "Trapo de Piso",
    "turron": "Turrón",
    "turrón": "Turrón",
    "vacio": "Vacío",
    "vacío": "Vacío",
    "yerba": "Yerba Mate",
    "yerba mate": "Yerba Mate",
}

# 3. Familias donde "Producto + Modificador" se separa en (Producto Base, Variedad)
# NOTA: Quesos, Harinas, Semillas, Almendras, Milanesas, Medallones y Filets NO se colapsan
# hacia el genérico sino que se promueven al producto específico (ej. 'Queso Cremoso',
# 'Queso Azul', 'Harina de Trigo', 'Semillas de Chía', 'Milanesa de Carne', 'Filet de Merluza').
PREFIJOS_PRODUCTO_A_SEPARAR = [
    ("aderezo ", "Aderezo"),
    ("condimento para ", "Condimento"),
    ("condimento ", "Condimento"),
    ("especias para ", "Condimento"),
    ("adobo para ", "Adobo"),
    ("premezcla para ", "Premezcla"),
    ("polvo para preparar ", "Premezcla"),
    ("polvo para ", "Premezcla"),
    ("tapas para empanadas", "Tapas de Empanadas"),
    ("tapas de empanada", "Tapas de Empanadas"),
    ("tapa de empanada", "Tapas de Empanadas"),
    ("tapas para copetin", "Tapas de Empanadas"),
    ("tapas para tarta", "Tapas de Tarta"),
    ("tapas para pascualina", "Tapas de Tarta"),
    ("tapa de tarta", "Tapas de Tarta"),
    ("barra de chocolate", "Chocolate"),
    ("barrita de chocolate", "Chocolate"),
    ("tableta de chocolate", "Chocolate"),
    ("barra de ", "Barra de Cereal"),
    ("barrita de ", "Barra de Cereal"),
    ("galletas de arroz", "Galletas de Arroz"),
    ("galleta de arroz", "Galletas de Arroz"),
    ("galletitas ", "Galletitas"),
    ("galletas ", "Galletitas"),
    ("limonada ", "Limonada"),
    ("jugo en polvo", "Jugo en Polvo"),
    ("jugo ", "Jugo"),
    ("agua mineral", "Agua Mineral"),
    ("agua con gas", "Agua Mineral"),
    ("agua sin gas", "Agua Mineral"),
    ("agua saborizada", "Agua Saborizada"),
    ("agua tonica", "Agua Tónica"),
    ("agua tónica", "Agua Tónica"),
    ("bebida vegetal", "Bebida Vegetal"),
    ("bebida isotonica", "Bebida Isotónica"),
    ("bebida isotónica", "Bebida Isotónica"),
    ("bebida deportiva", "Bebida Isotónica"),
    ("bebida energizante", "Bebida Energizante"),
    ("pan dulce", "Pan Dulce"),
    ("pan rallado", "Pan Rallado"),
    ("panettone ", "Pan Dulce"),
    ("canela en ", "Canela"),
    ("ajo en ", "Ajo"),
    ("aji ", "Ají"),
    ("ají ", "Ají"),
    ("repelente de ", "Repelente"),
    ("repelente para ", "Repelente"),
    ("adhesivo ", "Adhesivo"),
    ("vegetales para ", "Vegetales"),
]


def resolver_producto_polisemico(
    prod: str, var: str, env: str, uni: str, desc: str, marca: str
) -> Tuple[str, str, str, bool]:
    """
    Resuelve nombres de producto genéricos, truncados o polisémicos
    (Crema, Gel, Polvo, Barra, Tableta, Pastillas, Cera, Cepillo, Guante, Toalla,
    Toallitas, Tapas, Papas, Tomate, Dulce, Pasta, Mix, Bebida, Producto, Mini, etc.)
    Devuelve (producto, variedad, envase, descartar).
    """
    p_clean = sin_tildes(prod)
    v_clean = sin_tildes(var)
    d_clean = sin_tildes(f"{desc} {prod} {var} {marca}")

    # Descarte global por regex de descripción o producto exacto
    if p_clean in PRODUCTOS_DESCARTE_EXACTO or REGEX_DESCARTE_DESC.search(d_clean):
        # Proteger perfumería/bebés/primeros auxilios legítimos
        if not any(k in d_clean for k in [
            "oleo calcareo", "panal", "algodon", "alcohol", "shampoo", "acondicionador",
            "desodorante", "jabon", "crema corporal", "crema facial", "pasta dental",
            "toallitas femeninas", "toallitas humedas", "protector solar", "agua micelar"
        ]):
            return (prod, var, env, True)

    # 1. MINI / PRODUCTO / PARA / HOME / LIBRERIA (nombres rotos)
    if p_clean in ("producto", "para", "almacen", "alimento", "aerosol"):
        if "coca cola" in d_clean or "pepsi" in d_clean or "sprite" in d_clean or "fanta" in d_clean:
            return ("Gaseosa", var, "Botella", False)
        if "gatorade" in d_clean or "powerade" in d_clean:
            return ("Bebida Isotónica", var, "Botella", False)
        if "cerveza" in d_clean or "quilmes" in d_clean:
            return ("Cerveza", var, "Botella", False)
        if "margarina" in d_clean:
            return ("Margarina", var, "Paquete", False)
        if "queso rallado" in d_clean:
            return ("Queso Rallado", var, "Paquete", False)
        if "queso" in d_clean:
            return ("Queso", var, "Paquete", False)
        if "miel" in d_clean:
            return ("Miel", var, "Frasco", False)
        if "tarta" in d_clean:
            return ("Tarta", var, "Paquete", False)
        return (prod, var, env, True)

    if p_clean == "mini":
        if "bizcocho" in d_clean:
            return ("Bizcochos", var.replace("Bizcochos", "").strip() or "Clásico", "Paquete", False)
        if "bombon" in d_clean:
            return ("Bombones", var, "Caja", False)
        if "alfajor" in d_clean or "torta" in d_clean:
            return ("Alfajor", var, "Paquete", False)
        if "tostada" in d_clean:
            return ("Tostadas", var, "Paquete", False)
        if "galletita" in d_clean or "galleta" in d_clean:
            return ("Galletitas", var, "Paquete", False)
        if "budin" in d_clean:
            return ("Budín", var, "Paquete", False)
        return (prod, var, env, True)

    if p_clean == "home":
        if "difusor" in d_clean:
            return ("Difusor Aromático", var.replace("Difusor", "").strip() or "Clásico", "Frasco", False)
        return ("Aromatizante de Ambiente", var.replace("Spray", "").strip() or "Clásico", "Botella", False)

    if p_clean in ("lava", "lubricante"):
        if "intimo" in d_clean or "sexual" in d_clean or "prime" in d_clean or "tulipan" in d_clean:
            return ("Gel Íntimo", var, "Botella", False)
        return (prod, var, env, True)

    if p_clean == "limpia":
        if any(k in d_clean for k in ["contacto", "fondo", "parabrisa", "motor", "tapizado"]):
            return (prod, var, env, True)
        return ("Limpiador", var, env, False)

    if p_clean == "untable":
        return ("Queso Untable", var, "Pote", False)

    if p_clean == "saborizada":
        return ("Agua Saborizada", var, "Botella", False)

    if p_clean == "formula":
        return ("Leche Infantil", var, "Lata" if "lata" in d_clean else "Caja", False)

    if p_clean in ("bloque", "canasta"):
        return ("Pastilla para Inodoro", var, "Blister", False)

    if p_clean == "discos":
        if "algodon" in d_clean:
            return ("Algodón", "Discos Desmaquillantes", "Paquete", False)
        if "inodoro" in d_clean or "limpieza" in d_clean or "glade" in d_clean or "pato" in d_clean:
            return ("Pastilla para Inodoro", var, "Blister", False)
        if "arroz" in d_clean:
            return ("Galletas de Arroz", var, "Paquete", False)
        return ("Tapas de Empanadas", var, "Paquete", False)

    if p_clean == "rollo":
        if "aluminio" in d_clean:
            return ("Papel Aluminio", var, "Caja", False)
        if "film" in d_clean:
            return ("Papel Film", var, "Caja", False)
        if "cocina" in d_clean or "papel" in d_clean or "multiuso" in d_clean:
            return ("Rollo de Cocina", var, "Paquete", False)
        if "residuo" in d_clean or re.search(r"\d+x\d+", d_clean):
            return ("Bolsas de Residuo", var, "Paquete", False)
        if "acero" in d_clean or "virulana" in d_clean:
            return ("Esponja", "Lana de Acero", "Paquete", False)
        return (prod, var, env, True)

    if p_clean == "repuesto":
        if "afeit" in d_clean or "mach3" in d_clean or "fusion" in d_clean or "gillette" in d_clean:
            return ("Repuesto de Afeitadora", var, "Blister", False)
        if "aero" in d_clean or "glade" in d_clean or "air wick" in d_clean or "ambiente" in d_clean:
            return ("Aromatizante de Ambiente", var, "Aerosol", False)
        if "mopa" in d_clean:
            return ("Mopa", "Repuesto", "Unidad", False)
        if "hoja" in d_clean or "escolar" in d_clean or "rivadavia" in d_clean or "exito" in d_clean:
            return ("Repuesto de Hojas Escolares", var, "Paquete", False)
        return (prod, var, env, True)

    # 2. TOALLA / TOALLITAS
    if p_clean in ("toalla", "toallitas", "toallas"):
        if any(k in d_clean for k in ["bano", "rostro", "visita", "playa", "algodon egipcio", "jacquard", "karsten", "cannon", "teka", "tex home", "franco valente"]):
            return (prod, var, env, True)
        if any(k in d_clean for k in ["femenina", "alas", "normal", "nocturna", "invisible", "kotex", "always", "ladysoft", "doncella", "lina"]):
            return ("Toallitas Femeninas", var, "Paquete", False)
        if any(k in d_clean for k in ["desinfectante", "limpieza", "clorox", "ayudin", "lysoform", "antibacterial"]):
            return ("Toallitas Desinfectantes", var, "Paquete", False)
        if any(k in d_clean for k in ["cocina", "papel", "absorbente"]):
            return ("Rollo de Cocina", var, "Paquete", False)
        return ("Toallitas Húmedas", var, "Paquete", False)

    # 3. CREMA
    if p_clean == "crema":
        if any(k in d_clean for k in ["chantilly", "batida", "leche", "doble", "cocinar", "sancor", "serenisima", "milkaut", "tregar", "ilolay", "tonadita"]):
            return ("Crema de Leche", var, "Pote" if env == "Paquete" else env, False)
        if "dental" in d_clean or "diente" in d_clean or "colgate" in d_clean or "sensodyne" in d_clean or "kolynos" in d_clean or "odol" in d_clean:
            return ("Pasta Dental", var, "Tubo", False)
        if "peinar" in d_clean or "capilar" in d_clean or "cabello" in d_clean or "rulos" in d_clean or "tratamiento" in d_clean or "enjuague" in d_clean:
            return ("Crema para Peinar", var, "Botella", False)
        if "depilat" in d_clean:
            return ("Crema Depilatoria", var, "Tubo", False)
        if "afeitar" in d_clean:
            return ("Espuma de Afeitar", var, "Tubo", False)
        if "facial" in d_clean or "rostro" in d_clean or "arruga" in d_clean or "hialuronico" in d_clean or "pond" in d_clean or "cicatricure" in d_clean:
            return ("Crema Facial", var, "Pote", False)
        if "mano" in d_clean or "cuerpo" in d_clean or "corporal" in d_clean or "hidratante" in d_clean or "nutritiva" in d_clean or "nivea" in d_clean or "dove" in d_clean or "bagovit" in d_clean or " Hinds" in d_clean or "dermibe" in d_clean:
            return ("Crema Corporal", var, "Botella" if uni == "ml" else "Pote", False)
        if "mani" in d_clean:
            return ("Pasta de Maní", var, "Frasco", False)
        if "avellana" in d_clean or "chocolina" in d_clean or "cacao" in d_clean:
            return ("Pasta de Avellanas", var, "Frasco", False)
        return ("Crema Corporal", var, env, False)

    # 4. GEL
    if p_clean == "gel":
        if "dental" in d_clean or "diente" in d_clean:
            return ("Pasta Dental", var, "Tubo", False)
        if "alcohol" in d_clean or "sanitizante" in d_clean or "antibacterial" in d_clean:
            return ("Alcohol en Gel", var, "Botella", False)
        if "ducha" in d_clean or "bano" in d_clean:
            return ("Gel de Ducha", var, "Botella", False)
        if "intimo" in d_clean or "lubricante" in d_clean:
            return ("Gel Íntimo", var, "Botella", False)
        if "afeitar" in d_clean or "after shave" in d_clean:
            return ("Espuma de Afeitar", var, "Aerosol", False)
        if "inodoro" in d_clean or "limpiador" in d_clean or "lavavajilla" in d_clean:
            return ("Limpiador de Inodoros", var, "Botella", False)
        if "facial" in d_clean or "corporal" in d_clean or "aloe" in d_clean or "post solar" in d_clean or "centella" in d_clean or "hialuronico" in d_clean:
            return ("Gel Corporal", var, "Botella", False)
        return ("Gel Fijador", var, "Pote" if env == "Paquete" else env, False)

    # 5. TAPAS
    if p_clean == "tapas":
        if "tarta" in d_clean or "pascualina" in d_clean:
            return ("Tapas de Tarta", var, "Paquete", False)
        if "asado" in d_clean:
            return ("Tapa de Asado", var, "Bandeja", False)
        if "nalga" in d_clean:
            return ("Tapa de Nalga", var, "Bandeja", False)
        if "alfajor" in d_clean:
            return ("Tapas de Alfajor", var, "Paquete", False)
        if "frasco" in d_clean or "cristal" in d_clean or "plastico" in d_clean:
            return (prod, var, env, True)
        return ("Tapas de Empanadas", var, "Paquete", False)

    # 6. PAPAS
    if p_clean in ("papas", "papa"):
        if any(k in d_clean for k in ["frita", "acanalada", "ondulada", "pay", "snacks", "lays", "krachitos", "pehuamar", "pringles", "quento", "jamon serrano", "cheddar", "barbacoa", "asado criollo", "crema y cebolla", "ketchup"]):
            return ("Papas Fritas", var, "Tubo" if "tubo" in d_clean or "pringles" in d_clean else "Paquete", False)
        if any(k in d_clean for k in ["congelad", "prefrita", "baston", "mccain", "noisette", "caritas", "horno"]):
            return ("Papas Prefritas Congeladas", var, "Paquete", False)
        return ("Papa", var, "Granel" if uni == "kg" else "Bolsa", False)

    # 7. TOMATE
    if p_clean == "tomate":
        if "pure" in d_clean:
            return ("Puré de Tomate", var, "Cartón (Tetra Brik)" if env == "Paquete" else env, False)
        if "triturado" in d_clean:
            return ("Tomate Triturado", var, "Botella" if "botella" in d_clean or "vidrio" in d_clean else "Cartón (Tetra Brik)", False)
        if any(k in d_clean for k in ["pelado", "perita en lata", "cubeteado", "trozado", "lata", "conserva", "arca", "noel", "la campagnola", "inca", "marolio", "de la huerta", "bolognesa"]):
            return ("Tomate en Conserva", var, "Lata" if env == "Paquete" else env, False)
        return ("Tomate", var, "Granel" if uni == "kg" else "Bandeja", False)

    # 8. DULCE
    if p_clean == "dulce":
        if "leche" in d_clean:
            return ("Dulce de Leche", var, "Pote", False)
        if "batata" in d_clean:
            return ("Dulce de Batata", var, "Paquete", False)
        if "membrillo" in d_clean:
            return ("Dulce de Membrillo", var, "Paquete", False)
        return ("Mermelada", var, "Frasco" if env == "Paquete" else env, False)

    # 9. CERA / CEPILLO / GUANTE / PALA / SECADOR / FIBRA
    if p_clean == "cera":
        if "auto" in d_clean:
            return (prod, var, env, True)
        if "depilat" in d_clean:
            return ("Cera Depilatoria", var, "Pote", False)
        if "capilar" in d_clean or "pelo" in d_clean or "cabello" in d_clean or "peinar" in d_clean or "frizz" in d_clean or "mate" in d_clean:
            return ("Cera Capilar", var, "Pote", False)
        return ("Cera para Pisos", var, "Botella", False)

    if p_clean == "cepillo":
        if any(k in d_clean for k in ["acero", "alambre", "electrico", "alisador", "aire", "bellissima"]):
            return (prod, var, env, True)
        if any(k in d_clean for k in ["dental", "diente", "interdental", "ortodoncia", "colgate", "oral-b", "oral b", "gum", "kolynos", "sensodyne"]):
            return ("Cepillo Dental", var, "Blister", False)
        if any(k in d_clean for k in ["pelo", "cabello", "desenredante", "brushing", "neumatico", "termico"]):
            return ("Cepillo para Cabello", var, "Unidad", False)
        return ("Cepillo de Limpieza", var, "Unidad", False)

    if p_clean == "guante":
        if any(k in d_clean for k in ["boxeo", "arquero", "trabajo", "descarne", "moteado", "algodon", "lana", "abrigo"]):
            return (prod, var, env, True)
        return ("Guantes de Limpieza", var, "Paquete", False)

    if p_clean == "pala":
        if any(k in d_clean for k in ["jardin", "punta", "ancha", "playa", "ceniza"]):
            return (prod, var, env, True)
        return ("Pala para Residuos", var, "Unidad", False)

    if p_clean == "secador":
        if "cabello" in d_clean or "pelo" in d_clean or "watt" in d_clean:
            return (prod, var, env, True)
        return ("Secador de Piso", var, "Unidad", False)

    if p_clean == "fibra":
        if "escolar" in d_clean or "marcador" in d_clean or "colores" in d_clean or "faber" in d_clean:
            return ("Marcador", var, "Paquete", False)
        return ("Esponja", var, "Paquete", False)

    return (prod, var, env, False)
