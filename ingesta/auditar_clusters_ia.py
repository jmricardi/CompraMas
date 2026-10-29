#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
auditar_clusters_ia.py
-----------------------
Auditor de Control de Calidad de Clústeres mediante Inteligencia Artificial (OpenRouter / Gemini).

Evalúa la coherencia semántica de los clústeres de productos:
1. Detecta intrusos de variedad (ej. descremada vs entera, clásica vs saborizada).
2. Detecta intrusos de tamaño/gramaje (ej. 1 kg mezclado con 500 g).
3. Detecta contaminación de marca en el nombre canónico.
4. Genera un reporte detallado con puntajes de coherencia y lista de discrepancias.

Uso:
    python auditar_clusters_ia.py --lotes 5 --tamano-lote 10
    python auditar_clusters_ia.py --filtro "leche"
    python auditar_clusters_ia.py --filtro "tomate"
"""

import os
import sys
import json
import time
import argparse
import requests
import pandas as pd
from pathlib import Path
from datetime import datetime

# Rutas del proyecto
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
CLUSTERS_DIR = DATA_DIR / "clusters"

from config import OPENROUTER_API_KEY, GEMINI_API_KEY

OPENROUTER_MODELS = [
    "thinkingmachines/inkling-small:free",
    "thinkingmachines/inkling:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
]

AUDIT_SYSTEM_PROMPT = """Eres el Auditor Senior de Control de Calidad de un sistema de comparación de precios de supermercados.
Tu trabajo es auditar CLÚSTERES de productos.
Un clúster debe agrupar ÚNICAMENTE productos que sean SUSTITUTOS DIRECTOS EQUIVALENTES:
- Mismo tipo de producto base.
- Misma variedad o sabor (NO mezclar leche entera con descremada, NO mezclar puré clásico con puré con albahaca o pizzero, NO mezclar aceite de oliva con girasol, NO mezclar harina 000 con leudante).
- Mismo contenido neto / gramaje equivalente (margen de tolerancia: +-5%).
- Los productos pueden ser de DISTINTAS marcas (eso es lo esperado y deseable).

