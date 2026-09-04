# ============================================================
# Carga de librerías y datos globales
# ============================================================
#
# Los datos llegan pre-convertidos por scripts/02_preparar_datos_app.R:
# el CSV crudo de denuncias (376 MB) se guarda como parquet evento a evento
# (~13 MB) sin perder ninguna columna. La app conserva el detalle completo
# —fecha exacta, hora, seccional policial, barrio— y arranca en segundos.

required_pkgs <- c(
  "shiny", "bslib", "data.table", "dplyr", "dtplyr", "plotly",
  "DT", "arrow", "leaflet", "sf", "shinycssloaders", "viridisLite", "htmltools"
)
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cran.r-project.org")
  }
}

library(shiny)
library(bslib)
library(data.table)
library(dplyr)
library(dtplyr)
library(plotly)
library(DT)
library(arrow)
library(leaflet)
library(sf)
library(shinycssloaders)
library(viridisLite)
library(htmltools)

APP_DATA <- "data/app"

# ============================================================
# DATOS
# ============================================================

# --- Denuncias, evento a evento --------------------------------------------
# Se mantienen los nombres en mayúscula que ya usaban los módulos y se agregan
# en minúscula las columnas nuevas (sec_id, barrio, fecha).
delitos_dt <- as.data.table(read_parquet(file.path(APP_DATA, "eventos.parquet")))
setnames(delitos_dt,
         old = c("delito", "tentativa", "depto", "dia_semana"),
         new = c("DELITO", "TENTATIVA", "DEPTO", "DIA_SEMANA"))
delitos_dt[, ANIO := anio]
delitos_dt[, HORA_NUM := hora]
setkey(delitos_dt, ANIO, DEPTO, DELITO)

# --- Homicidios ------------------------------------------------------------
homicidios_dt <- as.data.table(read_parquet(file.path(APP_DATA, "homicidios.parquet")))
setnames(homicidios_dt, toupper(names(homicidios_dt)))
setnames(homicidios_dt, "SEC_ID", "sec_id")
homicidios_dt[, EDADCALC := suppressWarnings(as.numeric(EDADCALC))]

# --- Geografía -------------------------------------------------------------
# Las 280 seccionales policiales. `seccionales_sf` va simplificada a 25 m para
# dibujar; `seccionales_full.rds` guarda la geometría sin tocar, por si hace
# falta para un cálculo de área o una descarga.
seccionales_sf <- readRDS(file.path(APP_DATA, "seccionales.rds"))

# Los departamentos se disuelven de las seccionales, así la app no depende de
# rnaturalearth (rnaturalearthhires no está en CRAN y rompe el deploy).
uruguay_sf <- readRDS(file.path(APP_DATA, "departamentos.rds"))
uruguay_sf$depto_norm <- uruguay_sf$depto
uruguay_sf$name <- uruguay_sf$depto

normalize_depto <- function(x) {
  x <- toupper(trimws(x))
  x <- gsub("[ÁÀÂÄ]", "A", x); x <- gsub("[ÉÈÊË]", "E", x)
  x <- gsub("[ÍÌÎÏ]", "I", x); x <- gsub("[ÓÒÔÖ]", "O", x)
  x <- gsub("[ÚÙÛÜ]", "U", x); x <- gsub("[Ñ]", "N", x)
  x
}

# Nombre legible de cada seccional, para tablas y popups.
sec_label <- setNames(
  sprintf("%s — Seccional %d%s", seccionales_sf$depto, seccionales_sf$seccion,
          ifelse(is.na(seccionales_sf$nombre) | seccionales_sf$nombre == "", "",
                 paste0(" (", seccionales_sf$nombre, ")"))),
  seccionales_sf$sec_id
)

# ============================================================
# VARIABLES GLOBALES PARA FILTROS
# ============================================================
años_delitos   <- sort(unique(delitos_dt$ANIO))
delito_tipos   <- sort(unique(as.character(delitos_dt$DELITO)))
deptos_delitos <- sort(unique(as.character(delitos_dt$DEPTO)))

años_hom    <- sort(unique(homicidios_dt$ANIO))
deptos_hom  <- sort(unique(homicidios_dt$DEPARTAMENTO))
motivos_hom <- sort(unique(homicidios_dt$MOTIVO_APARENTE))
sexos_hom   <- sort(unique(homicidios_dt$SEXO))
armas_hom   <- sort(unique(homicidios_dt$ARMAREC))

dias_orden <- c("LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO", "DOMINGO")

# Delitos que registran hora. El hurto no la trae en el 88% de los casos y el
# abigeato en el 100%: se descubren después y la víctima no sabe cuándo pasó.
# Un heatmap día × hora sobre esos dos sería engañoso.
delitos_con_hora <- c("RAPIÑA", "LESIONES", "VIOLENCIA DOMÉSTICA")

# El último año del panel suele estar incompleto: se avisa en la interfaz.
fecha_max <- max(delitos_dt$fecha, na.rm = TRUE)
anio_max <- max(años_delitos)
anio_incompleto <- as.integer(format(fecha_max, "%m")) < 12

colores_delito <- c(
  "HURTO" = "#1d4ed8", "RAPIÑA" = "#2563eb",
  "VIOLENCIA DOMÉSTICA" = "#3b82f6", "LESIONES" = "#60a5fa",
  "ABIGEATO" = "#93c5fd"
)

plot_bg_color   <- "transparent"
paper_bg_color  <- "transparent"
font_color_dark <- "#94a3b8"
grid_color_dark <- "#334155"
