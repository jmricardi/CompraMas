#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
consolidar_clusters_5_elementos.py
----------------------------------
Re-consolida el 100% de los clústeres e ítems bajo el modelo de 5 Elementos:
  a) producto      (en producto_clusters)
  b) variedad      (en producto_clusters)
  c) marca         (en producto_cluster_items)
  d) envase        (en producto_cluster_items)
  e) presentacion  (en producto_clusters)

Fusiona clústeres fragmentados (ej. 1000g vs 1kg, 0.5l vs 500ml, 0.9l vs 900ml,
harina_000 vs harina_de_trigo_000) e integra todas las marcas y envases dentro
del mismo clúster de (producto + variedad + presentacion).
"""

import re
import pandas as pd
from pathlib import Path
from typing import Tuple

from config import PROCESSED_DIR, CLUSTERS_DIR
from cluster_canonico_builder import (
    construir_cluster_canonico,
    normalizar_texto,
    limpiar_tokens_envase_y_marca,
    capitalizar_frase,
)

# Prefijos de Producto Base ordenados de más específicos a más generales
PRODUCTOS_BASE_CONOCIDOS = [
    ("harina de trigo", "Harina de Trigo"),
    ("harina de maiz", "Harina de Maíz"),
    ("pure de tomate", "Puré de Tomate"),
    ("salsa de tomate", "Salsa de Tomate"),
    ("extracto de tomate", "Extracto de Tomate"),
    ("pulpa de tomate", "Pulpa de Tomate"),
    ("tomate perita", "Tomate Perita"),
    ("dulce de leche", "Dulce de Leche"),
    ("dulce de batata", "Dulce de Batata"),
    ("dulce de membrillo", "Dulce de Membrillo"),
    ("crema de leche", "Crema de Leche"),
    ("crema de mani", "Pasta de Maní"),
    ("pasta de mani", "Pasta de Maní"),
    ("manteca de mani", "Pasta de Maní"),
    ("leche en polvo", "Leche en Polvo"),
    ("leche condensada", "Leche Condensada"),
    ("bebida de almendras", "Bebida de Almendras"),
    ("leche de almendras", "Bebida de Almendras"),
    ("yerba mate", "Yerba Mate"),
    ("mate cocido", "Mate Cocido"),
    ("agua mineralizada", "Agua Mineral"),
    ("agua mineral", "Agua Mineral"),
    ("agua de mesa", "Agua Mineral"),
    ("agua saborizada", "Agua Saborizada"),
    ("jugo en polvo", "Jugo en Polvo"),
    ("jugo listo", "Jugo Listo"),
    ("jugo concentrado", "Jugo Concentrado"),
    ("queso crema", "Queso Crema"),
    ("queso untable", "Queso Untable"),
    ("queso rallado", "Queso Rallado"),
    ("queso port salut", "Queso Port Salut"),
    ("queso cremoso", "Queso Cremoso"),
    ("queso cuartirolo", "Queso Cremoso"),
    ("queso muzzarella", "Queso Muzzarella"),
    ("queso mozzarella", "Queso Muzzarella"),
    ("queso pategras", "Queso Pategrás"),
    ("queso reggianito", "Queso Reggianito"),
    ("queso sardo", "Queso Sardo"),
    ("queso provolone", "Queso Provolone"),
    ("queso azul", "Queso Azul"),
    ("queso tybo", "Queso Tybo"),
    ("queso danbo", "Queso Danbo"),
    ("tapas para empanadas", "Tapas para Empanadas"),
    ("tapas de empanadas", "Tapas para Empanadas"),
    ("tapa de empanada", "Tapas para Empanadas"),
    ("tapas para pascualina", "Tapas para Pascualina"),
    ("tapas de pascualina", "Tapas para Pascualina"),
    ("tapa de pascualina", "Tapas para Pascualina"),
    ("pan de molde", "Pan Lactal"),
    ("pan lactal", "Pan Lactal"),
    ("pan para hamburguesa", "Pan de Hamburguesa"),
    ("pan de hamburguesa", "Pan de Hamburguesa"),
    ("pan para pancho", "Pan de Pancho"),
    ("pan de pancho", "Pan de Pancho"),
    ("pan rallado", "Pan Rallado"),
    ("rebozador", "Rebozador"),
    ("galletitas dulces", "Galletitas Dulces"),
    ("galletitas de agua", "Galletitas de Agua"),
    ("galletitas saladas", "Galletitas Saladas"),
    ("galletitas crackers", "Galletitas Saladas"),
    ("galletas de arroz", "Galletas de Arroz"),
    ("tostadas de arroz", "Tostadas de Arroz"),
    ("salsa golf", "Salsa Golf"),
    ("salsa de soja", "Salsa de Soja"),
    ("papel higienico", "Papel Higiénico"),
    ("rollo de cocina", "Rollo de Cocina"),
    ("servilletas de papel", "Servilletas de Papel"),
    ("panuelos descartables", "Pañuelos Descartables"),
    ("jabon liquido", "Jabón Líquido"),
    ("jabon en polvo", "Jabón en Polvo"),
    ("jabon en pan", "Jabón en Pan"),
    ("jabon de tocador", "Jabón de Tocador"),
    ("crema dental", "Crema Dental"),
    ("pasta dental", "Crema Dental"),
    ("enjuague bucal", "Enjuague Bucal"),
    ("cepillo dental", "Cepillo Dental"),
    ("cepillo de dientes", "Cepillo Dental"),
    ("toallitas femeninas", "Toallitas Femeninas"),
    ("toallas femeninas", "Toallitas Femeninas"),
    ("protectores diarios", "Protectores Diarios"),
    ("alimento para perro", "Alimento para Perro"),
    ("alimento para gato", "Alimento para Gato"),
    ("papel aluminio", "Papel Aluminio"),
    ("film adherente", "Film Adherente"),
    ("bolsas de residuos", "Bolsas de Residuos"),
    ("espuma de afeitar", "Espuma de Afeitar"),
    ("crema corporal", "Crema Corporal"),
    ("crema facial", "Crema Facial"),
    ("protector solar", "Protector Solar"),
    ("repelente de insectos", "Repelente"),
    ("insecticida", "Insecticida"),
    ("desodorante de ambiente", "Desodorante de Ambiente"),
    ("limpiador liquido", "Limpiador Líquido"),
    ("limpiador cremoso", "Limpiador Cremoso"),
    ("lavavajillas", "Detergente Lavavajillas"),
    ("detergente", "Detergente Lavavajillas"),
    ("lavandina", "Lavandina"),
    ("suavizante", "Suavizante para Ropa"),
    ("quitamanchas", "Quitamanchas"),
    ("desinfectante", "Desinfectante"),
    ("harina", "Harina de Trigo"),
    ("leche", "Leche"),
    ("aceite", "Aceite"),
    ("arroz", "Arroz"),
    ("azucar", "Azúcar"),
    ("yerba", "Yerba Mate"),
    ("fideos", "Fideos"),
    ("pasta seca", "Fideos"),
    ("noquis", "Ñoquis"),
    ("ravioles", "Ravioles"),
    ("capelettis", "Capelettis"),
    ("sorrentinos", "Sorrentinos"),
    ("polenta", "Polenta"),
    ("avena", "Avena"),
    ("sal", "Sal"),
    ("vinagre", "Vinagre"),
    ("aceto", "Aceto Balsámico"),
    ("mayonesa", "Mayonesa"),
    ("mostaza", "Mostaza"),
    ("ketchup", "Ketchup"),
    ("mermelada", "Mermelada"),
    ("miel", "Miel"),
    ("cafe", "Café"),
    ("te", "Té"),
    ("cacao", "Cacao en Polvo"),
    ("edulcorante", "Edulcorante"),
    ("endulzante", "Edulcorante"),
    ("galletitas", "Galletitas"),
    ("bizcochos", "Bizcochos"),
    ("grisines", "Grisines"),
    ("tostadas", "Tostadas"),
    ("budin", "Budín"),
    ("magdalenas", "Magdalenas"),
    ("alfajor", "Alfajor"),
    ("chocolate", "Chocolate"),
    ("bombones", "Bombones"),
    ("turron", "Turrón"),
    ("caramelos", "Caramelos"),
    ("gomitas", "Gomitas"),
    ("chicles", "Chicles"),
    ("papas fritas", "Papas Fritas"),
    ("snacks", "Snack"),
    ("manies", "Maní"),
    ("mani", "Maní"),
    ("palitos salados", "Palitos Salados"),
    ("chizitos", "Chizitos"),
    ("nachos", "Nachos"),
    ("cereales", "Cereal"),
    ("cereal", "Cereal"),
    ("granola", "Granola"),
    ("barrita de cereal", "Barra de Cereal"),
    ("barra de cereal", "Barra de Cereal"),
    ("gaseosa", "Gaseosa"),
    ("agua", "Agua Mineral"),
    ("soda", "Soda"),
    ("jugo", "Jugo"),
    ("cerveza", "Cerveza"),
    ("vino", "Vino"),
    ("espumante", "Espumante"),
    ("champagne", "Espumante"),
    ("sidra", "Sidra"),
    ("fernet", "Fernet"),
    ("aperitivo", "Aperitivo"),
    ("vermouth", "Aperitivo"),
    ("energizante", "Bebida Energizante"),
    ("isotonica", "Bebida Isotónica"),
    ("yogur", "Yogur"),
    ("yogurt", "Yogur"),
    ("postre", "Postre Lácteo"),
    ("flan", "Flan"),
    ("gelatina", "Gelatina"),
    ("manteca", "Manteca"),
    ("margarina", "Margarina"),
    ("levadura", "Levadura"),
    ("ricota", "Ricota"),
    ("queso", "Queso"),
    ("jamon cocido", "Jamón Cocido"),
    ("jamon crudo", "Jamón Crudo"),
    ("salame", "Salame"),
    ("mortadela", "Mortadela"),
    ("paleta", "Paleta"),
    ("panceta", "Panceta"),
    ("salchichas", "Salchichas"),
    ("salchicha", "Salchichas"),
    ("chorizo", "Chorizo"),
    ("morcilla", "Morcilla"),
    ("hamburguesas", "Hamburguesas"),
    ("hamburguesa", "Hamburguesas"),
    ("medallones", "Medallones"),
    ("nuggets", "Nuggets"),
    ("patitas", "Patitas de Pollo"),
    ("milanesas", "Milanesas"),
    ("helado", "Helado"),
    ("atun", "Atún"),
    ("caballa", "Caballa"),
    ("sardinas", "Sardinas"),
    ("choclo", "Choclo en Grano"),
    ("arvejas", "Arvejas"),
    ("lentejas", "Lentejas"),
    ("garbanzos", "Garbanzos"),
    ("porotos", "Porotos"),
    ("aceitunas", "Aceitunas"),
    ("duraznos", "Duraznos en Almíbar"),
    ("anana", "Ananá en Almíbar"),
    ("palmitos", "Palmitos"),
    ("champignones", "Champignones"),
    ("pate", "Paté"),
    ("picadillo", "Picadillo de Carne"),
    ("caldo", "Caldo"),
    ("sopa", "Sopa"),
    ("pure de papas", "Puré de Papas"),
    ("bizcochuelo", "Premezcla Bizcochuelo"),
    ("premezcla", "Premezcla"),
    ("polvo para hornear", "Polvo para Hornear"),
    ("almidon de maiz", "Almidón de Maíz"),
    ("huevos", "Huevos"),
    ("huevo", "Huevos"),
    ("shampoo", "Shampoo"),
    ("champu", "Shampoo"),
    ("acondicionador", "Acondicionador"),
    ("desodorante", "Desodorante"),
    ("antitranspirante", "Desodorante"),
    ("talco", "Talco"),
    ("algodon", "Algodón"),
    ("hisopos", "Hisopos"),
    ("panales", "Pañales"),
    ("panal", "Pañales"),
    ("toallitas humedas", "Toallitas Húmedas"),
    ("esponja", "Esponja"),
    ("trapo de piso", "Trapo de Piso"),
    ("rejilla", "Paño Rejilla"),
    ("franela", "Franela"),
    ("guantes", "Guantes de Limpieza"),
    ("fosforos", "Fósforos"),
    ("velas", "Velas"),
    ("carbon", "Carbón"),
]


def quitar_presentacion_final(nombre_canonico: str) -> Tuple[str, float, str]:
    """
    Quita la unidad/presentación del final de un nombre canónico y retorna:
    (texto_sin_presentacion, contenido_extraido, unidad_extraida)
    """
    txt = str(nombre_canonico or "").strip()
    patron = re.compile(
        r"\b(\d+(?:[.,]\d+)?)\s*(kg|kilo|kilos|g|gr|grs|gramos|l|lt|lts|litros|ml|cc|cm3|u|un|unid|unidades)\s*$",
        re.IGNORECASE,
    )
    m = patron.search(txt)
    if m:
        val_str = m.group(1).replace(",", ".")
        unidad_str = m.group(2).lower()
        sin_pres = txt[:m.start()].strip()
        try:
            return sin_pres, float(val_str), unidad_str
        except ValueError:
            pass
    return txt, 0.0, ""


def separar_producto_y_variedad(texto_canonico_sin_pres: str, desc_original: str, marca: str) -> Tuple[str, str]:
    """
    Separa de manera determinista el texto en (a) Producto y (b) Variedad.
    """
    limpio = limpiar_tokens_envase_y_marca(texto_canonico_sin_pres, marca)
    if not limpio:
        limpio = limpiar_tokens_envase_y_marca(desc_original, marca)
    if not limpio:
        return "Producto", "Clásico"

    # 1. Buscar en diccionario de Productos Base conocidos
    for prefijo_norm, titulo_prod in PRODUCTOS_BASE_CONOCIDOS:
        # Si comienza con el prefijo o lo contiene como palabra al inicio
        if limpio == prefijo_norm or limpio.startswith(prefijo_norm + " "):
            resto = limpio[len(prefijo_norm):].strip()
            return titulo_prod, (resto if resto else "clasico")

    # 2. Heurística general si no está en la tabla:
    # Si la segunda palabra es "de" o "para" o "en" (ej. "jugo de naranja", "salsa para pizza")
    palabras = limpio.split()
    if len(palabras) == 1:
        return capitalizar_frase(palabras[0]), "clasico"
    elif len(palabras) >= 3 and palabras[1] in ("de", "del", "para", "en", "al", "con", "sin"):
        # Ej: "almidon de maiz" -> producto = "Almidón de Maíz", resto = variedad
        prod = " ".join(palabras[:3])
        var = " ".join(palabras[3:])
        return capitalizar_frase(prod), (var if var else "clasico")
    else:
        # Primera palabra como producto (o primeras 2 si la primera es genérica)
        prod = palabras[0]
        var = " ".join(palabras[1:])
        return capitalizar_frase(prod), (var if var else "clasico")


def ejecutar_consolidacion():
    print("\n=====================================================================")
    print(" CONSOLIDACIÓN DE CLÚSTERES DE 5 ELEMENTOS (Producto/Variedad/Pres.)")
    print("=====================================================================")

    f_cat = PROCESSED_DIR / "catalogo_productos.csv"
    f_clusters = CLUSTERS_DIR / "producto_clusters.csv"
    f_items = CLUSTERS_DIR / "producto_cluster_items.csv"

    df_cat = pd.read_csv(f_cat, dtype=str)
    df_clusters = pd.read_csv(f_clusters, dtype=str)
    df_items = pd.read_csv(f_items, dtype=str)

    print(f"[*] Estado inicial:")
    print(f"    - Clústeres antes de consolidar: {len(df_clusters):,}")
    print(f"    - Ítems asociados:               {len(df_items):,}")

    # Mapa rápido de catálogo: id_producto -> (descripcion, marca, cant, um)
    cat_map = {}
    for row in df_cat.itertuples(index=False):
        pid = str(getattr(row, "id_producto", "")).strip()
        desc = str(getattr(row, "productos_descripcion", "") or "").strip()
        marca = str(getattr(row, "productos_marca", "") or "").strip()
        if pid:
            cat_map[pid] = (desc, marca)

    # Mapa de clústeres actuales: cluster_id -> (nombre_canonico, categoria)
    old_cluster_map = {}
    for row in df_clusters.itertuples(index=False):
        cid = str(getattr(row, "cluster_id", "")).strip()
        nc = str(getattr(row, "nombre_canonico", "") or "").strip()
        cat = str(getattr(row, "categoria", "Almacén") or "Almacén").strip()
        old_cluster_map[cid] = (nc, cat)

    nuevos_clusters = {}
    nuevos_items = []

    for row in df_items.itertuples(index=False):
        pid = str(getattr(row, "id_producto", "")).strip()
        old_cid = str(getattr(row, "cluster_id", "")).strip()
        if not pid or not old_cid or pid not in cat_map:
            continue

        old_nc, old_cat = old_cluster_map.get(old_cid, ("", "Almacén"))
        desc_orig, marca_orig = cat_map.get(pid, ("", ""))
        if not marca_orig or marca_orig.lower() == "nan":
            marca_orig = str(getattr(row, "marca", "") or "").strip()

        # Contenido neto y unidad de referencia actuales
        try:
            cn_val = float(str(getattr(row, "contenido_neto", "1.0")).replace(",", "."))
        except ValueError:
            cn_val = 1.0
        um_val = str(getattr(row, "unidad_referencia", "kg") or "kg").strip()

        # Extraer texto sin presentación desde el nombre canónico previo
        sin_pres, cn_extraido, um_extraida = quitar_presentacion_final(old_nc)
        if (cn_val <= 0 or (cn_val == 1.0 and cn_extraido > 0)) and um_extraida:
            cn_val = cn_extraido
            um_val = um_extraida

        prod_base, var_sabor = separar_producto_y_variedad(sin_pres, desc_orig, marca_orig)

        res = construir_cluster_canonico(
            nombre_base=prod_base,
            variedad_sabor=var_sabor,
            marca=marca_orig,
            contenido_neto=cn_val,
            unidad_medida=um_val,
            pack_unidades=1,
            categoria=old_cat,
            descripcion_original=f"{desc_orig} {old_nc}",
        )

        new_cid = res["cluster_id"]
        if new_cid not in nuevos_clusters:
            nuevos_clusters[new_cid] = {
                "cluster_id": new_cid,
                "producto": res["producto"],
                "variedad": res["variedad"],
                "presentacion": res["presentacion"],
                "nombre_canonico": res["nombre_canonico"],
                "categoria": res["categoria"],
            }

        nuevos_items.append({
            "id_producto": pid,
            "cluster_id": new_cid,
            "marca": res["marca"],
            "envase": res["envase"],
            "contenido_neto": res["contenido_neto"],
            "unidad_referencia": res["unidad_referencia"],
        })

    df_new_clusters = pd.DataFrame(list(nuevos_clusters.values()))
    df_new_items = pd.DataFrame(nuevos_items).drop_duplicates(subset=["id_producto"], keep="first")

    # Filtrar clústeres que tengan al menos 1 ítem
    cids_activos = set(df_new_items["cluster_id"])
    df_new_clusters = df_new_clusters[df_new_clusters["cluster_id"].isin(cids_activos)]

    df_new_clusters.to_csv(f_clusters, index=False, encoding="utf-8")
    df_new_items.to_csv(f_items, index=False, encoding="utf-8")

    fusionados = len(df_clusters) - len(df_new_clusters)
    print(f"\n[OK] Consolidación finalizada con éxito:")
    print(f"    - Clústeres resultantes:         {len(df_new_clusters):,} ({fusionados:,} clústeres fragmentados fusionados)")
    print(f"    - Ítems con 5 elementos:         {len(df_new_items):,}")

    # Mostrar verificación de Harina de Trigo, Leche y Aceite
    print("\n[*] Verificación de Clústeres de Harina de Trigo:")
    harinas = df_new_clusters[df_new_clusters["producto"] == "Harina de Trigo"].copy()
    counts = df_new_items.groupby("cluster_id").size().to_dict()
    harinas["items"] = harinas["cluster_id"].map(lambda x: counts.get(x, 0))
    harinas = harinas.sort_values("items", ascending=False).head(8)
    for r in harinas.itertuples(index=False):
        print(f"    - {r.cluster_id:32s} | Prod: {r.producto:16s} | Var: {r.variedad:10s} | Pres: {r.presentacion:6s} | {r.items} marcas/envases")


if __name__ == "__main__":
    ejecutar_consolidacion()
