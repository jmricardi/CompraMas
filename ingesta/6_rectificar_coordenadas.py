#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
6_rectificar_coordenadas.py
---------------------------
Rectifica las coordenadas inexactas declaradas por supermercados en SEPA
utilizando una estrategia en cascada 100% gratuita:
  1. OpenStreetMap Overpass API (búsqueda de POI de la cadena en radio cercano).
  2. Georef-AR (API Oficial del Instituto Geográfico Nacional / Datos Gob AR).
  3. Nominatim OpenStreetMap (Geocodificador de direcciones argentinas).

Persistencia Dual Inmutable:
  - Local: data/georef/sucursales_rectificadas.csv
  - Nube: Tabla 'sucursales_rectificadas' en Supabase + UPDATE en tabla 'sucursales'
"""

import sys
import os
import re
import json
import time
import math
import argparse
import urllib.request
import urllib.parse
from pathlib import Path
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

from config import (
    BASE_DIR,
    PROCESSED_DIR,
    GEOREF_DIR,
    SUPABASE_DB_URL
)

RECTIFICADAS_CSV = GEOREF_DIR / "sucursales_rectificadas.csv"

# Normalizador de marcas de supermercado
CADENAS_CONOCIDAS = {
    "10_": "carrefour",
    "12_": "coto",
    "15_": "dia",
    "9_1": "vea",
    "9_2": "disco",
    "9_3": "jumbo",
    "9_": "cencosud",
    "11_": "changomas",
    "2_": "la anonima",
    "13_": "cooperativa obrera",
    "21_": "toledo",
    "6_": "comodin",
    "makro": "makro",
    "vital": "vital",
    "maxiconsumo": "maxiconsumo",
}

def resolver_marca(ent_id: str, nombre_sucursal: str) -> str:
    ent_id_clean = str(ent_id).strip().lower()
    for pref, marca in CADENAS_CONOCIDAS.items():
        if ent_id_clean.startswith(pref) or ent_id_clean == pref:
            return marca
    nom_upper = str(nombre_sucursal).upper()
    if "CARREFOUR" in nom_upper: return "carrefour"
    if "COTO" in nom_upper: return "coto"
    if "DIA" in nom_upper: return "dia"
    if "JUMBO" in nom_upper: return "jumbo"
    if "DISCO" in nom_upper: return "disco"
    if "VEA" in nom_upper: return "vea"
    if "CHANGOMAS" in nom_upper or "CHANGO" in nom_upper: return "changomas"
    if "ANONIMA" in nom_upper: return "la anonima"
    if "COOPERATIVA" in nom_upper: return "cooperativa obrera"
    if "TOLEDO" in nom_upper: return "toledo"
    if "MAKRO" in nom_upper: return "makro"
    if "VITAL" in nom_upper: return "vital"
    if "MAXICONSUMO" in nom_upper: return "maxiconsumo"
    return ""

def calcular_distancia_metros(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def extraer_calle_y_altura(domicilio: str) -> tuple:
    """Extrae calle y número de alturas de una dirección argentina."""
    if not domicilio or pd.isna(domicilio):
        return "", ""
    partes = [p.strip() for p in str(domicilio).split(",") if p.strip()]
    if not partes:
        return "", ""
    
    # Caso 1: partes[0] es la calle y partes[1] es la altura ("Nazca", "1944")
    if len(partes) >= 2 and re.match(r"^\d{1,5}$", partes[1]):
        return partes[0].strip(), partes[1].strip()

    # Caso 2: partes[0] contiene calle y altura juntas ("Av. Nazca 1944")
    match = re.search(r"^(.*?)\s+(\d{1,5})(?:\s+.*)?$", partes[0])
    if match:
        return match.group(1).strip(), match.group(2).strip()

    # Caso 3: buscar primer número entero en cualquier parte
    match_any = re.search(r"\b(\d{1,5})\b", str(domicilio))
    if match_any:
        altura = match_any.group(1)
        calle = partes[0].replace(altura, "").strip()
        return calle, altura

    return partes[0].strip(), ""

# ---------------------------------------------------------
# Nivel 1: OpenStreetMap (Overpass API)
# ---------------------------------------------------------
def buscar_poi_osm(lat_dec: float, lon_dec: float, marca: str, radio_m: int = 1500) -> tuple:
    if not marca or lat_dec == 0 or lon_dec == 0:
        return None, None, ""
    
    query = f"""
    [out:json][timeout:8];
    (
      node["shop"~"supermarket|convenience"](around:{radio_m},{lat_dec},{lon_dec});
      way["shop"~"supermarket|convenience"](around:{radio_m},{lat_dec},{lon_dec});
    );
    out center;
    """
    url = "https://overpass-api.de/api/interpreter"
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"User-Agent": "CompraMas-Georef-Auditor/1.0 (contacto: soporte@compramas.app)"}
    )
    
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data_json = json.loads(resp.read().decode("utf-8"))
            elements = data_json.get("elements", [])
            
            mejor_match = None
            min_dist = float("inf")
            marca_patron = marca.lower().replace(" ", "")

            for elem in elements:
                tags = elem.get("tags", {})
                nom = (tags.get("name", "") + " " + tags.get("brand", "")).lower().replace(" ", "")
                if marca_patron in nom or (marca == "dia" and ("dia%" in nom or "dia" in nom)):
                    e_lat = elem.get("lat") or elem.get("center", {}).get("lat")
                    e_lon = elem.get("lon") or elem.get("center", {}).get("lon")
                    if e_lat and e_lon:
                        dist = calcular_distancia_metros(lat_dec, lon_dec, float(e_lat), float(e_lon))
                        if dist < min_dist:
                            min_dist = dist
                            mejor_match = (float(e_lat), float(e_lon), "osm_poi")

            if mejor_match:
                return mejor_match
    except Exception:
        pass
    return None, None, ""

PROVINCIAS_ISO = {
    "AR-C": "Ciudad Autónoma de Buenos Aires",
    "AR-B": "Buenos Aires",
    "AR-X": "Córdoba",
    "AR-S": "Santa Fe",
    "AR-M": "Mendoza",
    "AR-T": "Tucumán",
    "AR-E": "Entre Ríos",
    "AR-W": "Corrientes",
    "AR-H": "Chaco",
    "AR-N": "Misiones",
    "AR-A": "Salta",
    "AR-Y": "Jujuy",
    "AR-J": "San Juan",
    "AR-D": "San Luis",
    "AR-L": "La Pampa",
    "AR-Q": "Neuquén",
    "AR-R": "Río Negro",
    "AR-U": "Chubut",
    "AR-Z": "Santa Cruz",
    "AR-V": "Tierra del Fuego",
    "AR-K": "Catamarca",
    "AR-F": "La Rioja",
    "AR-G": "Santiago del Estero",
    "AR-P": "Formosa",
}

def resolver_provincia(domicilio: str) -> str:
    dom_upper = str(domicilio).upper()
    for iso, nombre in PROVINCIAS_ISO.items():
        if iso in dom_upper:
            return nombre
    if "CIUDAD AUTÓNOMA" in dom_upper or "CIUDAD AUTONOMA" in dom_upper or "CABA" in dom_upper or "CAPITAL FEDERAL" in dom_upper:
        return "Ciudad Autónoma de Buenos Aires"
    if "BUENOS AIRES" in dom_upper:
        return "Buenos Aires"
    if "CORDOBA" in dom_upper or "CÓRDOBA" in dom_upper:
        return "Córdoba"
    if "SANTA FE" in dom_upper:
        return "Santa Fe"
    if "MENDOZA" in dom_upper:
        return "Mendoza"
    return ""

# ---------------------------------------------------------
# Nivel 2: Georef-AR (API Oficial República Argentina)
# ---------------------------------------------------------
def geocodificar_georef_ar(domicilio: str) -> tuple:
    calle, altura = extraer_calle_y_altura(domicilio)
    if not calle or not altura:
        return None, None, ""

    provincia = resolver_provincia(domicilio)

    params = {
        "direccion": f"{calle} {altura}",
        "max": 1
    }
    if provincia:
        params["provincia"] = provincia

    url = "https://apis.datos.gob.ar/georef/api/direcciones?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "CompraMas/1.0"}
    )
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data_json = json.loads(resp.read().decode("utf-8"))
            direcciones = data_json.get("direcciones", [])
            if direcciones:
                ub = direcciones[0].get("ubicacion", {})
                lat = ub.get("lat")
                lon = ub.get("lon")
                if lat and lon:
                    return float(lat), float(lon), "georef_ar"
    except Exception:
        pass
    return None, None, ""

# ---------------------------------------------------------
# Nivel 3: Nominatim OSM (Direcciones y Barrios de Argentina)
# ---------------------------------------------------------
def geocodificar_nominatim(domicilio: str, marca: str = "") -> tuple:
    calle, altura = extraer_calle_y_altura(domicilio)
    if not calle or not altura:
        return None, None, ""

    provincia = resolver_provincia(domicilio)
    partes = [p.strip() for p in str(domicilio).split(",") if p.strip()]
    localidad = partes[2] if len(partes) > 2 and partes[2] not in PROVINCIAS_ISO else ""

    query_parts = [calle, altura]
    if localidad and "CIUDAD" not in localidad.upper():
        query_parts.append(localidad)
    if provincia:
        query_parts.append(provincia)
    query_parts.append("Argentina")

    q = " ".join(query_parts)
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode({
        "q": q,
        "format": "json",
        "countrycodes": "ar",
        "limit": 1
    })
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "CompraMas-App/1.0 (auditor@compramas.app)"}
    )
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data_json = json.loads(resp.read().decode("utf-8"))
            if data_json:
                lat = data_json[0].get("lat")
                lon = data_json[0].get("lon")
                if lat and lon:
                    return float(lat), float(lon), "osm_nominatim"
    except Exception:
        pass
    return None, None, ""

# ---------------------------------------------------------
# Conexión y Gestión en Supabase
# ---------------------------------------------------------
def obtener_rectificadas_existentes():
    mapa = {}
    if RECTIFICADAS_CSV.exists():
        try:
            df = pd.read_csv(RECTIFICADAS_CSV, dtype=str)
            for _, r in df.iterrows():
                mapa[(str(r["id_entidad"]).strip(), str(r["id_sucursal"]).strip())] = r.to_dict()
        except Exception:
            pass

    if SUPABASE_DB_URL:
        try:
            conn = psycopg2.connect(SUPABASE_DB_URL)
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id_entidad, id_sucursal, sucursales_nombre, sucursales_domicilio,
                           latitud_original, longitud_original, latitud_rectificada, longitud_rectificada,
                           distancia_ajuste_metros, fuente_rectificacion
                    FROM sucursales_rectificadas;
                """)
                rows = cur.fetchall()
                for row in rows:
                    k = (str(row[0]).strip(), str(row[1]).strip())
                    mapa[k] = {
                        "id_entidad": str(row[0]).strip(),
                        "id_sucursal": str(row[1]).strip(),
                        "sucursales_nombre": row[2],
                        "sucursales_domicilio": row[3],
                        "latitud_original": row[4],
                        "longitud_original": row[5],
                        "latitud_rectificada": row[6],
                        "longitud_rectificada": row[7],
                        "distancia_ajuste_metros": row[8],
                        "fuente_rectificacion": row[9],
                    }
            conn.close()
        except Exception as e:
            print(f"[!] Aviso: No se pudo consultar sucursales_rectificadas de Supabase: {e}")
    return mapa

