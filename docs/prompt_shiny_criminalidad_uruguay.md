# Prompt: Shiny App — Estadísticas de Criminalidad Uruguay (AECA)

Construí una Shiny app en R para analizar estadísticas de criminalidad en Uruguay usando datos oficiales del Ministerio del Interior (AECA). La app debe cargar dos archivos de datos que estarán en el directorio de trabajo.

---

## Archivos de datos

**1. `delitos_2013_2025tri4.csv`**
- Separado por `;`, encoding UTF-8 BOM
- ~2.4 millones de registros de eventos delictivos (2013–2025)
- Columnas: `ID_EVENTO`, `DELITO`, `VICT_RAP`, `VICT_HUR`, `TENTATIVA`, `FECHA`, `AÑO`, `MES`, `SEMESTRE`, `TRIMESTRE`, `DIA_SEMANA`, `HORA`, `DEPTO`, `JURISDICCION`, `BARRIO_MONTEVIDEO`
- Valores de `DELITO`: HURTO / RAPIÑA / VIOLENCIA DOMÉSTICA / LESIONES / ABIGEATO
- `TENTATIVA`: SI / NO

**2. `homicidios_dolosos_consumados.xlsx`**
- 4.356 registros de homicidios dolosos consumados (2013–2025)
- Columnas: `ID_VICTIMA`, `FECHA`, `AÑO`, `MES`, `TRIMESTRE`, `DIA_SEMANA`, `HORA`, `DEPARTAMENTO`, `JURISDICCION`, `LUGAR`, `MOTIVO_APARENTE`, `TIPO`, `ARMAREC`, `PROCESADOS`, `MENORESCINICIOPROC`, `ACLARADO`, `SEXO`, `EDADCALC`, `NACIONALIDAD`, `ANTECEDENTES`, `ANTECEDENTESPORESTUPEFACIENTES`, `REL_VICT_AGRES`
- `ACLARADO`: ACLARADO / SIN ACLARAR
- `MOTIVO_APARENTE`: AJUSTE DE CUENTAS/ CONFLICTOS ENTRE CRIMINALES / ALTERCADOS ESPONTANEOS/ CONFLICTOS DIVERSOS / VIOLENCIA DOMESTICA Y ASOCIADOS / RAPIÑA / HURTO / COPAMIENTO / OTROS MOTIVOS / SIN DATO/ DESCONOCIDO
- `ARMAREC`: ARMA DE FUEGO / CORTO / PUNZANTE / ARMA PERSONAL / ESTRANGULACION / ASFIXIA / AHOGAMIENTO / OBJETO PESADO / CONTUNDENTE / OTRAS ARMAS / SIN DATO
- `REL_VICT_AGRES`: AMIGO/CONOCIDO / VINCULO DESCONOCIDO / PAREJA/EX PAREJA / SIN RELACION / FAMILIAR

---

## Estructura de la app

Usá `{bslib}` con `bslib::page_navbar()` y tema `bs_theme(bootswatch = "flatly")`. Todos los textos de la interfaz en español.

---

### Sección 1 — Delitos generales

**Filtros (sidebar):**
- Rango de años: `sliderInput` (2013–2025)
- Tipo de delito: `checkboxGroupInput` (todos seleccionados por defecto)
- Departamento: `selectInput` con opción "Todos los departamentos"
- Tentativa: `radioButtons` (Ambos / Solo consumados / Solo tentativas)

**KPIs (fila superior):**
- Total de eventos en el período filtrado
- Delito más frecuente
- Departamento con más eventos
- Porcentaje de tentativas

**Visualizaciones:**
- Gráfico de líneas: evolución anual del total de eventos por tipo de delito (una línea por delito)
- Gráfico de barras horizontales: ranking de departamentos por cantidad de eventos en el período filtrado
- Heatmap: día de la semana (eje Y) vs. hora del día 0–23 (eje X), coloreado por cantidad de eventos — excluir registros con `HORA == "SIN DATO"`
- Tabla interactiva (`{DT}`): datos agregados por año, departamento y tipo de delito

---

### Sección 2 — Homicidios dolosos

