#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
1_descargar_sepa.py
-------------------
Consulta la API oficial de CKAN del portal de datos del Ministerio de Economía
y descarga en streaming el archivo ZIP más reciente de SEPA (Precios Claros).
"""

import sys
import os
import argparse
import time
import requests
from pathlib import Path
from config import CKAN_DATASET_API_URL, RAW_DIR

def obtener_recursos_sepa():
    """Consulta la metadata del dataset SEPA en la API de CKAN"""
    print(f"[*] Consultando API de CKAN: {CKAN_DATASET_API_URL}")
    try:
        response = requests.get(CKAN_DATASET_API_URL, timeout=30)
        response.raise_for_status()
        data = response.json()
        if not data.get("success"):
            raise ValueError("La API de CKAN no devolvió success=True")
        
        resources = data["result"]["resources"]
        zip_resources = [
            r for r in resources 
            if r.get("format", "").lower() == "zip" or r.get("url", "").lower().endswith(".zip")
        ]
        return zip_resources
    except Exception as e:
        print(f"[-] Error al consultar API de CKAN: {e}")
        return []

def descargar_archivo(url: str, destino_path: Path):
    """Descarga en streaming con reporte de progreso en MB"""
    print(f"[*] Iniciando descarga desde: {url}")
    print(f"[*] Destino: {destino_path}")
    
    t0 = time.time()
    try:
        with requests.get(url, stream=True, timeout=60) as r:
            r.raise_for_status()
            total_bytes = int(r.headers.get("content-length", 0))
            total_mb = total_bytes / (1024 * 1024) if total_bytes > 0 else 0
            
            descargado_bytes = 0
            chunk_size = 2 * 1024 * 1024  # 2MB por bloque
            
            with open(destino_path, "wb") as f:
                for chunk in r.iter_content(chunk_size=chunk_size):
                    if chunk:
                        f.write(chunk)
                        descargado_bytes += len(chunk)
                        mb = descargado_bytes / (1024 * 1024)
                        if total_mb > 0:
                            pct = (descargado_bytes / total_bytes) * 100
                            sys.stdout.write(f"\r    -> {mb:.1f} MB / {total_mb:.1f} MB ({pct:.1f}%)")
                        else:
                            sys.stdout.write(f"\r    -> {mb:.1f} MB descargados")
                        sys.stdout.flush()
        
        elapsed = time.time() - t0
        print(f"\n[OK] Descarga completa en {elapsed:.1f}s: {destino_path}")
        return True
    except Exception as e:
        print(f"\n[-] Error durante la descarga: {e}")
        return False

def ejecutar_descarga(dia: str = None, destino: Path = None):
    destino_final = destino or (RAW_DIR / "sepa_latest.zip")
    
    recursos = obtener_recursos_sepa()
    if not recursos:
        print("[-] No se encontraron recursos ZIP disponibles en la API.")
        return None
    
    recurso_seleccionado = None
    if dia:
        dia_lower = dia.lower()
        for r in recursos:
            nombre = (r.get("name") or "").lower()
            descripcion = (r.get("description") or "").lower()
            if dia_lower in nombre or dia_lower in descripcion:
                recurso_seleccionado = r
                break
    
    if not recurso_seleccionado:
        recurso_seleccionado = recursos[0]
    
    nombre_recurso = recurso_seleccionado.get("name", "SEPA Precios")
    url_descarga = recurso_seleccionado.get("url")
    print(f"[+] Recurso seleccionado: '{nombre_recurso}'")
    
    ok = descargar_archivo(url_descarga, destino_final)
    return destino_final if ok else None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Descarga el dump diario de SEPA")
    parser.add_argument("--dia", help="Día específico a descargar (ej: viernes, lunes)")
    parser.add_argument("--output", help="Ruta de salida para el archivo ZIP")
    args = parser.parse_args()
    
    dest = Path(args.output) if args.output else None
    ejecutar_descarga(dia=args.dia, destino=dest)
