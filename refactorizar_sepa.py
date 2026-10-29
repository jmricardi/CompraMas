import pandas as pd
import os
from pathlib import Path

def crear_directorio_salida(directorio_base):
    """Crea el directorio de salida si no existe"""
    ruta_salida = os.path.join(directorio_base, 'optimizados')
    Path(ruta_salida).mkdir(parents=True, exist_ok=True)
    return ruta_salida

def procesar_comercio(directorio_entrada, directorio_salida):
    """Procesa el archivo de comercio hacia el formato optimizado"""
    print("Procesando comercio_final.csv...")
    
    ruta_entrada = os.path.join(directorio_entrada, 'comercio_final.csv')
    ruta_salida = os.path.join(directorio_salida, 'comercio_opt.csv')
    
    df = pd.read_csv(ruta_entrada, sep='|', encoding='utf-8', low_memory=False)
    
    # Descartar filas completamente vacías o sin identificador
    df = df.dropna(subset=['id_comercio', 'id_bandera']).copy()
    
    # Limpiar tipos a entero para IDs y CUIT
    def limpiar_id(val):
        try:
            return str(int(float(val)))
        except (ValueError, TypeError):
            return str(val).strip()

    id_com = df['id_comercio'].apply(limpiar_id)
    id_band = df['id_bandera'].apply(limpiar_id)
    
    # Crear id_entidad concatenando id_comercio + "_" + id_bandera
    df['id_entidad'] = id_com + '_' + id_band
    
    # Formatear CUIT sin decimales
    if 'comercio_cuit' in df.columns:
        df['comercio_cuit'] = df['comercio_cuit'].apply(lambda v: str(int(float(v))) if pd.notna(v) and str(v).strip() != '' else '')
    
    # Eliminar columnas originales
    df = df.drop(['id_comercio', 'id_bandera'], axis=1)
    
    # Reordenar columnas para tener id_entidad primero
    cols = ['id_entidad'] + [col for col in df.columns if col != 'id_entidad']
    df = df[cols]
    
    df.to_csv(ruta_salida, sep=',', index=False, encoding='utf-8')
    print(f"[OK] comercio_opt.csv generado: {len(df)} filas")

def procesar_sucursales(directorio_entrada, directorio_salida):
    """Procesa el archivo de sucursales hacia el formato optimizado reparando líneas partidas"""
    print("Procesando sucursales_final.csv...")
    
    ruta_entrada = os.path.join(directorio_entrada, 'sucursales_final.csv')
    ruta_salida = os.path.join(directorio_salida, 'sucursales_opt.csv')
    
    # Lectura manual robusta para reconstruir filas que contienen saltos de línea internos
    with open(ruta_entrada, 'r', encoding='utf-8', errors='replace') as f:
        header_line = f.readline().strip()
        columnas_csv = header_line.split('|')
        expected_len = len(columnas_csv)
        
        filas = []
        buffer = ''
        
        for line in f:
            clean = line.rstrip('\r\n').replace('\x00', '')
            if not clean.strip():
                continue
            buffer = clean if not buffer else buffer + clean
            parts = buffer.split('|')
            if len(parts) == expected_len:
                filas.append(parts)
                buffer = ''
            elif len(parts) > expected_len:
                # Si supera el número esperado de campos, descartar buffer anómalo
                buffer = ''
    
    df = pd.DataFrame(filas, columns=columnas_csv)
    
    # Filtrar cualquier registro sin id_comercio o id_sucursal
    df = df[df['id_comercio'].str.strip() != ''].copy()
    df = df[df['id_sucursal'].str.strip() != ''].copy()
    
    def limpiar_id(val):
        try:
            return str(int(float(val)))
        except (ValueError, TypeError):
            return str(val).strip()

    id_com = df['id_comercio'].apply(limpiar_id)
    id_band = df['id_bandera'].apply(limpiar_id)
    df['id_sucursal'] = df['id_sucursal'].apply(limpiar_id)
    
    # Crear id_entidad
    df['id_entidad'] = id_com + '_' + id_band
    
    # Función para concatenar dirección manejando nulos y espacios
    def concatenar_direccion(row):
        partes = []
        campos = [
            'sucursales_calle', 'sucursales_numero', 'sucursales_observaciones',
            'sucursales_barrio', 'sucursales_localidad', 'sucursales_codigo_postal',
            'sucursales_provincia'
        ]
        for c in campos:
            val = row.get(c)
            if pd.notna(val) and str(val).strip():
                partes.append(str(val).strip())
        return ', '.join(partes) if partes else ''
    
    # Función para concatenar horarios
    def concatenar_horarios(row):
        dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo']
        prefijos = ['L:', 'M:', 'X:', 'J:', 'V:', 'S:', 'D:']
        horarios = []
        
        for dia, prefijo in zip(dias, prefijos):
            col = f'sucursales_{dia}_horario_atencion'
            val = str(row.get(col, '')).strip()
            if val and val.lower() != 'cerrado':
                horario = val.replace(' a ', '-').replace(':', '')
                if '-' in horario:
                    partes = horario.split('-')
                    if len(partes) == 2 and partes[0].isdigit() and partes[1].isdigit():
                        inicio = partes[0].zfill(4)
                        fin = partes[1].zfill(4)
                        horario_formateado = f"{inicio[:2]}:{inicio[2:]}-{fin[:2]}:{fin[2:]}"
                        horarios.append(f"{prefijo}{horario_formateado}")
                    else:
                        horarios.append(f"{prefijo}{val}")
                else:
                    horarios.append(f"{prefijo}{val}")
            else:
                horarios.append(f"{prefijo}CERRADO")
        
        return ', '.join(horarios)
    
    # Crear columnas concatenadas
    df['sucursales_domicilio_completo'] = df.apply(concatenar_direccion, axis=1)
    df['sucursales_horarios'] = df.apply(concatenar_horarios, axis=1)
    
    # Limpiar latitud y longitud
    def limpiar_coord(val):
        if pd.isna(val) or not str(val).strip():
            return ''
        try:
            return str(float(str(val).strip()))
        except ValueError:
            return ''

    df['sucursales_latitud'] = df['sucursales_latitud'].apply(limpiar_coord)
    df['sucursales_longitud'] = df['sucursales_longitud'].apply(limpiar_coord)
    
    # Columnas a mantener
    columnas_finales = [
        'id_entidad', 'id_sucursal', 'sucursales_nombre', 'sucursales_tipo',
        'sucursales_domicilio_completo', 'sucursales_latitud', 'sucursales_longitud',
        'sucursales_horarios'
    ]
    
    df = df[columnas_finales]
    
    df.to_csv(ruta_salida, sep=',', index=False, encoding='utf-8')
    print(f"[OK] sucursales_opt.csv generado correctamente: {len(df)} filas")

