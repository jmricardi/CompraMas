#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
filtro_fmcg.py
---------------
Filtro de Dominio de Consumo Masivo / Supermercado (FMCG).

Garantiza que la base de datos de CompraMás contenga exclusivamente:
- Alimentos y Bebidas
- Limpieza del Hogar
- Cuidado Personal, Higiene y Perfumería
- Librería, Escolares y Papelería

Descarta categorías no deseadas de hipermercados:
- Juguetes y Juegos
- Jardinería y Vivero
- Muebles y Colchones
- Electrónica, Telefonía y Electrodomésticos
- Textil, Ropa, Calzado y Blanquería
- Marroquinería, Bolsos y Valijas
- Fármacos / Medicamentos de Farmacia
- Bazar pesado, Ferretería y Rodados
"""

import re
import unicodedata

def normalizar_para_filtro(texto: str) -> str:
    if not texto:
        return ""
    texto = texto.strip().lower()
    texto = "".join(
        c for c in unicodedata.normalize("NFD", texto)
        if unicodedata.category(c) != "Mn"
    )
    return re.sub(r'[^a-z0-9\s]', ' ', texto)

# -------------------------------------------------------------------------
# PALABRAS CLAVE QUE DELATAN ARTÍCULOS QUE NO SON DE SUPERMERCADO
# -------------------------------------------------------------------------

PATRONES_EXCLUSION = [
    # 1. Juguetes y Juegos
    r'\bjuguete\b', r'\bjuguetes\b', r'\bmuneco\b', r'\bmunecos\b',
    r'\bmuneca\b', r'\bmunecas\b', r'\bautito\b', r'\bautitos\b',
    r'\bpeluche\b', r'\bpeluches\b', r'\bjuego de mesa\b', r'\bpista de auto\b',
    r'\bbarbie\b', r'\blego\b', r'\bfigura de accion\b', r'\bpistola de agua\b',
    r'\brompecabezas\b', r'\bslime\b', r'\bmasa para modelar\b', r'\bcotillon\b',
    r'\bzombie\b', r'\bkittens\b',

    # 2. Jardinería y Vivero
    r'\bmaceta\b', r'\bmacetas\b', r'\btierra fertil\b', r'\btierra abonada\b',
    r'\bfertilizante para planta\b', r'\bsustrato\b', r'\bmanguera de riego\b',
    r'\bregadera\b', r'\bpodadora\b', r'\bcortadora de cesped\b',
    r'\bsemillas de cesped\b', r'\brastrillo\b', r'\bguantes de jardin\b',

    # 3. Muebles y Colchonería
    r'\bmueble\b', r'\bmuebles\b', r'\bmesa de plastico\b', r'\bmesa ratona\b',
    r'\bmesa plegable\b', r'\bmesa de luz\b', r'\bmesa comedor\b',
    r'\bsilla plegable\b', r'\bsilla de plastico\b', r'\bsillon\b', r'\bsillones\b',
    r'\bestanteria\b', r'\bestanterias\b', r'\bplacard\b', r'\bplacares\b',
    r'\bescritorio\b', r'\bcomoda\b', r'\bmodular\b', r'\bbahiut\b',
    r'\bcolchon\b', r'\bsommier\b', r'\balmohada\b', r'\breposera\b',

    # 4. Electrónica, Telefonía y Electrodomésticos
    r'\bcelular\b', r'\bcelulares\b', r'\bsmartphone\b', r'\bsmartwatch\b',
    r'\btelevisor\b', r'\btelevisores\b', r'\btv\b', r'\btv led\b', r'\btv smart\b', r'\bsmart tv\b',
    r'\bauricular\b', r'\bauriculares\b',
    r'\btablet\b', r'\bnotebook\b', r'\bparlante bluetooth\b', r'\bcargador usb\b',
    r'\bfunda para celular\b', r'\bventilador\b', r'\bestufa\b', r'\bpava electrica\b',
    r'\blicuadora\b', r'\btostadora\b', r'\bmicroondas\b', r'\blavarropas\b',
    r'\bsecarropas\b', r'\bheladera\b', r'\bfreezer\b', r'\bcaloventor\b',
    r'\baire acondicionado\b', r'\bfreidora de aire\b', r'\bair fryer\b',
    r'\bhorno electrico\b', r'\bbatidora\b', r'\bprocesadora\b', r'\bcafetera electrica\b',

    # 5. Medicamentos y Fármacos Éticos (con receta / dosis activa)
    r'\bcomprimido\b', r'\bcomprimidos\b', r'\bcomp\b', r'\bampolla\b', r'\bampollas\b',
    r'\bantibiotico\b', r'\bantibioticos\b',
    r'\binyectable\b', r'\binyectables\b', r'\bansiolitico\b', r'\bclonazepam\b',
    r'\bamoxicilina\b', r'\bibuprofeno 600\b', r'\bibuprofeno 800\b',
    r'\bparacetamol 1g\b', r'\blosartan\b', r'\batorvastatina\b', r'\benalapril\b',
    r'\bgotas oftalmicas\b', r'\bcolirio\b', r'\bprospecto\b', r'\bventa bajo receta\b',
    r'\bcapsula\b(?!\s*(?:de\s+)?cafe)', r'\bcapsulas\b(?!\s*(?:de\s+)?cafe)',

    # 6. Textil, Indumentaria, Ropa Interior y Calzado
    r'\bremera\b', r'\bremeras\b', r'\bpantalon\b', r'\bpantalones\b',
    r'\bboxer\b', r'\bboxers\b', r'\bbombacha\b', r'\bbombachas\b',
    r'\bpanty\b', r'\bpantys\b', r'\bcalzoncillo\b', r'\bcalzoncillos\b',
    r'\bcampera\b', r'\bcamperas\b', r'\bshort deportivo\b', r'\bshorts\b',
    r'\bzapatilla\b', r'\bzapatillas\b', r'\bzapa\b', r'\bzapas\b', r'\bzapato\b', r'\bzapatos\b',
    r'\bzueco\b', r'\bzuecos\b', r'\bcrocs\b', r'\balpargata\b', r'\balpargatas\b',
    r'\bbota\b', r'\bbotas\b', r'\bbotita\b', r'\bbotitas\b', r'\bmocasin\b', r'\bmocasines\b',
    r'\bpantufla\b', r'\bpantuflas\b', r'\bchinela\b', r'\bchinelas\b',
    r'\bsandalia\b', r'\bsandalias\b', r'\bojota\b', r'\bojotas\b',
    r'\bmedia\b(?!\s*crema|\s*tarde|\s*luna)',
    r'\bmedias\b', r'\bsoquete\b', r'\bsoquetes\b', r'\bzoquete\b', r'\bzoquetes\b',
    r'\bcorpino\b', r'\bcorpinos\b', r'\btanga\b', r'\btangas\b',
    r'\bpijama\b', r'\bpijamas\b', r'\bcamisa\b', r'\bcamisas\b',
    r'\bbuzo\b', r'\bbuzos\b', r'\bbikini\b', r'\bbikinis\b',
    r'\bmalla de bano\b', r'\bmusculosa\b', r'\bmusculosas\b',
    r'\bcalza\b', r'\bcalzas\b', r'\bvestido\b', r'\bvestidos\b',
    r'\bpolera\b', r'\bchalina\b', r'\bbufanda\b', r'\bcorbata\b',
    r'\bsabana\b', r'\bsabanas\b', r'\bacolchado\b', r'\bfrazada\b',
    r'\bcortina de bano\b', r'\btoalla y toallon\b', r'\bzalea\b', r'\bzaleas\b',

    # 7. Marroquinería, Bolsos, Rodados y Viaje
    r'\bbandolera\b', r'\bbandoleras\b',
    r'\bcartera\b', r'\bcarteras\b', r'\bbilletera\b', r'\bbilleteras\b',
    r'\bmonedero\b', r'\bvalija\b', r'\bvalijas\b', r'\bparaguas\b',
    r'\bbicicleta\b', r'\bmonopatin\b',

    # 8. Libros y Editoriales (Excluyendo útiles de librería)
    r'\blibro\b(?!\s*para colorear|\s*infantil)', r'\blibros\b',
    r'\bnovela\b', r'\bnovelas\b', r'\beditorial planeta\b', r'\beditorial atlantida\b',

    # 9. Bazar, Vajilla, Cristalería y Recipientes Permanentes (No descartables)
    r'\bazucarera\b', r'\byerbera\b', r'\bespeciero\b', r'\bsalero\b', r'\bpimentero\b', r'\baceitera\b',
    r'\blata\s+(?:para|de)?\s*(?:azucar|yerba|galletitas|cafe)\b',
    r'\blata\s+hava\b', r'\blinea\s+matero\b',
    r'\btermo\b(?!\s*termal)', r'\bbombilla\s+para\s+mate\b', r'\bmate\s+de\s+(?:madera|vidrio|silicona|calabaza|acero)\b',
    r'\bplato\s+(?:playo|hondo|postre)\b(?!\s*descartable)',
    r'\bvaso\s+(?:vidrio|cristal)\b', r'\bcopa\s+(?:vidrio|cristal|vino|champagne)\b',
    r'\btaza\s+(?:ceramica|porcelana|vidrio)\b', r'\bjarr\b', r'\bjarra\s+(?:vidrio|acrilico)\b',
    r'\bsarten\b', r'\bolla\b', r'\bcacerola\b', r'\bpava\s+(?:acero|inoxidable)\b',
    r'\bcubiertos\b', r'\btenedor\b', r'\bcuchillo\s+de\s+mesa\b'
]

RE_EXCLUSION = re.compile("|".join(PATRONES_EXCLUSION), re.IGNORECASE)

# -------------------------------------------------------------------------
# SALVEDADES EXPRESAS DE LIMPIEZA / ALIMENTOS / LIBRERÍA QUE USAN ESAS PALABRAS
# -------------------------------------------------------------------------
PATRONES_RESCATE = [
    # Alimentos / Bebidas
    r'\bsal de mesa\b', r'\bcapsulas de cafe\b', r'\bcapsulas nespresso\b',
    r'\bcapsulas dolce gusto\b', r'\bpaleta de cerdo\b', r'\bpaleta vacuna\b',
    r'\bmedialuna\b', r'\bmedialunas\b', r'\bmedia crema\b', r'\blengua\b',
    r'\bojo de bife\b', r'\bmiel\b',

    # Limpieza y consumibles descartables de cocina
    r'\bsuavizante\b', r'\blavandina\b', r'\bjabon para ropa\b', r'\bjabon liq\b',
    r'\bjabon polvo\b', r'\bquitamanchas\b', r'\bperfume para ropa\b',
    r'\baromatizante para ropa\b', r'\baromatizante para placard\b', r'\bdesodorante para placard\b',
    r'\bbroches para ropa\b', r'\bcepillo de ropa\b', r'\binodoro\b', r'\bmochila inodoro\b',
    r'\bbolsa para freezer\b', r'\bbolsas para freezer\b', r'\bbolsa de freezer\b', r'\bbolsas de freezer\b',
    r'\bbolsa de residuo\b', r'\bbolsas de residuos\b', r'\bbolsa de consorcio\b',
    r'\bpapel de aluminio\b', r'\bpapel aluminio\b', r'\bpapel film\b', r'\bfilm adherente\b',
    r'\bpapel para freidora\b', r'\bpapel manteca\b',

    # Librería escolar y papelería (PERMITIDOS)
    r'\bcuaderno\b', r'\bcuadernos\b', r'\bcartuchera\b', r'\bcartucheras\b',
    r'\brepuesto escolar\b', r'\brepuesto n\s*3\b', r'\bcarpeta escolar\b',
    r'\bresma\b', r'\bresma de papel\b', r'\blapiz\b', r'\blapices\b',
    r'\bboligrafo\b', r'\bboligrafos\b', r'\bmarcador\b', r'\bmarcadores\b',
    r'\bgoma de borrar\b', r'\bsacapuntas\b', r'\bplasticola\b', r'\bvoligoma\b',
    r'\bhojas canson\b', r'\bcorrector liquido\b'
]
RE_RESCATE = re.compile("|".join(PATRONES_RESCATE), re.IGNORECASE)

def es_producto_supermercado(descripcion: str, marca: str = "") -> bool:
    """
    Retorna True si el producto pertenece al dominio de supermercado / FMCG
    (Alimentos, Bebidas, Limpieza, Perfumería, Librería).
    Retorna False si es juguete, jardinería, mueble, electrodoméstico, medicamento,
    ropa o bazar pesado.
    """
    if not descripcion:
        return False

    texto = normalizar_para_filtro(f"{descripcion} {marca}")

    # Si coincide con un rescate prioritario (ej. sal de mesa, cápsulas de café, cuadernos de librería), es VÁLIDO
    if RE_RESCATE.search(texto):
        return True

    # Si coincide con la lista de exclusiones (juguetes, muebles, electro, jardinería, ropa), se DESCARTA
    if RE_EXCLUSION.search(texto):
        return False

    return True

if __name__ == "__main__":
    pruebas = [
        # Permitidos
        ("Leche Entera 1L", True),
        ("Pure de Tomate 520g", True),
        ("Suavizante para ropa Vivere 3L", True),
        ("Bloque para inodoro mochila Glade", True),
        ("Sal de mesa Dos Anclas 500g", True),
        ("Cuaderno Rivadavia Tapa Dura 50 Hojas", True),  # Librería permitida
        ("Boligrafo Bic Cristal Azul x 4 un", True),     # Librería permitida
        ("Resma Ledesma A4 75g 500 hojas", True),        # Librería permitida
        ("Capsulas de cafe Cabrales", True),

        # Descartados
        ("Horno Microondas Philco 20L", False),          # Electro
        ("Smart TV Samsung 50 pulgadas", False),         # Electro
        ("Muneco Batman articulado 30cm", False),        # Juguete
        ("Autito Hot Wheels coleccion", False),          # Juguete
        ("Mesa de plastico jardin blanca", False),       # Mueble
        ("Sillon 3 cuerpos ecocuero", False),            # Mueble
        ("Maceta Plastica Redonda N 18", False),         # Jardinería
        ("Tierra Fertil Abonada 20L", False),            # Jardinería
        ("Amoxicilina 500mg 16 comprimidos", False),     # Medicamento
        ("Remera Lisa Algodon Talle L", False),          # Ropa
        ("Novela 'El Aleph' Jorge Luis Borges", False),  # Libro literario
    ]

    errores = 0
    for texto, esperado in pruebas:
        resultado = es_producto_supermercado(texto)
        if resultado != esperado:
            print(f"[FAIL] '{texto}' -> Esperado {esperado}, obtuvo {resultado}")
            errores += 1
        else:
            print(f"[OK] '{texto}' -> {resultado}")

    if errores == 0:
        print("\n¡Todas las pruebas del filtro FMCG pasaron exitosamente!")