**Filtros (sidebar):**
- Rango de años: `sliderInput`
- Departamento: `selectInput`
- Motivo aparente: `checkboxGroupInput`
- Sexo de la víctima: `checkboxGroupInput` (HOMBRE / MUJER / SIN DATO)
- Tipo de arma: `checkboxGroupInput`

**KPIs (fila superior):**
- Total de homicidios en el período
- Tasa de esclarecimiento (% ACLARADO)
- Proporción hombres/mujeres
- Motivo más frecuente

**Visualizaciones:**
- Gráfico de líneas: evolución anual de homicidios totales con línea secundaria para la tasa de esclarecimiento (%)
- Gráfico de barras apiladas: distribución por motivo aparente por año
- Gráfico de barras: distribución por tipo de arma (`ARMAREC`)
- Histograma / density plot: distribución de edad de víctimas (`EDADCALC`), separado por sexo
- Gráfico de barras: relación víctima-agresor (`REL_VICT_AGRES`)
- Tabla interactiva (`{DT}`): microdatos filtrados con columnas seleccionadas

---

### Sección 3 — Comparativa departamental

**Filtros (sidebar):**
- Año: `selectInput` (único año)
- Indicador: `selectInput` (Total delitos / Homicidios / Rapiñas / Hurtos / Violencia doméstica / Lesiones)

**Visualizaciones:**
- Mapa coroplético de Uruguay por departamento usando `{leaflet}`. Para el shapefile usá `{rnaturalearth}` con `ne_states(country = "Uruguay", returnclass = "sf")` o descargá el GeoJSON de departamentos del INE Uruguay. Colorear por el indicador seleccionado con escala divergente.
- Gráfico de barras: ranking de todos los departamentos para el indicador seleccionado
- Tabla comparativa: todos los departamentos con múltiples indicadores para el año seleccionado

---

## Consideraciones técnicas

### Carga de datos
- Usá `data.table::fread()` para el CSV grande — cargarlo una sola vez al iniciar la app con `reactive` o directamente en el servidor global
- El CSV tiene BOM UTF-8; especificá `encoding = "UTF-8"` y eliminá el BOM del nombre de la primera columna si aparece `\uFEFF`
- Para el xlsx usá `readxl::read_excel()`

### Performance
- Usá `{data.table}` o `{dplyr}` con `{dtplyr}` para todas las agregaciones sobre el CSV
- Envolvé los datos filtrados en `reactive()` para evitar recalcular innecesariamente
- Para el mapa, precalculá los joins espaciales fuera de los reactivos cuando sea posible

### Visualizaciones
- Usá `{plotly}` para todos los gráficos (interactivos, con tooltips informativos en español)
- Paleta de colores consistente: asigná un color fijo por tipo de delito y mantenerlo en todos los gráficos de la Sección 1
- Para el heatmap usá una escala de color secuencial (ej. viridis o YlOrRd)

### UI
- `bslib::page_navbar()` con tema `bs_theme(bootswatch = "flatly")`
- KPIs con `bslib::value_box()`
- Layouts internos con `bslib::layout_sidebar()` y `bslib::layout_columns()`
- Todos los textos, etiquetas y mensajes en español
- Spinner de carga con `{shinycssloaders}` para los gráficos pesados

---

## Contexto metodológico (fuente: Manual AECA, enero 2026)

- Los datos provienen del **Sistema de Gestión de Seguridad Pública (SGSP)** del Ministerio del Interior, con cobertura nacional desde 2013.
- La tipificación de eventos puede ser policial (primaria) o judicial (prevalece sobre la policial). Cuando un evento combina múltiples delitos, se clasifica según el delito más grave.
- Los homicidios dolosos siguen un proceso de identificación manual caso a caso por AECA, por eso están en un archivo separado con variables adicionales.
- Un homicidio se considera **esclarecido** cuando al menos una persona fue imputada penalmente, o cuando el autor está plenamente identificado pero circunstancias fuera del control de las autoridades impiden su arresto (ej. suicidio posterior).
- La unidad de análisis en el CSV de delitos es el **evento**, no la víctima.
