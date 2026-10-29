#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
1b_descargar_combustibles.py
----------------------------
Descarga el dataset oficial de precios de combustibles en surtidor
(Resolución 314/2016 de la Secretaría de Energía de la Nación)
y lo normaliza en un CSV listo para ingesta masiva en Supabase.
"""

import os
import sys
import time
import csv
from datetime import datetime, timezone
import requests
from pathlib import Path

# Ajustar import de config
sys.path.insert(0, str(Path(__file__).resolve().parent))
from config import RAW_DIR, PROCESSED_DIR

COMBUSTIBLES_URL = (
    "http://datos.energia.gob.ar/dataset/1c181390-5045-475e-94dc-410429be4b17/"
    "resource/80ac25de-a44a-4445-9215-090cf55cfda5/download/"
    "precios-en-surtidor-resolucin-3142016.csv"
)

DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/csv,application/csv,text/plain;q=0.9,*/*;q=0.8"
}

def descargar_csv_combustibles(destino_raw: Path) -> bool:
    print(f"[*] Descargando precios de combustibles desde Secretaría de Energía...")
    print(f"    URL: {COMBUSTIBLES_URL}")
    t0 = time.time()
    try:
        with requests.get(COMBUSTIBLES_URL, stream=True, headers=DEFAULT_HEADERS, timeout=60) as r:
            r.raise_for_status()
            total_bytes = 0
            chunk_size = 512 * 1024  # 512 KB
            with open(destino_raw, "wb") as f:
                for chunk in r.iter_content(chunk_size=chunk_size):
                    if chunk:
                        f.write(chunk)
                        total_bytes += len(chunk)
            mb = total_bytes / (1024 * 1024)
            duracion = time.time() - t0
            print(f"[OK] Descarga completada en {duracion:.1f}s ({mb:.2f} MB) -> {destino_raw}")
            return True
    except Exception as e:
        print(f"[-] Error al descargar dataset de combustibles: {e}")
        return False

def normalizar_combustibles(raw_path: Path, output_csv: Path) -> int:
    """
    Limpia BOM, normaliza tipos y encabezados para carga COPY en PostgreSQL / Supabase.
    - Exporta registros de precios con fecha_vigencia <= 30 días.
    - Exporta 1 registro de ubicación (sin precio) para estaciones sin datos recientes,
      permitiendo que figuren en el mapa como «Sin datos».
    """
    print("[*] Procesando y normalizando dataset de combustibles...")
    t0 = time.time()
    
    target_columns = [
        "idempresa", "cuit", "empresa", "direccion", "localidad",
        "provincia", "region", "idproducto", "producto", "idtipohorario",
        "tipohorario", "precio", "fecha_vigencia", "idempresabandera",
        "empresabandera", "latitud", "longitud"
    ]
    
    now = datetime.now()
    stations_catalog = {}
    valid_price_rows = []
    seen_products = set()
    count_total = 0

    with open(raw_path, "r", encoding="utf-8-sig", errors="replace") as f_in:
        reader = csv.DictReader(f_in)
        for row in reader:
            count_total += 1
            idempresa = (row.get("idempresa") or "").strip()
            if not idempresa:
                continue
                
            lat_raw = row.get("latitud", "").replace(",", ".")
            lon_raw = row.get("longitud", "").replace(",", ".")
            try:
                lat = float(lat_raw) if lat_raw else None
                lon = float(lon_raw) if lon_raw else None
                if lat is not None and (lat > -15 or lat < -60):
                    lat = None
                if lon is not None and (lon > -45 or lon < -80):
                    lon = None
            except ValueError:
                lat, lon = None, None

            if lat is None or lon is None:
                continue

            cuit = (row.get("cuit") or "").strip()
            empresa = (row.get("empresa") or "").strip()
            direccion = (row.get("direccion") or "").strip()
            localidad = (row.get("localidad") or "").strip()
            provincia = (row.get("provincia") or "").strip()
            region = (row.get("region") or "").strip()
            idempresabandera = (row.get("idempresabandera") or "").strip()
            empresabandera = (row.get("empresabandera") or "").strip()

            if idempresa not in stations_catalog:
                stations_catalog[idempresa] = [
                    idempresa, cuit, empresa, direccion, localidad, provincia, region,
                    "", "", "", "", "", "",
                    idempresabandera, empresabandera,
                    f"{lat:.6f}", f"{lon:.6f}"
                ]

            try:
                precio_raw = row.get("precio", "").replace(",", ".")
                precio = float(precio_raw) if precio_raw else 0.0
            except ValueError:
                precio = 0.0

            fecha_vigencia = (row.get("fecha_vigencia") or "").strip()
            producto = (row.get("producto") or "").strip()
            idproducto = (row.get("idproducto") or "").strip()
            idtipohorario = (row.get("idtipohorario") or "").strip()
            tipohorario = (row.get("tipohorario") or "").strip()

            if precio > 0 and fecha_vigencia and producto:
                try:
                    clean_dt = fecha_vigencia.replace("Z", "").split(".")[0]
                    f_dt = datetime.fromisoformat(clean_dt)
                    if (now - f_dt).days <= 30:
                        k = (idempresa, direccion, producto)
                        if k not in seen_products:
                            seen_products.add(k)
                            valid_price_rows.append([
                                idempresa, cuit, empresa, direccion, localidad, provincia, region,
                                idproducto, producto, idtipohorario, tipohorario,
                                f"{precio:.2f}", fecha_vigencia, idempresabandera, empresabandera,
                                f"{lat:.6f}", f"{lon:.6f}"
                            ])
                except Exception:
                    pass

    # Identificar estaciones que no tienen precios vigentes
    stations_with_price = {r[0] for r in valid_price_rows}
    no_price_rows = [s for id_e, s in stations_catalog.items() if id_e not in stations_with_price]

    with open(output_csv, "w", encoding="utf-8", newline="") as f_out:
        writer = csv.writer(f_out, quoting=csv.QUOTE_MINIMAL)
        writer.writerow(target_columns)
        for r in valid_price_rows:
            writer.writerow(r)
        for r in no_price_rows:
            writer.writerow(r)

    count_valid = len(valid_price_rows) + len(no_price_rows)
    duracion = time.time() - t0
    print(f"[OK] Normalización finalizada en {duracion:.1f}s.")
    print(f"    Total leídos: {count_total:,} | Con precio <= 30d: {len(valid_price_rows):,} | Sin precio (solo mapa): {len(no_price_rows):,}")
    print(f"    Total exportado: {count_valid:,} -> {output_csv}")
    return count_valid

def ejecutar_paso_combustibles() -> Path:
    raw_file = RAW_DIR / "precios_combustibles_raw.csv"
    processed_file = PROCESSED_DIR / "combustibles.csv"
    
    ok = descargar_csv_combustibles(raw_file)
    if not ok:
        if raw_file.exists():
            print("[*] Usando archivo raw existente como respaldo...")
        else:
            raise RuntimeError("No se pudo descargar el dataset de combustibles ni hay respaldo local.")
            
    normalizar_combustibles(raw_file, processed_file)
    return processed_file

ejecutar_descarga = ejecutar_paso_combustibles

if __name__ == "__main__":
    ejecutar_paso_combustibles()
