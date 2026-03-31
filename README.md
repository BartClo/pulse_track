# OCR Blood Pressure Data Extractor (PulseTrack)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Google ML Kit](https://img.shields.io/badge/Google%20ML%20Kit-OCR-4285F4?logo=google&logoColor=white)
![Isar](https://img.shields.io/badge/Isar-Local%20DB-00C7B7)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-6E6E6E)

PulseTrack es una aplicación móvil enfocada en la **extracción de datos clínicos** desde imágenes de tensiómetros. Su objetivo principal es convertir texto no estructurado (foto de pantalla del dispositivo) en registros estructurados y utilizables: **SYS, DIA y PUL**.

## Problema de negocio (Business Value)

En escenarios reales, muchas lecturas de presión arterial se registran de forma manual, lo que introduce errores de digitación, pérdida de datos y baja trazabilidad.

Este proyecto digitaliza el flujo de captura y estandarización de mediciones para:

- Reducir errores humanos en la transcripción.
- Estandarizar datos para consumo analítico.
- Preparar la base para pipelines ETL posteriores (almacenamiento, monitoreo y BI).
- Facilitar seguimiento longitudinal del paciente con datos consistentes.

## Arquitectura de extracción de datos

La lógica de extracción está diseñada como un pipeline robusto de OCR + parseo:

`Captura de imagen -> OCR (ML Kit) -> Limpieza y parseo -> Validación fisiológica -> Variables objetivo (SYS, DIA, PUL)`

### 1) Captura de imagen

- Fuente cámara y galería (`ScanScreen`).
- Recorte opcional para imágenes de galería (`image_cropper`) para mejorar señal OCR.
- Control de permisos de cámara/almacenamiento por plataforma.

### 2) OCR con Google ML Kit

- Motor OCR: `google_mlkit_text_recognition`.
- Servicio principal: `SmartOcrService`.
- Estrategia multi-paso:
  - OCR sobre imagen completa.
  - OCR sobre imagen preprocesada (escalado, grayscale, contraste, umbral binario).
  - Fallback por regiones (top/middle/bottom) para equipos con layout variable.

### 3) Limpieza / parseo (Regex + lógica heurística)

Implementado en `OcrParser` con pipeline multicapa:

- Normalización de texto OCR (`O -> 0`, `I/L -> 1`, `S -> 5`, `B -> 8`, etc.).
- Extracción de números por regex (`\\d{2,3}`).
- Extracción por etiquetas (`SYS`, `DIA`, `PUL`, `BPM`) cuando están presentes.
- Corrección de confusiones comunes (ej. 50/60, 95/96 según frecuencia observada).
- Agrupación de valores cercanos y deduplicación por tolerancia.
- Asignación inteligente de roles:
  - SYS: candidato de presión alta.
  - DIA: candidato menor a SYS y dentro de rango esperado.
  - PUL: valor más cercano a frecuencia cardiaca objetivo.

### 4) Validación y scoring de confianza

El parser aplica reglas fisiológicas y metadatos de calidad:

- Rango SYS, DIA y PUL.
- Relación `SYS > DIA`.
- Diferencia mínima `SYS - DIA >= 20`.
- Señales para UX/operación:
  - `requiresManualInput`
  - `allowRetake`
  - `warnings[]`
  - `confidenceScore`

Resultado: extracción estructurada con trazabilidad de confianza, lista para persistencia y análisis.

### 5) Persistencia y consumo analítico local

- Almacenamiento local en Isar (`PressureReading`, `PressureRepository`).
- Exportación a **CSV** y **PDF** (`ExportService`), útil para intercambio y análisis offline.

## Stack tecnológico

- **Lenguaje/App**: Dart, Flutter
- **OCR / IA aplicada**: Google ML Kit Text Recognition
- **Procesamiento de imagen**: `image`, `image_cropper`, `image_picker`, `camera`
- **Persistencia local**: Isar
- **Visualización**: `fl_chart`
- **Notificaciones**: `flutter_local_notifications`, `timezone`
- **Exportación**: `pdf`, `share_plus`

## Setup y ejecución local

### Prerrequisitos

- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio (Android SDK) y/o Xcode (para iOS)
- Dispositivo físico o emulador con cámara (recomendado para pruebas OCR)

### Instalación

```bash
git clone https://github.com/BartClo/pulse_track.git
cd pulse_track
flutter pub get
```

### Ejecutar en desarrollo

```bash
flutter run
```

### Build opcional

```bash
flutter build apk
```

## Consideraciones de plataforma

- Android ya declara permisos de cámara y notificaciones en `AndroidManifest.xml`.
- Para iOS, validar permisos de cámara/galería/notificaciones según el dispositivo objetivo antes de publicar.

## Roadmap / siguientes pasos (enfoque Data)

1. **API de ingestión con FastAPI**  
   Exponer endpoint para recibir lecturas OCR validadas y centralizar datos.

2. **Persistencia relacional en PostgreSQL**  
   Modelar esquema analítico (lecturas, usuario, dispositivo, timestamp, calidad OCR).

3. **Pipeline ETL incremental**  
   Normalizar y versionar lecturas, control de calidad de datos y auditoría de correcciones manuales.

4. **Dashboard analítico (Power BI / Metabase)**  
   KPIs: tendencia SYS/DIA/PUL, distribución por rangos, alertas y adherencia a mediciones.

5. **Métricas de calidad OCR en producción**  
   Tasa de extracción automática vs. corrección manual, drift por tipo de tensiómetro e iluminación.

6. **MLOps ligero para mejora continua**  
   Dataset anonimizado de errores OCR para iterar reglas de parseo y estrategia de preprocesamiento.

## Valor para roles de Data Engineering / Analytics Engineering

Este proyecto demuestra capacidades aplicadas en:

- Diseño de pipelines de extracción desde fuentes no estructuradas.
- Limpieza y estandarización robusta de datos ruidosos.
- Validación de calidad y reglas de negocio sobre señales clínicas.
- Preparación de datos para downstream analytics y reporting.
- Visión end-to-end: captura -> estructuración -> persistencia -> exportación.
