#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Auditoría Taxonómica de Clusters mediante LLM (OpenRouter / Gemini)
Detecta y corrige:
1. Tokens huérfanos numéricos o fraccionarios ("0000", "1", "1/2", etc.)
2. Fusión de productos heterogéneos bajo un mismo nodo numérico
3. Detección y descarte de fármacos / medicamentos éticos con receta
4. Normalización de Producto Básico vs Marca vs Variedad

Modelos soportados en cascada:
1. nvidia/nemotron-3-ultra-550b-a55b:free (OpenRouter - 550B params, Free)
2. nvidia/nemotron-3-super-120b-a12b:free / nvidia/nemotron-3.5-lightning:free (OpenRouter)
3. thinkingmachines/inkling-small / thinkingmachines/inkling (OpenRouter)
4. gemini-2.5-flash-lite (Google AI Studio - Fallback)
"""

import os
import sys
import json
import time
import re
import argparse
from typing import List, Dict, Any, Optional
import requests

from config import (
    BASE_DIR,
    CLUSTERS_DIR,
    OPENROUTER_API_KEY,
    GEMINI_API_KEY,
)

INPUT_JSON_PATH = CLUSTERS_DIR / "arbol_clusters_auditoria.json"
CHECKPOINT_PATH = CLUSTERS_DIR / "auditoria_checkpoint.json"
REPORTE_PATH = CLUSTERS_DIR / "reporte_auditoria.json"
OUTPUT_DEPURADO_PATH = CLUSTERS_DIR / "arbol_clusters_depurado.json"

# Modelos en orden de prioridad
OPENROUTER_MODELS = [
    "nvidia/nemotron-3-ultra-550b-a55b:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
    "nvidia/nemotron-3.5-lightning:free",
    "thinkingmachines/inkling-small:free",
    "thinkingmachines/inkling:free",
]

PROMPT_SISTEMA = """Eres un auditor senior experto en catalogación y taxonomía de productos de consumo masivo (CPG / Supermercados) de la República Argentina.
Tu tarea es auditar un lote de productos y normalizar su jerarquía taxonómica:
- Producto Básico (Sustantivo genérico del alimento o producto de consumo masivo, ej: "Harina de trigo", "Huevos de gallina", "Pollo", "Leche infantil").
- Variedad (ej: "0000", "Media docena", "Entero", "Trozado", "Etapa 1").
- Categoría ("Almacén", "Frescos", "Bebidas", "Limpieza", "Perfumería", "Librería", "Descartar").

Reglas de Negocio Estrictas:
1. ALCANCE DEL CATÁLOGO DE CONSUMO MASIVO:
   El catálogo de CompraMas incluye ÚNICAMENTE:
   - Alimentos y Bebidas ("Almacén", "Frescos", "Bebidas")
   - Artículos de Limpieza del hogar ("Limpieza")
   - Perfumería y Cuidado personal ("Perfumería")
   - Librería, útiles escolares y papelería ("Librería": cuadernos, lápices, bolígrafos, resmas, marcadores, etc. -> SÍ SE INCLUYEN)

   TODO LO DEMÁS SE DEBE DESCARTAR OBLIGATORIAMENTE con "accion": "descartar" (BAJO NINGÚN CONCEPTO CORREGIR A NOMBRE GENÉRICO; SI ES ELECTRODOMÉSTICO, TECNOLOGÍA, JUGUETE O MUEBLE, SIEMPRE DEBE DESCARTARSE):
   - JUGUETES Y JUEGOS (muñecos, autitos, peluches, juegos de mesa, inflables, cotillón):
     "accion": "descartar", "motivo": "juguetes_entretenimiento"
   - JARDINERÍA (macetas, plantas, tierra, fertilizantes, mangueras, regaderas, podadoras):
     "accion": "descartar", "motivo": "jardineria"
   - MUEBLES (mesas, sillas, sillones, estanterías, placares, colchones):
     "accion": "descartar", "motivo": "muebles"
   - ELECTRODOMÉSTICOS Y TECNOLOGÍA (microondas, televisores, heladeras, pavas eléctricas, licuadoras, lavarropas, celulares, audio, etc.):
     "accion": "descartar", "motivo": "electrodomestico_tecnologia" (¡NO CORREGIR A 'Horno microondas' O SIMILAR, DESCARTAR DIRECTAMENTE!)
   - FÁRMACOS Y MEDICAMENTOS DE FARMACIA (comprimidos, antibióticos, ansiolíticos, inyectables, anestésicos con droga activa):
     "accion": "descartar", "motivo": "medicamento_farmacia"
   - BAZAR DURADERO, INDUMENTARIA, FERRETERÍA, AUTOMOTRIZ, DEPORTES/CAMPING:
     "accion": "descartar", "motivo": "no_cpg"

