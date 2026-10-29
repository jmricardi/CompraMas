import os

source = 'D:/GoogleAntigravity/CompraMas/lib/ui/screens/scan/scan_screen.dart'
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
    return class_code.replace('class _', 'class ').replace('const _', 'const ').replace('_ScanSuccessView', 'ScanSuccessView').replace('_SearchIdleView', 'SearchIdleView').replace('_ScanLoadingView', 'ScanLoadingView').replace('_ScanErrorView', 'ScanErrorView').replace('_ProductHeaderCard', 'ProductHeaderCard').replace('_ProductHeaderImage', 'ProductHeaderImage').replace('_ProductDetailsColumn', 'ProductDetailsColumn').replace('_BarcodeBadge', 'BarcodeBadge').replace('_NutritionToggleButton', 'NutritionToggleButton').replace('_ProductImageZoomDialog', 'ProductImageZoomDialog')

target_classes = ['_SearchIdleView', '_ScanLoadingView', '_ScanErrorView', '_ScanSuccessView', '_ScanSuccessViewState', '_ProductHeaderCard', '_ProductHeaderImage', '_ProductDetailsColumn', '_BarcodeBadge', '_NutritionToggleButton', '_ProductImageZoomDialog']

extracted_code = {}
for cls in target_classes:
    for i, line in enumerate(lines):
        if line.startswith(f'class {cls} ') or line.startswith(f'class {cls}<'):
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

imports_states = """import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:compra_mas/services/locale_service.dart';
import 'package:compra_mas/viewmodels/scanner_viewmodel.dart';
"""

imports_success = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:compra_mas/models/off_product.dart';
import 'package:compra_mas/services/locale_service.dart';
import 'package:compra_mas/ui/screens/scan/components/product_header_card.dart';
import 'package:compra_mas/ui/widgets/price_comparison_list.dart';
import 'package:compra_mas/viewmodels/scanner_viewmodel.dart';
"""

imports_header = """import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:compra_mas/models/off_product.dart';
import 'package:compra_mas/services/locale_service.dart';
import 'package:provider/provider.dart';
import 'package:compra_mas/utils/network_image_util.dart';
"""

components_dir = 'D:/GoogleAntigravity/CompraMas/lib/ui/screens/scan/components'
os.makedirs(components_dir, exist_ok=True)

with open(f'{components_dir}/scan_states_views.dart', 'w', encoding='utf-8') as f:
    f.write(imports_states + '\n')
    f.write(extracted_code['_SearchIdleView'] + '\n')
    f.write(extracted_code['_ScanLoadingView'] + '\n')
    f.write(extracted_code['_ScanErrorView'] + '\n')

with open(f'{components_dir}/scan_success_view.dart', 'w', encoding='utf-8') as f:
    f.write(imports_success + '\n')
    f.write(extracted_code.get('_ScanSuccessView', '') + '\n')
    f.write(extracted_code.get('_ScanSuccessViewState', '') + '\n')

with open(f'{components_dir}/product_header_card.dart', 'w', encoding='utf-8') as f:
    f.write(imports_header + '\n')
    f.write(extracted_code.get('_ProductHeaderCard', '') + '\n')
    f.write(extracted_code.get('_ProductHeaderImage', '') + '\n')
    f.write(extracted_code.get('_ProductDetailsColumn', '') + '\n')
    f.write(extracted_code.get('_BarcodeBadge', '') + '\n')
    f.write(extracted_code.get('_NutritionToggleButton', '') + '\n')
    f.write(extracted_code.get('_ProductImageZoomDialog', '') + '\n')

main_lines = main_code.split('\n')
insert_idx = 0
for i, line in enumerate(main_lines):
    if line.startswith('import ') and not main_lines[i+1].startswith('import '):
        insert_idx = i + 1
        break
main_lines.insert(insert_idx, "import 'components/scan_states_views.dart';\nimport 'components/scan_success_view.dart';")

with open(source, 'w', encoding='utf-8') as f:
    f.write('\n'.join(main_lines))

print('Done extracting components from scan_screen.dart')