def procesar_catalogo_productos(directorio_entrada, directorio_salida):
    """Extrae el catálogo de productos eliminando duplicados"""
    print("Procesando catálogo de productos...")
    
    ruta_entrada = os.path.join(directorio_entrada, 'productos_final.csv')
    ruta_salida = os.path.join(directorio_salida, 'catalogo_productos.csv')
    
    # Leer solo las columnas necesarias para el catálogo
    columnas_catalogo = [
        'id_producto', 'productos_ean', 'productos_descripcion', 'productos_marca',
        'productos_cantidad_presentacion', 'productos_unidad_medida_presentacion'
    ]
    
    # Usar chunks para evitar problemas de memoria
    chunks = []
    chunksize = 500000
    dtypes_cat = {c: str for c in columnas_catalogo}
    
    for i, chunk in enumerate(pd.read_csv(ruta_entrada, sep='|', encoding='utf-8', 
                                          chunksize=chunksize, low_memory=False,
                                          dtype=dtypes_cat,
                                          usecols=columnas_catalogo)):
        print(f"  Leyendo chunk {i+1} para catálogo...")
        chunks.append(chunk)
    
    # Concatenar todos los chunks
    df = pd.concat(chunks, ignore_index=True)
    
    def limpiar_codigo_barra(val):
        if pd.isna(val):
            return ''
        s = str(val).strip()
        if s.endswith('.0'):
            s = s[:-2]
        return s

    df['id_producto'] = df['id_producto'].apply(limpiar_codigo_barra)
    if 'productos_ean' in df.columns:
        df['productos_ean'] = df['productos_ean'].apply(limpiar_codigo_barra)
    
    # Filtrar productos vacíos y deduplicar priorizando la descripción más completa
    df = df[df['id_producto'] != ''].copy()
    df['_desc_len'] = df['productos_descripcion'].fillna('').astype(str).str.len()
    df = df.sort_values(by='_desc_len', ascending=False)
    df = df.drop_duplicates(subset=['id_producto'], keep='first')
    df = df.drop(columns=['_desc_len'])
    
    df.to_csv(ruta_salida, sep=',', index=False, encoding='utf-8')
    print(f"[OK] catalogo_productos.csv generado: {len(df)} productos únicos (ceros preservados)")

