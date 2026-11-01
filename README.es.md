[English](README.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Português](README.pt-BR.md) · **Español**

# Pricing AI

Pricing AI ayuda a pequeños negocios de servicios y estudios de software a fijar precios con seguridad: calcula cuánto cuesta realmente cada servicio, crea una web de reservas, presupuesta proyectos de software y muestra por cuánto se adjudicaron contratos públicos similares en Taiwán. La IA funciona en tu propio ordenador: tus datos no se envían a una IA en la nube.

- Web: https://pricingai.minervaelectronics.com/es/
- Descargar para macOS: https://github.com/matt-hima/pricing-ai/releases/latest
- Versión de navegador (sin IA, sin instalación): https://pricingai.minervaelectronics.com/app/?lang=es

## Funciones

La app tiene cuatro pestañas.

### 1. Precios de servicios

Para peluquerías, clínicas, restaurantes, escuelas y espacios de alquiler.

- Introduce tu pago por hora, costes fijos mensuales, horas reservables, beneficio objetivo, impuestos y redondeo.
- Para cada servicio, introduce los minutos y los materiales; la app muestra el coste real, el precio que alcanza tu margen y el beneficio.
- Un resumen muestra el coste indirecto por hora, las horas para cubrir costes y el beneficio mensual según tu plan.
- 14 monedas con sus impuestos y redondeos habituales. Exporta un CSV o añade la lista de precios a tu web de reservas con un clic.
- App de escritorio: la IA sugiere servicios para tu negocio, y "Consultar precios" busca en la web cuánto cobran negocios similares y lo convierte en una lista de precios (solo se usan precios que aparecen en los resultados).

### 2. Crear web

- Empieza con una plantilla limpia en inglés, chino tradicional, japonés, portugués o español y edita visualmente.
- Añade servicios y precios, preguntas frecuentes, diagramas de flujo y un aspecto tecnológico oscuro.
- Recibe reservas con Google Forms: un Apps Script crea el formulario y un calendario que muestra los horarios ocupados, y cada reserva se convierte en un evento.
- Exporta un ZIP para cualquier alojamiento.
- App de escritorio: describe tu negocio en un chat y la IA escribe la página, reescribe partes y dibuja imágenes de banner; publica en Firebase con un clic.

### 3. Presupuesto de proyecto (desarrollo de software)

- Introduce tu empresa, la tarifa por persona-mes y los impuestos, el cliente y las condiciones del presupuesto.
- Elige el tipo de proyecto, las plataformas (web, iOS, Android…), el nivel de diseño y hasta 17 módulos de funciones, cada uno con notas en lenguaje sencillo.
- Obtén un rango de precio total (el límite superior incluye un margen de riesgo de 1,2–1,5×), el desglose en persona-mes por fase, el plazo y las cuotas de mantenimiento sugeridas.
- Presupuesto en PDF en vivo: vista previa, descarga, impresión o envío al equipo comercial.
- App de escritorio: la IA local divide cada módulo en subtareas y estima las horas; los precios siempre los calcula la app a partir de tu tarifa, nunca la IA.
- "Casos anteriores": abre el Sistema de Compras del gobierno de Taiwán para proyectos similares adjudicados y resume precios y competencia junto a tu presupuesto (ver abajo).

### 4. Análisis de licitaciones (compras públicas de Taiwán)

Función de la app de escritorio. El Sistema de Compras Electrónicas del gobierno (web.pcc.gov.tw) se abre en un navegador dentro de la app; tú navegas y la app solo lee las páginas que abres.

- Ampliación de palabras clave según la regla del sitio: compara el término como una frase continua (se ignoran los espacios), así que variantes como 網站 / 網頁 / 官網 se buscan por separado y se combinan.
- Importes adjudicados: número, mediana, 50 % central, media, rango y distribución, los organismos que más compran y las modalidades.
- Dónde queda tu presupuesto: el porcentaje de casos similares por debajo de tu precio y si está en la franja baja, típica o alta.
- Competencia: abre algunos avisos de adjudicación para ver cuántas empresas licitaron, qué tan cerca del presupuesto quedó el importe y quién ganó.
- Posibles competidores: todos los licitadores de los avisos abiertos; consulta el historial de cualquier empresa en los últimos 12 meses (victorias, ofertas, tasa de éxito, importe típico, organismos).
- Google Modo IA se abre en el navegador de la app para información pública sobre una empresa o un mercado, para que la leas.
- Exporta los casos en CSV.
- Datos abiertos oficiales: descarga el conjunto de adjudicaciones del Sistema de Compras (contratos de TWD 1M o más, con unos 2 meses de retraso) y analiza varios años a la vez, sin verificaciones: importes, ganadores frecuentes, organismos y formas de adjudicación. Fuente: Comisión de Obras Públicas del Yuan Ejecutivo, datos abiertos bajo la Open Government Data License v1.0.

## ¿App de escritorio o navegador?

| Función | App de escritorio | Navegador |
|---|---|---|
| Calculadora de precios de servicios | ✓ | ✓ |
| Editor de webs y exportación en ZIP | ✓ | ✓ |
| Presupuesto de proyecto con la tabla incluida | ✓ | ✓ |
| Presupuestos con IA y web escrita por chat | ✓ | — |
| Análisis de licitaciones y resumen con IA | ✓ | — |
| Historial de competidores y Google Modo IA | ✓ | — |
| Publicación en Firebase con un clic | ✓ | — |
| Tus datos se quedan en tu ordenador | ✓ | ✓ |

La versión de navegador, incluido el acceso directo que Chrome ofrece instalar ("Pricing AI Web"), no es la app de escritorio.

## Descargar e instalar (macOS)

