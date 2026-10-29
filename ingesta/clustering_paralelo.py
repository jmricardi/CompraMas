#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
clustering_paralelo.py
-----------------------
Clustering incremental de productos SEPA usando únicamente Gemini 3.5 Flash Lite:
- 1 Worker dedicado con modelo: gemini-3.5-flash-lite (con fallback automático si 404/503).
- Lotes de 60 productos por request.
- Rate limit: 12 RPM (1 llamada cada 5.0 segundos).
- Guarda respuestas JSON correlativas en ingesta/respuestas/ (respuesta_XXXX.json).
- Actualiza incrementalmente los CSVs en data/clusters/.
- Sube resultados a Supabase al finalizar o al cancelar con Ctrl+C.
"""

import os
import sys
import json
import time
import glob
import re
import signal
import queue
import threading
import argparse
import requests
import psycopg2
import pandas as pd
from pathlib import Path

from config import GEMINI_API_KEY, SUPABASE_DB_URL, PROCESSED_DIR, CLUSTERS_DIR, BASE_DIR

RESPUESTAS_DIR = BASE_DIR / "respuestas"
CATALOGO_CSV = PROCESSED_DIR / "catalogo_productos.csv"

SYSTEM_PROMPT = """Actúa como un experto en catalogación de productos de consumo masivo (supermercados en Argentina).
Tu objetivo es asignar un identificador canónico ('cluster_id') y normalizar el 'contenido_neto' en unidad base para calcular el PRECIO POR KG o LITRO.

Instrucciones:
1. 'cluster_id': Slug en minúsculas [generico]_[cantidad][unidad] (ej: 'leche_condensada_395g', 'arroz_largo_fino_1kg', 'aceite_girasol_900ml', 'detergente_vajilla_500ml'). Usa SIEMPRE gramos para <1kg (ej: '395g', NUNCA '0.395kg') y mililitros para <1L (ej: '900ml', NUNCA '0.9l').
2. 'nombre_canonico': Título humano legible (ej: 'Leche Condensada ~395g', 'Arroz Largo Fino 1kg').
3. 'categoria': (ej: 'Lácteos', 'Almacén', 'Bebidas', 'Limpieza', 'Golosinas', 'Perfumería', 'Frescos', 'Bebés').
4. 'contenido_neto': Número float convertido a unidad base:
   - Gramos (g, gr, grm): divide por 1000 para llevar a kg (ej: 395g -> 0.395, 29.5g -> 0.0295, 1kg -> 1.0).
   - Mililitros (ml, cc): divide por 1000 para llevar a litros (ej: 900ml -> 0.9, 1.5lt -> 1.5, 750cc -> 0.75).
   - Unidades: cantidad entera (ej: 4 rollos -> 4.0, 1 unidad -> 1.0).
5. 'unidad_referencia': 'kg' (para sólidos), 'l' (para líquidos), o 'u' (para unidades).
6. 'confianza': float entre 0.0 y 1.0.

