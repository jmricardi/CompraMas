# Script de compilación optimizada y ofuscada para Google Play Store
# Genera el App Bundle (.aab) con R8 / ProGuard y ofuscación Dart AOT.

$symbolsDir = "build/app/outputs/symbols"
if (!(Test-Path $symbolsDir)) {
    New-Item -ItemType Directory -Force -Path $symbolsDir | Out-Null
}

Write-Host "🚀 Compilando Android App Bundle para Play Store con ofuscación..." -ForegroundColor Cyan

flutter build appbundle --release `
    --obfuscate `
    --split-debug-info=$symbolsDir

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ App Bundle generado con éxito en:" -ForegroundColor Green
    Write-Host "   build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
    Write-Host "`nℹ️  Archivos de símbolos de depuración (Dart symbols) guardados en:" -ForegroundColor Green
    Write-Host "   $symbolsDir" -ForegroundColor Yellow
    Write-Host "   (Útiles para subir a Google Play Console si solicita mapeo de trazas de error)." -ForegroundColor Gray
} else {
    Write-Host "`n❌ Error al compilar el App Bundle." -ForegroundColor Red
}
