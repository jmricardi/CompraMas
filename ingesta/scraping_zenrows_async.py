#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scraping_zenrows_async.py
-------------------------
Módulo para monitorear y actualizar precios usando la API Async Jobs de ZenRows.
Envía tareas en paralelo a los servidores de ZenRows, optimizado para consumir
el mínimo de créditos posible (js_render=false, proxy_country=ar).
"""

import sys
import time
import json
import argparse
import requests
import pandas as pd
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

INGESTA_DIR = Path(__file__).resolve().parent
if str(INGESTA_DIR) not in sys.path:
    sys.path.insert(0, str(INGESTA_DIR))

from config import PROCESSED_DIR, ZENROWS_API_KEY

OUTPUT_FILE = PROCESSED_DIR / "precios_online.csv"
CATALOGO_FILE = PROCESSED_DIR / "catalogo_productos.csv"
ASYNC_JOBS_URL = "https://async.api.zenrows.com/v1/jobs"

def parsear_coto_json(data: dict, ean: str) -> Optional[Dict]:
    """Extrae precio, stock y nombre del JSON devuelto por el motor Endeca de Coto."""
    try:
        if isinstance(data, str):
            data = json.loads(data)
        contents = data.get("contents", [{}])[0]
        main_slots = [i for i in contents.get("Main", []) if i.get("@type") == "Main_Slot"]
        if not main_slots:
            return None
        records = main_slots[0].get("records", [])
        if not records:
            return None
        
        rec = records[0]
        attrs = rec.get("attributes", {})
        
        # Precio
        price_list = attrs.get("product.precio", []) or attrs.get("product.dto_precio", [])
        if not price_list:
            return None
        
        raw_price = str(price_list[0]).replace("$", "").replace(".", "").replace(",", ".").strip()
        price = float(raw_price)
        
        name = (attrs.get("product.displayName", [""])[0] or "").strip()
        sku = (attrs.get("product.repositoryId", [""])[0] or "").strip()
        url = f"https://www.cotodigital3.com.ar/sitios/cdigi/producto/{sku}" if sku else "https://www.cotodigital3.com.ar/sitios/cdigi/"
        
        return {
            "id_producto": str(ean).strip(),
            "id_entidad": "coto",
            "precio": price,
            "stock": True,
            "url": url,
            "fecha_captura": datetime.now().isoformat(),
            "nombre_scraper": name
        }
    except Exception:
        return None

def obtener_eans_coto(limit: int = 50) -> List[str]:
    """Obtiene los EANs prioritarios a monitorear (prioriza los que ya sabemos que existen en Coto)."""
    eans = []
    if OUTPUT_FILE.exists():
        try:
            df = pd.read_csv(OUTPUT_FILE, dtype=str)
            eans = df[df["id_entidad"] == "coto"]["id_producto"].dropna().unique().tolist()
        except Exception:
            pass

    if not eans and CATALOGO_FILE.exists():
        try:
            df_cat = pd.read_csv(CATALOGO_FILE, dtype=str)
            eans = df_cat["id_producto"].dropna().unique().tolist()
        except Exception:
            pass
            
    return eans[:limit]

def crear_job_zenrows(eans: List[str], api_key: str, batch_name: str = "Coto-Precios") -> Optional[str]:
    """Crea un Async Job en ZenRows con todas las tareas en un solo paquete cerrado."""
    tasks = []
    for ean in eans:
        url = f"https://www.cotodigital3.com.ar/sitios/cdigi/categoria?Ntk=product.eanPrincipal&Ntt={ean}&format=json"
        tasks.append({
            "url": url,
            "custom_id": str(ean),
            "zenrows_params": {
                "autoparse": "true",
                "mode": "auto",
                "js_render": "false"  # Consumo mínimo: 1 solo crédito por producto
            }
        })

    payload = {
        "type": "regular",
        "status": "closed",
        "name": batch_name,
        "zenrows_params": {
            "proxy_country": "ar",
            "mode": "auto",
            "autoparse": "true",
            "js_render": "false"
        },
        "tasks": tasks
    }

    headers = {
        "X-API-Key": api_key,
        "Content-Type": "application/json"
    }

    print(f"[*] Enviando Job de {len(tasks)} tareas a ZenRows (modo Async Batch)...")
    try:
        res = requests.post(ASYNC_JOBS_URL, headers=headers, json=payload, timeout=30)
        if res.status_code in (200, 201):
            data = res.json()
            job_id = data.get("job_id") or data.get("id")
            print(f"[OK] Job creado exitosamente en ZenRows con ID: {job_id}")
            return job_id
        else:
            print(f"[-] Error al crear Job en ZenRows (HTTP {res.status_code}): {res.text}")
            return None
    except Exception as e:
        print(f"[-] Error de conexión con ZenRows: {e}")
        return None

def esperar_y_descargar_resultados(job_id: str, api_key: str) -> List[Dict]:
    """Hace polling del estado del Job y descarga los resultados cuando finaliza."""
    headers = {"X-API-Key": api_key}
    job_status_url = f"{ASYNC_JOBS_URL}/{job_id}"
    
    print("[*] Monitoreando progreso del Job en ZenRows...")
    t0 = time.time()
    
    while True:
        try:
            res = requests.get(job_status_url, headers=headers, timeout=15)
            if res.status_code == 200:
                data = res.json()
                estado = data.get("status")
                completadas = data.get("completed_tasks", 0)
                totales = data.get("total_tasks", 0)
                fallidas = data.get("failed_tasks", 0)
                
                sys.stdout.write(f"\r    Estado: {estado.upper()} | Completadas: {completadas}/{totales} | Fallidas: {fallidas} (Tiempo: {int(time.time() - t0)}s)")
                sys.stdout.flush()
                
                if estado in ("finished", "completed"):
                    print("\n[OK] El Job ha finalizado.")
                    break
                elif estado in ("failed", "canceled"):
                    print(f"\n[-] El Job terminó con estado: {estado}")
                    return []
            else:
                print(f"\n[!] Advertencia al consultar estado (HTTP {res.status_code})")
        except Exception as e:
            print(f"\n[!] Error momentáneo consultando estado: {e}")

        time.sleep(5)

    # Descargar resultados
    results_url = f"{ASYNC_JOBS_URL}/{job_id}/results"
    print(f"[*] Descargando resultados desde {results_url}...")
    try:
        res = requests.get(results_url, headers=headers, timeout=30)
        if res.status_code == 200:
            raw_results = res.json()
            if isinstance(raw_results, dict) and "data" in raw_results:
                raw_results = raw_results["data"]
            return raw_results if isinstance(raw_results, list) else []
        else:
            print(f"[-] No se pudieron descargar los resultados (HTTP {res.status_code}): {res.text}")
            return []
    except Exception as e:
        print(f"[-] Error al descargar resultados: {e}")
        return []

def guardar_precios_extraidos(resultados: List[Dict]):
    """Parsea las respuestas de cada tarea y las guarda en precios_online.csv."""
    precios_validos = []
    
    for item in resultados:
        ean = item.get("custom_id")
        # El contenido puede venir en 'response', 'body', o 'data'
        body = item.get("response") or item.get("body") or item.get("data")
        if not body:
            continue
            
        precio_info = parsear_coto_json(body, ean)
        if precio_info:
            precios_validos.append(precio_info)

    if not precios_validos:
        print("[!] No se extrajeron precios válidos de las respuestas.")
        return

    print(f"[OK] {len(precios_validos)} precios de Coto procesados y normalizados.")
    
    df_nuevos = pd.DataFrame(precios_validos)
    if OUTPUT_FILE.exists():
        try:
            df_ex = pd.read_csv(OUTPUT_FILE, dtype=str)
            df_total = pd.concat([df_ex, df_nuevos], ignore_index=True)
            df_total = df_total.drop_duplicates(subset=["id_producto", "id_entidad"], keep="last")
        except Exception:
            df_total = df_nuevos
    else:
        df_total = df_nuevos

    df_total.to_csv(OUTPUT_FILE, index=False, encoding="utf-8")
    print(f"[OK] {OUTPUT_FILE.name} actualizado exitosamente ({len(df_total):,} registros en total).")

def main():
    parser = argparse.ArgumentParser(description="Monitoreo de precios con ZenRows Async Jobs API")
    parser.add_argument("--limit", type=int, default=50, help="Cantidad de EANs a monitorear si no se usa cola (por defecto: 50)")
    parser.add_argument("--name", type=str, default="CompraMas-Batch-Blocked", help="Nombre del Job en ZenRows")
    parser.add_argument("--solo-cola", action="store_true", help="Procesa únicamente las URLs que quedaron bloqueadas en la cola")
    args = parser.parse_args()

    if not ZENROWS_API_KEY:
        print("[-] Error: ZENROWS_API_KEY no encontrada en config.json.")
        sys.exit(1)

    print("========================================================")
    print(" ZENROWS ASYNC BATCH: MONITOREO DE PRECIOS OPTIMIZADO")
    print("========================================================")
    
    from scrapers.zenrows_queue import leer_cola_bloqueados, limpiar_cola_bloqueados
    cola_items = leer_cola_bloqueados()

    tasks = []
    if cola_items:
        print(f"[!] Se encontraron {len(cola_items)} URLs bloqueadas en la cola.")
        for item in cola_items[:args.limit]:
            tasks.append({
                "url": item["url"],
                "custom_id": item["custom_id"],
                "zenrows_params": {
                    "autoparse": "true",
                    "mode": "auto",
                    "js_render": "false"
                }
            })
    elif not args.solo_cola:
        eans = obtener_eans_coto(limit=args.limit)
        if not eans:
            print("[-] No se encontraron EANs para monitorear.")
            sys.exit(1)
        for ean in eans:
            url = f"https://www.cotodigital3.com.ar/sitios/cdigi/categoria?Ntk=product.eanPrincipal&Ntt={ean}&format=json"
            tasks.append({
                "url": url,
                "custom_id": str(ean),
                "zenrows_params": {
                    "autoparse": "true",
                    "mode": "auto",
                    "js_render": "false"
                }
            })
    else:
        print("[OK] No hay URLs bloqueadas en la cola. Nada que enviar a ZenRows.")
        return

    if not tasks:
        print("[-] No hay tareas para enviar.")
        return

    print(f"[*] Total tareas para ZenRows: {len(tasks)}")
    print(f"[*] Configuración: js_render=false (1 crédito/tarea), proxy_country=ar.")
    print(f"[*] Consumo estimado: ~{len(tasks)} créditos.")

    payload = {
        "type": "regular",
        "status": "closed",
        "name": args.name,
        "zenrows_params": {
            "proxy_country": "ar",
            "mode": "auto",
            "autoparse": "true",
            "js_render": "false"
        },
        "tasks": tasks
    }

    headers = {
        "X-API-Key": ZENROWS_API_KEY,
        "Content-Type": "application/json"
    }

    try:
        res = requests.post(ASYNC_JOBS_URL, headers=headers, json=payload, timeout=30)
        if res.status_code not in (200, 201):
            print(f"[-] Error al crear Job en ZenRows (HTTP {res.status_code}): {res.text}")
            sys.exit(1)
        data = res.json()
        job_id = data.get("job_id") or data.get("id")
        print(f"[OK] Job creado exitosamente en ZenRows con ID: {job_id}")
    except Exception as e:
        print(f"[-] Error de conexión con ZenRows: {e}")
        sys.exit(1)

    resultados = esperar_y_descargar_resultados(job_id, ZENROWS_API_KEY)
    if resultados:
        guardar_precios_extraidos(resultados)
        if cola_items:
            limpiar_cola_bloqueados()
            print("[OK] Cola de URLs bloqueadas vaciada exitosamente.")
    else:
        print("[-] No se obtuvieron resultados del batch.")

if __name__ == "__main__":
    main()
