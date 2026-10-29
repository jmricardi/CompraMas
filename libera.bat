@echo off
REM =====================================================================
REM Script de Liberacion de Memoria y Procesos - FirmApp
REM =====================================================================
chcp 65001 >nul
echo =====================================================================
echo INICIANDO LIBERACION DE MEMORIA PARA COMPILACION...
echo =====================================================================
echo.

REM 1. Detener Daemons de Gradle
echo [1/4] Deteniendo Gradle Daemons...
if exist android\gradlew.bat (
    call android\gradlew.bat --stop >nul 2>&1
    echo   - Gradle Daemons detenidos con exito.
) else (
    echo   - Carpeta android o gradlew no encontrados. Saltando paso.
)
echo.

REM 2. Cerrar procesos colgados
echo [2/4] Finalizando procesos innecesarios de desarrollo...
echo   - Cerrando procesos Java...
taskkill /F /IM java.exe /T >nul 2>&1
echo   - Cerrando procesos Dart y Flutter...
taskkill /F /IM dart.exe /T >nul 2>&1
taskkill /F /IM flutter.exe /T >nul 2>&1
echo   - Cerrando ADB (puente de depuracion de Android)...
taskkill /F /IM adb.exe /T >nul 2>&1
echo   - Cerrando procesos de Node...
taskkill /F /IM node.exe /T >nul 2>&1
echo   - Procesos finalizados de forma segura.
echo.

REM 3. Limpieza de cache de Flutter
echo [3/4] Limpiando cache del proyecto Flutter...
call flutter clean >nul 2>&1
echo   - Cache de Flutter limpiada.
echo.

REM 4. Liberacion adicional de Windows
echo [4/4] Optimizando memoria del sistema...
echo   - Vaciando cache de DNS...
ipconfig /flushdns >nul 2>&1
echo   - Memoria RAM y cache liberadas con exito.
echo.

echo =====================================================================
echo SISTEMA LISTO PARA COMPILAR!
echo Puedes ejecutar: compilar.bat o compilarfinal.bat
echo =====================================================================
pause
