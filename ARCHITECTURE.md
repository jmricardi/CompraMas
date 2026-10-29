# NutriScan - Documento de Arquitectura de Software

## 1. Topología y Patrones Arquitectónicos
La aplicación sigue estrictamente el patrón **MVVM (Model-View-ViewModel)** recomendado por Google, garantizando la separación de responsabilidades y el flujo unidireccional de datos (UDF).

### 1.1 Capa de Presentación (UI)
- **Framework:** Jetpack Compose (Declarativo).
- **Gestión de Estado:** Migración de estado reactiva mediante `StateFlow` expuesto desde el ViewModel. La UI reacciona a un único árbol de estado sellado (`ScanUiState`), lo que previene condiciones de carrera en la renderización y estados inconsistentes.
- **Ciclo de vida:** Uso de `rememberLauncherForActivityResult` para la gestión transaccional de intents asíncronos (Cámara/Escáner y Permisos de Ubicación) sin retener referencias a la Activity, evitando *memory leaks*.

### 1.2 Capa de Dominio y Lógica de Negocio (ViewModel)
- **Ejecución Asíncrona:** Uso de Kotlin Coroutines (`viewModelScope`) estructurado. Los trabajos se cancelan automáticamente cuando el ViewModel es destruido.
- **Cálculo Espacial:** Integración con `Location.distanceTo` ejecutada en memoria sobre los datos recuperados, enlazando coordenadas locales del usuario con las coordenadas relacionales de la base de datos (Supermercados).

### 1.3 Capa de Datos (Data & Network)
- **Red (Network):** `Retrofit2` con `OkHttp3` (manejo de timeouts y LoggingInterceptor) acoplado a `Moshi` para deserialización estricta de JSON. Conectado a Open Food Facts y Google Gemini API.
- **Persistencia Local (Edge Cache):** `Room Database` procesado vía KSP. Esquema relacional optimizado con `Flow` reactivos (`PriceDao.getPricesForProduct`) para asegurar que el Main Thread no sea bloqueado por I/O.

---

## 2. Puntos Faltantes y Deuda Técnica (Roadmap)

Como Arquitecto, identifico los siguientes puntos críticos de falla o áreas de mejora obligatorias antes de un paso a producción:

### 2.1 Backend de Precios (Crucial)
- **Problema:** Actualmente se utiliza una semilla local (Seed) en Room para simular precios y supermercados debido a la inexistencia de una API pública de precios.
- **Solución Requerida:** Implementar un Backend Serverless (ej. *Supabase* o *Cloudflare Workers*) que centralice el *crowdsourcing* de precios. Reemplazar la semilla local por una sincronización *Offline-First* utilizando una estrategia de mediador (RemoteMediator en Paging3) entre la DB remota y Room.

### 2.2 Optimización de Geolocalización
- **Problema:** El uso de `fusedLocationClient.lastLocation` es rápido pero asume que el sistema operativo tiene una ubicación en caché. Si el GPS estuvo apagado, retornará `null`.
- **Solución Requerida:** Transicionar a `getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, CancellationToken)` combinado con un `suspendCancellableCoroutine` para forzar al hardware a triangular la ubicación actual con un *timeout* estricto de 5 segundos para no bloquear la UI.

### 2.3 Inyección de Dependencias (DI)
- **Problema:** El repositorio (`PriceRepository`) se inyecta manualmente a través de un `ViewModelProvider.Factory` instanciado a nivel de `Application`. A gran escala, esto genera código *boilerplate* y dificulta el testing aislado.
- **Solución Requerida:** Integrar **Hilt** (Dagger) para la gestión del grafo de dependencias en tiempo de compilación.

### 2.4 Retención de Flujos (Lifecycle Awareness)
- **Problema:** El estado se recolecta actualmente con `collectAsState()`. Si la app pasa a segundo plano, las actualizaciones de flujo siguen emitiéndose, consumiendo recursos y potencialmente provocando fugas en vistas complejas.
- **Solución Requerida:** Migrar a `collectAsStateWithLifecycle()` de la librería `androidx.lifecycle.compose` para que el recolector se pause en estados `ON_STOP` de la Activity.

### 2.5 Seguridad y Ofuscación
- **Problema:** Retrofit expone estructuras de datos. Las keys están en el `BuildConfig`, pero pueden ser extraídas mediante ingeniería inversa del APK.
- **Solución Requerida:** Activar `R8` (MinifyEnabled = true) en el tipo de construcción *release* y utilizar AppCheck de Firebase si se migra el backend, evitando el uso no autorizado de la cuota de la Gemini API.
