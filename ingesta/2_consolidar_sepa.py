#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2_consolidar_sepa.py
--------------------
Descomprime y consolida los archivos del paquete ZIP de SEPA.
Soporta paquetes anidados (comercio_*.zip) o archivos CSV directos.
Genera master_comercio.csv, master_sucursales.csv y master_productos.csv.
"""

import os
import sys
import zipfile
import io
import argparse
import time
from pathlib import Path
from config import RAW_DIR

PREFIJOS_FOOTER = ("ultima actualizaci", "última actualizaci")
ENCODINGS = ("utf-8", "latin-1", "cp1252")

def detectar_encoding(raw: bytes) -> str:
    for enc in ENCODINGS:
        try:
            raw.decode(enc)
            return enc
        except Exception:
            continue
    return "latin-1"

def es_linea_valida(linea: str) -> bool:
    stripped = linea.strip()
    if not stripped:
        return False
    lowered = stripped.lower()
    return not any(lowered.startswith(p) for p in PREFIJOS_FOOTER)

def procesar_csv_bytes(raw: bytes, f_out, escribir_encabezado: bool) -> tuple:
    enc = detectar_encoding(raw[:1024])
    texto = raw.decode(enc, errors="replace")
    reader = io.StringIO(texto)
    
    es_primera = True
    filas = 0
    enc_escrito = False
    
    for linea in reader:
        limpia = linea.rstrip("\r\n")
        if not es_linea_valida(limpia):
            continue
        if es_primera:
            es_primera = False
            if escribir_encabezado:
                f_out.write(limpia + "\n")
                enc_escrito = True
            continue
        
        f_out.write(limpia + "\n")
        filas += 1
        
    return enc_escrito, filas

def consolidar_zip(zip_path: Path, output_dir: Path):
    print(f"[*] Consolidando paquete SEPA: {zip_path}")
    t0 = time.time()
    
    f_com = open(output_dir / "master_comercio.csv", "w", encoding="utf-8", newline="")
    f_suc = open(output_dir / "master_sucursales.csv", "w", encoding="utf-8", newline="")
    f_prod = open(output_dir / "master_productos.csv", "w", encoding="utf-8", newline="")
    
    enc_com = enc_suc = enc_prod = False
    cnt_com = cnt_suc = cnt_prod = 0
    
    try:
        with zipfile.ZipFile(zip_path, "r") as z_root:
            namelist = z_root.namelist()
            zips_internos = [n for n in namelist if n.lower().endswith(".zip")]
            
            if zips_internos:
                print(f"[+] Se detectaron {len(zips_internos)} comercios empaquetados en el ZIP.")
                for i, nombre_zip in enumerate(zips_internos):
                    if (i + 1) % 50 == 0 or (i + 1) == len(zips_internos):
                        sys.stdout.write(f"\r    Procesando comercio {i + 1}/{len(zips_internos)}...")
                        sys.stdout.flush()
                    
                    data_zip = z_root.read(nombre_zip)
                    if not data_zip or len(data_zip) < 22:
                        continue
                    
                    try:
                        with zipfile.ZipFile(io.BytesIO(data_zip)) as z_inner:
                            for item in z_inner.namelist():
                                nombre_lower = item.lower()
                                if "comercio" in nombre_lower and nombre_lower.endswith(".csv"):
                                    w, c = procesar_csv_bytes(z_inner.read(item), f_com, not enc_com)
                                    if w: enc_com = True
                                    cnt_com += c
                                elif "sucursal" in nombre_lower and nombre_lower.endswith(".csv"):
                                    w, c = procesar_csv_bytes(z_inner.read(item), f_suc, not enc_suc)
                                    if w: enc_suc = True
                                    cnt_suc += c
                                elif "producto" in nombre_lower and nombre_lower.endswith(".csv"):
                                    w, c = procesar_csv_bytes(z_inner.read(item), f_prod, not enc_prod)
                                    if w: enc_prod = True
                                    cnt_prod += c
                    except zipfile.BadZipFile:
                        continue
                print()
            else:
                print("[+] Extrayendo archivos CSV directos del ZIP raíz...")
                for item in namelist:
                    nombre_lower = item.lower()
                    if "comercio" in nombre_lower and nombre_lower.endswith(".csv"):
                        w, c = procesar_csv_bytes(z_root.read(item), f_com, not enc_com)
                        if w: enc_com = True
                        cnt_com += c
                    elif "sucursal" in nombre_lower and nombre_lower.endswith(".csv"):
                        w, c = procesar_csv_bytes(z_root.read(item), f_suc, not enc_suc)
                        if w: enc_suc = True
                        cnt_suc += c
                    elif "producto" in nombre_lower and nombre_lower.endswith(".csv"):
                        w, c = procesar_csv_bytes(z_root.read(item), f_prod, not enc_prod)
                        if w: enc_prod = True
                        cnt_prod += c
    finally:
        f_com.close()
        f_suc.close()
        f_prod.close()
        
    elapsed = time.time() - t0
    print(f"[OK] Consolidación finalizada en {elapsed:.1f}s:")
    print(f"    - master_comercio.csv:   {cnt_com:,} filas")
    print(f"    - master_sucursales.csv: {cnt_suc:,} filas")
    print(f"    - master_productos.csv:  {cnt_prod:,} filas")
    return {
        "comercio": output_dir / "master_comercio.csv",
        "sucursales": output_dir / "master_sucursales.csv",
        "productos": output_dir / "master_productos.csv",
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Consolida el archivo ZIP de SEPA")
    parser.add_argument("--zip", help="Ruta al archivo ZIP (por defecto data/raw/sepa_latest.zip)")
    parser.add_argument("--output", help="Directorio de salida (por defecto data/raw)")
    args = parser.parse_args()
    
    zip_input = Path(args.zip) if args.zip else (RAW_DIR / "sepa_latest.zip")
    out_dir = Path(args.output) if args.output else RAW_DIR
    
    if not zip_input.exists():
        print(f"[-] No se encontró el archivo ZIP en {zip_input}")
        sys.exit(1)
        
    consolidar_zip(zip_input, out_dir)