2. PRODUCTOS NUMÉRICOS O INCOMPLETOS:
   Si el "producto_basico" es un número ("0000", "1", "10", "12", "1/2"), reconstruye el sustantivo común a partir de los nombres comerciales de los miembros:
   - "0000" con miembros "Harina Pureza 4/0" -> producto_basico: "Harina de trigo", variedad: "0000".
   - Si un nodo "1" contiene productos totalmente incompatibles (ej. huevos, pollo y leche vital 1), márcalo con "accion": "dividir" y devuelve la lista en "particiones".

3. SEPARACIÓN MARCA COMERCIAL VS PRODUCTO:
   El producto básico NUNCA debe incluir la marca (ej: NO poner "Harina Pureza", poner "Harina de trigo").

4. REGLA ESTRICTA DE VARIEDAD (SIN REDUNDANCIA NI MARCAS):
   - La variedad NUNCA debe contener el nombre del producto básico (ej: en Leche, poner "Chocolatada", NUNCA "Leche Chocolatada"; en Harina, poner "0000", NUNCA "Harina 0000").
   - La variedad NUNCA debe incluir marcas comerciales (ej: NO poner "Sin TACC Pérgola", poner "Sin TACC").

5. PREMEZCLAS Y MEZCLAS:
   - Toda premezcla o mezcla para panadería, repostería, pizza o masa madre debe tener producto_basico: "Premezcla" (ej: "Premezcla", variedad: "Masa Madre Sin TACC"), NUNCA "Harina".