1. Descarga `PricingAI-mac.dmg` de la [última versión](https://github.com/matt-hima/pricing-ai/releases/latest).
2. Abre el .dmg y arrastra **Pricing AI** a **Aplicaciones**.
3. Abre Pricing AI. Esta versión aún no está firmada con un Apple Developer ID, así que la primera vez macOS puede decir que no puede verificar al desarrollador: abre **Ajustes del Sistema → Privacidad y seguridad** y pulsa **Abrir igualmente** (solo una vez).
4. La primera tarea de IA descarga una vez el motor y un modelo (0,5–5 GB). Después, la IA funciona en tu ordenador.

A partir de la versión 0.2.0 la app se actualiza sola: busca una versión nueva al abrirse y una vez al día, y **Buscar actualizaciones** está en *Cómo se estima* en la columna derecha. La versión 0.1.0 no tiene actualizador, así que instala la 0.2.0 una vez a mano.

La versión para Windows llegará pronto.

### Requisitos del sistema

| | |
|---|---|
| macOS | 10.15 o posterior; se recomienda Apple silicon (generar imágenes requiere Apple silicon) |
| Windows | 10 u 11, 64 bits; se recomienda una tarjeta gráfica con Vulkan (NVIDIA, AMD o Intel) |
| Memoria | 8 GB de RAM o más; 16 GB para los modelos grandes |
| Disco | Unos 1–6 GB libres para el motor y el modelo de IA |
| Internet | Para descargar el modelo de IA una vez y consultar licitaciones |

## Privacidad

- App de escritorio: los modelos de IA funcionan en tu ordenador con llama.cpp (Metal en Mac, Vulkan en Windows). Tus presupuestos, precios y webs se guardan en tu ordenador.
- Versión de navegador: sin IA; tus datos se guardan en el navegador.
- Uso de la red: descargar el motor y los modelos de IA (GitHub, Hugging Face); el sitio de compras y Google, solo en el navegador de la app cuando usas el análisis de licitaciones; "Consultar precios" envía tus términos de búsqueda a Bing.
- Los presupuestos y precios son una ayuda de planificación, no un consejo ni una oferta vinculante.

## Modelos de IA

Los modelos se descargan solo cuando los eliges y no forman parte de este repositorio ni de los instaladores. Cada modelo tiene su propia licencia.

| Modelo | Tamaño | Licencia |
|---|---|---|
| Qwen2.5 0.5B / 1.5B / 7B Instruct | 0,5 / 1,1 / 4,7 GB | Apache-2.0 |
| Llama 3.1 8B Instruct | 4,9 GB | Llama 3.1 Community License (Built with Llama) |
| Stable Diffusion 1.5 / 2.1 / SDXL (imágenes) | 1,7–4,8 GB | CreativeML OpenRAIL-M / OpenRAIL++-M |

## Compilar desde el código

Requiere [Flutter](https://flutter.dev) con Dart 3.12 o posterior; Xcode para compilar en macOS; Visual Studio en Windows para compilar en Windows.

```bash
cd flutter_app
flutter pub get
flutter test                      # pruebas unitarias y de widgets
flutter run -d macos              # app de escritorio con IA local
flutter build macos --release     # Pricing AI.app
flutter build web --base-href /app/
```

Prueba de integración de la app real en Mac (sitio de compras real e IA local):

```bash
cd flutter_app
LIVE_ENGINE_STORAGE=/path/to/pricing-ai caffeinate -d -i flutter test integration_test/case_analysis_app_test.dart -d macos
```

Web y herramientas:

| Comando | Qué hace |
|---|---|
| `tool/deploy.sh` | Comprueba, prueba, compila la app web en `/app/`, monta el sitio y lo publica en Firebase Hosting (`--no-deploy` solo compila) |
| `tool/build_site.sh` | Monta `build/site`: página de inicio en `/`, app web en `/app/` |
| `python3 tool/gen_landing.py` | Genera la página de inicio centrada en la descarga en 5 idiomas (enlaces de instaladores en `HOSTED_URLS`) |
| `tool/release_mac.sh` | Genera la versión para Mac en `dist/`: DMG, `appcast.xml` firmado con Sparkle para la actualización automática, SHA-256 en las notas de la versión (pasos al inicio del script) |
| `python3 tool/gen_notices.py` | Vuelve a generar los avisos y textos de licencias de terceros |
| `python3 tool/check_i18n.py` | Comprueba que los 5 idiomas tienen los mismos textos |

## Estructura del repositorio

| Carpeta | Qué es |
|---|---|
| `flutter_app/lib/` | Código de la app: `service_pricing/`, `site/` (crear web), `estimator.dart` (presupuesto de proyecto), `case_analysis/` (análisis de licitaciones), `engine/` (motor de IA local), `i18n/` (5 idiomas), `ui/` |
| `flutter_app/assets/editor/` | El editor de webs (GrapesJS) que funciona dentro de la app |
| `flutter_app/web/` | Archivos de la versión web, puentes de PDF y de IA en el navegador, fuentes |
| `flutter_app/landing/` | Páginas de inicio generadas |
| `flutter_app/test/`, `integration_test/` | Pruebas, con páginas guardadas del sitio de compras como datos de prueba |
| `flutter_app/macos/`, `windows/` | Proyectos de escritorio |
| `site_builder/` | Una versión anterior e independiente del editor de webs |
| `css/`, `js/`, `index.html`, `logo/` | La página de presupuesto estática original |

## Licencia

Pricing AI se distribuye bajo la [Apache License 2.0](LICENSE). Usa software de terceros bajo sus propias licencias, enumeradas en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), con los textos completos en [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt). Todas las bibliotecas incluidas usan licencias BSD, MIT o Apache, y las fuentes usan la SIL Open Font License.
