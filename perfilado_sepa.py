import pandas as pd
import os
import sys

def perfilar_archivo_completo(ruta, nombre):
    """Perfilado para archivos pequeños que caben en memoria"""
    print("Leyendo archivo...")
    sys.stdout.flush()
    
    df = pd.read_csv(ruta, sep='|', encoding='utf-8', low_memory=False)
    filas, columnas = df.shape
    memoria_mb = df.memory_usage(deep=True).sum() / (1024 * 1024)
    
    print(f"Filas: {filas:,} | Columnas: {columnas}")
    print(f"Uso de Memoria RAM: {memoria_mb:.2f} MB\n")
    
    print("Cardinalidad por columna:")
    for col in df.columns:
        unicos = df[col].nunique(dropna=False)
        pct_unico = (unicos / filas) * 100 if filas > 0 else 0
        print(f" - {col}: {unicos:,} únicos ({pct_unico:.2f}%)")
    
    return df, filas, columnas, memoria_mb

def perfilar_archivo_grande_chunks(ruta, nombre, chunksize=100000):
    """Perfilado para archivos grandes usando chunks"""
    print(f"Archivo grande, leyendo en chunks de {chunksize:,} filas...")
    sys.stdout.flush()
    
    total_filas = 0
    columnas = None
    memoria_estimada = 0
    cardinalidad = {}
    
    # Primero obtener las columnas leyendo solo el header
    df_sample = pd.read_csv(ruta, sep='|', encoding='utf-8', nrows=1)
    columnas = df_sample.columns.tolist()
    cardinalidad = {col: set() for col in columnas}
    
    # Leer en chunks
    for i, chunk in enumerate(pd.read_csv(ruta, sep='|', encoding='utf-8', chunksize=chunksize, low_memory=False)):
        total_filas += len(chunk)
        chunk_mem = chunk.memory_usage(deep=True).sum() / (1024 * 1024)
        memoria_estimada += chunk_mem
        
        # Actualizar cardinalidad (limitando para no explotar memoria)
        for col in columnas:
            if col in chunk.columns:
                unicos_chunk = chunk[col].dropna().unique()
                # Si hay demasiados únicos, guardar solo una muestra
                if len(cardinalidad[col]) + len(unicos_chunk) > 100000:
                    cardinalidad[col] = set(list(cardinalidad[col])[:50000])  # Limitar
                else:
                    cardinalidad[col].update(unicos_chunk)
        
        if i % 5 == 0:
            print(f"  Procesados {total_filas:,} filas...")
            sys.stdout.flush()
    
    print(f"Filas: {total_filas:,} | Columnas: {columnas}")
    print(f"Uso de Memoria RAM estimado: {memoria_estimada:.2f} MB\n")
    
    print("Cardinalidad por columna:")
    for col in columnas:
        unicos = len(cardinalidad[col])
        pct_unico = (unicos / total_filas) * 100 if total_filas > 0 else 0
        if unicos >= 100000:
            print(f" - {col}: >100,000 únicos ({pct_unico:.2f}%) [límite alcanzado]")
        else:
            print(f" - {col}: {unicos:,} únicos ({pct_unico:.2f}%)")
    
    return None, total_filas, columnas, memoria_estimada

def perfilar_datos_sepa(directorio):
    archivos = {
        'Comercio': 'comercio_final.csv',
        'Sucursales': 'sucursales_final.csv',
        'Productos': 'productos_final.csv'
    }
    
    for nombre, archivo in archivos.items():
        ruta = os.path.join(directorio, archivo)
        print(f"\n{'='*40}\nPerfilando: {nombre} ({archivo})\n{'='*40}")
        
        if not os.path.exists(ruta):
            print(f"Error: Archivo no encontrado en {ruta}")
            continue
        
        # Obtener tamaño del archivo para decidir método
        tamano_mb = os.path.getsize(ruta) / (1024 * 1024)
        print(f"Tamaño del archivo: {tamano_mb:.2f} MB")
        
        if tamano_mb < 500:  # Menos de 500 MB, cargar completo
            df, filas, columnas, memoria_mb = perfilar_archivo_completo(ruta, nombre)
        else:  # Archivo grande, usar chunks
            df, filas, columnas, memoria_mb = perfilar_archivo_grande_chunks(ruta, nombre)
            
        # Análisis de redundancia para la tabla más pesada
        if nombre == 'Productos' and df is not None and 'id_producto' in df.columns:
            print("\nAnálisis de Redundancia (Productos):")
            productos_unicos = df['id_producto'].nunique()
            filas_redundantes = filas - productos_unicos
            print(f" - Catálogo real (productos únicos): {productos_unicos:,}")
            print(f" - Filas repetidas por asignación a sucursales: {filas_redundantes:,}")
            
            if 'productos_descripcion' in df.columns:
                mem_desc = df['productos_descripcion'].memory_usage(deep=True) / (1024 * 1024)
                print(f" - Memoria ocupada solo por descripciones de texto: {mem_desc:.2f} MB")
            
            # Análisis adicional de redundancia en columnas de texto
            columnas_texto = [col for col in df.columns if 'descripcion' in col.lower() or 'marca' in col.lower() or 'nombre' in col.lower()]
            if columnas_texto:
                print("\nAnálisis de redundancia en columnas de texto:")
                for col in columnas_texto:
                    if col in df.columns:
                        mem_col = df[col].memory_usage(deep=True) / (1024 * 1024)
                        valores_unicos = df[col].nunique(dropna=False)
                        print(f" - {col}: {mem_col:.2f} MB ({valores_unicos:,} valores únicos)")
                        
                        # Calcular memoria potencial si estuviera normalizada
                        if productos_unicos > 0 and valores_unicos < filas:
                            mem_normalizada = (mem_col * productos_unicos) / filas
                            ahorro = mem_col - mem_normalizada
                            print(f"   → Memoria normalizada: {mem_normalizada:.2f} MB (ahorro: {ahorro:.2f} MB)")

# Ejecutar con la ruta especificada
ruta_base = r"D:\GoogleAntigravity\ConsumoAtento\Bases de Datos Precios\sepa_output"
perfilar_datos_sepa(ruta_base)