def procesar_precios(directorio_entrada, directorio_salida):
    """Procesa los precios agrupando por id_entidad, id_producto y columnas de precio"""
    print("Procesando precios (archivo grande, esto puede tardar varios minutos)...")
    
    ruta_entrada = os.path.join(directorio_entrada, 'productos_final.csv')
    ruta_salida = os.path.join(directorio_salida, 'precios.csv')
    
    columnas_grupo = [
        'id_entidad',
        'id_producto',
        'productos_precio_lista',
        'productos_precio_referencia',
        'productos_cantidad_referencia',
        'productos_unidad_medida_referencia',
        'productos_precio_unitario_promo1',
        'productos_leyenda_promo1',
        'productos_precio_unitario_promo2',
        'productos_leyenda_promo2'
    ]
    
    columnas_lectura = [
        'id_comercio', 'id_bandera', 'id_producto',
        'productos_precio_lista', 'productos_precio_referencia',
        'productos_cantidad_referencia', 'productos_unidad_medida_referencia',
        'productos_precio_unitario_promo1', 'productos_leyenda_promo1',
        'productos_precio_unitario_promo2', 'productos_leyenda_promo2',
        'id_sucursal'
    ]
    
    def limpiar_id_entero(val):
        if pd.isna(val):
            return ''
        try:
            f = float(val)
            if f.is_integer():
                return str(int(f))
            return str(val).strip()
        except ValueError:
            return str(val).strip()

    def limpiar_codigo_barra(val):
        if pd.isna(val):
            return ''
        s = str(val).strip()
        if s.endswith('.0'):
            s = s[:-2]
        return s

    chunksize = 500000
    chunks = []
    dtypes_precios = {
        'id_comercio': str,
        'id_bandera': str,
        'id_producto': str,
        'id_sucursal': str
    }
    
    for i, chunk in enumerate(pd.read_csv(ruta_entrada, sep='|', encoding='utf-8', 
                                          chunksize=chunksize, low_memory=False,
                                          dtype=dtypes_precios,
                                          usecols=columnas_lectura)):
        c_com = chunk['id_comercio'].apply(limpiar_id_entero)
        c_band = chunk['id_bandera'].apply(limpiar_id_entero)
        chunk['id_entidad'] = c_com + '_' + c_band
        chunk['id_producto'] = chunk['id_producto'].apply(limpiar_codigo_barra)
        chunk['id_sucursal'] = chunk['id_sucursal'].apply(limpiar_id_entero)
        
        chunk = chunk[chunk['id_producto'] != ''].copy()
        chunk = chunk[chunk['productos_precio_lista'].notna()].copy()
        
        chunk_group = chunk.drop(columns=['id_comercio', 'id_bandera'])
        
        def agrupar_sucursales(x):
            return ','.join(sorted(set([str(v) for v in x if str(v).strip()])))
            
        grouped = chunk_group.groupby(columnas_grupo, dropna=False).agg({
            'id_sucursal': agrupar_sucursales
        }).reset_index()
        
        chunks.append(grouped)
        print(f"  Chunk {i+1} procesado...")
        
    print(f"Concatenando {len(chunks)} chunks intermedios...")
    df_final = pd.concat(chunks, ignore_index=True)
    
    print("Agrupación final de precios...")
    def agrupar_final(x):
        s = set()
        for val in x:
            if pd.notna(val) and str(val).strip():
                s.update([p.strip() for p in str(val).split(',') if p.strip()])
        return ','.join(sorted(s, key=lambda item: int(item) if item.isdigit() else item))

    df_final = df_final.groupby(columnas_grupo, dropna=False).agg({
        'id_sucursal': agrupar_final
    }).reset_index()
    
    df_final = df_final.rename(columns={'id_sucursal': 'grupo_sucursales'})
    df_final.to_csv(ruta_salida, sep=',', index=False, encoding='utf-8')
    print(f"[OK] precios.csv generado: {len(df_final)} grupos de precios con id_entidad")

def main():
    directorio_entrada = r"D:\GoogleAntigravity\ConsumoAtento\Bases de Datos Precios\sepa_output"
    directorio_salida = crear_directorio_salida(directorio_entrada)
    
    print(f"Directorio de salida: {directorio_salida}")
    print("="*50)
    
    # Procesar archivos pequeños primero
    procesar_comercio(directorio_entrada, directorio_salida)
    procesar_sucursales(directorio_entrada, directorio_salida)
    
    # Procesar productos (dividido en dos partes)
    procesar_catalogo_productos(directorio_entrada, directorio_salida)
    procesar_precios(directorio_entrada, directorio_salida)
    
    print("="*50)
    print("[OK] Proceso completado exitosamente")

if __name__ == "__main__":
    main()