Devuelve ÚNICAMENTE un objeto JSON válido con la clave "auditorias", sin markdown adicional ni comentarios.
IMPORTANTE - AHORRO DE TOKENS:
Incluye en "auditorias" ÚNICAMENTE los productos que requieran acción ("descartar", "corregir", "dividir").
Los productos que estén bien y pertenezcan al consumo masivo NO los incluyas (se asumirán como correctos automáticamente):
{
  "auditorias": [
    {
      "producto_original": "string",
      "accion": "corregir" | "descartar" | "dividir",
      "producto_basico_sugerido": "string",
      "variedad_sugerida": "string",
      "categoria_sugerida": "string",
      "motivo": "string",
      "particiones": [
        {
          "producto_basico": "string",
          "variedad": "string",
          "cluster_ids_afectados": ["id1", "id2"]
        }
      ]
    }
  ]
}"""

def call_openrouter(prompt_usuario: str, model_name: str) -> Optional[str]:
    """Realiza una llamada a la API de OpenRouter."""
    if not OPENROUTER_API_KEY:
        return None
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://compramas.app",
        "X-Title": "CompraMas Catalog Auditor"
    }
    payload = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": PROMPT_SISTEMA},
            {"role": "user", "content": prompt_usuario}
        ],
        "temperature": 0.1,
    }
    try:
        r = requests.post(url, headers=headers, json=payload, timeout=45)
        if r.status_code == 200:
            data = r.json()
            choices = data.get("choices", [])
            if choices:
                return choices[0].get("message", {}).get("content", "")
        else:
            print(f"      [!] OpenRouter {model_name} HTTP {r.status_code}: {r.text[:120]}")
    except Exception as e:
        print(f"      [!] Error en OpenRouter {model_name}: {e}")
    return None

def call_gemini_fallback(prompt_usuario: str) -> Optional[str]:
    """Fallback directo con Gemini 2.5 Flash-Lite vía Google AI Studio."""
    if not GEMINI_API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={GEMINI_API_KEY}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": f"{PROMPT_SISTEMA}\n\nDatos a auditar:\n{prompt_usuario}"}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json"
        }
    }
    try:
        r = requests.post(url, headers=headers, json=payload, timeout=30)
        if r.status_code == 200:
            data = r.json()
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                if parts:
                    return parts[0].get("text", "")
        else:
            print(f"      [!] Gemini Flash-Lite HTTP {r.status_code}: {r.text[:120]}")
    except Exception as e:
        print(f"      [!] Error en Gemini Flash-Lite: {e}")
    return None

def consultar_llm_en_cascada(prompt_usuario: str) -> Optional[Dict[str, Any]]:
    """Consulta secuencialmente OpenRouter y fallback a Gemini."""
    for model in OPENROUTER_MODELS:
        raw_text = call_openrouter(prompt_usuario, model)
        if raw_text:
            cleaned = _limpiar_json_markdown(raw_text)
            try:
                parsed = json.loads(cleaned)
                if "auditorias" in parsed:
                    return parsed
            except Exception:
                pass
    
    # Fallback a Gemini
    raw_text = call_gemini_fallback(prompt_usuario)
    if raw_text:
        cleaned = _limpiar_json_markdown(raw_text)
        try:
            parsed = json.loads(cleaned)
            if "auditorias" in parsed:
                return parsed
        except Exception:
            pass
    return None

def _limpiar_json_markdown(text: str) -> str:
    """Extrae bloques de código JSON o remueve delimitadores markdown."""
    clean = text.strip()
    if "```json" in clean:
        clean = clean.split("```json")[1].split("```")[0].strip()
    elif "```" in clean:
        clean = clean.split("```")[1].split("```")[0].strip()
    return clean

def es_candidato_sospechoso(prod_entry: Dict[str, Any]) -> bool:
    """Heurística rápida para identificar clusters con alta probabilidad de error."""
    nombre = prod_entry.get("producto_basico", "").strip()
    # 1. Solo dígitos o fracciones
    if re.match(r"^\d+(\s*[\/%-]\s*\d+)?$", nombre):
        return True
    # 2. Muy corto (<= 2 caracteres)
    if len(nombre) <= 2:
        return True
    # 3. Fármacos conocidos o dosis en mg/ml
    patron_med = r"\b(\d+\s*mg\b|\d+\s*ml\b|comp\b|comprimidos|gotas|capsulas|recubiertos|sildenafil|ibuprofeno|paracetamol|amoxicilina|loratadina|aspirina|clonazepam|omeprazol)\b"
    if re.search(patron_med, nombre, re.IGNORECASE):
        return True
    # 4. Variedades con disparidad evidente
    variedades = [v.get("variedad", "") for v in prod_entry.get("variedades", [])]
    if any(re.match(r"^\d", v.strip()) for v in variedades):
        return True
    return False

def preparar_resumen_cluster(prod_entry: Dict[str, Any]) -> Dict[str, Any]:
    nombre = prod_entry.get("producto_basico", "").strip()
    variedades = [v.get("variedad", "").strip() for v in prod_entry.get("variedades", [])[:5] if v.get("variedad")]
    muestras = []
    for v in prod_entry.get("variedades", [])[:2]:
        for pr in v.get("presentaciones", [])[:2]:
            for c in pr.get("contenidos", [])[:2]:
                for m in c.get("marcas_miembros", [])[:2]:
                    nom = m.get("nombre_comercial") or m.get("descripcion")
                    if nom:
                        muestras.append(str(nom)[:45].strip())
    return {
        "producto": nombre,
        "variedades": variedades[:3],
        "muestras": muestras[:2]
    }

def ejecutar_auditoria(limite: Optional[int] = None, solo_sospechosos: bool = True, batch_size: int = 10):
    print("=" * 70)
    print(" INICIANDO AUDITORÍA TAXONÓMICA CON MODELOS OPENROUTER / GEMINI")
    print("=" * 70)
    print(f"[*] Archivo fuente: {INPUT_JSON_PATH}")

    if not INPUT_JSON_PATH.exists():
        print(f"[ERROR] No se encontró {INPUT_JSON_PATH}")
        return

    with open(INPUT_JSON_PATH, "r", encoding="utf-8") as f:
        catalogo = json.load(f)

    total_prods = len(catalogo)
    print(f"[*] Total de productos básicos en catálogo: {total_prods}")

    # Filtrar universo de trabajo
    if solo_sospechosos:
        candidatos = [p for p in catalogo if es_candidato_sospechoso(p)]
        print(f"[*] Filtro heurístico: {len(candidatos)} productos sospechosos detectados para auditar.")
    else:
        candidatos = catalogo
        print(f"[*] Modo completo: {len(candidatos)} productos para auditar.")

    if limite:
        candidatos = candidatos[:limite]
        print(f"[*] Límite de prueba aplicado: {len(candidatos)} productos a procesar.")

    # Cargar checkpoint previo si existe
    checkpoint = {}
    if CHECKPOINT_PATH.exists():
        try:
            with open(CHECKPOINT_PATH, "r", encoding="utf-8") as f:
                checkpoint = json.load(f)
            print(f"[*] Checkpoint recuperado: {len(checkpoint)} productos ya auditados.")
        except Exception:
            checkpoint = {}

    reporte_auditorias = checkpoint.copy()
    items_a_procesar = [p for p in candidatos if p["producto_basico"] not in reporte_auditorias]
    print(f"[*] Pendientes por auditar en este ciclo: {len(items_a_procesar)}")

    # Procesar en lotes (batches)
    num_batches = (len(items_a_procesar) + batch_size - 1) // batch_size
    for i in range(num_batches):
        batch = items_a_procesar[i * batch_size : (i + 1) * batch_size]
        nombres_batch = [p["producto_basico"] for p in batch]
        print(f"\n[Batch {i+1}/{num_batches}] Auditando {len(batch)} productos: {nombres_batch}...")

        batch_compacto = [preparar_resumen_cluster(p) for p in batch]
        prompt_input = json.dumps(batch_compacto, ensure_ascii=False, indent=2)

        respuesta = consultar_llm_en_cascada(prompt_input)
        if respuesta and "auditorias" in respuesta:
            observados = set()
            for item in respuesta["auditorias"]:
                orig = item.get("producto_original") or item.get("producto_basico_original")
                if orig:
                    observados.add(orig)
                    reporte_auditorias[orig] = item
                    print(f"   -> [{item.get('accion', 'ok').upper()}] '{orig}': {item.get('motivo', '')} -> {item.get('producto_basico_sugerido', '')}")

            # Los productos del lote no observados se confirman como mantener
            for p in batch:
                pb = p.get("producto_basico", "").strip()
                if pb and pb not in observados and pb not in reporte_auditorias:
                    reporte_auditorias[pb] = {
                        "producto_original": pb,
                        "accion": "mantener",
                        "categoria_sugerida": p.get("categoria", "Almacén"),
                        "motivo": "auditado_ok_llm"
                    }

            with open(CHECKPOINT_PATH, "w", encoding="utf-8") as f:
                json.dump(reporte_auditorias, f, ensure_ascii=False, indent=2)
        else:
            print("   [!] No se pudo obtener respuesta válida del LLM para este lote.")

        time.sleep(2.0)

    # Generar reporte consolidado final
    print("\n" + "=" * 70)
    print(" GENERANDO REPORTE DE AUDITORÍA Y CATÁLOGO DEPURADO")
    print("=" * 70)

    with open(REPORTE_PATH, "w", encoding="utf-8") as f:
        json.dump(reporte_auditorias, f, ensure_ascii=False, indent=2)
    print(f"[OK] Reporte de auditoría guardado en: {REPORTE_PATH}")

    # Contadores
    descartados = sum(1 for v in reporte_auditorias.values() if v.get("accion") == "descartar")
    corregidos = sum(1 for v in reporte_auditorias.values() if v.get("accion") == "corregir")
    divididos = sum(1 for v in reporte_auditorias.values() if v.get("accion") == "dividir")
    mantenidos = sum(1 for v in reporte_auditorias.values() if v.get("accion") == "mantener")

    print(f"Resumen de auditoría:")
    print(f" - A descartar (medicamentos / fuera de rubro): {descartados}")
    print(f" - A corregir nombre / variedad:               {corregidos}")
    print(f" - A dividir (productos fusionados):           {divididos}")
    print(f" - A mantener sin cambios:                     {mantenidos}")

    aplicar_reporte_al_arbol()

def aplicar_reporte_al_arbol():
    """Toma el árbol original y el reporte de auditoría para emitir arbol_clusters_depurado.json."""
    if not REPORTE_PATH.exists() or not INPUT_JSON_PATH.exists():
        print("[!] No se encontró el árbol o el reporte de auditoría.")
        return

    with open(INPUT_JSON_PATH, "r", encoding="utf-8") as f:
        catalogo = json.load(f)
    with open(REPORTE_PATH, "r", encoding="utf-8") as f:
        reporte = json.load(f)

    from filtro_fmcg import es_producto_supermercado

    nuevo_catalogo_map = {}

    for prod in catalogo:
        nombre = prod.get("producto_basico", "")

        # Filtro de dominio FMCG (descarta juguetes, muebles, electro, jardinería, etc.)
        if not es_producto_supermercado(nombre):
            continue

        regla = reporte.get(nombre)

        if not regla:
            nuevo_catalogo_map[nombre] = prod
            continue

        accion = regla.get("accion", "mantener")
        categoria = (regla.get("categoria_sugerida") or "").lower()
        motivo = (regla.get("motivo") or "").lower()

        # Descarte si la acción es descartar o si fue catalogado fuera de rubro
        if (accion == "descartar" or
            "electrodomest" in categoria or
            "electrodomest" in motivo or
            "no contemplada" in motivo or
            categoria == "descartar" or
            "tecnologia" in categoria or
            "tecnologia" in motivo or
            "juguet" in categoria or
            "juguet" in motivo or
            "jardiner" in categoria or
            "jardiner" in motivo or
            "mueble" in categoria or
            "mueble" in motivo or
            "cotillon" in categoria or
            "cotillon" in motivo):
            continue

        elif accion == "corregir":
            nuevo_nombre = regla.get("producto_basico_sugerido") or nombre
            if not es_producto_supermercado(nuevo_nombre):
                continue
            nueva_variedad = regla.get("variedad_sugerida")

            prod_copia = json.loads(json.dumps(prod))
            prod_copia["producto_basico"] = nuevo_nombre
            if nueva_variedad and prod_copia.get("variedades"):
                for v in prod_copia["variedades"]:
                    if v.get("variedad") in ["Clásico", "Estándar", "0000", ""]:
                        v["variedad"] = nueva_variedad

            if nuevo_nombre in nuevo_catalogo_map:
                nuevo_catalogo_map[nuevo_nombre]["variedades"].extend(prod_copia.get("variedades", []))
            else:
                nuevo_catalogo_map[nuevo_nombre] = prod_copia

        elif accion == "dividir":
            particiones = regla.get("particiones", [])
            if not particiones:
                nuevo_catalogo_map[nombre] = prod
                continue

            clusters_map = {}
            for var in prod.get("variedades", []):
                for pres in var.get("presentaciones", []):
                    for cont in pres.get("contenidos", []):
                        cid = cont.get("cluster_id")
                        if cid:
                            clusters_map[cid] = (var, pres, cont)

            for part in particiones:
                p_nombre = part.get("producto_basico", "").strip()
                p_var = part.get("variedad", "").strip()
                c_ids = part.get("cluster_ids_afectados", [])
                if not p_nombre or not c_ids:
                    continue
                if not es_producto_supermercado(p_nombre):
                    continue

                if p_nombre not in nuevo_catalogo_map:
                    nuevo_catalogo_map[p_nombre] = {
                        "producto_basico": p_nombre,
                        "variedades": []
                    }

                nueva_var_entry = {
                    "variedad": p_var if p_var else "Estándar",
                    "presentaciones": []
                }
                
                pres_dict = {}
                for cid in c_ids:
                    if cid in clusters_map:
                        orig_var, orig_pres, cont = clusters_map[cid]
                        p_tipo = orig_pres.get("presentacion", "Estándar")
                        if p_tipo not in pres_dict:
                            pres_dict[p_tipo] = []
                        pres_dict[p_tipo].append(cont)

                for p_tipo, cont_list in pres_dict.items():
                    nueva_var_entry["presentaciones"].append({
                        "presentacion": p_tipo,
                        "contenidos": cont_list
                    })

                nuevo_catalogo_map[p_nombre]["variedades"].append(nueva_var_entry)
        else:
            nuevo_catalogo_map[nombre] = prod

    catalogo_final = list(nuevo_catalogo_map.values())
    catalogo_final.sort(key=lambda x: x.get("producto_basico", "").lower())

    with open(OUTPUT_DEPURADO_PATH, "w", encoding="utf-8") as f:
        json.dump(catalogo_final, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Catálogo depurado generado exitosamente en: {OUTPUT_DEPURADO_PATH}")
    print(f"Total productos depurados: {len(catalogo_final)} (Original: {len(catalogo)})")

    from sanitizar_catalogo_canonica import ejecutar_sanitizacion_canonica
    ejecutar_sanitizacion_canonica()

def sincronizar_csvs_desde_arbol_depurado(catalogo: List[Dict[str, Any]]):
    """Convierte el árbol depurado en producto_clusters.csv y producto_cluster_items.csv para Supabase."""
    print("[*] Sincronizando producto_clusters.csv y producto_cluster_items.csv...")

    clusters_rows = []
    items_rows = []
    vistos_cids = set()
    vistos_eans = set()

    for prod in catalogo:
        p_basico = prod.get("producto_basico", "").strip()
        cat = prod.get("categoria", "Almacén")

        for var in prod.get("variedades", []):
            v_nombre = var.get("variedad", "Estándar").strip()

            for pres in var.get("presentaciones", []):
                pr_nombre = pres.get("presentacion", "Estándar").strip()

                for cont in pres.get("contenidos", []):
                    cid = cont.get("cluster_id")
                    if not cid or cid in vistos_cids:
                        continue
                    vistos_cids.add(cid)

                    c_neto = cont.get("contenido_neto", {})
                    val = c_neto.get("valor", "")
                    uni = c_neto.get("unidad", "")
                    canonico = f"{p_basico} {v_nombre} {pr_nombre} {val} {uni}".strip()

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
                            "modelo_ia": "auditoria_llm_depurado"
                        })

    import pandas as pd
    df_clusters = pd.DataFrame(clusters_rows)
    df_items = pd.DataFrame(items_rows)

    c_path = CLUSTERS_DIR / "producto_clusters.csv"
    i_path = CLUSTERS_DIR / "producto_cluster_items.csv"

    df_clusters.to_csv(c_path, index=False, encoding="utf-8")
    df_items.to_csv(i_path, index=False, encoding="utf-8")

    print(f"[OK] Sincronizados exitosamente:")
    print(f"     - {c_path.name}: {len(df_clusters):,} clústeres canónicos.")
    print(f"     - {i_path.name}: {len(df_items):,} productos asociados a clústeres.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auditoría de clusters con LLM")
    parser.add_argument("--limit", type=int, default=None, help="Límite máximo de productos a auditar (para pruebas)")
    parser.add_argument("--all", action="store_true", help="Auditar todo el catálogo en lugar de solo sospechosos")
    parser.add_argument("--batch-size", type=int, default=50, help="Tamaño de lote por llamada al LLM")
    parser.add_argument("--apply", action="store_true", help="Aplica el reporte existente para generar el catálogo depurado")
    args = parser.parse_args()

    if args.apply:
        aplicar_reporte_al_arbol()
    else:
        ejecutar_auditoria(limite=args.limit, solo_sospechosos=not args.all, batch_size=args.batch_size)