def sincronizar_con_supabase(nuevos_registros: list):
    if not nuevos_registros or not SUPABASE_DB_URL:
        return
    
    print(f"[*] Sincronizando {len(nuevos_registros)} rectificaciones con Supabase...")
    try:
        conn = psycopg2.connect(SUPABASE_DB_URL)
        with conn.cursor() as cur:
            # 1. UPSERT en sucursales_rectificadas
            sql_upsert = """
                INSERT INTO sucursales_rectificadas (
                    id_entidad, id_sucursal, sucursales_nombre, sucursales_domicilio,
                    latitud_original, longitud_original, latitud_rectificada, longitud_rectificada,
                    distancia_ajuste_metros, fuente_rectificacion, fecha_rectificacion
                ) VALUES %s
                ON CONFLICT (id_entidad, id_sucursal) DO UPDATE SET
                    latitud_rectificada = EXCLUDED.latitud_rectificada,
                    longitud_rectificada = EXCLUDED.longitud_rectificada,
                    distancia_ajuste_metros = EXCLUDED.distancia_ajuste_metros,
                    fuente_rectificacion = EXCLUDED.fuente_rectificacion,
                    fecha_rectificacion = NOW();
            """
            filas_rect = [
                (
                    r["id_entidad"], r["id_sucursal"], r["sucursales_nombre"], r["sucursales_domicilio"],
                    r["latitud_original"], r["longitud_original"], r["latitud_rectificada"], r["longitud_rectificada"],
                    r["distancia_ajuste_metros"], r["fuente_rectificacion"], r.get("fecha_rectificacion", time.strftime("%Y-%m-%d %H:%M:%S"))
                )
                for r in nuevos_registros
            ]
            execute_values(cur, sql_upsert, filas_rect)

            # 2. UPDATE directo en la tabla sucursales para actualizar en caliente
            sql_update_suc = """
                UPDATE sucursales s
                SET sucursales_latitud = r.latitud_rectificada,
                    sucursales_longitud = r.longitud_rectificada,
                    codigo_georeferencia = 'COORDENADA_VERIFICADA'
                FROM sucursales_rectificadas r
                WHERE s.id_entidad = r.id_entidad AND s.id_sucursal = r.id_sucursal;
            """
            cur.execute(sql_update_suc)

        conn.commit()
        conn.close()
        print("[OK] Sincronización con Supabase finalizada exitosamente.")
    except Exception as e:
        print(f"[-] Error al sincronizar con Supabase: {e}")

