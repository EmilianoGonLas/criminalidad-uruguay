# criminalidad-uruguay

App Shiny para analizar **estadísticas de criminalidad en Uruguay** con datos
oficiales del **Ministerio del Interior (AECA)** — Sistema de Gestión de
Seguridad Pública (SGSP), cobertura nacional desde 2013.

🔗 **App en vivo:** https://emilianogonzalez.shinyapps.io/Denuncias/

![Captura de la app](captura.png)

## Secciones

1. **Delitos generales** — evolución anual por tipo de delito (hurto, rapiña,
   violencia doméstica, lesiones, abigeato), ranking departamental, heatmap
   día×hora, tabla agregada. Filtros por año, tipo, departamento y tentativa.
2. **Homicidios dolosos** — evolución + tasa de esclarecimiento, distribución por
   motivo / arma / edad / relación víctima-agresor. Filtros por año, depto,
   motivo, sexo y arma.
3. **Comparativa departamental** — mapa coroplético y ranking por indicador.
4. **Seccionales policiales** — el nivel geográfico más fino que publica la
   fuente: 280 seccionales contra 19 departamentos. Mapa con escala por
   cuantiles, ranking, evolución mensual, heatmap día×hora, barrios de
   Montevideo y tabla descargable.

UI con `bslib` (`page_navbar`, tema oscuro), gráficos `plotly`, tablas `DT`,
mapas `leaflet`.

## Los datos: por qué la app no lee el CSV crudo

El CSV de denuncias pesa **376 MB** (2,5 M de eventos). Cargarlo en cada arranque
era lento y obligaba a subirlo entero a shinyapps.io.

`scripts/02_preparar_datos_app.R` lo convierte una sola vez a parquet **evento a
evento, sin perder ninguna columna**: 2,5 M de filas entran en 13 MB. Se conserva
el detalle completo —fecha exacta, hora, seccional policial, barrio— y el bundle
del deploy baja a ~20 MB.

| | Crudo | En `data/app/` |
|---|---|---|
| Denuncias | 376 MB · 2,5 M eventos | 12,8 MB (parquet) |
| Homicidios | 430 KB (xlsx) | 0,09 MB |
| Seccionales | 9,2 MB (shapefile) | 1,10 MB (simplificado a 25 m) |
| Departamentos | — | 1,37 MB (disueltos de las seccionales) |

En memoria son unos 150 MB, holgado para el plan de shinyapps.io.

Los departamentos se disuelven del propio shapefile de seccionales, así la app
ya no depende de `rnaturalearth` — `rnaturalearthhires` no está en CRAN y era un
riesgo de deploy.

## Dos trampas de la fuente

**1. `JURISDICCION` no identifica una seccional.** Tiene sólo 33 valores
distintos para 280 seccionales: `SECCIONAL 10` existe en casi todos los
departamentos. La clave real es departamento + número (`sec_id`, como
`ARTIGAS|1`).

**2. El shapefile oficial escribe `TACUEREMBO`.** Sin corregirlo, Tacuarembó
entero queda sin cruzar —unos 45.000 eventos— y el mapa lo dibuja vacío sin dar
ningún error.

Corregidas las dos, cruza el **99,62%** de los eventos y las 280 seccionales
tienen datos. El 0,38% restante es jurisdicción no territorial (Prefectura,
Policía Marítima, Sin Clasificar): no tiene polígono ni debería tenerlo.

## Una advertencia sobre la hora

La hora falta en el 55% de las denuncias, pero **no al azar**:

| Delito | Sin hora |
|---|---|
| Rapiña · Lesiones · Violencia doméstica | 0% |
| Hurto | 87,9% |
| Abigeato | 100% |

Es estructural: al hurto se lo descubre después y la víctima no sabe cuándo
ocurrió. Los dos heatmaps de la app lo dicen explícitamente, y el de la pestaña
de seccionales directamente excluye hurto y abigeato.

## Otras advertencias

- **Son conteos, no tasas.** La fuente no publica población por seccional, así
  que no hay denominador. A nivel departamento sí se podría con el censo.
- **El último año está incompleto.** Los datos llegan al último trimestre
  cerrado; la app lo avisa en la barra lateral.
- **El barrio sólo existe para Montevideo.**

## Datos (`data/`)

| Archivo | Versionado |
|---|---|
| `app/*.parquet`, `app/*.rds` | sí — es lo que despliega la app |
| `homicidios_dolosos_consumados.xlsx` | sí |
| `seccionales_shp/` (shapefile) | sí (el KML y el .rar, no) |
| `otros-delitos.csv` (376 MB) | **no** — ver abajo |

El crudo se baja del [catálogo de datos abiertos](https://catalogodatos.gub.uy/dataset/ministerio-del-interior-delitos_denunciados_en_el_uruguay),
recurso *Denuncias de otros delitos (CSV)*, y se deja en `data/otros-delitos.csv`.
Va separado por `;` con BOM UTF-8. El dataset se actualiza **trimestralmente**.

Cobertura actual: denuncias hasta el **30/06/2026**, homicidios hasta **2026**.

## Correr y desplegar

```r
shiny::runApp()     # desde la raíz del proyecto
```

```bash
Rscript scripts/02_preparar_datos_app.R   # sólo si cambiaron los datos crudos
Rscript deploy.R                          # publica en shinyapps.io
```

## Estructura

```
app.R                  UI + server (navbar de 4 secciones)
global.R               carga los parquet y la geometría al iniciar
R/                     módulos: delitos, homicidios, comparativa, seccionales
scripts/               02_preparar_datos_app.R — crudo → parquet
data/app/              lo que carga y despliega la app
data/seccionales_shp/  shapefile oficial (EPSG:32721)
qgis/                  proyecto QGIS con el shape y el KML
docs/                  especificación + PDF de seccionales de Montevideo
```
