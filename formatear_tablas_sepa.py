#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para formatear archivos SEPA (delimitados por pipe '|') a formato estándar CSV (coma ',').
Procesa eficientemente tablas grandes (como productos de más de 1.000.000 de filas)
utilizando streaming con bajo consumo de memoria.

Uso:
    python formatear_tablas_sepa.py
    python formatear_tablas_sepa.py --dir "ruta/a/carpeta"
    python formatear_tablas_sepa.py --import-supabase
"""

import os
import sys
import csv
import time
import argparse
import json

DEFAULT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "Bases de Datos Precios",
    "sepa_viernes"
)

TABLES = [
    {"name": "comercio", "file_in": "comercio.csv", "file_out": "comercio_formateado.csv"},
    {"name": "sucursales", "file_in": "sucursales.csv", "file_out": "sucursales_formateado.csv"},
    {"name": "productos", "file_in": "productos.csv", "file_out": "productos_formateado.csv"},
]


def format_pipe_csv(input_path: str, output_path: str) -> int:
    """Convierte un archivo delimitado por '|' a formato estándar RFC 4180 delimitado por ','."""
    if not os.path.exists(input_path):
        print(f"[-] Archivo no encontrado: {input_path}")
        return 0

    t_start = time.time()
    valid_rows = 0
    ignored_lines = 0

    with open(input_path, "r", encoding="utf-8", errors="replace") as f_in, \
         open(output_path, "w", encoding="utf-8", newline="") as f_out:

        reader = csv.reader(f_in, delimiter="|")
        writer = csv.writer(
            f_out,
            delimiter=",",
            quotechar='"',
            quoting=csv.QUOTE_MINIMAL,
            lineterminator="\n"
        )

        try:
            header = next(reader)
        except StopIteration:
            print(f"[-] El archivo {input_path} está vacío.")
            return 0

        # Normalizar nombres de columnas del encabezado
        clean_header = [col.strip() for col in header]
        expected_cols = len(clean_header)
        writer.writerow(clean_header)

        for row in reader:
            # Filtrar filas vacías o líneas de pie de página (ej. "Ultima actualizacion: ...")
            if not row or len(row) == 0:
                ignored_lines += 1
                continue

            if len(row) != expected_cols:
                # Si es una línea de metadatos o pie de página, ignorarla
                line_str = "".join(row).strip()
                if line_str.lower().startswith("ultima actualizacion"):
                    ignored_lines += 1
                    continue
                # Si faltan columnas, rellenar o ignorar
                if len(row) < expected_cols:
                    ignored_lines += 1
                    continue
                else:
                    # Truncar si hay pipes extras accidentales
                    row = row[:expected_cols]

            # Limpiar espacios en blanco de cada celda
            clean_row = [cell.strip() for cell in row]
            writer.writerow(clean_row)
            valid_rows += 1

            if valid_rows % 250000 == 0:
                print(f"    ... {valid_rows:,} filas procesadas...")

    elapsed = time.time() - t_start
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"[+] {os.path.basename(output_path)}: {valid_rows:,} filas formateadas ({size_mb:.2f} MB) en {elapsed:.2f}s (ignoradas {ignored_lines} líneas no tabulares).")
    return valid_rows


def import_to_supabase(folder_path: str):
    """Opcionalmente importa los datos formateados a la base de datos Supabase."""
    try:
        import psycopg2
        from psycopg2 import extras
    except ImportError:
        print("[-] psycopg2 no está instalado. Ejecute: pip install psycopg2-binary")
        return

    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
    if not os.path.exists(config_path):
        print(f"[-] No se encontró config.json en {config_path}")
        return

    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    sb_cfg = config.get("supabase", {})
    db_cfg = sb_cfg.get("db", {})

    host = db_cfg.get("host", "aws-0-us-east-1.pooler.supabase.com")
    port = db_cfg.get("port", 5432)
    user = db_cfg.get("user", f"postgres.{sb_cfg.get('project_url', '').split('//')[-1].split('.')[0]}")
    password = sb_cfg.get("password")
    dbname = db_cfg.get("database", "postgres")

    print(f"[*] Conectando a Supabase ({host}:{port})...")
    conn = psycopg2.connect(
        host=host,
        port=port,
        user=user,
        password=password,
        dbname=dbname
    )
    conn.autocommit = True
    cur = conn.cursor()

    print("[*] Conexión establecida. Iniciando carga de datos...")
    
    # 1. Comercio
    com_path = os.path.join(folder_path, "comercio_formateado.csv")
    if os.path.exists(com_path):
        with open(com_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            rows = []
            for r in reader:
                rows.append((
                    int(r['id_comercio']),
                    int(r['id_bandera']),
                    r['comercio_cuit'] or None,
                    r['comercio_razon_social'] or None,
                    r['comercio_bandera_nombre'] or None,
                    r['comercio_bandera_url'] or None,
                    r['comercio_ultima_actualizacion'] or None,
                    r['comercio_version_sepa'] or None
                ))
            extras.execute_values(
                cur,
                """INSERT INTO public.comercio (
                    id_comercio, id_bandera, comercio_cuit, comercio_razon_social,
                    comercio_bandera_nombre, comercio_bandera_url, comercio_ultima_actualizacion, comercio_version_sepa
                ) VALUES %s ON CONFLICT (id_comercio, id_bandera) DO UPDATE SET
                    comercio_cuit = EXCLUDED.comercio_cuit,
                    comercio_razon_social = EXCLUDED.comercio_razon_social,
                    comercio_bandera_nombre = EXCLUDED.comercio_bandera_nombre,
                    comercio_bandera_url = EXCLUDED.comercio_bandera_url,
                    comercio_ultima_actualizacion = EXCLUDED.comercio_ultima_actualizacion,
                    comercio_version_sepa = EXCLUDED.comercio_version_sepa
                """,
                rows
            )
            print(f"[+] {len(rows)} comercios sincronizados en Supabase.")

    # 2. Sucursales
    suc_path = os.path.join(folder_path, "sucursales_formateado.csv")
    if os.path.exists(suc_path):
        with open(suc_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            rows = []
            for r in reader:
                lat = float(r['sucursales_latitud']) if r.get('sucursales_latitud') else None
                lon = float(r['sucursales_longitud']) if r.get('sucursales_longitud') else None
                rows.append((
                    int(r['id_comercio']),
                    int(r['id_bandera']),
                    int(r['id_sucursal']),
                    r.get('sucursales_nombre') or None,
                    r.get('sucursales_tipo') or None,
                    r.get('sucursales_calle') or None,
                    r.get('sucursales_numero') or None,
                    lat,
                    lon,
                    r.get('sucursales_observaciones') or None,
                    r.get('sucursales_barrio') or None,
                    r.get('sucursales_codigo_postal') or None,
                    r.get('sucursales_localidad') or None,
                    r.get('sucursales_provincia') or None,
                    r.get('sucursales_lunes_horario_atencion') or None,
                    r.get('sucursales_martes_horario_atencion') or None,
                    r.get('sucursales_miercoles_horario_atencion') or None,
                    r.get('sucursales_jueves_horario_atencion') or None,
                    r.get('sucursales_viernes_horario_atencion') or None,
                    r.get('sucursales_sabado_horario_atencion') or None,
                    r.get('sucursales_domingo_horario_atencion') or None
                ))
            extras.execute_values(
                cur,
                """INSERT INTO public.sucursales (
                    id_comercio, id_bandera, id_sucursal, sucursales_nombre, sucursales_tipo,
                    sucursales_calle, sucursales_numero, sucursales_latitud, sucursales_longitud,
                    sucursales_observaciones, sucursales_barrio, sucursales_codigo_postal,
                    sucursales_localidad, sucursales_provincia, sucursales_lunes_horario_atencion,
                    sucursales_martes_horario_atencion, sucursales_miercoles_horario_atencion,
                    sucursales_jueves_horario_atencion, sucursales_viernes_horario_atencion,
                    sucursales_sabado_horario_atencion, sucursales_domingo_horario_atencion
                ) VALUES %s ON CONFLICT (id_comercio, id_bandera, id_sucursal) DO UPDATE SET
                    sucursales_nombre = EXCLUDED.sucursales_nombre,
                    sucursales_tipo = EXCLUDED.sucursales_tipo,
                    sucursales_calle = EXCLUDED.sucursales_calle,
                    sucursales_numero = EXCLUDED.sucursales_numero,
                    sucursales_latitud = EXCLUDED.sucursales_latitud,
                    sucursales_longitud = EXCLUDED.sucursales_longitud,
                    sucursales_localidad = EXCLUDED.sucursales_localidad
                """,
                rows
            )
    # 3. Productos (Bulk COPY)
    prod_path = os.path.join(folder_path, "productos_formateado.csv")
    if os.path.exists(prod_path):
        print("[*] Iniciando carga masiva de productos (COPY)...")
        t_prod = time.time()
        # Obtener comercios presentes en el archivo para reemplazar de forma limpia
        copy_sql = """
        COPY public.productos (
            id_comercio, id_bandera, id_sucursal, id_producto, productos_ean,
            productos_descripcion, productos_cantidad_presentacion,
            productos_unidad_medida_presentacion, productos_marca,
            productos_precio_lista, productos_precio_referencia,
            productos_cantidad_referencia, productos_unidad_medida_referencia,
            productos_precio_unitario_promo1, productos_leyenda_promo1,
            productos_precio_unitario_promo2, productos_leyenda_promo2
        ) FROM STDIN WITH (FORMAT csv, HEADER true, NULL '');
        """
        # Identificar qué comercio se está cargando para evitar duplicados de ese comercio
        with open(prod_path, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            next(reader)
            first_row = next(reader, None)
            if first_row:
                comm_id = int(first_row[0])
                cur.execute("DELETE FROM public.productos WHERE id_comercio = %s;", (comm_id,))
                conn.commit()

        with open(prod_path, "r", encoding="utf-8") as f:
            cur.copy_expert(copy_sql, f)
        conn.commit()

        cur.execute("SELECT count(*) FROM public.productos;")
        total_p = cur.fetchone()[0]
        print(f"[+] Productos sincronizados exitosamente en {time.time() - t_prod:.2f}s (Total en BD: {total_p:,}).")

    conn.close()
    print("[+] Sincronizacion finalizada con exito.")


def main():
    parser = argparse.ArgumentParser(
        description="Formatear tablas SEPA de delimitador pipe '|' a CSV estándar coma ','."
    )
    parser.add_argument(
        "--dir",
        default=DEFAULT_DIR,
        help=f"Directorio donde se encuentran los archivos .csv originales (por defecto: {DEFAULT_DIR})"
    )
    parser.add_argument(
        "--import-supabase",
        action="store_true",
        help="Sincronizar automáticamente en la base de datos Supabase tras formatear"
    )
    args = parser.parse_args()

    folder = os.path.abspath(args.dir)
    print("=" * 70)
    print(f"Formateador de Tablas SEPA -> CSV Estándar")
    print(f"Directorio: {folder}")
    print("=" * 70)

    if not os.path.exists(folder):
        print(f"[-] Error: La carpeta {folder} no existe.")
        sys.exit(1)

    total_records = 0
    t0 = time.time()

    for item in TABLES:
        in_path = os.path.join(folder, item["file_in"])
        out_path = os.path.join(folder, item["file_out"])
        print(f"\n[*] Procesando {item['name']} ({item['file_in']})...")
        count = format_pipe_csv(in_path, out_path)
        total_records += count

    total_time = time.time() - t0
    print("\n" + "=" * 70)
    print(f"[OK] Proceso completado con exito.")
    print(f"    Total de filas formateadas: {total_records:,}")
    print(f"    Tiempo total: {total_time:.2f} segundos")
    print("=" * 70)

    if args.import_supabase:
        print("\n[*] Iniciando importación a Supabase...")
        import_to_supabase(folder)


if __name__ == "__main__":
    main()
