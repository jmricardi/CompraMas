#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
4_clustering_ia.py
------------------
Proceso incremental de Inteligencia Artificial utilizando Gemini Flash para
agrupar códigos de barra equivalentes bajo un cluster_id canónico.
- Lee los productos desde data/processed/catalogo_productos.csv.
- Identifica productos nuevos que no tienen cluster_id asignado.
- Agrupa en batches y consulta la API de Gemini (con structured JSON).
- Guarda y actualiza de manera incremental:
    - data/clusters/producto_clusters.csv
    - data/clusters/producto_cluster_items.csv
"""

import os
import sys
import json
import time
import argparse
import requests
import pandas as pd
from pathlib import Path
from config import GEMINI_API_KEY, OPENROUTER_API_KEY, PROCESSED_DIR, CLUSTERS_DIR

OPENROUTER_FREE_MODELS = [
    "thinkingmachines/inkling-small:free",
    "thinkingmachines/inkling:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
    "cohere/north-mini-code:free",
    "liquid/lfm-2.5-2.6b:free",
    "nvidia/nemotron-3.5-lightning:free"
]

MODELOS_CASCADA_GEMINI = [
    {
        "name": "gemini-flash-lite-latest",
        "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent"
    },
    {
        "name": "gemini-2.5-flash",
        "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    },
    {
        "name": "gemini-flash-latest",
        "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"
    },
    {
        "name": "gemini-2.5-pro",
        "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
    }
]

BATCH_SIZE_FLASH_LITE = 50
BATCH_SIZE_FLASH = 120

from cluster_canonico_builder import construir_cluster_canonico

SYSTEM_PROMPT = """Actúa como un experto catalogador de consumo masivo (supermercados en Argentina).
Tu misión es DESCOMPONER cada producto en sus CINCO ELEMENTOS FUNDAMENTALES para agrupar clústeres por (producto + variedad + presentación):

CINCO ELEMENTOS OBLIGATORIOS:
1. 'nombre_base' (Producto): Sustantivo formal y específico de qué es el artículo (ej: 'Harina de Trigo', 'Leche', 'Aceite', 'Puré de Tomate', 'Arroz', 'Fideos', 'Pan Rallado', 'Cerveza', 'Papel Higiénico').
   REGLA DE ORO DE GRANULARIDAD (NUNCA usar nombres hiper-genéricos):
   - Quesos: NUNCA 'Queso' a secas. Usar siempre 'Queso Cremoso', 'Queso Port Salut', 'Queso Azul', 'Queso Muzzarella', 'Queso Sardo', 'Queso Tybo', 'Queso Cheddar', 'Queso Danbo', 'Queso Untable', 'Queso Crema', etc.
   - Harinas: NUNCA 'Harina' a secas. Usar 'Harina de Trigo', 'Harina de Maíz', 'Harina de Almendras', 'Harina de Arroz', etc.
   - Semillas: NUNCA 'Semillas' a secas. Usar 'Semillas de Chía', 'Semillas de Girasol', 'Semillas de Lino', 'Semillas de Sésamo', etc.
   - Milanesas: NUNCA 'Milanesa' a secas. Usar 'Milanesa de Carne', 'Milanesa de Pollo', 'Milanesa de Merluza', 'Milanesa de Soja', etc.
   - Medallones: NUNCA 'Medallón' a secas. Usar 'Medallón de Carne', 'Medallón de Pollo', 'Medallón de Merluza', 'Medallón de Soja', etc.
   - Pescados: NUNCA 'Filet' a secas. Usar 'Filet de Merluza', 'Filet de Abadejo', 'Filet de Lenguado', etc.
2. 'variedad_sabor' (Variedad): La variante, corte o sabor específico:
   - Para Quesos: 'En Fetas', 'En Hebras', 'Rallado', 'Por Peso', 'Horma', 'Light', 'Sin Lactosa', 'Sin Sal', 'Clásico'.
   - Para Harinas: '000', '0000', 'Leudante', 'Integral', 'Para Pizza'.
   - Para Leche fluida: 'Entera', 'Descremada', 'Deslactosada', 'Chocolatada'.
   - Si es neutro/estándar usa 'Clásico'.
