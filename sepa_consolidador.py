"""
sepa_consolidador.py
--------------------
Consolida los archivos CSV del paquete SEPA (sepa_viernes.zip).

Estructura esperada:
  sepa_viernes.zip
  ├── comercio_XXXXX.zip
  │   ├── comercio.csv      (separador: |)
  │   ├── sucursales.csv    (separador: |)
  │   └── productos.csv     (separador: |)
  ├── comercio_YYYYY.zip
  │   └── ...
  └── ...

Salida:
  <directorio_salida>/
  ├── master_comercio.csv
  ├── master_sucursales.csv
  └── master_productos.csv

Uso:
  python sepa_consolidador.py sepa_viernes.zip ./sepa_consolidado
"""

import os
import sys
import zipfile
import shutil
import io
import logging
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuración de logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
NOMBRES_CSV = ("comercio.csv", "sucursales.csv", "productos.csv")
PREFIJOS_FOOTER = ("ultima actualizaci", "última actualizaci")
SEPARADOR = "|"
ENCODINGS_FALLBACK = ("utf-8", "utf-8-sig", "latin-1", "cp1252")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def detectar_encoding(raw: bytes) -> str:
    """Prueba encodings en orden y devuelve el primero que decodifica sin errores."""
    for enc in ENCODINGS_FALLBACK:
        try:
            raw.decode(enc)
            return enc
        except (UnicodeDecodeError, ValueError):
            continue
    return "utf-8"


def es_linea_valida(linea: str) -> bool:
    """Devuelve True si la línea debe incluirse en la salida."""
    stripped = linea.strip()
    if not stripped:
        return False
    lowered = stripped.lower()
    return not any(lowered.startswith(p) for p in PREFIJOS_FOOTER)


def procesar_csv_desde_bytes(
    raw: bytes,
    archivo_salida,
    escribir_encabezado: bool,
) -> tuple:
    """
    Lee un CSV crudo (bytes), filtra líneas inválidas y lo vuelca al archivo
    de salida ya abierto. Procesa línea por línea para minimizar uso de RAM.

    Retorna (encabezado_escrito_ahora: bool, filas_de_datos_escritas: int).
    """
    enc = detectar_encoding(raw)
    texto = raw.decode(enc, errors="replace")
    reader = io.StringIO(texto)

    es_primera_linea = True
    filas_escritas = 0
    encabezado_escrito_ahora = False

    for linea in reader:
        linea_limpia = linea.rstrip("\r\n")

        if not es_linea_valida(linea_limpia):
            es_primera_linea = False
            continue

        if es_primera_linea:
            es_primera_linea = False
            if escribir_encabezado:
                archivo_salida.write(linea_limpia + "\n")
                encabezado_escrito_ahora = True
            # Si el encabezado ya fue escrito globalmente, omitimos esta línea
        else:
            archivo_salida.write(linea_limpia + "\n")
            filas_escritas += 1

    return encabezado_escrito_ahora, filas_escritas


# ---------------------------------------------------------------------------
# Función principal
# ---------------------------------------------------------------------------

def consolidar_paquetes_sepa(ruta_zip_principal: str, directorio_salida: str) -> None:
    ruta_zip = Path(ruta_zip_principal)
    if not ruta_zip.is_file():
        raise FileNotFoundError(f"No se encontró el ZIP principal: {ruta_zip}")

    dir_salida = Path(directorio_salida)
    dir_salida.mkdir(parents=True, exist_ok=True)

    archivos_maestros = {
        nombre: dir_salida / f"master_{nombre}"
        for nombre in NOMBRES_CSV
    }
    encabezados_escritos = {nombre: False for nombre in NOMBRES_CSV}
    stats = {nombre: 0 for nombre in NOMBRES_CSV}
    sub_zips_procesados = 0
    sub_zips_con_error = 0

    dir_temp = dir_salida / "_temp_sepa_extract"

    try:
        # 1. Extraer el ZIP principal
        log.info("Extrayendo ZIP principal: %s", ruta_zip)
        with zipfile.ZipFile(ruta_zip, "r") as zp:
            zp.extractall(dir_temp)
        log.info("Extracción completada en: %s", dir_temp)

        # Abrir archivos maestros (modo escritura — se sobreescriben si ya existen)
        handles = {
            nombre: open(archivos_maestros[nombre], "w", encoding="utf-8", newline="")
            for nombre in NOMBRES_CSV
        }

        try:
            # 2. Procesar cada sub-ZIP
            sub_zips = sorted(dir_temp.rglob("*.zip"))
            total = len(sub_zips)
            log.info("Se encontraron %d sub-ZIP(s) para procesar.", total)

            for idx, ruta_sub_zip in enumerate(sub_zips, start=1):
                log.info("[%d/%d] Procesando: %s", idx, total, ruta_sub_zip.name)

                try:
                    with zipfile.ZipFile(ruta_sub_zip, "r") as sub_zip:
                        nombres_internos = sub_zip.namelist()

                        for nombre_csv in NOMBRES_CSV:
                            if nombre_csv not in nombres_internos:
                                log.debug("  '%s' no encontrado en %s", nombre_csv, ruta_sub_zip.name)
                                continue

                            with sub_zip.open(nombre_csv) as f_in:
                                raw = f_in.read()

                            escribir_enc = not encabezados_escritos[nombre_csv]
                            enc_escrito, filas = procesar_csv_desde_bytes(
                                raw,
                                handles[nombre_csv],
                                escribir_encabezado=escribir_enc,
                            )

                            if enc_escrito:
                                encabezados_escritos[nombre_csv] = True

                            stats[nombre_csv] += filas
                            log.debug("    %s -> %d filas de datos", nombre_csv, filas)

                    sub_zips_procesados += 1

                except zipfile.BadZipFile as exc:
                    log.warning("  Sub-ZIP corrupto, se omite: %s — %s", ruta_sub_zip.name, exc)
                    sub_zips_con_error += 1

        finally:
            for handle in handles.values():
                handle.close()

    finally:
        # 3. Limpiar directorio temporal
        if dir_temp.exists():
            shutil.rmtree(dir_temp)
            log.info("Directorio temporal eliminado.")

    # Resumen
    log.info("=" * 60)
    log.info("PROCESO FINALIZADO")
    log.info("  Sub-ZIPs procesados : %d", sub_zips_procesados)
    if sub_zips_con_error:
        log.warning("  Sub-ZIPs con error  : %d", sub_zips_con_error)
    for nombre, total_filas in stats.items():
        log.info("  %-20s -> %10d filas de datos", nombre, total_filas)
    log.info("Archivos consolidados en: %s", dir_salida.resolve())
    log.info("=" * 60)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Consolida paquetes SEPA (ZIP de ZIPs) en archivos CSV maestros."
    )
    parser.add_argument(
        "zip_principal",
        help="Ruta al ZIP principal (ej: sepa_viernes.zip)",
    )
    parser.add_argument(
        "directorio_salida",
        nargs="?",
        default="./sepa_consolidado",
        help="Directorio de salida (default: ./sepa_consolidado)",
    )
    args = parser.parse_args()

    try:
        consolidar_paquetes_sepa(args.zip_principal, args.directorio_salida)
    except FileNotFoundError as exc:
        log.error("%s", exc)
        sys.exit(1)
    except zipfile.BadZipFile as exc:
        log.error("El archivo ZIP principal está corrupto o no es válido: %s", exc)
        sys.exit(1)
    except KeyboardInterrupt:
        log.warning("Proceso interrumpido por el usuario.")
        sys.exit(130)


if __name__ == "__main__":
    main()
