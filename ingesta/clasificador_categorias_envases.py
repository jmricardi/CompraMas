#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Clasificador robusto de categorías, envases y resolución de familias polisémicas.
Insensible a tildes y con límites de palabra estrictos (evita falsos positivos
como 'ron' en 'Turrón'/'Morrón' o 'papa' en 'Papas Fritas').
"""

import re
from typing import Tuple

from reglas_taxonomia import sin_tildes


def resolver_polisemia_extra(
    prod: str, var: str, env: str, uni: str, desc: str, marca: str
) -> Tuple[str, str, str, bool]:
    """Segunda etapa de resolución de productos polisémicos."""
    p_clean = sin_tildes(prod)
    d_clean = sin_tildes(f"{desc} {prod} {var} {marca}")

    if p_clean == "protector":
        if any(k in d_clean for k in ["auditivo", "bucal", "cable", "cortina", "juanete", "callo", "pantalla", "colchon", "voltaje", "tension"]):
            return (prod, var, env, True)
        if "solar" in d_clean or "fps" in d_clean or "spf" in d_clean or "uv" in d_clean or "nivea sun" in d_clean or "dermavan" in d_clean:
            return ("Protector Solar", var, "Botella", False)
        if "termico" in d_clean or "capilar" in d_clean or "cabello" in d_clean:
            return ("Protector Térmico Capilar", var, "Botella", False)
        if "mamario" in d_clean or "lactancia" in d_clean:
            return ("Protectores Mamarios", var, "Caja", False)
        if "labial" in d_clean:
            return ("Bálsamo Labial", var, "Blister", False)
        if "micrones" in d_clean or "escolar" in d_clean or "hoja" in d_clean:
            return ("Folio Escolar", var, "Paquete", False)
        return ("Protectores Diarios", var, "Paquete", False)

    if p_clean in ("barra", "barrita"):
        if "jabon" in d_clean:
            return ("Jabón de Tocador", var, "Paquete", False)
        if "chocolate" in d_clean or "choc " in d_clean or "cacao" in d_clean and "cereal" not in d_clean and "arroz" not in d_clean:
            return ("Chocolate", var, "Paquete", False)
        return ("Barra de Cereal", var, "Paquete", False)

    if p_clean == "polvo":
        if "hornear" in d_clean:
            return ("Polvo para Hornear", var, "Paquete", False)
        if "cacao" in d_clean or "chocolat" in d_clean:
            return ("Cacao en Polvo", var, "Paquete", False)
        if "decolorante" in d_clean or "compacto" in d_clean or "maquillaje" in d_clean:
            return ("Maquillaje", var, "Unidad", False)
        if "limpiador" in d_clean or "lavavajilla" in d_clean or "ropa" in d_clean or "almidon" in d_clean:
            return ("Limpiador en Polvo", var, "Paquete", False)
        if "jugo" in d_clean or "bebida" in d_clean:
            return ("Jugo en Polvo", var, "Sobre", False)
        return ("Premezcla", var, "Paquete", False)

    if p_clean == "pasta":
        if "dental" in d_clean or "diente" in d_clean:
            return ("Pasta Dental", var, "Tubo", False)
        if "aceituna" in d_clean:
            return ("Pasta de Aceitunas", var, "Frasco", False)
        if "mani" in d_clean:
            return ("Pasta de Maní", var, "Frasco", False)
        if "avellana" in d_clean:
            return ("Pasta de Avellanas", var, "Frasco", False)
        if "sesamo" in d_clean or "tahini" in d_clean:
            return ("Pasta de Sésamo", var, "Frasco", False)
        if "berenjena" in d_clean or "babaganoush" in d_clean:
            return ("Pasta de Berenjenas", var, "Frasco", False)
        if "ajo" in d_clean:
            return ("Pasta de Ajo", var, "Frasco", False)
        if "aji" in d_clean:
            return ("Pasta de Ají", var, "Frasco", False)
        if "frola" in d_clean:
            return ("Pastafrola", var, "Paquete", False)
        return ("Fideos", var, "Paquete", False)

    if p_clean in ("maquina", "máquina"):
        if "afeit" in d_clean or "rasur" in d_clean or "gillette" in d_clean or "bic" in d_clean or "schick" in d_clean or "filo" in d_clean:
            return ("Máquina de Afeitar", var, "Blister", False)
        return (prod, var, env, True)

    if p_clean in ("pastillas", "pastilla"):
        if "cloro" in d_clean or "encendido" in d_clean or "fuego" in d_clean:
            return (prod, var, env, True)
        if "inodoro" in d_clean or "mochila" in d_clean:
            return ("Pastilla para Inodoro", var, "Blister", False)
        if "mosquito" in d_clean or "termoevaporable" in d_clean or "raid" in d_clean or "fuyi" in d_clean:
            return ("Pastillas Termoevaporables", var, "Caja", False)
        if "corega" in d_clean or "protesis" in d_clean:
            return ("Limpiador para Prótesis Dental", var, "Caja", False)
        return ("Pastillas", var, "Paquete", False)

    if p_clean == "tableta":
        if "mosquito" in d_clean or "raid" in d_clean or "fuyi" in d_clean:
            return ("Pastillas Termoevaporables", var, "Caja", False)
        if "inodoro" in d_clean:
            return ("Pastilla para Inodoro", var, "Blister", False)
        if "lavavajilla" in d_clean or "finish" in d_clean:
            return ("Jabón para Lavavajillas", var, "Caja", False)
        return ("Chocolate", var, "Paquete", False)

    if p_clean == "paleta":
        if any(k in d_clean for k in ["helad", "agua", "anana", "frutilla", "limon", "chocolate", "crema"]):
            return ("Helado", var, "Paquete", False)
        if "maquillaje" in d_clean or "sombra" in d_clean or "pintura" in d_clean:
            return (prod, var, env, True)
        return ("Paleta de Cerdo", var, "Bandeja", False)

    if p_clean in ("solucion", "solución"):
        if "nebuliz" in d_clean or "inhal" in d_clean:
            return (prod, var, env, True)
        if "lente" in d_clean or "multiaccion" in d_clean or "renu" in d_clean or "opti-free" in d_clean:
            return ("Solución para Lentes de Contacto", var, "Botella", False)
        return ("Solución Fisiológica", var, "Botella", False)

    if p_clean in ("tratamiento", "mascara", "máscara", "mascarilla"):
        if any(k in d_clean for k in ["arlequin", "batman", "spider", "cotillon", "snorkel", "buceo", "soldar"]):
            return (prod, var, env, True)
        if "pestana" in d_clean or "rimel" in d_clean or "maybelline" in d_clean or "vogue" in d_clean:
            return ("Máscara de Pestañas", var, "Unidad", False)
        if "facial" in d_clean or "rostro" in d_clean or "arcilla" in d_clean or "hidratante" in d_clean and "capilar" not in d_clean:
            return ("Mascarilla Facial", var, "Paquete", False)
        return ("Tratamiento Capilar", var, "Pote", False)

    if p_clean == "mix":
        if any(k in d_clean for k in ["berries", "frutos rojos", "frutas congelad", "bosque congelad"]):
            return ("Frutas Congeladas", var, "Paquete", False)
        if any(k in d_clean for k in ["brocoli", "vegetal", "verdura", "primavera", "wok", "sopa", "ensalada", "lechuga", "hojas"]):
            return ("Vegetales", var, "Paquete", False)
        if any(k in d_clean for k in ["marisco", "frutos del mar"]):
            return ("Mariscos", var, "Paquete", False)
        if any(k in d_clean for k in ["especia", "botanico", "pimienta", "curry", "chimichurri"]):
            return ("Condimento", var, "Paquete", False)
        if "semilla" in d_clean:
            return ("Semillas", var, "Paquete", False)
        if "cereal" in d_clean or "granola" in d_clean:
            return ("Cereal", var, "Paquete", False)
        return ("Mix de Frutos Secos", var, "Paquete", False)

    if p_clean == "bebida":
        if any(k in d_clean for k in ["almendra", "avena", "castana", "coco", "soja", "vegetal", "silk", "ades", "tratenfu", "vrink", "biba"]):
            return ("Bebida Vegetal", var, "Cartón (Tetra Brik)", False)
        if "isotonica" in d_clean or "deportiva" in d_clean or "gatorade" in d_clean or "powerade" in d_clean:
            return ("Bebida Isotónica", var, "Botella", False)
        if "energizante" in d_clean or "red bull" in d_clean or "monster" in d_clean or "speed" in d_clean:
            return ("Bebida Energizante", var, "Lata", False)
        if "lactea" in d_clean or "chocolatada" in d_clean or "cacao" in d_clean:
            return ("Leche Chocolatada", var, "Cartón (Tetra Brik)", False)
        return ("Bebida sin Alcohol", var, env, False)

    if p_clean == "espuma":
        if "poliuretano" in d_clean or "carnaval" in d_clean or "nieve" in d_clean:
            return (prod, var, env, True)
        if "bano" in d_clean or "ducha" in d_clean:
            return ("Espuma de Baño", var, "Botella", False)
        if "limpieza" in d_clean or "horno" in d_clean or "tapizado" in d_clean:
            return ("Limpiador", var, "Aerosol", False)
        return ("Espuma de Afeitar", var, "Aerosol", False)

    if p_clean == "spray":
        if "nasal" in d_clean or "bucal" in d_clean or "tirotricina" in d_clean or "herida" in d_clean:
            return (prod, var, env, True)
        if "piojo" in d_clean or "repelente" in d_clean:
            return ("Repelente", var, "Botella", False)
        if "capilar" in d_clean or "cabello" in d_clean or "peinar" in d_clean or "fijador" in d_clean or "alisador" in d_clean:
            return ("Spray Capilar", var, "Aerosol", False)
        if "ambiente" in d_clean or "home" in d_clean:
            return ("Aromatizante de Ambiente", var, "Aerosol", False)
        return ("Body Splash", var, "Botella", False)

    return (prod, var, env, False)


def inferir_envase_robusto(prod: str, var: str, env_actual: str, uni: str, desc: str) -> str:
    """Corrige el envase evaluando producto, unidad y descripción del ítem individual."""
    p = sin_tildes(prod)
    d = sin_tildes(desc)

    # 1. Palabras explícitas en la descripción original del EAN (con límites de palabra)
    if re.search(r"\b(aerosol|aer)\b", d):
        return "Aerosol"
    if re.search(r"\b(doypack|pouch|doy)\b", d):
        return "Doypack"
    if re.search(r"\b(sachet|sach)\b", d):
        return "Sachet"
    if re.search(r"\b(tetra|brik|t\.brik|tbrik)\b", d):
        return "Cartón (Tetra Brik)"
    if re.search(r"\b(bidon)\b", d):
        return "Bidón"
    if re.search(r"\b(frasco|fco)\b", d):
        return "Frasco"
    if re.search(r"\b(pote)\b", d):
        return "Pote"
    if re.search(r"\b(lata|latita|lat)\b", d) and "abrelat" not in d and "chocolat" not in d and "gelat" not in d:
        return "Lata"
    if re.search(r"\b(blister|blis)\b", d):
        return "Blister"
    if re.search(r"\b(bandeja|band)\b", d):
        return "Bandeja"

    # 2. Reglas por familia de producto cuando el envase quedó genérico como 'Paquete'
    if env_actual == "Paquete":
        if p in ("mermelada", "miel", "aceto balsamico", "alcaparras", "pickles", "pasta de mani", "pasta de aceitunas", "pasta de avellanas", "pasta de sesamo", "pasta de berenjenas", "pasta de ajo", "pasta de aji", "cafe instantaneo"):
            return "Frasco"
        if p in ("dulce de leche", "queso crema", "queso untable", "crema de leche", "postre lacteo", "hummus", "cera capilar", "cera depilatoria", "tratamiento capilar", "gel fijador"):
            return "Pote"
        if p in ("atun", "sardinas", "caballa", "jurel", "palmitos", "duraznos en almibar", "anana en almibar", "pate", "picadillo", "tomate en conserva", "choclo en grano", "arvejas", "lentejas", "garbanzos", "porotos") and "remojad" in d:
            return "Lata"
        if p in ("atun", "sardinas", "caballa", "jurel", "palmitos", "duraznos en almibar", "anana en almibar", "pate", "picadillo"):
            return "Lata"
        if p in ("pure de tomate", "bebida vegetal", "leche chocolatada"):
            return "Cartón (Tetra Brik)"
        if p in ("pasta dental", "crema depilatoria"):
            return "Tubo"
        if p in ("tintura capilar", "preservativos", "espirales", "pastillas termoevaporables", "te", "mate cocido", "caldo", "edulcorante") and uni in ("u", "saquitos", "sobres"):
            return "Caja"
        if p in ("escoba", "escobillon", "secador de piso", "mopa", "pala para residuos", "cepillo para cabello", "cepillo de limpieza", "peine", "encendedor", "abrelatas", "espatula", "cuchillo", "cuchara", "pinza", "molde", "tijera", "cuaderno", "carpeta", "boligrafo", "sacapuntas", "resaltador", "lapiz", "chupete", "mamadera", "tetina", "mordillo"):
            return "Unidad"
        if p in ("asado", "bife", "vacio", "matambre", "peceto", "nalga", "tapa de asado", "tapa de nalga", "colita de cuadril", "cuadrada", "roast beef", "lomo vacuno", "lomo de cerdo", "bondiola", "cerdo", "cordero", "pollo", "suprema", "pechuga", "carne", "chorizo", "morcilla", "paleta de cerdo"):
            return "Bandeja"
        if p in ("papa", "cebolla", "tomate", "lechuga", "zanahoria", "zapallo", "espinaca", "acelga", "morron", "ajo", "apio", "brocoli", "coliflor", "chaucha", "berenjena", "pepinos", "remolacha", "batata", "manzana", "banana", "naranja", "pera", "mandarina", "duraznos", "uva", "limon", "lima", "pomelo", "melon", "kiwi", "ciruelas", "frutilla", "arandanos", "frambuesas", "cerezas"):
            return "Granel" if uni == "kg" else "Bandeja"

    return env_actual


def inferir_categoria_robusta(prod: str, var: str, desc: str) -> str:
    """Clasifica la categoría con límites de palabra sobre texto sin tildes."""
    p = sin_tildes(prod)
    v = sin_tildes(var)
    d = sin_tildes(desc)

    # 1. Bebés y Maternidad
    if re.search(
        r"\b(panal|panales|oleo calcareo|mamadera|chupete|tetina|mordillo|babero|"
        r"leche infantil|aceite para bebe|colonia para bebe|shampoo para bebe|"
        r"protectores mamarios|papilla)\b",
        p,
    ) or (p == "toallitas humedas" and re.search(r"\b(bebe|baby|huggies|pampers|estrella|johnson|qsoft)\b", f"{v} {d}")):
        return "Bebés y Maternidad"

    # 2. Mascotas
    if re.search(
        r"\b(perro|perros|gato|gatos|mascota|mascotas|piedras sanitarias|comedero|"
        r"pipeta|pretal|alimento balanceado)\b",
        f"{p} {v}",
    ) or p in ("piedras", "comedero", "collar", "correa", "hueso"):
        if p == "hueso" and any(k in f"{v} {d}" for k in ["caldo", "carne", "falda", "jamon", "osobuco", "novillo", "cerdo"]):
            return "Frescos"
        return "Mascotas"

    # 3. Librería
    if re.search(
        r"\b(cuaderno|carpeta|lapiz|lapicera|boligrafo|marcador|resaltador|tempera|"
        r"acuarela|sacapuntas|goma de borrar|regla|compas|cartuchera|cinta adhesiva|"
        r"adhesivo|plasticola|voligoma|folio escolar|repuesto de hojas|papel glace|"
        r"corrector|libreria|tinta)\b",
        p,
    ):
        return "Librería"

    # 4. Limpieza (evaluar ANTES de Cuidado Personal para 'desodorante de ambiente', 'jabón para ropa', 'jabón en polvo')
    if re.search(
        r"\b(lavandina|detergente|limpiador|desinfectante|jabon para ropa|jabon liquido para ropa|"
        r"jabon en polvo|jabon de lavar|jabon para lavavajillas|lavavajilla|suavizante|"
        r"quitamanchas|abrillantador|lustramuebles|cera para pisos|insecticida|repelente|"
        r"hormiguicida|espirales|pastillas termoevaporables|aromatizante|aromatizador|"
        r"ambientador|desodorante de ambiente|difusor aromatico|sahumerio|aceite aromatizante|"
        r"aceite citronella|papel higienico|rollo de cocina|servilletas de papel|"
        r"panuelos descartables|toallitas desinfectantes|esponja|pano de limpieza|"
        r"rejilla|trapo de piso|escoba|escobillon|secador de piso|mopa|balde|"
        r"pala para residuos|guantes de limpieza|bolsas de residuo|destapacanerias|"
        r"pastilla para inodoro|canasta para inodoro|antihumedad|absorbedor de humedad|"
        r"absorbedor de olores|broche para ropa|cepillo de limpieza|pomada para calzado)\b",
        p,
    ):
        return "Limpieza"

    # 5. Cuidado Personal
    if re.search(
        r"\b(shampoo|acondicionador|desodorante|jabon de tocador|jabon liquido|jabon intimo|"
        r"jabon facial|crema corporal|crema facial|crema para manos|crema para peinar|"
        r"crema depilatoria|cera depilatoria|cera capilar|pasta dental|crema dental|"
        r"cepillo dental|hilo dental|enjuague bucal|limpiador para protesis dental|"
        r"tintura|coloracion|tratamiento capilar|mascara capilar|mascarilla facial|"
        r"mascara de pestanas|maquillaje|labial|balsamo|esmalte de unas|quitaesmalte|"
        r"lima de unas|toallitas femeninas|protectores diarios|tampones|toallitas humedas|"
        r"algodon|alcohol|apositos|curitas|gasas|solucion fisiologica|"
        r"solucion para lentes de contacto|barbijo|afeitadora|maquina de afeitar|"
        r"repuesto de afeitadora|espuma de afeitar|espuma de bano|gel de ducha|"
        r"gel fijador|gel capilar|gel corporal|gel intimo|spray capilar|protector termico capilar|"
        r"perfume|colonia|body splash|locion corporal|serum facial|agua micelar|"
        r"agua oxigenada|protector solar|aceite bronceador|bronceador|aceite corporal|"
        r"aceite capilar|oleo capilar|aceite de ducha|aceite limpiador facial|"
        r"preservativos|talco|hisopos|peine|cepillo para cabello|exfoliante|emulsion|pomada)\b",
        p,
    ):
        return "Cuidado Personal"

    # 6. Bebidas (con límites de palabra estrictos: evita 'ron' en 'Turrón'/'Morrón')
    if re.search(
        r"\b(vino|cerveza|gaseosa|agua mineral|agua saborizada|agua tonica|agua con gas|"
        r"agua sin gas|jugo|limonada|soda|aperitivo|fernet|licor|whisky|vodka|gin|ron|"
        r"tequila|absenta|aguardiente|sidra|champagne|espumante|energizante|"
        r"bebida isotonica|bebida energizante|bebida vegetal|bebida sin alcohol|"
        r"leche chocolatada)\b",
        p,
    ):
        return "Bebidas"

    # 7. Lácteos y Frescos
    if re.search(
        r"\b(leche|yogur|manteca|margarina|crema de leche|queso|mozzarella|ricota|"
        r"dulce de leche|postre lacteo|flan|actimel|leche fermentada|huevos|"
        r"tapas de empanadas|tapas de tarta|masa para tarta|masa para empanadas|levadura)\b",
        p,
    ) and p not in ("queso vegetal", "leche de coco", "queso de cerdo"):
        return "Lácteos y Frescos"

    # 8. Frescos (Carnicería, Granja, Pescadería, Fiambrería, Frutas y Verduras frescas)
    # Excluir snacks y conservas de almacén ('papas fritas', 'pure de tomate', 'salsa de tomate', 'tomate en conserva', 'tomate triturado', 'duraznos en almibar', 'anana en almibar')
    if not p.startswith(("semillas", "mix de semillas", "harina")) and p not in (
        "papas fritas", "pure de tomate", "salsa de tomate", "tomate en conserva",
        "tomate triturado", "pure de papas", "duraznos en almibar", "anana en almibar",
        "atun", "sardinas", "caballa", "jurel", "aceitunas", "alcaparras", "pickles",
    ) and re.search(
        r"\b(carne|asado|bife|vacio|matambre|peceto|nalga|tapa de asado|tapa de nalga|"
        r"colita de cuadril|cuadril|cuadrada|roast beef|lomo vacuno|lomo de cerdo|"
        r"bondiola|cerdo|cordero|churrasco|carnaza|osobuco|entrana|pollo|suprema|"
        r"pechuga|patamuslo|alitas|achuras|chinchulin|molleja|rinon|lengua|mondongo|"
        r"milanesa|hamburguesas|medallon|nuggets|salchichas|chorizo|morcilla|longaniza|"
        r"salamin|salame|salchichon|jamon cocido|jamon crudo|mortadela|lomito|panceta|"
        r"paleta de cerdo|fiambre|pescado|filet|filete|merluza|salmon|calamar|"
        r"langostino|mejillones|mariscos|papa|papas prefritas congeladas|cebolla|"
        r"tomate|lechuga|zanahoria|zapallo|espinaca|acelga|morron|apio|brocoli|"
        r"coliflor|chaucha|berenjena|pepinos|remolacha|batata|choclo|perejil|"
        r"albahaca|rúcula|rucula|radicheta|puerro|verdeo|akusay|repollito|repollo|"
        r"champinones|hongos|vegetales|frutas congeladas|manzana|banana|naranja|"
        r"pera|mandarina|duraznos|uva|limon|lima|pomelo|melon|sandia|kiwi|ciruelas|"
        r"frutilla|arandanos|frambuesas|cerezas|palta|anana|mango)\b",
        p,
    ):
        return "Frescos"

    # 9. Bazar y Hogar
    if re.search(
        r"\b(abrelatas|destapador|pelapapas|rallador|cuchillo|tenedor|cuchara|cucharita|"
        r"espatula|colador|sacacorchos|pisapapas|batidor|pinza|molde|tijera|encendedor|"
        r"pilas|pila|velas|vela|lampara|foco|papel aluminio|papel film|papel manteca|"
        r"escarbadientes|palillos)\b",
        p,
    ):
        return "Bazar y Hogar"

    return "Almacén"



def promover_subtipo_a_producto(prod: str, var: str, desc: str) -> Tuple[str, str, bool]:
    """
    Promueve el subtipo de producto desde 'variedad' o 'descripcion' hacia 'producto'
    cuando el producto base por sí solo es demasiado general ('Queso', 'Harina',
    'Semillas', 'Milanesa', 'Medallón', 'Filet'), dejando en 'variedad' el formato,
    corte o atributo ('En Fetas', 'En Hebras', 'Por Peso', 'Light', '000', '0000', etc.).
    """
    p_cl = sin_tildes(prod)
    v_cl = sin_tildes(var)
    d_cl = sin_tildes(f"{prod} {var} {desc}")

    # 1. QUESOS: 'Queso Cremoso', 'Queso Azul', 'Queso Port Salut', 'Queso Muzzarella', etc.
    if p_cl.startswith("queso") or p_cl in ("mozzarella", "muzzarella"):
        tipos_queso = [
            ("queso de cerdo", "Queso de Cerdo"),
            ("vegetal", "Queso Vegetal"),
            ("fondue", "Queso Fondue"),
            ("cremoso", "Queso Cremoso"),
            ("crem", "Queso Cremoso"),
            ("port salut", "Queso Port Salut"),
            ("por salut", "Queso Port Salut"),
            ("p.salud", "Queso Port Salut"),
            ("po sal", "Queso Port Salut"),
            ("p/salu", "Queso Port Salut"),
            ("saint paulin", "Queso Saint Paulin"),
            ("st paulin", "Queso Saint Paulin"),
            ("burrata", "Queso Burrata"),
            ("burratina", "Queso Burrata"),
            ("bufala", "Queso Muzzarella de Búfala"),
            ("bocconcino", "Queso Muzzarella"),
            ("muzzarella", "Queso Muzzarella"),
            ("mozzarella", "Queso Muzzarella"),
            ("azul", "Queso Azul"),
            ("blue", "Queso Azul"),
            ("roquefort", "Queso Azul"),
            ("sardo", "Queso Sardo"),
            ("reggianito", "Queso Reggianito"),
            ("reggiano", "Queso Reggianito"),
            ("parmesano", "Queso Parmesano"),
            ("parmigiano", "Queso Parmesano"),
            ("grana padano", "Queso Grana Padano"),
            ("pecorino", "Queso Pecorino"),
            ("pepato", "Queso Pepato"),
            ("canestrato", "Queso Canestrato"),
            ("pategras", "Queso Pategrás"),
            ("holanda", "Queso Pategrás"),
            ("provoleta", "Queso Provoleta"),
            ("provola", "Queso Provoleta"),
            ("provolone", "Queso Provolone"),
            ("tybo", "Queso Tybo"),
            ("barra", "Queso Tybo"),
            ("danbo", "Queso Danbo"),
            ("dambo", "Queso Danbo"),
            ("gouda", "Queso Gouda"),
            ("edam", "Queso Edam"),
            ("cheddar", "Queso Cheddar"),
            ("brie", "Queso Brie"),
            ("briette", "Queso Brie"),
            ("camembert", "Queso Camembert"),
            ("camembertino", "Queso Camembert"),
            ("reblochon", "Queso Reblochon"),
            ("fontina", "Queso Fontina"),
            ("gruyere", "Queso Gruyere"),
            ("emmental", "Queso Emmental"),
            ("mascarpone", "Queso Mascarpone"),
            ("fynbo", "Queso Fynbo"),
            ("sbrinz", "Queso Sbrinz"),
            ("raclette", "Queso Raclette"),
            ("tetilla", "Queso Tetilla"),
            ("cottage", "Queso Cottage"),
            ("feta", "Queso Feta"),
            ("cabra", "Queso de Cabra"),
            ("oveja", "Queso de Oveja"),
            ("tandil", "Queso de Tandil"),
            ("atuel", "Queso Atuel"),
            ("banquete", "Queso Banquete"),
            ("capricho", "Queso Capricho"),
            ("casciotta", "Queso Casciotta"),
            ("chaource", "Queso Chaource"),
            ("chacroux", "Queso Chaource"),
            ("farcell", "Queso Farcell"),
            ("fiambrin", "Queso Fiambrín"),
            ("san simon", "Queso San Simón"),
            ("stracciatella", "Queso Stracciatella"),
            ("swiss", "Queso Suizo"),
            ("vacheroleau", "Queso Vacheroleau"),
            ("requeijao", "Queso Requeijão"),
            ("requeijao", "Queso Requeijão"),
            ("romano", "Queso Romano"),
            ("criollo", "Queso Criollo"),
            ("cuartirolo", "Queso Cuartirolo"),
            ("fresco", "Queso Fresco"),
            ("untable", "Queso Untable"),
            ("unt", "Queso Untable"),
            ("crematto", "Queso Untable"),
            ("finlandia", "Queso Untable"),
            ("crema", "Queso Crema"),
            ("blanco", "Queso Blanco"),
            ("fundido", "Queso Fundido"),
            ("procesado", "Queso Fundido"),
            ("rallado", "Queso Rallado"),
            ("hilado", "Queso Hilado"),
            ("hebras", "Queso Hilado"),
            ("saborizado", "Queso Saborizado"),
            ("especiado", "Queso Saborizado"),
            ("pimentino", "Queso Saborizado"),
            ("sabor", "Queso Saborizado"),
            ("pesto", "Queso Saborizado"),
            ("finas hierbas", "Queso Saborizado"),
            ("eneldo", "Queso Saborizado"),
            ("pimienta", "Queso Saborizado"),
            ("maduro", "Queso Semiduro"),
            ("semicurado", "Queso Semiduro"),
            ("semi curado", "Queso Semiduro"),
            ("tierno", "Queso Semiduro"),
            ("de campo", "Queso Semiduro"),
        ]
        prod_q = prod if p_cl != "mozzarella" else "Queso Muzzarella"
        for kw, canon_q in tipos_queso:
            if re.search(rf"\b{kw}\b", d_cl):
                prod_q = canon_q
                break

        # Extraer variedad de corte/formato/atributo ('En Fetas', 'En Hebras', 'Por Peso', 'Light', etc.)
        attrs = []
        if re.search(r"\b(fetas|feteado|feteada)\b", d_cl):
            attrs.append("En Fetas")
        elif re.search(r"\b(hebras|hilado)\b", d_cl) and prod_q != "Queso Hilado":
            attrs.append("En Hebras")
        elif re.search(r"\b(rallado)\b", d_cl) and prod_q != "Queso Rallado":
            attrs.append("Rallado")
        elif re.search(r"\b(horma)\b", d_cl):
            attrs.append("Horma")
        elif re.search(r"\b(trozado|trozo|fraccionado|cuno|cuna)\b", d_cl):
            attrs.append("Por Peso")

        if re.search(r"\b(light|magro|bajas calorias)\b", d_cl):
            attrs.append("Light")
        if re.search(r"\b(sin lactosa|deslactosado)\b", d_cl):
            attrs.append("Sin Lactosa")
        if re.search(r"\b(sin sal)\b", d_cl):
            attrs.append("Sin Sal")
        if re.search(r"\b(ahumado|ahumada)\b", d_cl):
            attrs.append("Ahumado")

        if attrs:
            var_q = " ".join(attrs)
        else:
            palabras_tipo = set(sin_tildes(prod_q).split()) | {"queso", "de", "en", "fetas", "feta", "hebras"}
            resto = [w for w in var.split() if sin_tildes(w) not in palabras_tipo]
            var_q = " ".join(resto).strip() or "Clásico"
        return (prod_q, var_q or "Clásico", False)

    # 2. HARINAS: 'Harina de Trigo', 'Harina de Almendras', 'Harina de Maíz', etc.
    if p_cl.startswith("harina"):
        tipos_harina = [
            ("almendra", "Harina de Almendras"),
            ("arroz", "Harina de Arroz"),
            ("avena", "Harina de Avena"),
            ("centeno", "Harina de Centeno"),
            ("coco", "Harina de Coco"),
            ("garbanzo", "Harina de Garbanzos"),
            ("algarroba", "Harina de Algarroba"),
            ("chia", "Harina de Chía"),
            ("lino", "Harina de Lino"),
            ("sesamo", "Harina de Sésamo"),
            ("quinoa", "Harina de Quinoa"),
            ("mandioca", "Harina de Mandioca"),
            ("soja", "Harina de Soja"),
            ("arveja", "Harina de Arvejas"),
            ("castana", "Harina de Castañas"),
            ("amaranto", "Harina de Amaranto"),
            ("maiz", "Harina de Maíz"),
            ("trigo", "Harina de Trigo"),
        ]
        prod_h = "Harina de Trigo" if p_cl == "harina" else prod
        for kw, canon_h in tipos_harina:
            if kw in d_cl:
                prod_h = canon_h
                break
        if "0000" in d_cl:
            var_h = "0000"
        elif "000" in d_cl:
            var_h = "000"
        elif "leudante" in d_cl:
            var_h = "Leudante"
        elif "integral" in d_cl:
            var_h = "Integral"
        else:
            var_h = var if sin_tildes(var) not in sin_tildes(prod_h) else "Clásico"
        return (prod_h, var_h or "Clásico", False)

    # 3. SEMILLAS: 'Semillas de Chía', 'Semillas de Girasol', 'Semillas de Lino', etc.
    if p_cl.startswith("semilla"):
        if any(k in d_cl for k in ["clavelina", "conejito", "dama de noche", "flores", "cesped", "huerta", "acelga", "achicoria", "apio"]):
            return (prod, var, True)
        tipos_sem = [
            ("chia", "Semillas de Chía"),
            ("girasol", "Semillas de Girasol"),
            ("lino", "Semillas de Lino"),
            ("sesamo", "Semillas de Sésamo"),
            ("amapola", "Semillas de Amapola"),
            ("quinoa", "Semillas de Quinoa"),
            ("zapallo", "Semillas de Zapallo"),
            ("mijo", "Semillas de Mijo"),
            ("amaranto", "Semillas de Amaranto"),
        ]
        for kw, canon_s in tipos_sem:
            if kw in d_cl:
                var_s = "Peladas" if "pelad" in d_cl else ("Tostadas" if "tostad" in d_cl else "Clásico")
                return (canon_s, var_s, False)
        return ("Mix de Semillas", var if var.lower() != "clásico" else "Clásico", False)

    # 4. MILANESAS, MEDALLONES y FILETS DE PESCADO
    if p_cl.startswith("milanesa"):
        if any(k in d_cl for k in ["not chicken", "not mila", "the not co", "base d/plant", "vegetal"]):
            return ("Milanesa Vegetal", var, False)
        if "cordero" in d_cl:
            return ("Milanesa de Cordero", var, False)
        if "pescado" in d_cl or "mercado del mar" in d_cl:
            return ("Milanesa de Pescado", var, False)
        if "napolitana" in d_cl or "papas fritas" in d_cl or "guarnicion" in d_cl:
            return ("Milanesa Preparada", var, False)
        if any(k in d_cl for k in ["mix vegetal", "5 vegetal", "vegetales"]):
            return ("Milanesa de Vegetales", var, False)
        if "garbanzo" in d_cl:
            return ("Milanesa de Garbanzos", var, False)
        if "lenteja" in d_cl:
            return ("Milanesa de Lentejas", var, False)
        if "mijo" in d_cl:
            return ("Milanesa de Mijo", var, False)
        if "quinoa" in d_cl:
            return ("Milanesa de Quinoa", var, False)
        if "arroz" in d_cl:
            return ("Milanesa de Arroz", var, False)
        if "brocoli" in d_cl:
            return ("Milanesa de Brócoli", var, False)
        if "jamon" in d_cl:
            return ("Milanesa de Cerdo", "Jamón Redondo", False)
        for kw, canon_m in [
            ("soja", "Milanesa de Soja"), ("pollo", "Milanesa de Pollo"),
            ("merluza", "Milanesa de Merluza"), ("cerdo", "Milanesa de Cerdo"),
            ("nalga", "Milanesa de Nalga"), ("peceto", "Milanesa de Peceto"),
            ("bola de lomo", "Milanesa de Bola de Lomo"), ("bola lomo", "Milanesa de Bola de Lomo"),
            ("cuadrada", "Milanesa de Cuadrada"), ("lomo", "Milanesa de Carne"),
            ("ternera", "Milanesa de Carne"), ("milancito", "Milanesa de Carne"),
            ("carne", "Milanesa de Carne"),
            ("berenjena", "Milanesa de Berenjena"), ("verengena", "Milanesa de Berenjena"),
            ("calabaza", "Milanesa de Calabaza"),
            ("espinaca", "Milanesa de Espinaca"), ("arveja", "Milanesa de Arveja"),
        ]:
            if kw in d_cl:
                var_m = var if sin_tildes(var) not in sin_tildes(canon_m) else "Clásico"
                return (canon_m, var_m or "Clásico", False)
        return ("Milanesa de Carne", var if var.lower() != "clásico" else "Clásico", False)

    if p_cl.startswith("medall"):
        if "durazno" in d_cl:
            return ("Helado", "Durazno", False)
        if any(k in d_cl for k in ["notburger", "not burger", "plant burger", "plantario", "falafel", "curry", "burrito", "tabbule", "base proteica"]):
            return ("Medallón Vegetal", var, False)
        if "salmon" in d_cl:
            return ("Medallón de Salmón", var, False)
        if "boga" in d_cl:
            return ("Medallón de Pescado", "Boga", False)
        if "pescado" in d_cl:
            return ("Medallón de Pescado", var, False)
        if "poroto" in d_cl:
            return ("Medallón de Porotos", var, False)
        if "aduki" in d_cl:
            return ("Medallón de Aduki", var, False)
        if "zanahoria" in d_cl:
            return ("Medallón de Zanahoria", var, False)
        if "verdura" in d_cl:
            return ("Medallón de Verduras", var, False)
        if "peceto" in d_cl:
            return ("Medallón de Carne", "Peceto", False)
        if "jamon" in d_cl:
            return ("Medallón de Cerdo", "Jamón", False)
        for kw, canon_md in [
            ("pollo", "Medallón de Pollo"), ("chicken", "Medallón de Pollo"),
            ("merluza", "Medallón de Merluza"), ("cerdo", "Medallón de Cerdo"),
            ("soja", "Medallón de Soja"), ("espinaca", "Medallón de Espinaca"),
            ("garbanzo", "Medallón de Garbanzos"), ("lenteja", "Medallón de Lentejas"),
            ("quinoa", "Medallón de Quinoa"), ("calabaza", "Medallón de Calabaza"),
            ("arveja", "Medallón de Arveja"), ("carne", "Medallón de Carne"),
            ("bife", "Medallón de Carne"), ("lomo", "Medallón de Carne"),
        ]:
            if kw in d_cl:
                var_md = "Rebozado" if "rebozad" in d_cl else (var if sin_tildes(var) not in sin_tildes(canon_md) else "Clásico")
                return (canon_md, var_md or "Clásico", False)
        return ("Medallón de Carne", var if var.lower() != "clásico" else "Clásico", False)

    if p_cl.startswith("filet"):
        if "anchoa" in d_cl:
            return ("Anchoas", "En Aceite" if "aceite" in d_cl else "Clásico", False)
        for kw, canon_f in [
            ("merluza", "Filet de Merluza"), ("abadejo", "Filet de Abadejo"),
            ("brotola", "Filet de Brótola"), ("boga", "Filet de Boga"),
            ("gatuzo", "Filet de Gatuzo"), ("lenguado", "Filet de Lenguado"),
            ("salmon", "Filet de Salmón"), ("trucha", "Filet de Trucha"),
            ("surubi", "Filet de Surubí"), ("corvina", "Filet de Corvina"),
            ("dorado", "Filet de Dorado"), ("bacalao", "Filet de Bacalao"),
            ("pollo de mar", "Filet de Pescado"), ("pescado", "Filet de Pescado"),
            ("pechuga", "Filet de Pollo"), ("muslo", "Filet de Pollo"),
        ]:
            if kw in d_cl:
                var_f = "A la Romana" if "romana" in d_cl else ("Rebozado" if "rebozad" in d_cl or "empanad" in d_cl else ("Congelado" if "congelad" in d_cl else "Clásico"))
                return (canon_f, var_f, False)
        return ("Filet de Pescado", var if var.lower() != "clásico" else "Clásico", False)

    return (prod, var, False)