Para cada clúster evaluado debes responder en JSON una lista de objetos con esta estructura estricta:
[
  {
    "cluster_id": "string",
    "estado": "CORRECTO" | "INTRUSO_DETECTADO" | "MARCA_EN_NOMBRE" | "HETEROGENEO",
    "coherencia_score": 1 a 10,
    "tiene_marca_en_nombre": true | false,
    "sugerencia_nombre": "Nombre canónico neutral sin marca si tiene_marca_en_nombre es true, sino null",
    "intrusos": [
      {
        "id_producto": "código de barras EAN",
        "motivo": "explicación clara (ej: es descremada, es de 1kg, es salsa en lugar de puré)"
      }
    ],
    "observaciones": "Breve diagnóstico del clúster"
  }
]
Responde ÚNICAMENTE el JSON válido sin texto adicional.
"""

def consultar_ia(clusters_data: list) -> list:
    """Envía un lote de clústeres a OpenRouter Free o Gemini para auditoría"""
    prompt = "Audita la coherencia de los siguientes clústeres y sus productos asignados:\n" + json.dumps(clusters_data, ensure_ascii=False, indent=2)

    # 1. OpenRouter Free
    if OPENROUTER_API_KEY:
        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
            "User-Agent": "Cline/3.0",
            "HTTP-Referer": "https://cline.bot",
            "X-Title": "Cline"
        }
        for model in OPENROUTER_MODELS:
            payload = {
                "model": model,
                "messages": [
                    {"role": "system", "content": AUDIT_SYSTEM_PROMPT},
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.1
            }
            try:
                res = requests.post("https://openrouter.ai/api/v1/chat/completions", headers=headers, json=payload, timeout=25)
                if res.status_code == 200:
                    text = res.json().get("choices", [{}])[0].get("message", {}).get("content", "").strip()
                    if text.startswith("```"):
                        lines = text.split("\n")
                        if lines[0].startswith("```"): lines = lines[1:]
                        if lines and lines[-1].strip() == "```": lines = lines[:-1]
                        text = "\n".join(lines).strip()
                    parsed = json.loads(text)
                    if isinstance(parsed, list):
                        return parsed
            except Exception:
                pass

    # 2. Fallback a Gemini Flash
    if GEMINI_API_KEY:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [
                {"parts": [{"text": AUDIT_SYSTEM_PROMPT}, {"text": prompt}]}
            ],
            "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"}
        }
        try:
            res = requests.post(url, json=payload, timeout=25)
            if res.status_code == 200:
                text = res.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
                parsed = json.loads(text)
                if isinstance(parsed, list):
                    return parsed
        except Exception as e:
            print(f"[-] Error en fallback Gemini: {e}")

    return []

def ejecutar_auditoria(
    filtro: str = None,
    limite_lotes: int = 5,
    tamano_lote: int = 10,
    min_productos: int = 2
):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
    print("=" * 65)
    print(" AUDITORÍA DE CALIDAD DE CLÚSTERES CON IA (OPENROUTER / GEMINI)")
    print("=" * 65)

    clusters_csv = CLUSTERS_DIR / "producto_clusters.csv"
    items_csv = CLUSTERS_DIR / "producto_cluster_items.csv"
    cat_csv = PROCESSED_DIR / "catalogo_productos.csv"

    if not clusters_csv.exists() or not items_csv.exists():
        print("[-] No se encontraron los archivos de clústeres en data/clusters/")
        return

    print("[*] Cargando datos locales...")
    df_clusters = pd.read_csv(clusters_csv, dtype=str)
    df_items = pd.read_csv(items_csv, dtype=str)
    
    df_cat = pd.DataFrame()
    if cat_csv.exists():
        df_cat = pd.read_csv(cat_csv, dtype=str).set_index("id_producto")

    # Contar productos por clúster
    conteos = df_items.groupby("cluster_id").size().reset_index(name="cant_prods")
    df_clusters = df_clusters.merge(conteos, on="cluster_id", how="left")
    df_clusters["cant_prods"] = df_clusters["cant_prods"].fillna(0).astype(int)

    # Filtrar por cantidad mínima de productos
    df_auditar = df_clusters[df_clusters["cant_prods"] >= min_productos].copy()

    # Filtro opcional por texto
    if filtro:
        f_lower = filtro.lower()
        mask = (
            df_auditar["cluster_id"].str.lower().str.contains(f_lower, na=False) |
            df_auditar["nombre_canonico"].str.lower().str.contains(f_lower, na=False)
        )
        df_auditar = df_auditar[mask]
        print(f"[+] Filtro aplicado '{filtro}': {len(df_auditar)} clústeres candidatos.")
    else:
        print(f"[+] Total clústeres multimarca (>= {min_productos} productos): {len(df_auditar)}")

    # Ordenar por los clústeres más poblados (mayor probabilidad de variedad de marcas y riesgo)
    df_auditar = df_auditar.sort_values(by="cant_prods", ascending=False).reset_index(drop=True)

    total_disponibles = len(df_auditar)
    max_clusters = limite_lotes * tamano_lote if limite_lotes else total_disponibles
    df_auditar = df_auditar.head(max_clusters)
    print(f"[*] Clústeres a auditar en esta sesión: {len(df_auditar)} (divididos en lotes de {tamano_lote})")

    # Mapear productos por clúster con sus metadatos reales
    items_por_cluster = {}
    for _, row in df_items.iterrows():
        cid = row["cluster_id"]
        pid = row["id_producto"]
        if cid not in items_por_cluster:
            items_por_cluster[cid] = []
        
        desc = ""
        marca = ""
        if pid in df_cat.index:
            cat_row = df_cat.loc[pid]
            if isinstance(cat_row, pd.DataFrame): cat_row = cat_row.iloc[0]
            desc = str(cat_row.get("productos_descripcion") or "")
            marca = str(cat_row.get("productos_marca") or "")

        items_por_cluster[cid].append({
            "id_producto": pid,
            "descripcion": desc,
            "marca": marca,
            "contenido_neto": str(row.get("contenido_neto") or ""),
            "unidad": str(row.get("unidad_referencia") or "")
        })

    # Procesar por lotes
    reporte_final = []
    total_lotes = (len(df_auditar) + tamano_lote - 1) // tamano_lote
    t0 = time.time()

    for idx in range(0, len(df_auditar), tamano_lote):
        lote_num = (idx // tamano_lote) + 1
        chunk = df_auditar.iloc[idx : idx + tamano_lote]
        
        payload_lote = []
        for _, c_row in chunk.iterrows():
            cid = c_row["cluster_id"]
            payload_lote.append({
                "cluster_id": cid,
                "nombre_canonico": c_row.get("nombre_canonico", ""),
                "categoria": c_row.get("categoria", ""),
                "cantidad_productos": int(c_row.get("cant_prods", 0)),
                "productos": items_por_cluster.get(cid, [])[:15]  # tope 15 productos representativos
            })

        print(f"    Auditor IA: Procesando lote {lote_num}/{total_lotes} ({len(payload_lote)} clústeres)...")
        dictamen = consultar_ia(payload_lote)
        if dictamen:
            reporte_final.extend(dictamen)
        else:
            print(f"    [!] Lote {lote_num} no obtuvo respuesta válida de IA.")
        time.sleep(1)

    # Resultados y Estadísticas
    duracion = time.time() - t0
    print("\n" + "=" * 65)
    print(f" RESUMEN DE AUDITORÍA DE CALIDAD ({duracion:.1f}s)")
    print("=" * 65)

    if not reporte_final:
        print("[-] No se generaron dictámenes de auditoría.")
        return

    # Guardar reporte en disco inmediatamente
    out_json = CLUSTERS_DIR / "reporte_auditoria.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(reporte_final, f, ensure_ascii=False, indent=2)

    total_auditados = len(reporte_final)
    correctos = sum(1 for r in reporte_final if r.get("estado") == "CORRECTO")
    con_intrusos = sum(1 for r in reporte_final if r.get("intrusos"))
    con_marca_nombre = sum(1 for r in reporte_final if r.get("tiene_marca_en_nombre"))
    promedio_score = sum(float(r.get("coherencia_score", 10)) for r in reporte_final) / total_auditados

    print(f"[*] Total Clústeres Auditados:      {total_auditados}")
    print(f"[OK] Clústeres 100% Correctos:       {correctos} ({correctos/total_auditados*100:.1f}%)")
    print(f"[!] Clústeres con Intrusos:         {con_intrusos} ({con_intrusos/total_auditados*100:.1f}%)")
    print(f"[!] Clústeres con Marca en Nombre:  {con_marca_nombre} ({con_marca_nombre/total_auditados*100:.1f}%)")
    print(f"[*] Coherencia Promedio:            {promedio_score:.1f} / 10.0")

    # Mostrar detalles de anomalías detectadas
    anomalias = [r for r in reporte_final if r.get("estado") != "CORRECTO" or r.get("intrusos")]
    if anomalias:
        print("\n" + "-" * 65)
        print(" DETALLE DE DISCREPANCIAS Y ANOMALÍAS ENCONTRADAS:")
        print("-" * 65)
        for anom in anomalias[:10]:
            cid = anom.get("cluster_id")
            score = anom.get("coherencia_score")
            estado = anom.get("estado")
            obs = anom.get("observaciones")
            intrusos = anom.get("intrusos", [])
            print(f"\n[!] Clúster: {cid} (Score: {score}/10 | Estado: {estado})")
            if anom.get("tiene_marca_en_nombre"):
                print(f"    -> Marca en título. Sugerencia: '{anom.get('sugerencia_nombre')}'")
            if intrusos:
                for intr in intrusos:
                    print(f"    -> Intruso EAN {intr.get('id_producto')}: {intr.get('motivo')}")
            if obs:
                print(f"    -> Observación: {obs}")
    else:
        print("\n[OK] ¡Felicidades! Todos los clústeres auditados mostraron 100% de coherencia y pureza.")

    print(f"\n[OK] Reporte completo guardado en: {out_json}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auditoría de Calidad de Clústeres con IA")
    parser.add_argument("--filtro", type=str, help="Filtra clústeres por nombre o ID (ej: 'leche', 'tomate', 'aceite')")
    parser.add_argument("--lotes", type=int, default=5, help="Cantidad de lotes a auditar (def: 5)")
    parser.add_argument("--tamano-lote", type=int, default=10, help="Clústeres por lote de IA (def: 10)")
    parser.add_argument("--min-prods", type=int, default=2, help="Mínimo de productos asociados por clúster (def: 2)")
    args = parser.parse_args()

    ejecutar_auditoria(
        filtro=args.filtro,
        limite_lotes=args.lotes,
        tamano_lote=args.tamano_lote,
        min_productos=args.min_prods
    )
