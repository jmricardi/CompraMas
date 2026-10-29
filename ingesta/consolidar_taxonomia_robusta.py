#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Consolidación Taxonómica y Estructural Robusta del Catálogo (Post-Auditoría LLM).

Resuelve de raíz las fallas estructurales detectadas en la revisión manual:
1. Aplica las 21,680 correcciones y descartes validados por el LLM (protegiendo
   perfumería, bebés y primeros auxilios de góndola).
2. Desambiguación profunda de productos polisémicos (especialmente 'Aceite':
   separa Aceite Comestible, Rocío Vegetal, Aceite para Bebé, Aceite Bronceador,
   Aceite Corporal/Capilar/Ducha/Facial, Aceite Aromatizante/Hornillo, Conservas
   en Aceite, y descarta lubricantes de motor/motos/cadenas/ferretería/bazar).
3. Corrección de envases ('presentacion') a nivel de ítem individual con límites
   de palabra estrictos (evitando que 'abrelata' coincida con 'lata' o que una
   lata de aceite de oliva contamine a las botellas de vidrio del mismo volumen).
4. Unificación canónica Singular/Plural tanto en 'producto' (414+ pares como
   Aceituna/Aceitunas, Abrelata/Abrelatas, Galletita/Galletitas) como en 'variedad'
   (Verde/Verdes, Descarozada/Descarozadas, etc.).
5. Normalización de casos específicos (Abrelatas con Perilla/Mariposa/Uña en Unidad
   o Blister; Abrillantador para Lavavajillas unificado y descarte de Speedway
   automotor; Absenta variedad Clásico en categoría Bebidas).
6. Clasificación precisa de 'categoria' (Almacén, Bebidas, Lácteos y Frescos,
   Frescos, Limpieza, Cuidado Personal, Bebés y Maternidad, Mascotas, Bazar y Hogar,
   Librería).