Responde ÚNICAMENTE en formato JSON válido:
[
  {
    "id_producto": "8445290900654",
    "cluster_id": "leche_condensada_395g",
    "nombre_canonico": "Leche Condensada ~395g",
    "categoria": "Lácteos",
    "contenido_neto": 0.395,
    "unidad_referencia": "kg",
    "confianza": 0.98
  }
]
"""

lock_csv = threading.Lock()
lock_indice = threading.Lock()
lock_print = threading.Lock()
stop_event = threading.Event()


def log_msg(worker_id: str, msg: str):
    with lock_print:
        ts = time.strftime("%H:%M:%S")
        print(f"[{ts}] [{worker_id}] {msg}")


def validar_item_respuesta(item: dict) -> dict:
    if not isinstance(item, dict):
        return None
    id_p = str(item.get("id_producto", "")).strip()
    c_id = str(item.get("cluster_id", "")).strip().lower().replace(" ", "_")
    if not id_p or not c_id:
        return None
        
    # Normalizar sufijos de unidades decimales en el slug (ej: _0.395kg -> _395g)
    m_kg = re.search(r'_0\.(\d+)kg$', c_id)
    if m_kg:
        val_g = int(float(f"0.{m_kg.group(1)}") * 1000)
        c_id = re.sub(r'_0\.\d+kg$', f'_{val_g}g', c_id)
    m_l = re.search(r'_0\.(\d+)(?:l|lt)$', c_id)
    if m_l:
        val_ml = int(float(f"0.{m_l.group(1)}") * 1000)
        c_id = re.sub(r'_0\.\d+(?:l|lt)$', f'_{val_ml}ml', c_id)
        
    n_canonico = str(item.get("nombre_canonico", "")).strip() or c_id
    cat = str(item.get("categoria", "")).strip() or "General"
    
    cn = item.get("contenido_neto")
    try:
        cn_float = float(cn) if cn is not None and str(cn).strip() != "" else None
        if cn_float is not None and cn_float <= 0:
            cn_float = None
    except (ValueError, TypeError):
        cn_float = None
        
    um = str(item.get("unidad_referencia", "kg")).strip().lower()
    if um not in ("kg", "l", "u"):
        um = "kg"
        
    try:
        conf = max(0.0, min(1.0, float(item.get("confianza", 1.0))))
    except (ValueError, TypeError):
        conf = 1.0
        
    return {
        "id_producto": id_p,
        "cluster_id": c_id,
        "nombre_canonico": n_canonico,
        "categoria": cat,
        "contenido_neto": cn_float,
        "unidad_referencia": um,
        "confianza": conf
    }


def obtener_siguiente_indice_respuesta() -> int:
    archivos = glob.glob(str(RESPUESTAS_DIR / "respuesta_*.json"))
    max_idx = 0
    for a in archivos:
        nums = re.findall(r"\d+", Path(a).stem)
        if nums:
            max_idx = max(max_idx, int(nums[0]))
    return max_idx + 1


def cargar_clusters_existentes():
    f_items = CLUSTERS_DIR / "producto_cluster_items.csv"
    if f_items.exists():
        df = pd.read_csv(f_items, dtype={"id_producto": str})
        return set(df["id_producto"].dropna().astype(str).str.strip())
    return set()


def guardar_progreso_local(items_procesados: list, modelo_usado: str):
    if not items_procesados:
        return
    CLUSTERS_DIR.mkdir(parents=True, exist_ok=True)
    f_clusters = CLUSTERS_DIR / "producto_clusters.csv"
    f_items = CLUSTERS_DIR / "producto_cluster_items.csv"
    
    with lock_csv:
        nuevos_c = {
            it["cluster_id"]: {
                "cluster_id": it["cluster_id"],
                "nombre_canonico": it["nombre_canonico"],
                "categoria": it["categoria"]
            }
            for it in items_procesados
        }
        df_new_c = pd.DataFrame(list(nuevos_c.values()))
        if f_clusters.exists():
            df_c_exist = pd.read_csv(f_clusters, dtype=str)
            df_c_tot = pd.concat([df_c_exist, df_new_c], ignore_index=True).drop_duplicates(subset=["cluster_id"], keep="last")
        else:
            df_c_tot = df_new_c
        df_c_tot.to_csv(f_clusters, index=False)
        
        nuevos_i = [
            {
                "id_producto": it["id_producto"],
                "cluster_id": it["cluster_id"],
                "contenido_neto": it["contenido_neto"],
                "unidad_referencia": it["unidad_referencia"],
                "confianza": it["confianza"],
                "modelo_ia": modelo_usado
            }
            for it in items_procesados
        ]
        df_new_i = pd.DataFrame(nuevos_i)
        if f_items.exists():
            df_i_exist = pd.read_csv(f_items, dtype=str)
            df_i_tot = pd.concat([df_i_exist, df_new_i], ignore_index=True).drop_duplicates(subset=["id_producto"], keep="last")
        else:
            df_i_tot = df_new_i
        df_i_tot.to_csv(f_items, index=False)


def llamar_gemini(modelo_nombre: str, productos_lote: list, worker_name: str) -> tuple[list, str]:
    prompt_usuario = (
        "Clasifica y extrae los atributos canónicos de los siguientes productos de supermercado:\n\n"
        + json.dumps(productos_lote, ensure_ascii=False, indent=1)
    )
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt_usuario}]}],
        "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.1}
    }
    
    # Lista de modelos con fallback
    modelos_a_probar = [modelo_nombre]
    modelos_disponibles = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-1.5-flash"]
    for m in modelos_disponibles:
        if m not in modelos_a_probar:
            modelos_a_probar.append(m)

    for mod in modelos_a_probar:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{mod}:generateContent?key={GEMINI_API_KEY}"
        for intento in range(1, 4):
            if stop_event.is_set():
                return None, mod
            try:
                resp = requests.post(url, json=payload, timeout=60)
                if resp.status_code == 200:
                    data = resp.json()
                    cands = data.get("candidates", [])
                    if not cands:
                        time.sleep(3)
                        continue
                    txt = cands[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
                    if txt.startswith("```"):
                        lines = txt.splitlines()
                        txt = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:]).strip()
                    parsed = json.loads(txt)
                    if isinstance(parsed, dict) and "items" in parsed:
                        parsed = parsed["items"]
                    elif not isinstance(parsed, list):
                        parsed = [parsed]
                    validados = [v for it in parsed if (v := validar_item_respuesta(it))]
                    return validados, mod
                elif resp.status_code == 429:
                    log_msg(worker_name, f"⚠️ Rate limit 429 ({mod}). Esperando 10s...")
                    time.sleep(10)
                elif resp.status_code == 503:
                    log_msg(worker_name, f"⚠️ Servidor ocupado 503 ({mod}). Reintentando en 6s...")
                    time.sleep(6)
                elif resp.status_code == 404:
                    # Modelo no existe en API, pasar directamente al siguiente
                    break
                else:
                    log_msg(worker_name, f"HTTP {resp.status_code} ({mod}): {resp.text[:120]}")
                    time.sleep(4)
            except Exception as e:
                log_msg(worker_name, f"Error de red ({e}). Reintentando...")
                time.sleep(4)
    return None, modelo_nombre


def worker_loop(worker_id: str, modelo_inicial: str, task_queue: queue.Queue, rpm: int, global_counter: dict):
    intervalo = 60.0 / float(rpm)
    ultimo_llamado = 0.0
    modelo_activo = modelo_inicial
    log_msg(worker_id, f"Iniciado con: '{modelo_inicial}' | {rpm} RPM ({intervalo:.1f}s/req)")
    
    while not stop_event.is_set():
        try:
            num_lote, productos_lote = task_queue.get(timeout=2)
        except queue.Empty:
            break
            
        espera = intervalo - (time.time() - ultimo_llamado)
        if espera > 0:
            time.sleep(espera)
        ultimo_llamado = time.time()
        
        log_msg(worker_id, f"Enviando lote #{num_lote} ({len(productos_lote)} items)...")
        resultado, modelo_activo = llamar_gemini(modelo_activo, productos_lote, worker_id)
        
        if resultado:
            with lock_indice:
                idx = global_counter["proximo_archivo"]
                global_counter["proximo_archivo"] += 1
                global_counter["procesados"] += len(resultado)
            
            fn = RESPUESTAS_DIR / f"respuesta_{idx:04d}.json"
            RESPUESTAS_DIR.mkdir(parents=True, exist_ok=True)
            with open(fn, "w", encoding="utf-8") as f:
                json.dump(resultado, f, ensure_ascii=False, indent=2)
                
            guardar_progreso_local(resultado, modelo_activo)
            log_msg(worker_id, f"✅ Lote #{num_lote} OK [{modelo_activo}] -> '{fn.name}' ({len(resultado)} items). Total sesión: {global_counter['procesados']:,}")
        else:
            log_msg(worker_id, f"❌ Falló lote #{num_lote}. Reencolando lote...")
            task_queue.put((num_lote, productos_lote))
            time.sleep(5)
            
        task_queue.task_done()
    log_msg(worker_id, "Worker completado.")


from psycopg2.extras import execute_values

def subir_resultados_a_supabase():
    print("\n" + "=" * 60)
    print(" SINCRONIZANDO CLÚSTERES ACUMULADOS EN SUPABASE")
    print("=" * 60)
    f_c = CLUSTERS_DIR / "producto_clusters.csv"
    f_i = CLUSTERS_DIR / "producto_cluster_items.csv"
    if not f_c.exists() or not f_i.exists() or not SUPABASE_DB_URL:
        print("[-] Archivos o credenciales de Supabase no disponibles.")
        return
    try:
        t0 = time.time()
        conn = psycopg2.connect(SUPABASE_DB_URL)
        with conn.cursor() as cur:
            # 1. Upsert rápido de producto_clusters
            df_c = pd.read_csv(f_c, dtype=str)
            print(f"[*] Sincronizando {len(df_c):,} familias en 'producto_clusters'...")
            q_c = """
                INSERT INTO producto_clusters (cluster_id, nombre_canonico, categoria)
                VALUES %s
                ON CONFLICT (cluster_id) DO UPDATE SET
                    nombre_canonico = EXCLUDED.nombre_canonico,
                    categoria = EXCLUDED.categoria;
            """
            rec_c = [(r["cluster_id"], r["nombre_canonico"], r.get("categoria", "General")) for _, r in df_c.iterrows()]
            execute_values(cur, q_c, rec_c, page_size=1000)
            
            # 2. Upsert rápido de producto_cluster_items
            df_i = pd.read_csv(f_i, dtype=str)
            print(f"[*] Sincronizando {len(df_i):,} productos en 'producto_cluster_items'...")
            q_i = """
                INSERT INTO producto_cluster_items 
                (id_producto, cluster_id, contenido_neto, unidad_referencia, confianza, modelo_ia)
                VALUES %s
                ON CONFLICT (id_producto) DO UPDATE SET
                    cluster_id = EXCLUDED.cluster_id,
                    contenido_neto = EXCLUDED.contenido_neto,
                    unidad_referencia = EXCLUDED.unidad_referencia,
                    confianza = EXCLUDED.confianza,
                    modelo_ia = EXCLUDED.modelo_ia;
            """
            rec_i = [
                (
                    r["id_producto"],
                    r["cluster_id"],
                    float(r["contenido_neto"]) if pd.notna(r.get("contenido_neto")) and str(r.get("contenido_neto")).strip() != "" else None,
                    str(r.get("unidad_referencia", "kg")).strip(),
                    float(r.get("confianza", 1.0)),
                    r.get("modelo_ia", "gemini-3.5-flash-lite")
                )
                for _, r in df_i.iterrows()
            ]
            execute_values(cur, q_i, rec_i, page_size=1000)
            
        conn.commit()
        conn.close()
        print(f"[OK] Sincronización exitosa en Supabase en {time.time() - t0:.2f}s.")
    except Exception as e:
        print(f"[ERROR] Error al sincronizar con Supabase: {e}")


def main():
    parser = argparse.ArgumentParser(description="Clustering IA con Gemini 3.5 Flash Lite")
    parser.add_argument("--modelo", type=str, default="gemini-3.5-flash-lite", help="Modelo a usar (def: gemini-3.5-flash-lite)")
    parser.add_argument("--batch-size", type=int, default=60, help="Tamaño de lote (def: 60)")
    parser.add_argument("--rpm", type=int, default=12, help="RPM (def: 12)")
    parser.add_argument("--max-items", type=int, default=None, help="Límite opcional de productos (def: TODOS los pendientes)")
    args = parser.parse_args()

    print("=" * 60)
    print(" CLUSTERING IA - GEMINI 3.5 FLASH LITE")
    print("=" * 60)
    print(f"• Modelo: {args.modelo} ({args.rpm} RPM)")
    print(f"• Tamaño de Lote: {args.batch_size} productos")
    print("=" * 60)

    if not GEMINI_API_KEY or not CATALOGO_CSV.exists():
        print("[-] ERROR: Verifique GEMINI_API_KEY y catalogo_productos.csv")
        sys.exit(1)

    df_cat = pd.read_csv(CATALOGO_CSV, dtype=str)
    ya_procesados = cargar_clusters_existentes()
    print(f"[+] Total en catálogo: {len(df_cat):,} | Ya procesados: {len(ya_procesados):,}")

    todos_pendientes = [
        {
            "id": pid,
            "desc": str(r.get("productos_descripcion", "")).strip(),
            "marca": str(r.get("productos_marca", "")).strip(),
            "cant": str(r.get("productos_cantidad_presentacion", "")).strip(),
            "um": str(r.get("productos_unidad_medida_presentacion", "")).strip()
        }
        for _, r in df_cat.iterrows()
        if (pid := str(r.get("id_producto", "")).strip()) and pid not in ya_procesados
    ]

    if args.max_items is not None and args.max_items > 0:
        pendientes = todos_pendientes[:args.max_items]
        print(f"[+] Meta seleccionada: {len(pendientes):,} productos (de {len(todos_pendientes):,} pendientes totales)")
    else:
        pendientes = todos_pendientes
        print(f"[+] Meta total: {len(pendientes):,} productos pendientes (100% de los faltantes)")

    if not pendientes:
        print("[OK] No hay productos pendientes. Todo el catálogo ya está procesado.")
        subir_resultados_a_supabase()
        return

    task_queue = queue.Queue()
    for i in range((len(pendientes) + args.batch_size - 1) // args.batch_size):
        ini = i * args.batch_size
        task_queue.put((i + 1, pendientes[ini:ini + args.batch_size]))

    global_counter = {"proximo_archivo": obtener_siguiente_indice_respuesta(), "procesados": 0}
    print(f"[*] Guardando respuestas a partir de: respuesta_{global_counter['proximo_archivo']:04d}.json")

    def manejador_sigint(sig, frame):
        if stop_event.is_set():
            print("\n[!] Forzando salida inmediata...")
            os._exit(0)
        print("\n[!] Deteniendo worker y sincronizando con Supabase (presione Ctrl+C otra vez para salir sin guardar)...")
        stop_event.set()

    signal.signal(signal.SIGINT, manejador_sigint)

    t1 = threading.Thread(target=worker_loop, args=("Worker-1 (3.5-Lite)", args.modelo, task_queue, args.rpm, global_counter), daemon=True)

    t0 = time.time()
    t1.start()

    while t1.is_alive():
        time.sleep(0.5)

    print(f"\n[FIN] Completado en {time.time() - t0:.1f}s. Productos procesados: {global_counter['procesados']:,}")
    subir_resultados_a_supabase()


if __name__ == "__main__":
    main()
