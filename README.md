<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# CompraMás - Comparador Inteligente de Precios

Aplicación Flutter y motor de datos para la comparación de precios de supermercados, mayoristas, hipermercados y estaciones de servicio en Argentina.

---

## ⚡ Ejecución Rápida del Pipeline de Precios

El módulo de ingesta y procesamiento de datos (`/ingesta/`) funciona de forma independiente con Python.

### 1. Actualización Diaria Completa (SEPA + Scraping + IA + Supabase)
```powershell
cd ingesta
python pipeline.py --all --confirm-truncate --skip-off
```

### 2. Actualización Express (~5 a 10 min)
```powershell
cd ingesta
python pipeline.py --express
```

> 📖 **Guía completa del pipeline:** Consulta la documentación detallada con todos los parámetros, pasos individuales, herramientas de auditoría y purga en [ingesta/README.md](file:///d:/GoogleAntigravity/CompraMas/ingesta/README.md).

---

## 📱 Ejecutar la Aplicación Flutter (Localmente)

**Requisitos:** Flutter SDK, Android Studio / VS Code.

1. Abrir el proyecto en el entorno de desarrollo.
2. Instalar dependencias:
   ```powershell
   flutter pub get
   ```
3. Ejecutar pruebas unitarias y de widgets:
   ```powershell
   flutter test
   ```
4. Correr la aplicación en emulador o dispositivo físico:
   ```powershell
   flutter run
   ```
