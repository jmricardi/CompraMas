import os

source = 'D:/GoogleAntigravity/CompraMas/lib/ui/screens/fuel/fuel_map_screen.dart'
with open(source, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def get_class_bounds(start_line_idx):
    idx = start_line_idx
    brace_count = 0
    started = False
    while idx < len(lines):
        line = lines[idx]
        if '{' in line:
            brace_count += line.count('{')
            started = True
        if '}' in line:
            brace_count -= line.count('}')
        if started and brace_count == 0:
            return idx + 1
        idx += 1
    return idx

def remove_private(class_code):
    return class_code.replace('class _', 'class ').replace('const _', 'const ').replace('_SearchAreaPillButton', 'SearchAreaPillButton').replace('_FuelTypeFilterChips', 'FuelTypeFilterChips').replace('_MapControlButtons', 'MapControlButtons').replace('_StationMarkerPin', 'StationMarkerPin').replace('_FuelBrandBadge', 'FuelBrandBadge').replace('_StationDetailCard', 'StationDetailCard')

target_classes = ['_SearchAreaPillButton', '_FuelTypeFilterChips', '_MapControlButtons', '_StationMarkerPin', '_FuelBrandBadge', '_StationDetailCard']

extracted_code = {}
for cls in target_classes:
    for i, line in enumerate(lines):
        if line.startswith(f'class {cls} '):
            end_idx = get_class_bounds(i)
            code = ''.join(lines[i:end_idx])
            extracted_code[cls] = remove_private(code)
            for j in range(i, end_idx):
                lines[j] = ''
            break

main_code = ''.join(lines)
for cls in target_classes:
    pub = cls.replace('_', '')
    main_code = main_code.replace(cls, pub)

imports = """import 'package:flutter/material.dart';
import 'package:compramas/models/fuel_model.dart';
import 'package:compramas/services/locale_service.dart';
import 'package:provider/provider.dart';
"""

components_dir = 'D:/GoogleAntigravity/CompraMas/lib/ui/screens/fuel/components'
os.makedirs(components_dir, exist_ok=True)

with open(f'{components_dir}/fuel_map_controls.dart', 'w', encoding='utf-8') as f:
    f.write(imports + '\n')
    f.write(extracted_code.get('_SearchAreaPillButton', '') + '\n')
    f.write(extracted_code.get('_FuelTypeFilterChips', '') + '\n')
    f.write(extracted_code.get('_MapControlButtons', '') + '\n')

with open(f'{components_dir}/fuel_station_markers.dart', 'w', encoding='utf-8') as f:
    f.write(imports + '\n')
    f.write("import 'package:url_launcher/url_launcher.dart';\n")
    f.write(extracted_code.get('_StationMarkerPin', '') + '\n')
    f.write(extracted_code.get('_FuelBrandBadge', '') + '\n')
    f.write(extracted_code.get('_StationDetailCard', '') + '\n')

main_lines = main_code.split('\n')
insert_idx = 0
for i, line in enumerate(main_lines):
    if line.startswith('import ') and not main_lines[i+1].startswith('import '):
        insert_idx = i + 1
        break
main_lines.insert(insert_idx, "import 'components/fuel_map_controls.dart';\nimport 'components/fuel_station_markers.dart';")

with open(source, 'w', encoding='utf-8') as f:
    f.write('\n'.join(main_lines))

print('Done extracting components from fuel_map_screen.dart')
