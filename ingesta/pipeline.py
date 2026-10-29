#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pipeline.py
-----------
Orquestador maestro del pipeline de ingesta, procesamiento, clustering por IA y subida a Supabase.

Uso:
    python pipeline.py --all
    python pipeline.py --step 1   # Solo descarga
    python pipeline.py --step 2   # Solo consolidación
    python pipeline.py --step 3   # Solo refactorización
    python pipeline.py --step 4   # Solo clustering IA (usar --lotes para pruebas)
    python pipeline.py --step 5   # Solo subida a Supabase
    python pipeline.py --local-zip "ruta/a/sepa.zip" --test-lotes 2
"""

import sys
import argparse
import time
from pathlib import Path

# Imports locales
from config import RAW_DIR, PROCESSED_DIR, CLUSTERS_DIR

def paso_1_descarga(dia: str = None):
    print("\n========================================================")
    print(" PASO 1: Descarga diaria de SEPA desde API CKAN")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("1_descargar_sepa")
    return modulo.ejecutar_descarga(dia=dia)

def paso_1b_combustibles(subir: bool = False):
    print("\n========================================================")
    print(" PASO 1B: Descarga de Precios en Surtidor (Secretaría de Energía)")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("1b_descargar_combustibles")
    modulo.ejecutar_descarga()
    if subir:
        print("\n[*] Sincronizando combustibles directamente en Supabase...")
        modulo_subida = import_module("5_subir_supabase")
        modulo_subida.ejecutar_subida(solo_combustibles=True)

def paso_2_consolidacion(zip_path: Path = None):
    print("\n========================================================")
    print(" PASO 2: Descompresión y Consolidación de CSVs")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("2_consolidar_sepa")
    z = zip_path or (RAW_DIR / "sepa_latest.zip")
    return modulo.consolidar_zip(z, RAW_DIR)

def paso_2b_enriquecer_off(limit: int = None):
    print("\n========================================================")
    print(" PASO 2B: Enriquecimiento con Open Food Facts")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("2b_enriquecer_off")
    modulo.enriquecer_catalogo(limit=limit)

def paso_3_refactorizacion():
    print("\n========================================================")
    print(" PASO 3: Refactorización y Deduplicación de Tablas")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("3_refactorizar_tablas")
    modulo.ejecutar_refactorizacion(RAW_DIR, PROCESSED_DIR)

def paso_3b_scraping_minorista(limit: int = None):
    print("\n========================================================")
    print(" PASO 3B: Scraping Web Minorista (VTEX & Coto)")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("2c_scraping_minoristas")
    modulo.ejecutar_scraping(limit=limit)

def paso_3c_scraping_mayorista(limit: int = None, start_index: int = None, resume: bool = False, skip_vital: bool = False, buscar_nuevos: bool = False):
    print("\n========================================================")
    print(" PASO 3C: Scraping Web Mayorista (Vital & Maxiconsumo)")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("2d_scraping_mayoristas")
    modulo.ejecutar_scraping_mayorista(
        limit=limit,
        start_index=start_index,
        resume=resume,
        skip_vital=skip_vital,
        buscar_nuevos=buscar_nuevos,
    )

def paso_4_clustering_ia(lotes: int = None, batch_size: int = None, modelo: str = "flash-lite", recluster: bool = False, filtro: str = None):
    print("\n========================================================")
    print(" PASO 4: Clustering Incremental con Inteligencia Artificial")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("4_clustering_ia")
    modulo.ejecutar_clustering(
        limite_lotes=lotes,
        tamano_lote=batch_size,
        modelo=modelo,
        recluster=recluster,
        filtro=filtro,
    )

def paso_2e_folletos(limit_folletos: int = None, subir: bool = False):
    print("\n========================================================")
    print(" PASO 2E: Scraping de Folletos y Ofertas Semanales")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("2e_scraping_folletos")
    modulo.ejecutar_scraping_folletos(limit_folletos_por_cadena=limit_folletos)
    if subir:
        paso_5_subida(solo_folletos=True)

def paso_5_subida(
    solo_clusters: bool = False,
    confirmar_truncate: bool = False,
    solo_combustibles: bool = False,
    solo_mayoristas: bool = False,
    solo_sucursales: bool = False,
    solo_online: bool = False,
    solo_precios: bool = False,
    solo_folletos: bool = False,
    solo_productos: bool = False,
    solo_mantenimiento: bool = False,
):
    print("\n========================================================")
    print(" PASO 5: Carga y Sincronización en Supabase")
    print("========================================================")
    from importlib import import_module
    modulo = import_module("5_subir_supabase")
    modulo.ejecutar_subida(
        solo_clusters=solo_clusters,
        confirmar_truncate=confirmar_truncate,
        solo_combustibles=solo_combustibles,
        solo_mayoristas=solo_mayoristas,
        solo_sucursales=solo_sucursales,
        solo_online=solo_online,
        solo_precios=solo_precios,
        solo_folletos=solo_folletos,
        solo_productos=solo_productos,
        solo_mantenimiento=solo_mantenimiento,
    )

def main():
    parser = argparse.ArgumentParser(description="Pipeline integral SEPA + Combustibles + OFF + Scraping + IA + Supabase")
    parser.add_argument("--all", action="store_true", help="Ejecuta el pipeline completo (Paso 1 al 5)")
    parser.add_argument("--express", action="store_true", help="Flujo A: Actualización diaria rápida (SEPA + Combustibles + Refactor + Supabase, ~5-10 min)")
    parser.add_argument("--deep", action="store_true", help="Flujo B: Enriquecimiento profundo y scraping (OFF + Folletos + Scraping Mayorista/Minorista + IA + Supabase)")
    parser.add_argument("--step", type=str, help="Ejecuta un paso específico: 1, 1b, combustibles, 2, 2b, 2e, folletos, 3, 3b, 3c, 4, 5")
    parser.add_argument("--local-zip", help="Usa un archivo ZIP local existente en lugar de descargar")
    parser.add_argument("--test-lotes", type=int, help="Limita los lotes de IA o de EANs para pruebas (ej: 2)")
    parser.add_argument("--batch-size", type=int, default=None, help="Cantidad de productos por lote de IA (def: 50 para Flash-Lite, 120 para Flash)")
    parser.add_argument("--modelo", default="flash-lite", choices=["flash", "flash-lite"], help="Modelo de Gemini (flash o flash-lite)")
    parser.add_argument("--recluster", action="store_true", help="Fuerza reclustering ignorando asociaciones previas")
    parser.add_argument("--filtro", type=str, help="Filtra productos a procesar por palabra clave (ej: 'tomate', 'pan rallado', 'rollo')")
    parser.add_argument("--skip-off", action="store_true", help="Omite el enriquecimiento con Open Food Facts (Paso 2B)")
    parser.add_argument("--off-limit", type=int, default=None, help="Límite de EANs a consultar en Open Food Facts (def: None, sin límite / procesa todos los pendientes)")
    parser.add_argument("--clusters-only", action="store_true", help="En el paso 5, sube solo las tablas de clústeres")
    parser.add_argument("--combustibles-only", action="store_true", help="En el paso 5, sube solo la tabla de combustibles")
    parser.add_argument("--mayoristas-only", action="store_true", help="En el paso 5, sube solo la tabla de precios mayoristas")
    parser.add_argument("--sucursales-only", action="store_true", help="En el paso 5, sube solo tablas comercio y sucursales")
    parser.add_argument("--productos-only", action="store_true", help="En el paso 5, sube de forma incremental los productos de catalogo_productos.csv")
    parser.add_argument("--online-only", action="store_true", help="En el paso 5, sube solo la tabla de precios online")
    parser.add_argument("--precios-only", action="store_true", help="En el paso 5, sube solo la tabla de precios físicos")
    parser.add_argument("--folletos-only", action="store_true", help="En el paso 5, sube portadas a Storage y tablas folletos y ofertas")
    parser.add_argument("--confirm-truncate", action="store_true", help="En el paso 5, autoriza truncar y reemplazar tablas base")
    parser.add_argument("--mantenimiento", action="store_true", help="Ejecuta solo la rutina permanente de índices, purga y VACUUM")
    parser.add_argument("--start-index", type=int, default=None, help="Índice de producto inicial para scraping mayorista (ej. 57875)")
    parser.add_argument("--resume", action="store_true", help="Reanuda scraping mayorista desde el último checkpoint")
    parser.add_argument("--skip-vital", action="store_true", help="Omitir Vital en el paso 3c y procesar solo Maxiconsumo")
    parser.add_argument("--buscar-nuevos", action="store_true", help="En paso 3c (Maxiconsumo), fuerza búsqueda activa de nuevos EANs en vez del Modo Monitoreo instantáneo")
    args = parser.parse_args()

    t_inicio = time.time()
    
    if args.all:
        zip_file = Path(args.local_zip) if args.local_zip else None
        if not zip_file or not zip_file.exists():
            zip_file = paso_1_descarga()
            if not zip_file or not zip_file.exists():
                fallback = RAW_DIR / "sepa_latest.zip"
                if fallback.exists():
                    print(f"[*] Usando {fallback} como respaldo...")
                    zip_file = fallback
                else:
                    print("[-] Error en el paso 1. Abortando pipeline.")
                    sys.exit(1)
            
        paso_1b_combustibles()
        paso_2_consolidacion(zip_file)
        if not args.skip_off:
            limite_off = args.test_lotes if args.test_lotes is not None else args.off_limit
            paso_2b_enriquecer_off(limit=limite_off)
        else:
            print("\n[*] Omitiendo Paso 2B (Open Food Facts) por bandera --skip-off.")
        paso_3_refactorizacion()
        paso_2e_folletos()
        paso_3b_scraping_minorista(limit=args.test_lotes)
        paso_3c_scraping_mayorista(limit=args.test_lotes, buscar_nuevos=args.buscar_nuevos)
        paso_4_clustering_ia(
            lotes=args.test_lotes,
            batch_size=args.batch_size,
            modelo=args.modelo,
            recluster=args.recluster,
            filtro=args.filtro,
        )
        paso_5_subida(solo_clusters=args.clusters_only, confirmar_truncate=args.confirm_truncate)
    elif args.express:
        print("\n>>> INICIANDO FLUJO A: ACTUALIZACIÓN DIARIA EXPRESS <<<")
        zip_file = Path(args.local_zip) if args.local_zip else None
        if not zip_file or not zip_file.exists():
            zip_file = paso_1_descarga()
            if not zip_file or not zip_file.exists():
                fallback = RAW_DIR / "sepa_latest.zip"
                if fallback.exists():
                    print(f"[*] Usando {fallback} como respaldo...")
                    zip_file = fallback
                else:
                    print("[-] Error en el paso 1. Abortando pipeline.")
                    sys.exit(1)
        paso_1b_combustibles(subir=True)
        paso_2_consolidacion(zip_file)
        paso_3_refactorizacion()
        paso_2e_folletos(subir=True)
        paso_5_subida(confirmar_truncate=True)
        print("\n[OK] Flujo A Express completado exitosamente.")
    elif args.deep:
        print("\n>>> INICIANDO FLUJO B: ENRIQUECIMIENTO PROFUNDO Y SCRAPING <<<")
        if not args.skip_off:
            limite_off = args.test_lotes if args.test_lotes is not None else args.off_limit
            paso_2b_enriquecer_off(limit=limite_off)
        paso_2e_folletos(limit_folletos=args.test_lotes)
        paso_3b_scraping_minorista(limit=args.test_lotes)
        paso_3c_scraping_mayorista(
            limit=args.test_lotes,
            start_index=args.start_index,
            resume=True if (args.resume or args.start_index is not None) else False,
            skip_vital=args.skip_vital,
            buscar_nuevos=args.buscar_nuevos,
        )
        paso_4_clustering_ia(
            lotes=args.test_lotes,
            batch_size=args.batch_size,
            modelo=args.modelo,
            recluster=args.recluster,
            filtro=args.filtro,
        )
        print("\n[*] Sincronizando datos de enriquecimiento en Supabase...")
        paso_5_subida(solo_clusters=True)
        paso_5_subida(solo_online=True)
        paso_5_subida(solo_mayoristas=True)
        paso_5_subida(solo_folletos=True)
        print("\n[OK] Flujo B Profundo completado exitosamente.")
    elif args.step == "1":
        paso_1_descarga()
    elif args.step in ("1b", "combustibles"):
        paso_1b_combustibles(subir=True)
    elif args.step == "2":
        z = Path(args.local_zip) if args.local_zip else (RAW_DIR / "sepa_latest.zip")
        paso_2_consolidacion(z)
    elif args.step == "2b":
        limite_off = args.test_lotes if args.test_lotes is not None else args.off_limit
        paso_2b_enriquecer_off(limit=limite_off)
    elif args.step in ("2e", "folletos"):
        paso_2e_folletos(limit_folletos=args.test_lotes, subir=True)
    elif args.step == "3":
        paso_3_refactorizacion()
    elif args.step == "3b":
        paso_3b_scraping_minorista(limit=args.test_lotes)
    elif args.step == "3c":
        paso_3c_scraping_mayorista(
            limit=args.test_lotes,
            start_index=args.start_index,
            resume=args.resume,
            skip_vital=args.skip_vital,
            buscar_nuevos=args.buscar_nuevos,
        )
    elif args.step == "4":
        paso_4_clustering_ia(
            lotes=args.test_lotes,
            batch_size=args.batch_size,
            modelo=args.modelo,
            recluster=args.recluster,
            filtro=args.filtro,
        )
    elif args.step == "5":
        paso_5_subida(
            solo_clusters=args.clusters_only,
            confirmar_truncate=args.confirm_truncate,
            solo_combustibles=args.combustibles_only,
            solo_mayoristas=args.mayoristas_only,
            solo_sucursales=args.sucursales_only,
            solo_online=args.online_only,
            solo_precios=args.precios_only,
            solo_folletos=args.folletos_only,
            solo_productos=args.productos_only,
            solo_mantenimiento=args.mantenimiento,
        )
    else:
        parser.print_help()
        
    print(f"\n[TIEMPO TOTAL PIPELINE]: {time.time() - t_inicio:.1f} segundos")

if __name__ == "__main__":
    main()
