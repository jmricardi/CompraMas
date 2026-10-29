#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_arbol_clusters_auditoria.py
-----------------------------------
Genera un archivo JSON estructurado jerárquicamente con la totalidad de la base
de clústeres para auditar y refinar el mecanismo de construcción de clústeres:

  Producto Básico -> Variedad -> Presentación (Envase) -> Contenido Neto -> Marcas/EANs

Incluye:
- Representante líder (ancla con foto)
- Perfil nutricional discriminando fuente (ARGENFOODS vs Open Food Facts)
- Marcas miembros agrupadas bajo el mismo clúster
"""

import os
import re
import json
import time
from pathlib import Path
import pandas as pd
from typing import Dict, List, Any, Optional

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
CLUSTERS_DIR = DATA_DIR / "clusters"
PROCESSED_DIR = DATA_DIR / "processed"
ROOT_DIR = BASE_DIR.parent
ASSETS_ARGENFOODS_PATH = ROOT_DIR / "assets" / "data" / "alimentos_basicos_ar.json"
OUTPUT_JSON = CLUSTERS_DIR / "arbol_clusters_auditoria.json"

# Mapeo de envases conocidos
ENVASES_PATTERNS = [
    (r"\bsachet\b", "Sachet"),
    (r"\b(tetrabrik|tetra\s*brik|tetra|brick|brik)\b", "Tetra Brik"),
    (r"\b(botella\s*pet|botella|pet)\b", "Botella"),
    (r"\b(lata|latita)\b", "Lata"),
    (r"\b(doypack|doy\s*pack|pouch)\b", "Doypack"),
    (r"\b(frasco|vidrio)\b", "Frasco"),
    (r"\b(pote|potecito)\b", "Pote"),
    (r"\b(bidon|bidón)\b", "Bidón"),
    (r"\b(caja|estuche)\b", "Caja"),
    (r"\b(paquete|bolsa|pack)\b", "Paquete"),
]

# Variedades infantiles comerciales que deben consolidarse en "Infantil"
VARIEDADES_INFANTILES_COMERCIALES = {
    "profutura", "nan", "crecer_baby", "crecer baby", "vital", "vital 1", "vital 2",
    "vital 3", "vital 4", "sancor bebe", "sancor bebé", "nutrilon", "enfagrow", "nestum",
    "similac", "alfare", "puramino", "pepti junior"
}

def detectar_envase(texto: str, envase_previo: str = "", producto: str = "") -> str:
    """Detecta el tipo de presentación/envase a partir del texto, metadatos y producto."""
    s = f"{envase_previo or ''} {texto or ''}".lower()

    # Caso específico LECHE: Las presentaciones reales en góndola son Sachet, Cartón (Tetra Brik) o Botella
    if "leche" in producto.lower() or "leche" in s:
        if re.search(r"\bsachet\b|\bbolsa\b", s):
            return "Sachet"
        if re.search(r"\bbotella\b|\bpet\b", s):
            return "Botella"
        if re.search(r"\b(tetrabrik|tetra\s*brik|tetra|brick|brik|carton|cartón|uat|uht|larga\s*vida|l\.vida|lv)\b", s):
            return "Cartón (Tetra Brik)"
        # Si es leche líquida sin envase explícito, el formato por defecto en góndola de almacén es Cartón
        return "Cartón (Tetra Brik)"

    for pat, nombre in ENVASES_PATTERNS:
        if re.search(pat, s, re.IGNORECASE):
            return nombre

    return "Paquete" if any(k in s for k in ["harina", "arroz", "polenta", "azucar"]) else "Estándar"

def normalizar_variedad(variedad_raw: str, producto_basico: str, texto_desc: str = "") -> str:
    """Normaliza y limpia la variedad quitando nombres comerciales espurios."""
    s_full = f"{variedad_raw or ''} {texto_desc or ''}".lower().replace("_", " ")

    # Si es leche: clasificación rigurosa
    if producto_basico.lower() == "leche":
        # 1. Deslactosada / 0% Lactosa
        if any(k in s_full for k in ["0% lactosa", "0%lactosa", "cero lactosa", "sin lactosa", "deslactosada", "reducida en lactosa"]):
            return "Deslactosada"
        # 2. Descremada
        if any(k in s_full for k in ["descremada", "parcialmente descremada", "liviana", "desnatada", "0% grasa", "1%", "2%"]):
            return "Descremada"
        # 3. Chocolatada
        if any(k in s_full for k in ["chocolatada", "chocolate", "cacao", "cindor"]):
            return "Chocolatada"
        # 4. Infantil
        for inf in VARIEDADES_INFANTILES_COMERCIALES:
            if inf in s_full:
                return "Infantil"
        if re.search(r"\b(etapa\s*\d|1_6_12m|1_a_3|0_a_6)\b", s_full):
            return "Infantil"
        # 5. Entera
        if any(k in s_full for k in ["entera", "clasica", "clásica", "3%", "tradicional"]):
            return "Entera"
        return "Entera"

    if not variedad_raw or str(variedad_raw).strip() in ("nan", "None", "null", ""):
        return "Clásico"

    var = str(variedad_raw).strip()
    var_lower = var.lower().replace("_", " ")

    # Limpiar prefijos redundantes (ej: 'harina leudante' -> 'Leudante')
    prod_word = producto_basico.lower()
    var = re.sub(r'\b' + re.escape(prod_word) + r's?\b', '', var, flags=re.IGNORECASE).strip()

    return var.title() if var else "Clásico"

def parsear_contenido_neto(contenido_neto_val: Any, unidad_ref: Any, presentacion_raw: str) -> tuple:
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

    return 1.0, "un"

def cargar_argenfoods() -> List[Dict]:
    if ASSETS_ARGENFOODS_PATH.exists():
        try:
            with open(ASSETS_ARGENFOODS_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"[!] Error al cargar ARGENFOODS: {e}")
    return []

def buscar_argenfoods(producto: str, variedad: str, argen_db: List[Dict]) -> Optional[Dict]:
    """Busca coincidencia en la base de alimentos básicos de ARGENFOODS."""
    if not argen_db:
        return None
    p_norm = (producto or "").lower()
    v_norm = (variedad or "").lower()
    query = f"{p_norm} {v_norm}".strip()

    for item in argen_db:
        for kw in item.get("keywords", []):
            kw_norm = kw.lower()
            if kw_norm in query or query in kw_norm:
                return item
    return None

def ejecutar_generacion_arbol():
    t0 = time.time()
    print("=================================================================")
    print(" GENERADOR DE ÁRBOL JERÁRQUICO DE CLÚSTERES PARA AUDITORÍA")
    print("=================================================================")

    # 1. Cargar fuentes de datos
    print("[1/5] Cargando catálogos y clústeres...")
    df_clusters = pd.read_csv(CLUSTERS_DIR / "producto_clusters.csv")
    df_items = pd.read_csv(CLUSTERS_DIR / "producto_cluster_items.csv")
    df_catalogo = pd.read_csv(PROCESSED_DIR / "catalogo_productos.csv", low_memory=False)

    print(f"      -> {len(df_clusters):,} clústeres cargados.")
    print(f"      -> {len(df_items):,} ítems asignados.")
    print(f"      -> {len(df_catalogo):,} productos en catálogo.")

    # 2. Cargar ARGENFOODS y OFF Cache
    print("[2/5] Cargando bases nutricionales de referencia (ARGENFOODS y OFF)...")
    argen_db = cargar_argenfoods()
    print(f"      -> {len(argen_db)} alimentos canónicos de ARGENFOODS disponibles.")

    off_cache = {}
    off_cache_path = PROCESSED_DIR / "off_cache.json"
    if off_cache_path.exists():
        try:
            with open(off_cache_path, "r", encoding="utf-8") as f:
                off_cache = json.load(f)
            print(f"      -> {len(off_cache):,} productos cacheados de Open Food Facts.")
        except Exception:
            pass

    # Mapeo rápido de catálogo por id_producto
    print("[3/5] Indexando productos y descripciones...")
    cat_dict = {}
    for _, row in df_catalogo.iterrows():
        id_p = str(row["id_producto"]).strip()
        cat_dict[id_p] = {
            "descripcion": str(row.get("productos_descripcion") or "").strip(),
            "marca": str(row.get("productos_marca") or "").strip(),
            "off_imagen": str(row.get("off_imagen") or "").strip(),
            "off_nutriscore": str(row.get("off_nutriscore") or "").strip()
        }

    # Indexar ítems por cluster_id
    items_by_cluster = {}
    for _, row in df_items.iterrows():
        c_id = str(row["cluster_id"]).strip()
        if c_id not in items_by_cluster:
            items_by_cluster[c_id] = []
        items_by_cluster[c_id].append(row)

    # 3. Construir la estructura de árbol:
    # arbol[producto_basico][variedad][presentacion][contenido_key] = datos_cluster
    print("[4/5] Construyendo árbol jerárquico de clústeres...")
    arbol = {}
    clusters_procesados = 0

    for _, c_row in df_clusters.iterrows():
        c_id = str(c_row["cluster_id"]).strip()
        prod_basico = str(c_row.get("producto") or "Varios").strip().title()
        variedad_raw = str(c_row.get("variedad") or "").strip()
        presentacion_raw = str(c_row.get("presentacion") or "").strip()

        # Miembros asignados a este clúster
        cluster_items = items_by_cluster.get(c_id, [])
        if not cluster_items:
            continue

        clusters_procesados += 1

        # Detectar envase dominante del clúster a partir de sus miembros
        envases_encontrados = []
        for it in cluster_items:
            id_p = str(it["id_producto"]).strip()
            cat_info = cat_dict.get(id_p, {})
            desc = cat_info.get("descripcion", "")
            env_it = str(it.get("envase") or "")
            env_det = detectar_envase(desc, env_it, prod_basico)
            envases_encontrados.append(env_det)

        # Envase más frecuente entre los miembros
        envase_final = max(set(envases_encontrados), key=envases_encontrados.count) if envases_encontrados else "Estándar"

        # Variedad limpia con contexto de descripciones
        todas_desc = " ".join(cat_dict.get(str(it["id_producto"]).strip(), {}).get("descripcion", "") for it in cluster_items[:5])
        variedad_final = normalizar_variedad(variedad_raw, prod_basico, todas_desc)

        # Contenido neto y unidad
        prim_it = cluster_items[0]
        cnt_val, cnt_und = parsear_contenido_neto(
            prim_it.get("contenido_neto"),
            prim_it.get("unidad_referencia"),
            presentacion_raw
        )

        # Representante líder con validación estricta de foto y variedad
        ean_lider = None
        foto_lider = None
        marcas_miembros = []
        marcas_set = set()

        for it in cluster_items:
            id_p = str(it["id_producto"]).strip()
            cat_info = cat_dict.get(id_p, {})
            marca = str(it.get("marca") or cat_info.get("marca") or "Sin Marca").strip()
            desc = cat_info.get("descripcion") or f"{prod_basico} {variedad_final}"
            foto = cat_info.get("off_imagen") or ""
            desc_low = desc.lower()

            # Validación de coherencia estricta para la foto líder
            foto_coherente = bool(foto)
            if foto_coherente and prod_basico.lower() == "leche":
                if variedad_final == "Entera" and any(k in desc_low for k in ["deslactosada", "0%", "lactosa", "descremada", "chocolate", "polvo", "formula", "infantil"]):
                    foto_coherente = False
                elif variedad_final == "Descremada" and any(k in desc_low for k in ["entera", "chocolate", "polvo", "3%"]):
                    foto_coherente = False
                elif variedad_final == "Deslactosada" and not any(k in desc_low for k in ["deslactosada", "0%", "lactosa"]):
                    foto_coherente = False

            if not ean_lider:
                ean_lider = id_p
            if foto_coherente and not foto_lider:
                ean_lider = id_p
                foto_lider = foto

            if (marca, id_p) not in marcas_set:
                marcas_set.add((marca, id_p))
                marcas_miembros.append({
                    "marca": marca,
                    "ean": id_p,
                    "nombre_comercial": desc
                })

        # Perfil Nutricional (ARGENFOODS vs OFF) con ingredientes limpios
        argen_match = buscar_argenfoods(prod_basico, variedad_final, argen_db)
        if argen_match:
            ingredientes_texto = argen_match.get("ingredientes") or (
                "Leche entera, vitaminas A y D" if "entera" in variedad_final.lower()
                else ("Leche descremada, vitaminas A y D" if "descremada" in variedad_final.lower() else prod_basico)
            )
            perfil_nutricional = {
                "fuente": "argenfoods",
                "ingredientes": ingredientes_texto,
                "sellos_ley_27642": "Exento de sellos de advertencia (Ley 27.642)",
                "argenfoods_datos": {
                    "id_oficial": argen_match.get("id"),
                    "nombre_oficial": argen_match.get("nombre"),
                    "tabla": "Tabla Oficial de Composición de Alimentos (República Argentina)",
                    "exento_ley_27642": True,
                    "por_100g": argen_match.get("por_100g", {})
                },
                "open_food_facts_datos": None
            }
        else:
            # Buscar en OFF Cache
            off_info = off_cache.get(str(ean_lider)) or {}
            if off_info.get("encontrado"):
                perfil_nutricional = {
                    "fuente": "open_food_facts",
                    "ingredientes": "Información no declarada en envase",
                    "sellos_ley_27642": "Evaluado según composición",
                    "argenfoods_datos": None,
                    "open_food_facts_datos": {
                        "nutriscore": off_info.get("off_nutriscore"),
                        "categorias": off_info.get("off_categorias"),
                        "exento_ley_27642": False
                    }
                }
            else:
                perfil_nutricional = {
                    "fuente": "sin_datos",
                    "ingredientes": "No disponible",
                    "sellos_ley_27642": "Sin información",
                    "argenfoods_datos": None,
                    "open_food_facts_datos": None
                }

        # Armado del nombre representativo limpio sin "Estándar 1.0 lit"
        cnt_clean = str(cnt_val).rstrip('0').rstrip('.') if '.' in str(cnt_val) else str(cnt_val)
        tam_clean = f"{cnt_clean} {cnt_und}".strip()
        env_repr = f" {envase_final}" if envase_final and envase_final != "Estándar" else ""
        nombre_rep = f"{prod_basico} {variedad_final}{env_repr} {tam_clean}".strip()

        # Armado del nodo de clúster
        cluster_node = {
            "cluster_id": c_id,
            "contenido_neto": {
                "valor": cnt_val,
                "unidad": cnt_und
            },
            "representante_lider": {
                "ean_lider": ean_lider or "",
                "nombre_representativo": nombre_rep,
                "imagen_url": foto_lider or None
            },
            "perfil_nutricional": perfil_nutricional,
            "marcas_miembros": marcas_miembros
        }

        # Insertar en el árbol
        if prod_basico not in arbol:
            arbol[prod_basico] = {}
        if variedad_final not in arbol[prod_basico]:
            arbol[prod_basico][variedad_final] = {}
        if envase_final not in arbol[prod_basico][variedad_final]:
            arbol[prod_basico][variedad_final][envase_final] = []

        arbol[prod_basico][variedad_final][envase_final].append(cluster_node)

    # 4. Transformar el diccionario en la estructura final de lista
    print("[5/5] Formateando y serializando estructura final JSON...")
    resultado_final = []
    for p_nombre in sorted(arbol.keys()):
        variedades_list = []
        for v_nombre in sorted(arbol[p_nombre].keys()):
            presentaciones_list = []
            for pres_nombre in sorted(arbol[p_nombre][v_nombre].keys()):
                contenidos_list = arbol[p_nombre][v_nombre][pres_nombre]
                presentaciones_list.append({
                    "presentacion": pres_nombre,
                    "contenidos": contenidos_list
                })
            variedades_list.append({
                "variedad": v_nombre,
                "presentaciones": presentaciones_list
            })
        resultado_final.append({
            "producto_basico": p_nombre,
            "variedades": variedades_list
        })

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(resultado_final, f, ensure_ascii=False, indent=2)

    elapsed = time.time() - t0
    tam_mb = OUTPUT_JSON.stat().st_size / (1024 * 1024)
    print("\n=================================================================")
    print(f" [OK] Auditoría completada en {elapsed:.1f}s")
    print(f"      - Productos básicos agrupados : {len(resultado_final):,}")
    print(f"      - Clústeres procesados        : {clusters_procesados:,}")
    print(f"      - Archivo generado            : {OUTPUT_JSON}")
    print(f"      - Peso del archivo            : {tam_mb:.2f} MB")
    print("=================================================================")

if __name__ == "__main__":
    ejecutar_generacion_arbol()
