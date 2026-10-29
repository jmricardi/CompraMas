import re

with open("app/src/main/java/com/example/MainActivity.kt", "r") as f:
    content = f.read()

old_block = """                                    val options = ScanOptions()
                                    options.setDesiredBarcodeFormats(ScanOptions.ALL_CODE_TYPES)
                                    options.setPrompt("Scan a product barcode")
                                    options.setBeepEnabled(true)
                                    options.setBarcodeImageEnabled(true)
                                    scanLauncher.launch(options)"""

new_block = """                                    val options = ScanOptions()
                                    // Use PRODUCT_CODE_TYPES (EAN, UPC) for much faster recognition and less false positives on supermarkets
                                    options.setDesiredBarcodeFormats(ScanOptions.PRODUCT_CODE_TYPES)
                                    options.setPrompt("Scan a product barcode")
                                    options.setBeepEnabled(true)
                                    options.setBarcodeImageEnabled(true)
                                    options.setOrientationLocked(true) // Lock to activity orientation
                                    options.setCaptureActivity(CustomScannerActivity::class.java) // Custom portrait activity
                                    scanLauncher.launch(options)"""

# Handle the fact that spaces might not perfectly match
# Let's use a regex that matches regardless of leading whitespaces.
import re

pattern = re.compile(r'val options = ScanOptions\(\)\s*options\.setDesiredBarcodeFormats\(ScanOptions\.ALL_CODE_TYPES\)\s*options\.setPrompt\("[^"]+"\)\s*options\.setBeepEnabled\(true\)\s*options\.setBarcodeImageEnabled\(true\)\s*scanLauncher\.launch\(options\)')
content = pattern.sub(new_block, content)

with open("app/src/main/java/com/example/MainActivity.kt", "w") as f:
    f.write(content)

