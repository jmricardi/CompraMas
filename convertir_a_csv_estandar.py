import csv
import os
import time

archivos = ['comercio_opt.csv', 'sucursales_opt.csv', 'catalogo_productos.csv', 'precios.csv']
base_dir = r"D:\GoogleAntigravity\ConsumoAtento\Bases de Datos Precios\sepa_output\optimizados"

def limpiar_id(val):
    if not val:
        return ''
    try:
        f = float(val)
        if f.is_integer():
            return str(int(f))
        return val
    except ValueError:
        return val

for arch in archivos:
    ruta_in = os.path.join(base_dir, arch)
    ruta_out = os.path.join(base_dir, arch.replace('.csv', '_std.csv'))
    print("Convirtiendo " + arch + " a CSV estandar...")
    t0 = time.time()
    
    with open(ruta_in, 'r', encoding='utf-8', errors='replace') as f_in, \
         open(ruta_out, 'w', encoding='utf-8', newline='') as f_out:
        
        reader = csv.reader(f_in, delimiter='|')
        writer = csv.writer(f_out, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        
        header = next(reader)
        writer.writerow(header)
        
        count = 0
        for row in reader:
            new_row = []
            for col_idx, val in enumerate(row):
                val_clean = val.strip()
                col_name = header[col_idx]
                if col_name in ('id_producto', 'productos_ean', 'comercio_cuit', 'id_sucursal'):
                    val_clean = limpiar_id(val_clean)
                elif col_name == 'id_entidad' and '.0' in val_clean:
                    parts = val_clean.split('_')
                    val_clean = '_'.join([limpiar_id(p) for p in parts])
                new_row.append(val_clean)
            writer.writerow(new_row)
            count += 1
            
    os.replace(ruta_out, ruta_in)
    duracion = time.time() - t0
    print("  [OK] " + arch + ": " + str(count) + " filas convertidas en " + str(round(duracion, 1)) + "s")

print("Conversion a CSV estandar completada!")