3. 'marca' (Marca): Nombre formal de la marca (ej: 'Morixe', 'Favorita', 'Coto', 'Arcor', 'La Serenísima', 'Marolio', 'Dia', 'Carrefour').
4. 'envase' (Envase): Tipo de envase si se indica o infiere claramente (ej: 'Sachet', 'Tetrabrick', 'Botella', 'Lata', 'Doypack', 'Pote', 'Frasco', 'Paquete', o '' vacío si no aplica).
5. 'contenido_neto', 'unidad_medida' y 'pack_unidades' (Presentación):
   - 'contenido_neto': Cantidad numérica en unidad base:
     * Peso en kg (ej: 500g -> 0.5, 1kg -> 1.0, 520g -> 0.52).
     * Volumen en litros (ej: 900ml -> 0.9, 1L -> 1.0, 1.5L -> 1.5).
     * Unidades (ej: 1 rollo -> 1.0, 3 rollos -> 3.0).
   - 'unidad_medida': 'kg', 'l', o 'u'.
   - 'pack_unidades': Entero con la cantidad de unidades en el pack (ej: 1 para unidad individual, 3 para rollo de cocina x 3, 6 para cerveza pack x 6).

REGLAS DE ORO:
- Toda leche fluida entera de 1 litro tiene nombre_base='Leche', variedad_sabor='Entera', contenido_neto=1.0, unidad_medida='l' (sin importar si es Sachet o Tetrabrick o la marca).
- Toda harina de trigo 000 de 1 kg tiene nombre_base='Harina de Trigo', variedad_sabor='000', contenido_neto=1.0, unidad_medida='kg'.
- Marcas líderes, marcas blancas y distintos envases comparten el mismo clúster de producto + variedad + presentación.

