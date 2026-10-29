#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_lotes.py
----------------
Genera archivos individuales en ingesta/lotes/ con 50 productos cada uno
para procesar manualmente en Gemini 3.5 Flash Lite (Google AI Studio o Chat).
"""

import os
import json
import argparse
import pandas as pd
from pathlib import Path
from config import BASE_DIR, PROCESSED_DIR

LOTES_DIR = BASE_DIR / "lotes"
CATALOGO_SRC = BASE_DIR.parent / "Bases de Datos Precios" / "sepa_output" / "optimizados" / "catalogo_productos.csv"
CATALOGO_DEST = PROCESSED_DIR / "catalogo_productos.csv"

def preparar_catalogo():
    if not CATALOGO_DEST.exists() and CATALOGO_SRC.exists():
        print(f"[*] Copiando catálogo procesado a {CATALOGO_DEST}...")
        df = pd.read_csv(CATALOGO_SRC, dtype=str)
        df.to_csv(CATALOGO_DEST, index=False)
        return df
    elif CATALOGO_DEST.exists():
        return pd.read_csv(CATALOGO_DEST, dtype=str)
    elif CATALOGO_SRC.exists():
        return pd.read_csv(CATALOGO_SRC, dtype=str)
    else:
        raise FileNotFoundError("No se encontró catalogo_productos.csv en ninguna ubicación.")

def generar_lotes(cantidad_lotes: int = None, tamano_lote: int = 50):
    LOTES_DIR.mkdir(parents=True, exist_ok=True)
    df = preparar_catalogo()
    total_prods = len(df)
    print(f"[+] Total productos en catálogo: {total_prods:,}")

    items = []
    for _, row in df.iterrows():
        items.append({
            "id": str(row.get("id_producto", "")).strip(),
            "desc": str(row.get("productos_descripcion", "")).strip(),
            "marca": str(row.get("productos_marca", "")).strip(),
            "cant": str(row.get("productos_cantidad_presentacion", "")).strip(),
            "um": str(row.get("productos_unidad_medida_presentacion", "")).strip()
        })

    num_total_lotes = (total_prods + tamano_lote - 1) // tamano_lote
    lotes_a_generar = cantidad_lotes if cantidad_lotes else num_total_lotes

    print(f"[*] Generando {lotes_a_generar} lotes de {tamano_lote} productos en {LOTES_DIR}...")

    for i in range(lotes_a_generar):
        idx_inicio = i * tamano_lote
        idx_fin = min(idx_inicio + tamano_lote, total_prods)
        sub_items = items[idx_inicio:idx_fin]
        
        file_name = LOTES_DIR / f"lote_{i+1:04d}.json"
        with open(file_name, "w", encoding="utf-8") as f:
            json.dump(sub_items, f, ensure_ascii=False, indent=2)

    print(f"[OK] Se generaron {lotes_a_generar} lotes exitosamente en {LOTES_DIR}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Genera lotes de productos para procesamiento manual con Gemini")
    parser.add_argument("--cantidad", type=int, default=100, help="Cantidad de lotes a generar (por defecto 100 lotes = 5.000 productos)")
    parser.add_argument("--todos", action="store_true", help="Genera todos los lotes del catálogo completo")
    parser.add_argument("--tamano", type=int, default=50, help="Tamaño de cada lote (por defecto 50)")
    args = parser.parse_args()

    cant = None if args.todos else args.cantidad
    generar_lotes(cantidad_lotes=cant, tamano_lote=args.tamano)