# ---------------------------------------------------------
# Proceso Principal
# ---------------------------------------------------------
def ejecutar_rectificacion(limit: int = None, forzar: bool = False, dry_run: bool = False):
    archivo_suc = PROCESSED_DIR / "sucursales_opt.csv"
    if not archivo_suc.exists():
        print(f"[-] No se encontró {archivo_suc}. Ejecuta primero 3_refactorizar_tablas.py")
        return

    df_suc = pd.read_csv(archivo_suc, dtype=str)
    # Filtrar solo sucursales físicas (no virtuales)
    df_suc = df_suc[
        (df_suc["codigo_georeferencia"] != "SIN_LOCALIZACION_FISICA") &
        (df_suc["sucursales_tipo"].str.lower() != "virtual")
    ].copy()

    rectificadas_existentes = obtener_rectificadas_existentes()
    print(f"[*] Total sucursales físicas en catálogo: {len(df_suc):,}")
    print(f"[*] Sucursales rectificadas previas en maestro: {len(rectificadas_existentes):,}")

    pendientes = []
    for _, row in df_suc.iterrows():
        ent_id = str(row.get("id_entidad", "")).strip()
        suc_id = str(row.get("id_sucursal", "")).strip()
        if forzar or (ent_id, suc_id) not in rectificadas_existentes:
            pendientes.append(row)

    print(f"[*] Sucursales a rectificar: {len(pendientes):,}")
    if limit:
        pendientes = pendientes[:limit]
        print(f"[*] Limitando ejecución a {limit} sucursales para prueba controlada...")

    if not pendientes:
        print("[OK] No hay sucursales pendientes de rectificar.")
        return

    nuevos_resultados = []
    total = len(pendientes)

    for idx, row in enumerate(pendientes, start=1):
        ent_id = str(row.get("id_entidad", "")).strip()
        suc_id = str(row.get("id_sucursal", "")).strip()
        nombre = str(row.get("sucursales_nombre", "")).strip()
        domicilio = str(row.get("sucursales_domicilio_completo", "")).strip()
        lat_str = str(row.get("sucursales_latitud", "")).strip()
        lon_str = str(row.get("sucursales_longitud", "")).strip()

        lat_dec = float(lat_str) if lat_str and lat_str != "nan" else 0.0
        lon_dec = float(lon_str) if lon_str and lon_str != "nan" else 0.0
        marca = resolver_marca(ent_id, nombre)

        print(f"\n[{idx}/{total}] Rectificando: {ent_id}-{suc_id} | {nombre} ({marca.upper()}) | {domicilio}")
        print(f"       Coords declaradas: lat={lat_dec}, lon={lon_dec}")

        lat_rec, lon_rec, fuente = None, None, ""

        # Nivel 1: OpenStreetMap Overpass (POI de la cadena)
        if lat_dec != 0 and lon_dec != 0 and marca:
            lat_rec, lon_rec, fuente = buscar_poi_osm(lat_dec, lon_dec, marca, radio_m=1500)
            if lat_rec:
                print(f"       -> [OSM POI Encontrado]: lat={lat_rec:.6f}, lon={lon_rec:.6f}")

        # Nivel 2: Georef-AR Oficial (Dirección Catastral exacta)
        if not lat_rec:
            time.sleep(0.15) # Respetar rate-limit
            lat_rec, lon_rec, fuente = geocodificar_georef_ar(domicilio)
            if lat_rec:
                print(f"       -> [Georef-AR Encontrado]: lat={lat_rec:.6f}, lon={lon_rec:.6f}")

        # Nivel 3: Nominatim OSM
        if not lat_rec:
            time.sleep(0.5)
            lat_rec, lon_rec, fuente = geocodificar_nominatim(domicilio, marca)
            if lat_rec:
                print(f"       -> [Nominatim Encontrado]: lat={lat_rec:.6f}, lon={lon_rec:.6f}")

        if lat_rec and lon_rec:
            dist_ajuste = calcular_distancia_metros(lat_dec, lon_dec, lat_rec, lon_rec) if (lat_dec != 0 and lon_dec != 0) else None
            
            # Validación de seguridad contra falsos positivos (calles homónimas en otras ciudades)
            if dist_ajuste is not None and dist_ajuste > 3000.0:
                print(f"       [!] Desvío excesivo ({dist_ajuste/1000:.1f} km > 3 km). Posible falso positivo de geocodificación. Se descarta.")
            else:
                print(f"       [OK EXITO] Fuente: {fuente} | Ajuste: {f'{dist_ajuste:.1f} metros' if dist_ajuste is not None else 'nueva coord'}")

                registro = {
                    "id_entidad": ent_id,
                    "id_sucursal": suc_id,
                    "sucursales_nombre": nombre,
                    "sucursales_domicilio": domicilio,
                    "latitud_original": lat_dec if lat_dec != 0 else None,
                    "longitud_original": lon_dec if lon_dec != 0 else None,
                    "latitud_rectificada": round(lat_rec, 6),
                    "longitud_rectificada": round(lon_rec, 6),
                    "distancia_ajuste_metros": round(dist_ajuste, 1) if dist_ajuste is not None else None,
                    "fuente_rectificacion": fuente,
                    "fecha_rectificacion": time.strftime("%Y-%m-%d %H:%M:%S")
                }
                nuevos_resultados.append(registro)
                rectificadas_existentes[(ent_id, suc_id)] = registro
        else:
            print("       [!] No se pudo georreferenciar con precisión. Mantiene declarada.")

        # Pausa breve de cortesía entre consultas
        time.sleep(0.2)

    if not dry_run and nuevos_resultados:
        # Guardar en CSV local
        df_total = pd.DataFrame(list(rectificadas_existentes.values()))
        df_total.to_csv(RECTIFICADAS_CSV, sep=",", index=False, encoding="utf-8")
        print(f"\n[OK] Maestro local actualizado: {RECTIFICADAS_CSV} ({len(df_total)} registros totales)")

        # Sincronizar en Supabase
        sincronizar_con_supabase(nuevos_resultados)
    elif dry_run:
        print(f"\n[DRY RUN] Se rectificaron {len(nuevos_resultados)} de {total} sucursales (sin persistir).")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rectificador inmutable de coordenadas de sucursales.")
    parser.add_argument("--limit", type=int, default=None, help="Límite de sucursales a procesar.")
    parser.add_argument("--forzar", action="store_true", help="Reprocesar incluso las ya rectificadas.")
    parser.add_argument("--dry-run", action="store_true", help="Ejecución de prueba sin guardar cambios.")
    args = parser.parse_args()

    ejecutar_rectificacion(limit=args.limit, forzar=args.forzar, dry_run=args.dry_run)