Responde ÚNICAMENTE en formato JSON válido:
[
  {
    "id_producto": "7790199602927",
    "nombre_base": "Harina de Trigo",
    "variante_sabor": "000",
    "marca": "Morixe",
    "envase": "Paquete",
    "es_marca_blanca": false,
    "contenido_neto": 1.0,
    "unidad_medida": "kg",
    "pack_unidades": 1,
    "categoria": "Almacén",
    "confianza": 0.99
  }
]
"""

def validar_item_respuesta(item: dict) -> dict:
    """Valida y genera de forma matemática determinista el cluster_id canónico sin alucinaciones"""
    if not isinstance(item, dict):
        return None
    id_p = str(item.get("id_producto", "")).strip()
    if not id_p:
        return None

    # Extraer variables atómicas devueltas por el LLM
    nb = str(item.get("nombre_base") or item.get("nombre") or item.get("producto") or "").strip()
    vs = str(item.get("variante_sabor") or item.get("variedad_sabor") or item.get("variedad") or "Clásico").strip()
    marca = str(item.get("marca") or "").strip()
    envase = str(item.get("envase") or "").strip()
    
    # Contenido neto y unidad
    cn_raw = item.get("contenido_neto")
    try:
        cn = float(cn_raw) if cn_raw is not None and str(cn_raw).strip() != "" else 1.0
    except (ValueError, TypeError):
        cn = 1.0
    
    um = str(item.get("unidad_medida") or item.get("unidad_referencia") or "kg").strip().lower()
    
    pack_raw = item.get("pack_unidades", 1)
    try:
        pack = int(pack_raw) if pack_raw is not None else 1
    except (ValueError, TypeError):
        pack = 1

    categoria = str(item.get("categoria") or "Almacén").strip()

    # Construcción matemática infalible del clúster canónico
    cluster_res = construir_cluster_canonico(
        nombre_base=nb,
        variedad_sabor=vs,
        marca=marca,
        envase=envase,
        contenido_neto=cn,
        unidad_medida=um,
        pack_unidades=pack,
        categoria=categoria
    )

    try:
        conf = float(item.get("confianza", 1.0))
        conf = max(0.0, min(1.0, conf))
    except (ValueError, TypeError):
        conf = 1.0

    return {
        "id_producto": id_p,
        "cluster_id": cluster_res["cluster_id"],
        "nombre_canonico": cluster_res["nombre_canonico"],
        "producto": cluster_res["producto"],
        "variedad": cluster_res["variedad"],
        "presentacion": cluster_res["presentacion"],
        "marca": cluster_res["marca"],
        "envase": cluster_res["envase"],
        "categoria": cluster_res["categoria"],
        "contenido_neto": cluster_res["contenido_neto"],
        "unidad_referencia": cluster_res["unidad_referencia"],
        "confianza": conf
    }

def llamar_gemini(items: list, api_key: str) -> tuple:
    """
    Envía un lote de productos a IA para clustering.
    Estrategia híbrida:
    1. Primario: Modelos Free de OpenRouter (NVIDIA Nemotron 120B, Cohere North Mini, LiquidAI) a costo $0.
    2. Fallback: Google Gemini (gemini-flash-lite-latest / gemini-2.5-flash) ante 429, timeout o error.
    Devuelve: (items_validados, modelo_utilizado)
    """
    prompt_contenido = "Clasifica y agrupa los siguientes productos:\n" + json.dumps(items, ensure_ascii=False, indent=2)

    # 1. INTENTO CON MODELOS FREE DE OPENROUTER
    if OPENROUTER_API_KEY:
        h_or = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
            "User-Agent": "Cline/3.0",
            "HTTP-Referer": "https://cline.bot",
            "X-Title": "Cline"
        }
        for or_model in OPENROUTER_FREE_MODELS:
            payload_or = {
                "model": or_model,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt_contenido}
                ],
                "temperature": 0.1
            }
            try:
                res_or = requests.post("https://openrouter.ai/api/v1/chat/completions", headers=h_or, json=payload_or, timeout=20)
                if res_or.status_code == 200:
                    c_or = res_or.json().get("choices", [{}])[0].get("message", {}).get("content", "").strip()
                    if c_or.startswith("```"):
                        lineas = c_or.split("\n")
                        if lineas[0].startswith("```"): lineas = lineas[1:]
                        if lineas and lineas[-1].strip() == "```": lineas = lineas[:-1]
                        c_or = "\n".join(lineas).strip()
                    try:
                        raw_list = json.loads(c_or)
                        if isinstance(raw_list, list) and len(raw_list) > 0:
                            items_validados = [validar_item_respuesta(it) for it in raw_list]
                            items_validados = [v for v in items_validados if v]
                            if items_validados:
                                return items_validados, f"openrouter/{or_model}"
                    except Exception:
                        pass
                elif res_or.status_code in (429, 403, 503):
                    pass  # Conmuta rápidamente al siguiente
            except Exception:
                pass

    # 2. FALLBACK A GOOGLE GEMINI
    if not api_key:
        raise ValueError("GEMINI_API_KEY no está configurada en config.json")
        
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": SYSTEM_PROMPT},
                    {"text": prompt_contenido}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json"
        }
    }
    
    headers = {"Content-Type": "application/json"}
    
    for ciclo in range(3):
        for modelo_info in MODELOS_CASCADA_GEMINI:
            model_name = modelo_info["name"]
            url = f"{modelo_info['url']}?key={api_key}"
            
            try:
                res = requests.post(url, headers=headers, json=payload, timeout=30)
                if res.status_code == 429:
                    print(f"    [!] Rate limit (429) en {model_name}. Conmutando al modelo de respaldo...")
                    continue  # Pasa inmediatamente al siguiente modelo de la lista
                    
                if res.status_code != 200:
                    print(f"    [-] HTTP {res.status_code} en {model_name}. Conmutando...")
                    continue
                
                data = res.json()
                cand = data.get("candidates", [])
                if not cand:
                    print(f"    [-] Sin candidatos en la respuesta de {model_name}.")
                    continue
                
                c0 = cand[0]
                finish_reason = c0.get("finishReason", "")
                
                # 1. Detección oficial de truncamiento por límite de tokens
                if finish_reason == "MAX_TOKENS":
                    print(f"\n    [ALERTA TRUNCAMIENTO] {model_name} alcanzó el límite máximo de tokens (MAX_TOKENS).")
                    print(f"    [!] La respuesta JSON quedó incompleta. Se recomienda reducir el tamaño del lote.")
                elif finish_reason and finish_reason not in ("STOP", ""):
                    print(f"    [!] Finalización atípica en {model_name}: finishReason='{finish_reason}'")

                texto = c0.get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                if texto.startswith("```"):
                    lineas = texto.split("\n")
                    if lineas[0].startswith("```"): lineas = lineas[1:]
                    if lineas and lineas[-1].strip() == "```": lineas = lineas[:-1]
                    texto = "\n".join(lineas).strip()
                
                # 2. Verificación sintáctica del JSON y recuperación parcial si está truncado
                try:
                    raw_list = json.loads(texto)
                except json.JSONDecodeError as jde:
                    print(f"\n    [ERROR JSON TRUNCADO] La respuesta de {model_name} no es un JSON válido ({jde}).")
                    print(f"    [!] Detalle: La salida se cortó en el caracter {jde.pos}. Intentando reparar cierre...")
                    # Intento de rescate si solo faltaba cerrar el array al final
                    raw_list = None
                    last_brace = texto.rfind("}")
                    if last_brace != -1:
                        try:
                            repaired_text = texto[:last_brace+1] + "\n]"
                            raw_list = json.loads(repaired_text)
                            print(f"    [RESCATE EXITOSO] Se recuperaron {len(raw_list)} items del bloque antes del corte.")
                        except Exception:
                            raw_list = None
                    if not raw_list:
                        continue

                if not isinstance(raw_list, list):
                    continue
                    
                items_validados = []
                for it in raw_list:
                    val = validar_item_respuesta(it)
                    if val:
                        items_validados.append(val)
                        
                # 3. Informar si la cantidad devuelta es menor a la solicitada
                if len(items_validados) < len(items):
                    print(f"    [AVISO] {model_name} devolvió {len(items_validados)}/{len(items)} items válidos.")

                if items_validados:
                    return items_validados, model_name
            except Exception as e:
                print(f"    [!] Conexión lenta o timeout en {model_name} ({e}). Conmutando...")
                continue
                
        espera = 15 * (ciclo + 1)
        print(f"    [!] Todos los modelos en espera de cuota. Aguardando {espera}s para reanudar...")
        time.sleep(espera)
        
    return [], "desconocido"

def cargar_clusters_existentes(clusters_dir: Path):
    """Carga los mapeos ya existentes para no reprocesar productos ya catalogados"""
    items_file = clusters_dir / "producto_cluster_items.csv"
    clusters_file = clusters_dir / "producto_clusters.csv"
    
    existentes_ids = set()
    df_items = None
    df_clusters = None
    
    if items_file.exists():
        df_items = pd.read_csv(items_file, dtype=str)
        existentes_ids = set(df_items["id_producto"].dropna().tolist())
        print(f"[+] Clústeres existentes cargados: {len(existentes_ids):,} productos ya asociados.")
    else:
        df_items = pd.DataFrame(columns=["id_producto", "cluster_id", "confianza", "modelo_ia"])
        
    if clusters_file.exists():
        df_clusters = pd.read_csv(clusters_file, dtype=str)
    else:
        df_clusters = pd.DataFrame(columns=["cluster_id", "nombre_canonico", "categoria"])
        
    return existentes_ids, df_items, df_clusters

def ejecutar_clustering(limite_lotes: int = None, tamano_lote: int = None, modelo: str = "flash-lite", recluster: bool = False, filtro: str = None):
    # Asignación automática: Flash-Lite -> 50 items | Flash -> 120 items
    mod_clean = (modelo or "flash-lite").lower().strip()
    if tamano_lote and tamano_lote > 0:
        batch_size = tamano_lote
    elif "lite" in mod_clean:
        batch_size = BATCH_SIZE_FLASH_LITE  # 50 items
    else:
        batch_size = BATCH_SIZE_FLASH       # 120 items
    
    print(f"[*] Iniciando proceso incremental de clustering por IA...")
    print(f"[*] Modo modelo: '{mod_clean}' | Configuración: Lotes de {batch_size} items")
    print(f"[*] Estrategia de IA: Primario OpenRouter Free (Nemotron 120B / Cohere / Liquid) -> Fallback Gemini Flash")
    
    cat_file = PROCESSED_DIR / "catalogo_productos.csv"
    if not cat_file.exists():
        print(f"[-] No se encontró {cat_file}. Ejecuta primero el paso 3 de refactorización.")
        return
        
    existentes_ids, df_items_total, df_clusters_total = cargar_clusters_existentes(CLUSTERS_DIR)
    
    df_cat = pd.read_csv(cat_file, dtype=str, low_memory=False)
    
    # Si se pide recluster o filtro específico
    if recluster or filtro:
        df_target = df_cat.copy()
        if filtro:
            termino = filtro.lower().strip()
            df_target = df_target[
                df_target["productos_descripcion"].str.lower().str.contains(termino, na=False) |
                df_target["productos_marca"].str.lower().str.contains(termino, na=False)
            ].copy()
            print(f"[+] Filtro aplicado '{filtro}': {len(df_target):,} productos encontrados.")
        if not recluster:
            df_nuevos = df_target[~df_target["id_producto"].isin(existentes_ids)].copy()
        else:
            df_nuevos = df_target
    else:
        df_nuevos = df_cat[~df_cat["id_producto"].isin(existentes_ids)].copy()

    # Descartar productos fuera del dominio de supermercado (libros, ropa, electro, etc.)
    # 1. Chequeo contra lista negra histórica de descartes
    blacklist_file = CLUSTERS_DIR / "productos_descartados_blacklist.csv"
    if blacklist_file.exists():
        try:
            df_bl = pd.read_csv(blacklist_file, dtype=str)
            bl_eans = set(df_bl["id_producto"].dropna())
            antes_bl = len(df_nuevos)
            df_nuevos = df_nuevos[~df_nuevos["id_producto"].isin(bl_eans)].copy()
            omitidos_bl = antes_bl - len(df_nuevos)
            if omitidos_bl > 0:
                print(f"[*] Blacklist histórica: {omitidos_bl:,} productos previamente descartados omitidos automáticamente.")
        except Exception:
            pass

    # 2. Filtro FMCG y reglas
    from filtro_fmcg import es_producto_supermercado
    mask_fmcg = df_nuevos.apply(
        lambda r: es_producto_supermercado(r.get("productos_descripcion", ""), r.get("productos_marca", "")),
        axis=1
    )
    descartados_fmcg = len(df_nuevos) - mask_fmcg.sum()
    if descartados_fmcg > 0:
        print(f"[*] Filtro FMCG: {descartados_fmcg:,} productos no-supermercado omitidos del clustering.")
    df_nuevos = df_nuevos[mask_fmcg].copy()

    total_nuevos = len(df_nuevos)
    print(f"[+] Total productos en catálogo: {len(df_cat):,}")
    print(f"[+] Productos válidos de supermercado pendientes de clustering: {total_nuevos:,}")
    
    if total_nuevos == 0:
        print("[OK] Todos los productos seleccionados ya cuentan con clúster asignado. Nada que hacer.")
        return
        
    # Preparar lotes
    items_nuevos = []
    for _, row in df_nuevos.iterrows():
        item = {
            "id": str(row.get("id_producto", "")).strip(),
            "desc": str(row.get("productos_descripcion", "")).strip(),
            "marca": str(row.get("productos_marca", "")).strip(),
            "cant": str(row.get("productos_cantidad_presentacion", "")).strip(),
            "um": str(row.get("productos_unidad_medida_presentacion", "")).strip()
        }
        
        # Si tiene datos de Open Food Facts, los añadimos para mejorar el contexto de Gemini
        if pd.notna(row.get("off_nombre")) and str(row.get("off_nombre")).strip() != "":
            item["off_nombre"] = str(row.get("off_nombre")).strip()
        if pd.notna(row.get("off_marca")) and str(row.get("off_marca")).strip() != "":
            item["off_marca"] = str(row.get("off_marca")).strip()
        if pd.notna(row.get("off_cantidad_num")):
            item["off_cantidad_num"] = float(row.get("off_cantidad_num"))
        if pd.notna(row.get("off_cantidad_str")) and str(row.get("off_cantidad_str")).strip() != "":
            item["off_cantidad_str"] = str(row.get("off_cantidad_str")).strip()
            
        items_nuevos.append(item)
        
    lotes = [items_nuevos[i:i + batch_size] for i in range(0, len(items_nuevos), batch_size)]
    if limite_lotes:
        lotes = lotes[:limite_lotes]
        print(f"[*] Modo prueba: limitado a los primeros {len(lotes)} lotes ({len(lotes)*batch_size} productos).")
        
    nuevos_items_rows = []
    nuevos_clusters_dict = {}
    
    t0 = time.time()
    for idx, lote in enumerate(lotes):
        sys.stdout.write(f"\r    Procesando lote {idx + 1}/{len(lotes)} ({len(lote)} items)...")
        sys.stdout.flush()
        
        respuestas, modelo_utilizado = llamar_gemini(lote, GEMINI_API_KEY)
        for r in respuestas:
            id_p = str(r.get("id_producto", "")).strip()
            c_id = str(r.get("cluster_id", "")).strip()
            n_canonico = str(r.get("nombre_canonico", "")).strip()
            cat = str(r.get("categoria", "")).strip()
            conf = r.get("confianza", 1.0)
            
            if id_p and c_id:
                nuevos_items_rows.append({
                    "id_producto": id_p,
                    "cluster_id": c_id,
                    "marca": str(r.get("marca", "")).strip(),
                    "envase": str(r.get("envase", "")).strip(),
                    "contenido_neto": r.get("contenido_neto"),
                    "unidad_referencia": str(r.get("unidad_referencia", "kg")).strip(),
                    "confianza": str(conf),
                    "modelo_ia": modelo_utilizado
                })
                if c_id not in nuevos_clusters_dict:
                    nuevos_clusters_dict[c_id] = {
                        "cluster_id": c_id,
                        "nombre_canonico": n_canonico or c_id,
                        "producto": str(r.get("producto", "")).strip(),
                        "variedad": str(r.get("variedad", "")).strip(),
                        "presentacion": str(r.get("presentacion", "")).strip(),
                        "categoria": cat or "General"
                    }
                    
        # Checkpoint cada 5 lotes para guardar avance parcial
        if (idx + 1) % 5 == 0 or (idx + 1) == len(lotes):
            _guardar_avance(nuevos_items_rows, nuevos_clusters_dict, CLUSTERS_DIR)
            
        time.sleep(0.5)  # Respetar rate limit suave
        
    print()
    elapsed = time.time() - t0
    print(f"[OK] Proceso de IA completado en {elapsed:.1f}s.")
    print(f"    - Nuevos productos asociados: {len(nuevos_items_rows):,}")
    print(f"    - Nuevos clústeres identificados: {len(nuevos_clusters_dict):,}")

def _guardar_avance(nuevos_items: list, nuevos_clusters: dict, clusters_dir: Path):
    if not nuevos_items:
        return
        
    items_file = clusters_dir / "producto_cluster_items.csv"
    clusters_file = clusters_dir / "producto_clusters.csv"
    
    df_new_items = pd.DataFrame(nuevos_items)
    df_new_clusters = pd.DataFrame(list(nuevos_clusters.values()))
    
    if items_file.exists():
        df_old_items = pd.read_csv(items_file, dtype=str)
        df_merged_items = pd.concat([df_old_items, df_new_items], ignore_index=True).drop_duplicates(subset=["id_producto"], keep="last")
    else:
        df_merged_items = df_new_items
        
    if clusters_file.exists():
        df_old_clusters = pd.read_csv(clusters_file, dtype=str)
        df_merged_clusters = pd.concat([df_old_clusters, df_new_clusters], ignore_index=True).drop_duplicates(subset=["cluster_id"], keep="last")
    else:
        df_merged_clusters = df_new_clusters
        
    df_merged_items.to_csv(items_file, index=False, encoding="utf-8")
    df_merged_clusters.to_csv(clusters_file, index=False, encoding="utf-8")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Clustering IA incremental de productos SEPA")
    parser.add_argument("--lotes", type=int, help="Límite de lotes a procesar para pruebas (ej: 2)")
    parser.add_argument("--batch-size", type=int, help="Cantidad de productos por lote (def: 50 para Flash-Lite, 120 para Flash)")
    parser.add_argument("--modelo", choices=["flash", "flash-lite"], default="flash-lite", help="Modelo de Gemini a utilizar (def: flash-lite)")
    parser.add_argument("--recluster", action="store_true", help="Fuerza reclustering ignorando asociaciones previas")
    parser.add_argument("--filtro", type=str, help="Filtra productos a procesar por palabra clave (ej: 'tomate', 'pan rallado', 'rollo')")
    args = parser.parse_args()
    
    ejecutar_clustering(limite_lotes=args.lotes, tamano_lote=args.batch_size, modelo=args.modelo, recluster=args.recluster, filtro=args.filtro)
