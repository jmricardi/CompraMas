#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
3_refactorizar_tablas.py
------------------------
Refactoriza y optimiza los datos consolidados de SEPA para Supabase:
- Elimina duplicaciones.
- Crea claves compuestas id_entidad (id_comercio_id_bandera).
- Preserva códigos de barra con ceros a la izquierda (EAN/GTIN).
- Agrupa precios por id_entidad e id_producto agrupando sucursales.
Salidas en data/processed/:
  - comercio_opt.csv
  - sucursales_opt.csv
  - catalogo_productos.csv
  - precios.csv
"""

import os
import sys
import argparse
import time
import psycopg2
import pandas as pd
from pathlib import Path
from config import RAW_DIR, PROCESSED_DIR, GEOREF_DIR, SUPABASE_DB_URL

def obtener_catalogo_existente_supabase() -> pd.DataFrame:
    """Descarga los productos existentes en Supabase para asegurar preservación incremental."""
    try:
        if not SUPABASE_DB_URL:
            return pd.DataFrame()
        conn = psycopg2.connect(SUPABASE_DB_URL)
        cols = [
            "id_producto", "productos_ean", "productos_descripcion", "productos_marca",
            "productos_cantidad_presentacion", "productos_unidad_medida_presentacion"
        ]
        query = f"SELECT {', '.join(cols)} FROM productos;"
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '60s';")
            cur.execute(query)
            rows = cur.fetchall()
            df_existente = pd.DataFrame(rows, columns=cols).astype(str)
        conn.close()
        print(f"[+] Productos históricos recuperados de Supabase: {len(df_existente):,}")
        return df_existente
    except Exception as e:
        print(f"[!] Aviso: No se pudo conectar a Supabase para recuperar catálogo histórico ({e}). Se continuará con el catálogo local.")
        return pd.DataFrame()

def limpiar_id(val):
    if pd.isna(val):
        return ""
    try:
        return str(int(float(val)))
    except (ValueError, TypeError):
        return str(val).strip()

def limpiar_codigo_barra(val):
    if pd.isna(val):
        return ""
    s = str(val).strip()
    if s.endswith(".0"):
        s = s[:-2]
    return s

def refactorizar_comercio(raw_dir: Path, out_dir: Path):
    print("[*] Refactorizando comercio...")
    input_file = raw_dir / "master_comercio.csv"
    if not input_file.exists():
        input_file = raw_dir / "comercio_final.csv"
    if not input_file.exists():
        print(f"[-] No se encontró archivo de comercio en {raw_dir}")
        return
        
    df = pd.read_csv(input_file, sep="|", encoding="utf-8-sig", low_memory=False, dtype=str)
    df.columns = [c.strip().lstrip("\ufeff") for c in df.columns]
    df = df.dropna(subset=["id_comercio", "id_bandera"]).copy()
    
    df["id_entidad"] = df["id_comercio"].apply(limpiar_id) + "_" + df["id_bandera"].apply(limpiar_id)
    if "comercio_cuit" in df.columns:
        df["comercio_cuit"] = df["comercio_cuit"].apply(limpiar_id)
        
    df = df.drop(columns=["id_comercio", "id_bandera"], errors="ignore")
    
    # Canales Online y Cadenas Mayoristas adicionales
    comercios_extra = pd.DataFrame([
        {"id_entidad": "vital_online", "comercio_razon_social": "MAYORISTA VITAL S.A.", "comercio_bandera_nombre": "Vital Mayorista"},
        {"id_entidad": "maxiconsumo_online", "comercio_razon_social": "MAXICONSUMO S.A.", "comercio_bandera_nombre": "Maxiconsumo"},
        {"id_entidad": "makro_online", "comercio_razon_social": "SUPERMERCADOS MAYORISTAS MAKRO S.A.", "comercio_bandera_nombre": "Makro"},
        {"id_entidad": "yaguar_online", "comercio_razon_social": "MAYORISTA YAGUAR S.A.", "comercio_bandera_nombre": "Yaguar"},
        {"id_entidad": "diarco_online", "comercio_razon_social": "DIARCO S.A.", "comercio_bandera_nombre": "Diarco"},
        {"id_entidad": "carrefour_online", "comercio_razon_social": "INC S.A.", "comercio_bandera_nombre": "Carrefour Online"},
        {"id_entidad": "coto_online", "comercio_razon_social": "COTO C.I.C.S.A.", "comercio_bandera_nombre": "Coto Digital"},
        {"id_entidad": "dia_online", "comercio_razon_social": "DIA ARGENTINA S.A.", "comercio_bandera_nombre": "DIA Online"},
    ])
    df = pd.concat([df, comercios_extra], ignore_index=True)
    df = df.drop_duplicates(subset=["id_entidad"], keep="first")
    
    cols = ["id_entidad"] + [c for c in df.columns if c != "id_entidad"]
    df = df[cols]
    
    out_file = out_dir / "comercio_opt.csv"
    df.to_csv(out_file, sep=",", index=False, encoding="utf-8")
    print(f"[OK] comercio_opt.csv generado: {len(df):,} comercios únicos (incluye mayoristas y canales online)")

def refactorizar_sucursales(raw_dir: Path, out_dir: Path):
    print("[*] Refactorizando sucursales...")
    input_file = raw_dir / "master_sucursales.csv"
    if not input_file.exists():
        input_file = raw_dir / "sucursales_final.csv"
    if not input_file.exists():
        print(f"[-] No se encontró archivo de sucursales en {raw_dir}")
        return
        
    with open(input_file, "r", encoding="utf-8-sig", errors="replace") as f:
        header = f.readline().strip().lstrip("\ufeff")
        cols = [c.strip().lstrip("\ufeff") for c in header.split("|")]
        expected = len(cols)
        
        rows = []
        buf = ""
        for line in f:
            clean = line.rstrip("\r\n").replace("\x00", "")
            if not clean.strip():
                continue
            buf = clean if not buf else buf + clean
            parts = buf.split("|")
            if len(parts) == expected:
                rows.append([p.strip() for p in parts])
                buf = ""
            elif len(parts) > expected:
                buf = ""
                
    df = pd.DataFrame(rows, columns=cols)
    df.columns = [c.strip().lstrip("\ufeff") for c in df.columns]
    df = df[(df["id_comercio"] != "") & (df["id_sucursal"] != "")].copy()
    
    df["id_entidad"] = df["id_comercio"].apply(limpiar_id) + "_" + df["id_bandera"].apply(limpiar_id)
    df["id_sucursal"] = df["id_sucursal"].apply(limpiar_id)
    
    def armar_direccion(row):
        partes = [
            row.get("sucursales_calle", ""),
            row.get("sucursales_numero", ""),
            row.get("sucursales_localidad", ""),
            row.get("sucursales_provincia", "")
        ]
        return ", ".join([p for p in partes if p and p.strip()])
        
    df["sucursales_domicilio_completo"] = df.apply(armar_direccion, axis=1)

    import re

    def limpiar_codigo_postal(val):
        if not val or pd.isna(val):
            return ""
        s = str(val).strip()
        m = re.search(r'(\d{4})', s)
        return m.group(1) if m else ""

    df["codigo_postal"] = df.get("sucursales_codigo_postal", pd.Series([""] * len(df))).apply(limpiar_codigo_postal)
    
    def limpiar_coord_lat(val):
        if not val or pd.isna(val):
            return ""
        s = str(val).strip().replace(",", ".")
        try:
            f = float(s)
            return str(f) if f != 0 else ""
        except ValueError:
            return ""

    def limpiar_coord_lon(val):
        if not val or pd.isna(val):
            return ""
        s = str(val).strip().replace(",", ".")
        try:
            f = float(s)
            if f != 0:
                # En Argentina las longitudes son siempre negativas
                if f > 0:
                    f = -abs(f)
                return str(f)
            return ""
        except ValueError:
            return ""

    df["sucursales_latitud"] = df["sucursales_latitud"].apply(limpiar_coord_lat)
    df["sucursales_longitud"] = df["sucursales_longitud"].apply(limpiar_coord_lon)

    import re
    patron_virtual = re.compile(
        r'\b(online|e-commerce|ecommerce|digital|virtual|web|internet)\b|https?://|www\.',
        re.IGNORECASE
    )

    # Cargar maestro inmutable de coordenadas rectificadas (Local y Supabase)
    mapa_rectificadas = {}
    f_rect_local = GEOREF_DIR / "sucursales_rectificadas.csv"
    if f_rect_local.exists():
        try:
            df_r = pd.read_csv(f_rect_local, dtype=str)
            for _, r in df_r.iterrows():
                k = (str(r["id_entidad"]).strip(), str(r["id_sucursal"]).strip())
                mapa_rectificadas[k] = (str(r["latitud_rectificada"]).strip(), str(r["longitud_rectificada"]).strip(), str(r.get("fuente_rectificacion", "rectificada")).strip())
            print(f"[*] {len(mapa_rectificadas)} sucursales rectificadas cargadas desde maestro local.")
        except Exception as e:
            print(f"[!] Error leyendo {f_rect_local}: {e}")

    if SUPABASE_DB_URL:
        try:
            conn = psycopg2.connect(SUPABASE_DB_URL)
            with conn.cursor() as cur:
                cur.execute("SELECT id_entidad, id_sucursal, latitud_rectificada, longitud_rectificada, fuente_rectificacion FROM sucursales_rectificadas;")
                filas = cur.fetchall()
                nuevas_sb = 0
                for row in filas:
                    k = (str(row[0]).strip(), str(row[1]).strip())
                    if k not in mapa_rectificadas:
                        mapa_rectificadas[k] = (str(row[2]).strip(), str(row[3]).strip(), str(row[4]).strip())
                        nuevas_sb += 1
                if nuevas_sb > 0:
                    print(f"[*] {nuevas_sb} sucursales rectificadas adicionales incorporadas desde Supabase.")
            conn.close()
        except Exception:
            pass

    def clasificar_sucursal(row):
        ent_id = str(row.get("id_entidad", "")).strip()
        suc_id = str(row.get("id_sucursal", "")).strip()
        nombre = str(row.get("sucursales_nombre", "")).strip()
        tipo = str(row.get("sucursales_tipo", "")).strip()
        domicilio = str(row.get("sucursales_domicilio_completo", "")).strip()

        full_txt = f"{nombre} {tipo} {domicilio}"
        is_virtual = bool(patron_virtual.search(full_txt)) or (ent_id, suc_id) in [
            ("2_1", "8015"), ("2_1", "9021"), ("15_1", "90000")
        ]

        if is_virtual:
            return pd.Series([
                "Virtual", "", "", "SIN_LOCALIZACION_FISICA"
            ], index=["sucursales_tipo", "sucursales_latitud", "sucursales_longitud", "codigo_georeferencia"])

        # Coordenada rectificada inmutable (prioridad absoluta sobre SEPA)
        if (ent_id, suc_id) in mapa_rectificadas:
            lat_r, lon_r, _ = mapa_rectificadas[(ent_id, suc_id)]
            return pd.Series([
                tipo or "Supermercado", lat_r, lon_r, "COORDENADA_VERIFICADA"
            ], index=["sucursales_tipo", "sucursales_latitud", "sucursales_longitud", "codigo_georeferencia"])

        lat_val = str(row.get("sucursales_latitud", "")).strip()
        lon_val = str(row.get("sucursales_longitud", "")).strip()
        georef = "COORDENADA_DECLARADA" if lat_val and lon_val else "COORDENADA_PENDIENTE"
        return pd.Series([
            tipo or "Supermercado", lat_val, lon_val, georef
        ], index=["sucursales_tipo", "sucursales_latitud", "sucursales_longitud", "codigo_georeferencia"])

    geo_cols = df.apply(clasificar_sucursal, axis=1)
    df["sucursales_tipo"] = geo_cols["sucursales_tipo"]
    df["sucursales_latitud"] = geo_cols["sucursales_latitud"]
    df["sucursales_longitud"] = geo_cols["sucursales_longitud"]
    df["codigo_georeferencia"] = geo_cols["codigo_georeferencia"]

    # Canales Online y Cadenas Mayoristas adicionales
    sucursales_extra = pd.DataFrame([
        {
            "id_entidad": "vital_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Vital Mayorista Online",
            "sucursales_tipo": "Mayorista",
            "sucursales_domicilio_completo": "Tienda Online Nacional y Venta Telefónica",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "Lunes a Viernes 08:00 a 18:00",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "maxiconsumo_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Maxiconsumo Online",
            "sucursales_tipo": "Mayorista",
            "sucursales_domicilio_completo": "Tienda Online y Sucursales Mayoristas",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "Lunes a Sábado 08:00 a 18:00",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "makro_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Makro Mayorista",
            "sucursales_tipo": "Mayorista",
            "sucursales_domicilio_completo": "Canal de Ofertas y Sucursales Mayoristas",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "Lunes a Sábado 08:00 a 19:00",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "yaguar_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Yaguar Mayorista",
            "sucursales_tipo": "Mayorista",
            "sucursales_domicilio_completo": "Portal B2B y Sucursales Mayoristas",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "Lunes a Sábado 08:00 a 18:00",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "diarco_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Diarco Mayorista",
            "sucursales_tipo": "Mayorista",
            "sucursales_domicilio_completo": "Canal Mayorista y Sucursales",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "Lunes a Sábado 08:00 a 18:00",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "carrefour_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Carrefour Online",
            "sucursales_tipo": "Virtual",
            "sucursales_domicilio_completo": "Tienda Online Carrefour.com.ar",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "24 Horas Web",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "coto_online",
            "id_sucursal": "online",
            "sucursales_nombre": "Coto Digital",
            "sucursales_tipo": "Virtual",
            "sucursales_domicilio_completo": "Tienda Online CotoDigital.com.ar",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "24 Horas Web",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
        {
            "id_entidad": "dia_online",
            "id_sucursal": "online",
            "sucursales_nombre": "DIA Online",
            "sucursales_tipo": "Virtual",
            "sucursales_domicilio_completo": "Tienda Online DiaOnline.supermercadosdia.com.ar",
            "sucursales_latitud": "",
            "sucursales_longitud": "",
            "sucursales_horarios": "24 Horas Web",
            "codigo_georeferencia": "SIN_LOCALIZACION_FISICA"
        },
    ])
    df = pd.concat([df, sucursales_extra], ignore_index=True)
    df = df.drop_duplicates(subset=["id_entidad", "id_sucursal"], keep="first")

    cols_supabase = [
        "id_entidad", "id_sucursal", "sucursales_nombre", "sucursales_tipo",
        "sucursales_domicilio_completo", "sucursales_latitud", "sucursales_longitud",
        "sucursales_horarios", "codigo_georeferencia", "codigo_postal"
    ]
    df = df[[c for c in cols_supabase if c in df.columns]]

    out_file = out_dir / "sucursales_opt.csv"
    df.to_csv(out_file, sep=",", index=False, encoding="utf-8")
    print(f"[OK] sucursales_opt.csv generado: {len(df):,} sucursales (incluye mayoristas y canales online)")

def limpiar_descripcion_producto(raw_desc: str, marca: str = None, cantidad: str = None, unidad: str = None) -> str:
    """Limpia y normaliza la descripción del producto eliminando sufijos técnicos, marcas redundantes y gramajes."""
    if not raw_desc or pd.isna(raw_desc):
        return ""
    import re
    text = str(raw_desc).strip()

    # 1. Quitar sufijos técnicos de empaque y gramajes al final (ej: "-395-gr.", "-1000-gr", "-1-lt")
    text = re.sub(r'[-–]\s*\d+(?:[.,]\d+)?\s*[-–]?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l|cm3|un|u)\b\.?$', '', text, flags=re.IGNORECASE).strip()

    # 2. Quitar descriptores técnicos de envase/packaging
    text = re.sub(r'\b(BRK|BRIK|TETRABRIK|TETRA BRIK|TETRA|TTB|TB|DOYPACK|DOY PACK|DOY|SACHET|POUCH|PET|BOT)\b', '', text, flags=re.IGNORECASE)

    # 3. Quitar la marca si está presente en el texto para evitar redundancia
    if marca and not pd.isna(marca):
        m_clean = str(marca).strip()
        if len(m_clean) >= 3:
            # Reemplazar la marca exacta o variaciones de acento (ej. NESTLE, Nestlé)
            pattern_marca = re.escape(m_clean).replace('e', '[eé]').replace('E', '[EÉ]').replace('a', '[aá]').replace('A', '[AÁ]').replace('o', '[oó]').replace('O', '[OÓ]')
            text = re.sub(rf'\b{pattern_marca}\b', '', text, flags=re.IGNORECASE)

    # 4. Quitar expresiones de cantidades/gramajes redundantes (ej: "x395g", "395g", "x 1L")
    text = re.sub(r'\bx\s*\d+(?:[.,]\d+)?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l)\b', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\b\d+(?:[.,]\d+)?\s*(?:grs?|grms?|g|kgs?|kilos?|cc|mls?|ml|lts?|litros?|l)\b', '', text, flags=re.IGNORECASE)

    # 5. Normalizar términos comunes (ej: Org -> Orgánica, Lgt -> Light, Ent -> Entera)
    text = re.sub(r'\b(Org|ORG|organica|Organica)\b', '', text, flags=re.IGNORECASE)  # Si el usuario prefiere 'Leche Condensada'
    text = re.sub(r'\b(Lgt|LGT)\b', 'Light', text)
    text = re.sub(r'\b(Desc|DESC|descremada)\b', 'Descremada', text, flags=re.IGNORECASE)
    text = re.sub(r'\b(Ent|ENT)\b', 'Entera', text)

    # 6. Limpiar espacios múltiples y caracteres residuales
    text = re.sub(r'\s+', ' ', text).strip(' -.,')

    # 7. Formatear en Title Case elegante
    palabras = text.split()
    menores = {'de', 'del', 'la', 'las', 'el', 'los', 'en', 'y', 'o', 'con', 'sin', 'por'}
    resultado = []
    for i, w in enumerate(palabras):
        w_low = w.lower()
        if i > 0 and w_low in menores:
            resultado.append(w_low)
        elif w.upper() in ['L/V', 'UAT', 'UHT']:
            resultado.append(w.upper())
        else:
            resultado.append(w_low.capitalize())
    return " ".join(resultado)

def refactorizar_catalogo_y_precios(raw_dir: Path, out_dir: Path):
    print("[*] Procesando catálogo de productos y tabla de precios agrupada...")
    input_file = raw_dir / "master_productos.csv"
    if not input_file.exists():
        input_file = raw_dir / "productos_final.csv"
    if not input_file.exists():
        print(f"[-] No se encontró archivo de productos en {raw_dir}")
        return
        
    cols_catalogo = [
        "id_producto", "productos_ean", "productos_descripcion", "productos_marca",
        "productos_cantidad_presentacion", "productos_unidad_medida_presentacion"
    ]
    dtypes = {c: str for c in cols_catalogo}
    
    # 1. Catálogo de productos
    chunks_cat = []
    chunksize = 500000
    for i, ch in enumerate(pd.read_csv(input_file, sep="|", encoding="utf-8-sig", chunksize=chunksize, dtype=dtypes, usecols=cols_catalogo, low_memory=False)):
        sys.stdout.write(f"\r    Leyendo bloque {i+1} de productos para catálogo...")
        sys.stdout.flush()
        ch.columns = [c.strip().lstrip("\ufeff") for c in ch.columns]
        chunks_cat.append(ch)
    print()
    
    df_cat_hoy = pd.concat(chunks_cat, ignore_index=True)
    df_cat_hoy["id_producto"] = df_cat_hoy["id_producto"].apply(limpiar_codigo_barra)
    if "productos_ean" in df_cat_hoy.columns:
        df_cat_hoy["productos_ean"] = df_cat_hoy["productos_ean"].apply(limpiar_codigo_barra)
    df_cat_hoy = df_cat_hoy[df_cat_hoy["id_producto"] != ""].copy()
    
    # Recuperar histórico de Supabase para no perder productos de días anteriores
    df_hist = obtener_catalogo_existente_supabase()
    if not df_hist.empty:
        df_hist["id_producto"] = df_hist["id_producto"].apply(limpiar_codigo_barra)
        if "productos_ean" in df_hist.columns:
            df_hist["productos_ean"] = df_hist["productos_ean"].apply(limpiar_codigo_barra)
        df_hist = df_hist[df_hist["id_producto"] != ""].copy()
        df_cat = pd.concat([df_hist, df_cat_hoy], ignore_index=True)
    else:
        df_cat = df_cat_hoy
        
    df_cat["_desc_len"] = df_cat["productos_descripcion"].fillna("").astype(str).str.len()
    df_cat = df_cat.sort_values(by="_desc_len", ascending=False)
    df_cat = df_cat.drop_duplicates(subset=["id_producto"], keep="first")
    df_cat = df_cat.drop(columns=["_desc_len"])

    # Sanitizar descripciones de productos eliminando marcas repetidas y gramajes
    print("    -> Sanitizando títulos de productos (eliminando marcas redundantes y gramajes)...")
    df_cat["productos_descripcion"] = df_cat.apply(
        lambda r: limpiar_descripcion_producto(
            r.get("productos_descripcion"),
            r.get("productos_marca"),
            r.get("productos_cantidad_presentacion"),
            r.get("productos_unidad_medida_presentacion")
        ),
        axis=1
    )
    
    # --- Integración con Open Food Facts (OFF) ---
    off_file = out_dir / "off_metadata.csv"
    if off_file.exists():
        print(f"[*] Enriqueciendo catálogo con datos de Open Food Facts...")
        df_off = pd.read_csv(off_file, dtype=str)
        # Asegurarnos de limpiar el EAN por si acaso
        df_off["id_producto"] = df_off["id_producto"].apply(limpiar_codigo_barra)
        df_off = df_off.drop_duplicates(subset=["id_producto"])
        
        # Merge (Left Join)
        df_cat = pd.merge(df_cat, df_off, on="id_producto", how="left")
        print(f"    -> Productos enriquecidos con OFF: {df_cat['off_nombre'].notna().sum():,}")
    else:
        print("[-] No se encontró off_metadata.csv. El catálogo se generará sin enriquecimiento.")

    # --- Filtrar estrictamente productos de dominio supermercado (FMCG) ---
    print("    -> Aplicando filtro FMCG (descartando libros, ropa, electro y no-supermercado)...")
    from filtro_fmcg import es_producto_supermercado
    cant_pre_filtro = len(df_cat)
    mask_fmcg = df_cat.apply(
        lambda r: es_producto_supermercado(r.get("productos_descripcion", ""), r.get("productos_marca", "")),
        axis=1
    )
    df_cat = df_cat[mask_fmcg].copy()
    print(f"    -> {cant_pre_filtro - len(df_cat):,} artículos ajenos descartados ({len(df_cat):,} productos legítimos).")
    # ------------------------------------------------------------------------

    out_cat = out_dir / "catalogo_productos.csv"
    df_cat.to_csv(out_cat, sep=",", index=False, encoding="utf-8")
    print(f"[OK] catalogo_productos.csv generado: {len(df_cat):,} productos únicos (catálogo acumulado incremental)")
    
    # 2. Precios agrupados por id_entidad e id_producto
    print("[*] Agrupando precios por entidad y producto...")
    cols_precios = [
        "id_comercio", "id_bandera", "id_producto", "id_sucursal",
        "productos_precio_lista", "productos_precio_referencia",
        "productos_cantidad_referencia", "productos_unidad_medida_referencia",
        "productos_precio_unitario_promo1", "productos_leyenda_promo1",
        "productos_precio_unitario_promo2", "productos_leyenda_promo2"
    ]
    dtypes_p = {c: str for c in cols_precios}
    
    chunks_p = []
    for i, ch in enumerate(pd.read_csv(input_file, sep="|", encoding="utf-8-sig", chunksize=chunksize, dtype=dtypes_p, usecols=cols_precios, low_memory=False)):
        sys.stdout.write(f"\r    Leyendo bloque {i+1} para tabla de precios...")
        sys.stdout.flush()
        ch.columns = [c.strip().lstrip("\ufeff") for c in ch.columns]
        ch["id_entidad"] = ch["id_comercio"].apply(limpiar_id) + "_" + ch["id_bandera"].apply(limpiar_id)
        ch["id_producto"] = ch["id_producto"].apply(limpiar_codigo_barra)
        ch["id_sucursal"] = ch["id_sucursal"].apply(limpiar_id)
        ch = ch[(ch["id_producto"] != "") & (ch["id_entidad"] != "_")]
        chunks_p.append(ch)
    print()
    
    df_p = pd.concat(chunks_p, ignore_index=True)
    
    # 2. Separar precios físicos vs precios online (sucursales virtuales de SEPA)
    SUCURSALES_VIRTUALES = {
        ("15_1", "90000"): ("dia", "https://diaonline.supermercadosdia.com.ar"),
        ("2_1", "8015"): ("la_anonima", "https://www.laanonimaonline.com"),
        ("2_1", "9021"): ("la_anonima", "https://www.laanonimaonline.com"),
    }

    print("[*] Separando precios online de sucursales virtuales SEPA...")
    pares = list(zip(df_p["id_entidad"], df_p["id_sucursal"]))
    mask_virtual = pd.Series([p in SUCURSALES_VIRTUALES for p in pares], index=df_p.index)
    
    df_p_virtual = df_p[mask_virtual].copy()
    df_p_fisica = df_p[~mask_virtual].copy()

    # Generar / actualizar precios_online.csv
    if not df_p_virtual.empty:
        records_online = []
        now_iso = time.strftime("%Y-%m-%d %H:%M:%S")
        for _, row in df_p_virtual.iterrows():
            k = (row["id_entidad"], row["id_sucursal"])
            entidad_nombre, url_base = SUCURSALES_VIRTUALES.get(k, (row["id_entidad"], ""))
            p_lista = float(row["productos_precio_lista"]) if pd.notna(row.get("productos_precio_lista")) and str(row.get("productos_precio_lista")).strip() != "" else None
            p_promo = float(row["productos_precio_unitario_promo1"]) if pd.notna(row.get("productos_precio_unitario_promo1")) and str(row.get("productos_precio_unitario_promo1")).strip() != "" else None
            precio_final = p_promo if (p_promo and p_lista and p_promo < p_lista) else (p_lista or p_promo)
            if precio_final and precio_final > 0:
                records_online.append({
                    "id_producto": row["id_producto"],
                    "id_entidad": entidad_nombre,
                    "precio": precio_final,
                    "stock": True,
                    "url": url_base,
                    "fecha_captura": now_iso,
                    "nombre_scraper": "sepa_virtual"
                })
        df_online_sepa = pd.DataFrame(records_online)
        df_online_sepa = df_online_sepa.drop_duplicates(subset=["id_producto", "id_entidad"], keep="first")

        out_online = out_dir / "precios_online.csv"
        if out_online.exists():
            try:
                df_online_exist = pd.read_csv(out_online, dtype=str)
                df_online_total = pd.concat([df_online_exist, df_online_sepa], ignore_index=True)
                df_online_total = df_online_total.drop_duplicates(subset=["id_producto", "id_entidad"], keep="first")
            except Exception:
                df_online_total = df_online_sepa
        else:
            df_online_total = df_online_sepa
            
        df_online_total.to_csv(out_online, sep=",", index=False, encoding="utf-8")
        print(f"[OK] precios_online.csv actualizado: {len(df_online_total):,} registros e-commerce (incluye {len(df_online_sepa):,} de SEPA virtual)")

    cols_group = [
        "id_entidad", "id_producto",
        "productos_precio_lista",
        "productos_precio_unitario_promo1", "productos_leyenda_promo1"
    ]
    
    print("[*] Agregando sucursales físicas presenciales...")
    df_resumen = df_p_fisica.groupby(cols_group, as_index=False, dropna=False)["id_sucursal"].apply(
        lambda s: ",".join(sorted(set(s.dropna())))
    )
    df_resumen.rename(columns={"id_sucursal": "grupo_sucursales"}, inplace=True)
    
    out_precios = out_dir / "precios.csv"
    df_resumen.to_csv(out_precios, sep=",", index=False, encoding="utf-8")
    print(f"[OK] precios.csv generado (100% físico): {len(df_resumen):,} registros de precios")

def ejecutar_refactorizacion(raw_dir: Path = None, out_dir: Path = None):
    r_dir = raw_dir or RAW_DIR
    o_dir = out_dir or PROCESSED_DIR
    o_dir.mkdir(parents=True, exist_ok=True)
    
    t0 = time.time()
    refactorizar_comercio(r_dir, o_dir)
    refactorizar_sucursales(r_dir, o_dir)
    refactorizar_catalogo_y_precios(r_dir, o_dir)
    elapsed = time.time() - t0
    print(f"\n[OK] Refactorización completa en {elapsed:.1f}s en: {o_dir}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Refactoriza tablas SEPA para Supabase")
    parser.add_argument("--raw", help="Directorio con archivos master*.csv")
    parser.add_argument("--output", help="Directorio de salida para CSV optimizados")
    args = parser.parse_args()
    
    r = Path(args.raw) if args.raw else RAW_DIR
    o = Path(args.output) if args.output else PROCESSED_DIR
    ejecutar_refactorizacion(r, o)