"""

import re
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple

import pandas as pd

from config import CLUSTERS_DIR, PROCESSED_DIR
from reglas_taxonomia import (
    MAPA_PRODUCTO_CANONICO,
    PREFIJOS_PRODUCTO_A_SEPARAR,
    resolver_producto_polisemico,
    sin_tildes,
)
from clasificador_categorias_envases import (
    inferir_categoria_robusta,
    inferir_envase_robusto,
    promover_subtipo_a_producto,
    resolver_polisemia_extra,
)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

CLUSTERS_CSV = CLUSTERS_DIR / "producto_clusters.csv"
ITEMS_CSV = CLUSTERS_DIR / "producto_cluster_items.csv"
CATALOGO_CSV = PROCESSED_DIR / "catalogo_productos.csv"
CORRECCIONES_CSV = CLUSTERS_DIR / "auditoria_productos_llm_correcciones.csv"

# Mapa explícito de unificación singular/plural y sinónimos de Producto Básico
CANONICAL_PRODUCT_MAP: Dict[str, str] = {
    "abrelata": "Abrelatas",
    "abrelatas": "Abrelatas",
    "abrelata con perilla": "Abrelatas",
    "aceituna": "Aceitunas",
    "aceitunas": "Aceitunas",
    "galletita": "Galletitas",
    "galletitas": "Galletitas",
    "empanada": "Empanadas",
    "empanadas": "Empanadas",
    "gaseosa": "Gaseosa",
    "gaseosas": "Gaseosa",
    "almendra": "Almendras",
    "almendras": "Almendras",
    "semilla": "Semillas",
    "semillas": "Semillas",
    "caldo": "Caldo",
    "caldos": "Caldo",
    "prepizza": "Prepizza",
    "prepizzas": "Prepizza",
    "fideo": "Fideos",
    "fideos": "Fideos",
    "alfajor": "Alfajor",
    "alfajores": "Alfajor",
    "caramelo": "Caramelos",
    "caramelos": "Caramelos",
    "chupetin": "Chupetines",
    "chupetín": "Chupetines",
    "chupetines": "Chupetines",
    "bombon": "Bombones",
    "bombón": "Bombones",
    "bombones": "Bombones",
    "panal": "Pañales",
    "panales": "Pañales",
    "pañal": "Pañales",
    "pañales": "Pañales",
    "hamburguesa": "Hamburguesas",
    "hamburguesas": "Hamburguesas",
    "salchicha": "Salchichas",
    "salchichas": "Salchichas",
    "nugget": "Nuggets",
    "nuggets": "Nuggets",
    "tostada": "Tostadas",
    "tostadas": "Tostadas",
    "grisin": "Grisines",
    "grisín": "Grisines",
    "grisines": "Grisines",
    "croqueta": "Croquetas",
    "croquetas": "Croquetas",
    "palmerita": "Palmeritas",
    "palmeritas": "Palmeritas",
    "garrapinada": "Garrapiñadas",
    "garrapiñada": "Garrapiñadas",
    "garrapinadas": "Garrapiñadas",
    "garrapiñadas": "Garrapiñadas",
    "salamito": "Salamitos",
    "salamitos": "Salamitos",
    "pepino": "Pepinos",
    "pepinos": "Pepinos",
    "higo": "Higos",
    "higos": "Higos",
    "cubanito": "Cubanitos",
    "cubanitos": "Cubanitos",
    "especia": "Especias",
    "especias": "Especias",
    "cappelletti": "Cappellettis",
    "cappellettis": "Cappellettis",
    "raviol": "Ravioles",
    "ravioles": "Ravioles",
    "noqui": "Ñoquis",
    "noquis": "Ñoquis",
    "ñoqui": "Ñoquis",
    "ñoquis": "Ñoquis",
    "sorrentino": "Sorrentinos",
    "sorrentinos": "Sorrentinos",
    "canelon": "Canelones",
    "canelones": "Canelones",
    "pasas de uva": "Pasas de Uva",
    "pasa de uva": "Pasas de Uva",
    "nuez": "Nueces",
    "nueces": "Nueces",
    "castana": "Castañas",
    "castañas": "Castañas",
    "avellana": "Avellanas",
    "avellanas": "Avellanas",
    "pistacho": "Pistachos",
    "pistachos": "Pistachos",
    "ciruela": "Ciruelas",
    "ciruelas": "Ciruelas",
    "durazno": "Duraznos",
    "duraznos": "Duraznos",
    "arveja": "Arvejas",
    "arvejas": "Arvejas",
    "lenteja": "Lentejas",
    "lentejas": "Lentejas",
    "garbanzo": "Garbanzos",
    "garbanzos": "Garbanzos",
    "poroto": "Porotos",
    "porotos": "Porotos",
    "salchichon": "Salchichón",
    "atun": "Atún",
    "jabon": "Jabón",
    "limon": "Limón",
    "azucar": "Azúcar",
    "cafe": "Café",
    "te": "Té",
    "shampo": "Shampoo",
    "champu": "Shampoo",
    "champú": "Shampoo",
}

utensilios_bazar = {
    "abrelatas", "destapador", "pelapapas", "rallador", "cuchillo", "tenedor",
    "cuchara", "cucharita", "espatula", "espátula", "colador", "sacacorchos",
    "pisapapas", "batidor", "pinza", "tabla de picar", "asidera", "molde",
    "tijera", "encendedor",
}


def slug(texto: str) -> str:
    s = str(texto).lower()
    reemplazos = {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ñ": "n", "ü": "u"}
    for k, v in reemplazos.items():
        s = s.replace(k, v)
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def fmt_num(valor: str) -> str:
    try:
        f = float(str(valor).replace(",", "."))
        return str(int(f)) if f.is_integer() else f"{f:g}"
    except (TypeError, ValueError):
        return "1"


def inferir_categoria(producto: str, variedad: str, desc: str) -> str:
    p = producto.lower()
    v = variedad.lower()
    d = desc.lower()
    texto = f"{p} {v} {d}"

    if any(k in p for k in [
        "pañal", "pañales", "óleo calcáreo", "oleo calcareo", "mamadera",
        "chupete", "leche infantil", "toallitas húmedas bebé", "aceite para bebé",
        "colonia para bebé", "shampoo para bebé"
    ]):
        return "Bebés y Maternidad"

    if any(k in p for k in [
        "shampoo", "acondicionador", "desodorante", "jabón de tocador", "jabón líquido",
        "crema corporal", "crema facial", "crema dental", "pasta dental", "cepillo dental",
        "enjuague bucal", "tintura", "toallitas femeninas", "protectores diarios",
        "tampones", "algodón", "alcohol", "curitas", "apósito", "gasas", "afeitadora",
        "espuma de afeitar", "depilatoria", "perfume", "colonia", "body splash",
        "protector solar", "aceite bronceador", "bronceador", "aceite corporal",
        "aceite capilar", "óleo capilar", "aceite de ducha", "aceite limpiador facial",
        "aceite desmaquillante", "agua micelar", "esmalte", "quitaesmalte", "talco",
        "hisopos", "crema para peinar", "gel fijador", "jabón"
    ]):
        return "Cuidado Personal"

    if any(k in p for k in [
        "lavandina", "detergente", "limpiador", "desinfectante", "jabón para ropa",
        "jabón en polvo", "suavizante", "quitamanchas", "abrillantador", "lustramuebles",
        "cera para pisos", "insecticida", "repelente", "espirales", "pastillas termoevaporables",
        "aromatizador", "desodorante de ambiente", "aceite aromatizante", "aceite citronella",
        "papel higiénico", "rollo de cocina", "servilletas de papel", "pañuelos descartables",
        "esponja", "paño", "rejilla", "trapo de piso", "escoba", "escobillón", "secador de piso",
        "mopa", "balde", "guantes de limpieza", "bolsas de residuo", "destapacañerías",
        "pastilla para inodoro", "canasta para inodoro", "crema para calzado", "pomada para calzado"
    ]):
        return "Limpieza"

    if any(k in p for k in [
        "vino", "cerveza", "gaseosa", "agua mineral", "agua saborizada", "agua con gas",
        "agua sin gas", "agua tónica", "jugo", "soda", "aperitivo", "fernet", "licor",
        "whisky", "vodka", "gin", "ron", "tequila", "absenta", "sidra", "champagne",
        "espumante", "energizante", "bebida isotónica", "bebida sin azúcar", "bebida vegetal",
        "bebida"
    ]):
        return "Bebidas"

    if any(k in p for k in [
        "leche", "yogur", "manteca", "margarina", "crema de leche", "queso", "ricota",
        "dulce de leche", "postre lácteo", "flan", "actimel", "leche fermentada",
        "huevos", "tapas de empanadas", "tapas de tarta", "levadura"
    ]):
        return "Lácteos y Frescos"

    if any(k in p for k in [
        "carne", "pollo", "cerdo", "milanesa", "hamburguesas", "salchichas", "chorizo",
        "morcilla", "fiambre", "jamón", "salame", "mortadela", "lomito", "panceta",
        "salamitos", "nuggets", "pescado", "merluza", " medallón", "fruta", "verdura",
        "papa", "cebolla", "tomate", "lechuga", "zanahoria", "manzana", "banana", "naranja"
    ]):
        return "Frescos"

    if any(k in p for k in [
        "alimento para perro", "alimento para gato", "alimento para mascotas",
        "piedras sanitarias", "snack para perro", "snack para gato"
    ]) or "perro" in texto or "gato" in texto and "alimento" in texto:
        return "Mascotas"

    if any(k in p for k in [
        "cuaderno", "lápiz", "lapicera", "bolígrafo", "marcador", "resaltador",
        "resma", "carpeta", "repuesto escolar", "goma de borrar", "sacapuntas",
        "regla", "adhesivo", "plasticola", "cinta adhesiva", "papel glacé", "cartulina"
    ]):
        return "Librería"

    if p in utensilios_bazar or any(k in p for k in [
        "fósforos", "velas", "escarbadientes", "film adherente", "papel aluminio",
        "papel manteca", "bolsas freezer", "broches", "pilas", "lámpara", "foco"
    ]):
        return "Bazar y Hogar"

    return "Almacén"


def refinar_aceite(desc: str, marca: str, prod_actual: str, var_actual: str, env_actual: str) -> Tuple[str, str, str, bool]:
    """Desambigua de forma determinística todos los productos que contienen 'Aceite'."""
    d_low = f"{desc} {var_actual}".lower()
    m_low = marca.lower()

    # 1. Lubricantes de motor, moto, cadena, máquina, ferretería -> DESCARTAR
    pat_motor = r"\b(0w20|0w30|5w30|5w40|10w30|10w40|15w40|15w50|20w50|1540|2050|1040|540|4t|2t|moto|motos|motogulf|cadena|cadenas|motor|lubricante|desoxidante|emulsionable|emulsionado|doble cocido|multiuso|aceitodo|wx10|auro|quartz|ineo|elaion|kriox)\b"
    marcas_motor = {"elaion", "ypf", "gulf", "total", "total quartz", "elf", "bardahl", "wander", "revigal", "penetrit", "puma", "gnc", "hunter", "parque", "grhesa", "gowiplay"}
    if re.search(pat_motor, d_low) or m_low in marcas_motor:
        return ("Aceite Lubricante", "Motor", "Botella", True)

    # 2. Bazar / Electrodomésticos con la palabra aceite -> DESCARTAR
    if any(k in d_low for k in ["aceitero", "aceitera", "vinagrera", "vinag.", "acei vinag", "aceit vinag", "freidora", "mdf50"]):
        return ("Bazar Aceitero", "Clásico", "Unidad", True)

    # 3. Cápsulas / Farmacia -> DESCARTAR
    if any(k in d_low for k in ["regulip", "cáps", "capsulas", "cápsulas"]) or m_low == "raffo":
        return ("Suplemento", "Clásico", "Caja", True)

    # 4. Conservas de pescado/mariscos que quedaron bajo 'Aceite'
    if "atun" in d_low or "atún" in d_low or "atun" in m_low:
        var_atun = "En Aceite con Champiñones" if "champi" in d_low else "En Aceite"
        return ("Atún", var_atun, "Lata", False)
    if "choritos" in d_low:
        return ("Choritos", "En Aceite", "Lata", False)
    if "jurel" in d_low:
        return ("Jurel", "En Aceite", "Lata", False)
    if "pulpitos" in d_low:
        return ("Pulpitos", "En Aceite", "Lata", False)
    if "salmon" in d_low or "salmón" in d_low:
        return ("Salmón en Conserva", "En Aceite", "Lata", False)
    if "sardinela" in d_low or "sardina" in d_low:
        return ("Sardinas", "En Aceite", "Lata", False)
    if "boqueron" in d_low or "boquerón" in d_low:
        return ("Boquerones", "En Aceite", "Frasco", False)
    if "anchoita" in d_low or "anchoa" in d_low:
        return ("Anchoas", "En Aceite", "Frasco", False)

    # 5. Óleo Calcáreo y Aceite para Bebé
    if "calcareo" in d_low or "calcáreo" in d_low:
        return ("Óleo Calcáreo", "Clásico", "Botella", False)
    if any(k in d_low for k in ["bebe", "bebé", "baby", "niños", "ninos", "hora de sue"]) or "baby" in m_low or "johnsons" in m_low:
        var_bebe = "Lavanda" if "lavanda" in d_low or "sue" in d_low else ("Aloe" if "aloe" in d_low else "Clásico")
        return ("Aceite para Bebé", var_bebe, "Botella", False)

    # 6. Bronceadores y Protectores Solares en Aceite
    if any(k in d_low for k in ["bronceador", "solar", "fps", "tanning", "f8", "f15", "f30"]) or m_low in ("cocoa beach", "rayito de sol", "hawaiian tropic", "australian gold"):
        return ("Aceite Bronceador", "Clásico", "Botella", False)

    # 7. Aceites de Cuidado Personal (Capilar, Ducha, Facial, Corporal, Cosmético)
    if any(k in d_low for k in ["capilar", "argan", "argán", "aqua oil", "oleo nutritivo", "reestructurante"]) or m_low in ("pantene", "herbal essences", "il salone", "elvive", "tresemme"):
        var_cap = "Argán" if "argan" in d_low or "argán" in d_low else ("Nutritivo" if "nutritivo" in d_low else "Clásico")
        return ("Aceite Capilar", var_cap, "Botella", False)
    if "ducha" in d_low or "oil cleans" in d_low or m_low in ("eucerin", "cerave"):
        var_ducha = "Lavanda y Arándano" if "lavanda" in d_low else ("PH5" if "ph5" in d_low else "Clásico")
        return ("Aceite de Ducha", var_ducha, "Botella", False)
    if "desmaquillante" in d_low or "limpieza facial" in d_low or "limpieza heartleaf" in d_low or "limpiador facial" in d_low or "vitamidermus" in d_low:
        return ("Aceite Limpiador Facial", "Clásico", "Botella", False)
    if "vaselina" in d_low:
        return ("Vaselina Líquida", "Con Aceite de Coco" if "coco" in d_low else "Clásico", "Botella", False)
    if "body oil" in d_low or "corporal" in d_low or m_low in ("isdin", "ewe", "aliada"):
        if "arbol de te" in d_low or "árbol de té" in d_low or "tea tree" in d_low:
            var_corp = "Árbol de Té"
        elif "almend" in d_low or "alme" in d_low:
            var_corp = "Almendras"
        elif "aloe" in d_low:
            var_corp = "Aloe Vera"
        elif "manzanilla" in d_low or "manz" in d_low:
            var_corp = "Manzanilla"
        elif "cera" in d_low:
            var_corp = "Depilatorio Post-Cera"
        else:
            var_corp = "Clásico"
        return ("Aceite Corporal", var_corp, "Botella", False)

    # 8. Aceites Aromatizantes / Hornillo / Esenciales / Citronella
    if any(k in d_low for k in ["citronella", "citroxan"]):
        return ("Aceite Citronella", "Clásico", "Botella", False)
    if any(k in d_low for k in ["hornillo", "aromatizante", "aromatico", "aromático", "esencial", "ecosmart", "sandalova", "aire de playa", "flores y coco", "verbena", "aceitevainilla", "aceitecitrus"]) or m_low in ("glade", "iluminarte", "ecovita"):
        if "vainilla" in d_low:
            var_ar = "Vainilla"
        elif "lavanda" in d_low:
            var_ar = "Lavanda"
        elif "verbena" in d_low:
            var_ar = "Verbena"
        elif "citrus" in d_low:
            var_ar = "Citrus"
        elif "flores y coco" in d_low:
            var_ar = "Flores y Coco"
        else:
            var_ar = "Clásico"
        return ("Aceite Aromatizante", var_ar, "Botella", False)

    # 9. Rocío Vegetal / Aceite en Aerosol Antiadherente
    if any(k in d_low for k in ["rocio vegetal", "rocío vegetal", "antiadherente", "antiadherent", "aerosol", " aer"]) or m_low == "fritolim" or env_actual == "Aerosol":
        if "manteca" in d_low or "mantec" in d_low:
            var_rv = "Manteca"
        elif "oliva" in d_low:
            var_rv = "Oliva"
        elif "coco" in d_low:
            var_rv = "Coco"
        elif "maiz" in d_low or "maíz" in d_low:
            var_rv = "Maíz"
        else:
            var_rv = "Girasol"
        return ("Rocío Vegetal", var_rv, "Aerosol", False)

    # 10. Aceite Comestible legítimo (Almacén)
    # Envase real por ítem individual:
    if re.search(r"\b(bidon|bidón)\b", d_low):
        env_ac = "Bidón"
    elif re.search(r"\b(lata|lat)\b", d_low) and "vidrio" not in d_low and "botella" not in d_low:
        env_ac = "Lata"
    elif re.search(r"\b(frasco|fco)\b", d_low):
        env_ac = "Frasco"
    elif re.search(r"\b(caja)\b", d_low) and "uni" in d_low:
        env_ac = "Caja"
    else:
        env_ac = "Botella"

    # Variedad real del aceite comestible:
    if "oliva" in d_low or "oliv" in d_low or "olv " in d_low:
        if "extra virgen" in d_low or "extr.virgen" in d_low or "virg.extra" in d_low or "virgen extra" in d_low or "e. virgen" in d_low or "e virgen" in d_low or "ev " in d_low or "ex vir" in d_low or "ext virgen" in d_low:
            if "intenso" in d_low or "fuerte" in d_low or "robusto" in d_low:
                var_ac = "Oliva Extra Virgen Intenso"
            elif "suave" in d_low:
                var_ac = "Oliva Extra Virgen Suave"
            elif "organico" in d_low or "orgánico" in d_low:
                var_ac = "Oliva Extra Virgen Orgánico"
            else:
                var_ac = "Oliva Extra Virgen"
        elif "mezcla" in d_low or "girasol" in d_low or "gira/oliv" in d_low or "canola" in d_low:
            var_ac = "Mezcla con Oliva"
        else:
            var_ac = "Oliva Virgen"
    elif "coco" in d_low:
        var_ac = "Coco Neutro" if "neutro" in d_low else "Coco Virgen"
    elif "canola" in d_low:
        if "ajo" in d_low:
            var_ac = "Canola con Ajo"
        elif "albahaca" in d_low:
            var_ac = "Canola con Albahaca"
        elif "limon" in d_low or "limón" in d_low:
            var_ac = "Canola con Limón"
        else:
            var_ac = "Canola"
    elif "sesamo" in d_low or "sésamo" in d_low:
        var_ac = "Sésamo"
    elif "palta" in d_low:
        var_ac = "Palta"
    elif "maiz" in d_low or "maíz" in d_low:
        var_ac = "Maíz"
    elif "soja" in d_low and "mezcla" not in d_low:
        var_ac = "Soja"
    elif "mezcla" in d_low:
        var_ac = "Mezcla"
    elif "alto oleico" in d_low or "alt oleico" in d_low or "alto omega" in d_low:
        var_ac = "Girasol Alto Oleico"
    else:
        var_ac = "Girasol"

    return ("Aceite", var_ac, env_ac, False)


def normalizar_item(row: pd.Series) -> Tuple[str, str, str, str, str, str, bool]:
    """Devuelve (producto, variedad, envase, contenido, unidad, marca, descartar)."""
    desc = str(row.get("productos_descripcion") or "").strip()
    marca = str(row.get("marca") or row.get("productos_marca") or "").strip()
    prod = str(row.get("producto") or "").strip()
    var = str(row.get("variedad") or "Clásico").strip()
    env = str(row.get("envase") or row.get("presentacion") or "Paquete").strip()
    cont = fmt_num(row.get("contenido_neto") or "1")
    uni = str(row.get("unidad_referencia") or "u").strip().lower()
    d_low = f"{desc} {prod} {var}".lower()
    p_low = prod.lower()

    # 1. Caso especial: ABRELATAS
    if "abrelat" in p_low or "abrelat" in desc.lower():
        prod = "Abrelatas"
        env = "Blister" if "blister" in d_low or "blis" in d_low else "Unidad"
        cont, uni = "1", "u"
        if "mariposa" in d_low or "maringo" in d_low:
            var = "Mariposa"
        elif "perilla" in d_low:
            var = "Con Perilla"
        elif "manija" in d_low:
            var = "A Manija"
        elif "uña" in d_low or "una" in d_low:
            var = "De Uña"
        elif "madera" in d_low:
            var = "Mango de Madera"
        elif "marmol" in d_low or "mármol" in d_low:
            var = "Mango Símil Mármol"
        elif "acero inox" in d_low:
            var = "Acero Inoxidable"
        else:
            var = "Clásico"
        if "jovifel" in d_low and marca.lower() in ("", "sin marca", "generico", "campagna hnos e hijos sa"):
            marca = "Jovifel"
        elif "ilko" in d_low:
            marca = "Ilko"
        return (prod, var, env, cont, uni, marca, False)

    # 2. Caso especial: ABRILLANTADOR
    if p_low == "abrillantador" or "abrillantador" in p_low:
        if "gati" in d_low or "gato" in d_low or marca.lower() == "speedway":
            return ("Abrillantador Automotor", "Clásico", "Botella", cont, uni, marca, True)
        if any(k in d_low for k in ["lavavaj", "maq", "máquina", "automatica", "automática"]) or marca.lower() in ("finish", "sun", "magistral", "rex"):
            return ("Abrillantador para Lavavajillas", "Clásico", "Botella", cont, uni, marca, False)

    # 3. Caso especial: ABSENTA
    if p_low == "absenta":
        return ("Absenta", "Clásico", "Botella", cont, uni, marca, False)

    # 4. Caso especial: ACEITE y derivados
    if "aceite" in p_low:
        prod_ac, var_ac, env_ac, desc_ac = refinar_aceite(desc, marca, prod, var, env)
        return (prod_ac, var_ac, env_ac, cont, uni, marca, desc_ac)

    # 4b. Caso especial: ÓLEO / OLEO (Óleo Calcáreo, Óleo Capilar, Óleo Corporal/Ducha)
    if p_low in ("oleo", "óleo", "oleo calcareo", "óleo calcáreo", "oleo capilar", "óleo capilar"):
        if "calcareo" in d_low or "calcáreo" in d_low:
            if uni == "u" or "toallita" in d_low or "paño" in d_low:
                return ("Toallitas Húmedas", "Óleo Calcáreo", "Paquete", cont, uni, marca, False)
            if "algodon" in d_low or "algodón" in d_low:
                var_oc = "Algodón"
            elif "avena" in d_low:
                var_oc = "Avena"
            elif "almendra" in d_low:
                var_oc = "Almendras"
            elif "palta" in d_low:
                var_oc = "Palta"
            elif "pantenol" in d_low:
                var_oc = "Pantenol"
            elif "sin fragancia" in d_low or "s/frag" in d_low:
                var_oc = "Sin Fragancia"
            elif "hipoalerg" in d_low:
                var_oc = "Hipoalergénico"
            else:
                var_oc = "Clásico"
            return ("Óleo Calcáreo", var_oc, "Botella", cont, "ml" if uni == "g" else uni, marca, False)
        if "capilar" in d_low or any(k in d_low for k in ["bond repair", "extraordinario", "reestructurante", "kerankay", "uv brillo", "elvive", "pantene"]):
            if "bond repair" in d_low:
                var_cap = "Bond Repair"
            elif "extraordinario" in d_low:
                var_cap = "Extraordinario"
            elif "reestructurante" in d_low:
                var_cap = "Reestructurante"
            elif "uv brillo" in d_low:
                var_cap = "UV Brillo"
            else:
                var_cap = "Clásico"
            return ("Óleo Capilar", var_cap, "Frasco" if "frasco" in d_low else "Botella", cont, uni, marca, False)
        if "ducha" in d_low or "limpiador" in d_low:
            return ("Aceite de Ducha", "Clásico", "Botella", cont, uni, marca, False)
        return ("Aceite Corporal", "Clásico", "Botella", cont, uni, marca, False)

    # 5. Caso especial: ACEITUNAS (unificar Aceituna y Aceitunas, y variedades singular/plural)
    if p_low in ("aceituna", "aceitunas"):
        prod = "Aceitunas"
        es_negra = "negra" in d_low
        color = "Negras" if es_negra else "Verdes"
        if "rellena" in d_low:
            var = f"{color} Rellenas"
        elif "rodaja" in d_low or "feteada" in d_low:
            var = f"{color} en Rodajas"
        elif "descarozad" in d_low or "descremada" in d_low or "s/carozo" in d_low or "sin carozo" in d_low:
            var = f"{color} Descarozadas"
        elif "ajo" in d_low:
            var = f"{color} con Ajo"
        elif "ahumad" in d_low:
            var = f"{color} Ahumadas"
        else:
            var = f"{color} con Carozo"
        if any(k in d_low for k in ["frasco", "fco", "vidrio"]):
            env = "Frasco"
        elif any(k in d_low for k in ["balde", "cubeta"]) or (uni == "kg" and float(cont or 0) >= 2):
            env = "Balde"
        elif "lata" in d_low:
            env = "Lata"
        else:
            env = "Doypack" if "doypack" in d_low or "pouch" in d_low else "Paquete"
        return (prod, var, env, cont, uni, marca, False)

    # 6. Resolución de productos polisémicos, genéricos o truncados y descarte de no-supermercado
    prod, var, env, desc_pol1 = resolver_producto_polisemico(prod, var, env, uni, desc, marca)
    if desc_pol1:
        return (prod, var, env, cont, uni, marca, True)
    prod, var, env, desc_pol2 = resolver_polisemia_extra(prod, var, env, uni, desc, marca)
    if desc_pol2:
        return (prod, var, env, cont, uni, marca, True)

    # 6b. Promover subtipo específico a 'producto' (Queso Cremoso, Harina de Trigo, Milanesa de Pollo...)
    prod, var, desc_sub = promover_subtipo_a_producto(prod, var, desc)
    if desc_sub:
        return (prod, var, env, cont, uni, marca, True)

    p_clean = sin_tildes(prod)

    # 7. Separar modificadores incrustados en 'producto' hacia 'variedad' (ej. 'Queso Cremoso', 'Harina de Almendras')
    for prefijo, prod_base in PREFIJOS_PRODUCTO_A_SEPARAR:
        if p_clean.startswith(prefijo) and p_clean != sin_tildes(prod_base):
            resto = prod[len(prefijo):].strip()
            if resto:
                for prep in ("de ", "con ", "para ", "al ", "en "):
                    if resto.lower().startswith(prep):
                        resto = resto[len(prep):].strip()
                if var.lower() in ("clásico", "clasico", "estándar", "estandar", "") or resto.lower() in var.lower():
                    var = resto.title() if var.lower() in ("clásico", "clasico", "estándar", "estandar", "") else var
                else:
                    var = f"{resto.title()} {var}"
            prod = prod_base
            p_clean = sin_tildes(prod)
            break

    # 8. Unificación canónica de sinónimos, tildes y singular/plural
    if p_clean in MAPA_PRODUCTO_CANONICO:
        prod = MAPA_PRODUCTO_CANONICO[p_clean]
    elif prod.lower() in CANONICAL_PRODUCT_MAP:
        prod = CANONICAL_PRODUCT_MAP[prod.lower()]
    p_low = prod.lower()

    # 9. Impedir que utensilios de bazar o artículos no enlatados tengan envase 'Lata' por falso positivo
    if env == "Lata" and not re.search(r"\b(lata|latita|lat)\b", desc.lower()):
        if p_low in utensilios_bazar:
            env = "Unidad"
        elif uni in ("ml", "litro"):
            env = "Botella"
        else:
            env = "Paquete"

    # 10. Inferencia robusta de envase por ítem individual
    env = inferir_envase_robusto(prod, var, env, uni, desc)

    return (prod, var, env, cont, uni, marca, False)


def ejecutar_consolidacion() -> None:
    print("=" * 78)
    print(" CONSOLIDACIÓN TAXONÓMICA Y ESTRUCTURAL ROBUSTA DEL CATÁLOGO")
    print("=" * 78)

    baks_clusters = sorted(CLUSTERS_DIR.glob("producto_clusters.*.bak"))
    baks_items = sorted(CLUSTERS_DIR.glob("producto_cluster_items.*.bak"))
    if baks_clusters and baks_items:
        src_clusters = baks_clusters[0]
        src_items = baks_items[0]
    else:
        sello = datetime.now().strftime("%Y%m%d_%H%M%S")
        src_clusters = CLUSTERS_CSV.with_suffix(f".{sello}.bak")
        src_items = ITEMS_CSV.with_suffix(f".{sello}.bak")
        shutil.copy2(CLUSTERS_CSV, src_clusters)
        shutil.copy2(ITEMS_CSV, src_items)

    items = pd.read_csv(src_items, dtype=str).fillna("")
    clusters = pd.read_csv(src_clusters, dtype=str).fillna("")
    cat = pd.read_csv(CATALOGO_CSV, dtype=str).fillna("").drop_duplicates("id_producto")
    corr = pd.read_csv(CORRECCIONES_CSV, dtype=str).fillna("")

    # Paso 1: Incorporar las 21,680 correcciones del LLM sobre items y clusters
    corr_map = {r["id_producto"]: r for _, r in corr.iterrows()}
    print(f"[*] Correcciones LLM cargadas: {len(corr_map):,}")

    df = items.merge(
        clusters[["cluster_id", "producto", "variedad", "presentacion", "categoria"]],
        on="cluster_id",
        how="left",
    ).merge(
        cat[["id_producto", "productos_descripcion", "productos_marca"]],
        on="id_producto",
        how="left",
    ).fillna("")

    pre_items = []
    conteo_prod: Dict[str, int] = {}
    descartados = 0

    for _, row in df.iterrows():
        ean = row["id_producto"]
        c_llm = corr_map.get(ean)

        if c_llm is not None:
            if str(c_llm.get("descartar", "")).lower() == "true":
                descartados += 1
                continue
            row = row.copy()
            row["producto"] = c_llm.get("producto") or row["producto"]
            row["variedad"] = c_llm.get("variedad") or row["variedad"]
            row["envase"] = c_llm.get("envase") or row["envase"]
            row["contenido_neto"] = c_llm.get("contenido_neto") or row["contenido_neto"]
            row["unidad_referencia"] = c_llm.get("unidad") or row["unidad_referencia"]
            row["marca"] = c_llm.get("marca") or row["marca"]

        prod, var, env, cont, uni, marca, desc_flag = normalizar_item(row)
        if desc_flag:
            descartados += 1
            continue

        if prod.lower() in CANONICAL_PRODUCT_MAP:
            prod = CANONICAL_PRODUCT_MAP[prod.lower()]

        conteo_prod[prod] = conteo_prod.get(prod, 0) + 1
        pre_items.append((ean, row["cluster_id"], row["productos_descripcion"], prod, var, env, cont, uni, marca))

    # Construir diccionario global de pluralización post-normalización (0 pares singular/plural)
    plural_auto_map: Dict[str, str] = {}
    map_low_to_orig = {p.lower(): p for p in conteo_prod}
    for p_low_k, p_orig in list(map_low_to_orig.items()):
        for suf in ("s", "es"):
            pl_low = p_low_k + suf
            if pl_low in map_low_to_orig:
                pl_orig = map_low_to_orig[pl_low]
                ganador = pl_orig if conteo_prod.get(pl_orig, 0) >= conteo_prod.get(p_orig, 0) else p_orig
                plural_auto_map[p_low_k] = ganador
                plural_auto_map[pl_low] = ganador

    nuevos_items = []
    nuevos_clusters: Dict[str, Dict[str, str]] = {}
    reclasificados = 0

    for ean, old_cid, desc_orig, prod, var, env, cont, uni, marca in pre_items:
        p_cl = sin_tildes(prod)
        if p_cl in MAPA_PRODUCTO_CANONICO:
            prod = MAPA_PRODUCTO_CANONICO[p_cl]
        elif prod.lower() in CANONICAL_PRODUCT_MAP:
            prod = CANONICAL_PRODUCT_MAP[prod.lower()]
        elif prod.lower() in plural_auto_map:
            prod = plural_auto_map[prod.lower()]

        if var.lower() == prod.lower() or not var:
            var = "Clásico"

        cat_final = inferir_categoria_robusta(prod, var, desc_orig)
        cid = f"{slug(prod)}_{slug(var)}_{slug(env)}_{cont}{uni}"

        if cid != old_cid:
            reclasificados += 1

        if cid not in nuevos_clusters:
            es_gen = var.lower() in ("clásico", "clasico", "estándar", "estandar") or var.lower() in prod.lower()
            canonico = prod if es_gen else f"{prod} {var}"
            nuevos_clusters[cid] = {
                "cluster_id": cid,
                "producto": prod,
                "variedad": var,
                "presentacion": env,
                "nombre_canonico": canonico,
                "categoria": cat_final,
            }

        nuevos_items.append({
            "id_producto": ean,
            "cluster_id": cid,
            "marca": marca,
            "envase": env,
            "contenido_neto": cont,
            "unidad_referencia": uni,
            "confianza": "1.0",
            "modelo_ia": "consolidacion_taxonomica_llm",
        })

    df_clusters_out = pd.DataFrame(list(nuevos_clusters.values())).sort_values("cluster_id")
    df_items_out = pd.DataFrame(nuevos_items)

    df_clusters_out.to_csv(CLUSTERS_CSV, index=False, encoding="utf-8")
    df_items_out.to_csv(ITEMS_CSV, index=False, encoding="utf-8")

    print(f"[OK] Consolidación completada:")
    print(f"     - Productos descartados (no supermercado): {descartados:,}")
    print(f"     - Productos reclasificados/normalizados:   {reclasificados:,}")
    print(f"     - Total EANs activos finales:              {len(df_items_out):,}")
    print(f"     - Total Clústeres canónicos finales:       {len(df_clusters_out):,}")
    print("\n[*] Distribución por Categoría:")
    print(df_clusters_out["categoria"].value_counts().to_string())


if __name__ == "__main__":
    ejecutar_consolidacion()
