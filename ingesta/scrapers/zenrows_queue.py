#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scrapers/zenrows_queue.py
--------------------------
Administrador de la cola de URLs bloqueadas o fallidas.
Acumula las URLs que no pudieron extraerse localmente para ejecutarlas
posteriormente en un único lote eficiente (Batch) mediante ZenRows.
"""

import json
from pathlib import Path
from typing import List, Dict

INGESTA_DIR = Path(__file__).resolve().parent.parent
QUEUE_FILE = INGESTA_DIR / "data" / "processed" / "zenrows_pending_jobs.jsonl"

def registrar_url_bloqueada(url: str, custom_id: str, retailer: str, motivo: str = "bloqueo_waf"):
    """
    Agrega una URL a la cola zenrows_pending_jobs.jsonl evitando duplicados.
    """
    QUEUE_FILE.parent.mkdir(parents=True, exist_ok=True)
    
    # Leer URLs ya encoladas para no duplicar
    existentes = set()
    if QUEUE_FILE.exists():
        try:
            with open(QUEUE_FILE, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip():
                        try:
                            obj = json.loads(line)
                            existentes.add(obj.get("url"))
                        except Exception:
                            pass
        except Exception:
            pass

    if url in existentes:
        return

    item = {
        "url": url,
        "custom_id": str(custom_id),
        "retailer": retailer,
        "motivo": motivo
    }

    with open(QUEUE_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")

def leer_cola_bloqueados() -> List[Dict]:
    """Retorna la lista de tareas acumuladas en la cola."""
    if not QUEUE_FILE.exists():
        return []
    
    items = []
    with open(QUEUE_FILE, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                try:
                    items.append(json.loads(line))
                except Exception:
                    pass
    return items

def limpiar_cola_bloqueados():
    """Vacía la cola tras procesar el lote exitosamente."""
    if QUEUE_FILE.exists():
        QUEUE_FILE.unlink()
