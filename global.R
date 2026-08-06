# ============================================================
# Carga de Librerías y Datos Globales
# ============================================================

# --- Instalar paquetes faltantes ---
required_pkgs <- c(
  "shiny", "bslib", "data.table", "dplyr", "dtplyr", "plotly",
  "DT", "readxl", "leaflet", "rnaturalearth", "rnaturalearthdata",
  "sf", "shinycssloaders", "viridisLite", "htmltools"
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
library(readxl)
library(leaflet)
library(rnaturalearth)
library(rnaturalearthdata)
library(rnaturalearthhires)
library(sf)
library(shinycssloaders)
library(viridisLite)
library(htmltools)

# ============================================================
# CARGA DE DATOS (una sola vez)
# ============================================================

# --- Delitos generales ---
csv_candidates <- list.files(
  path = "data",
  pattern = "delitos_2013_2025tri4.*\\.csv$",
  full.names = TRUE
)
if (length(csv_candidates) == 0) {
  stop("No se encontró el archivo CSV de delitos en el directorio de trabajo.")
}
csv_file <- csv_candidates[1]

# Cargar rápido con data.table minimizando memoria (Drop de columnas innecesarias)
delitos_dt <- fread(
  csv_file,
  sep = ";",
  encoding = "UTF-8",
  header = TRUE,
  drop = c(1, 3, 4, 6, 8, 9, 10, 14, 15)  # Drop: ID, VICT_RAP, VICT_HUR, FECHA, MES, SEMESTRE, TRIMESTRE, JURIS, BARRIO
)

# Convertir HORA a numérico (manejar "SIN DATO")
delitos_dt[, HORA_NUM := suppressWarnings(as.integer(HORA))]

# Normalizar nombres de columnas para evitar problemas de encoding con Ñ
normalize_colnames <- function(x) {
  x <- iconv(x, to = "UTF-8")
  x <- gsub("\u004E\u0303", "\u00D1", x) # N + combining tilde -> Ñ
  x <- gsub("\u006E\u0303", "\u00F1", x) # n + combining tilde -> ñ
  x
}
setnames(delitos_dt, normalize_colnames(names(delitos_dt)))
delitos_dt[, ANIO := as.integer(get(grep("A.*O$", names(delitos_dt), value = TRUE)[1]))]


# --- Homicidios ---
homicidios_dt <- as.data.table(read_excel("data/homicidios_dolosos_consumados.xlsx"))
setnames(homicidios_dt, normalize_colnames(names(homicidios_dt)))
homicidios_dt[, ANIO := as.integer(get(grep("A.*O$", names(homicidios_dt), value = TRUE)[1]))]
homicidios_dt[, EDADCALC := suppressWarnings(as.numeric(EDADCALC))]


# --- Datos para mapa ---
uruguay_sf <- ne_states(country = "Uruguay", returnclass = "sf")

normalize_depto <- function(x) {
  x <- toupper(trimws(x))
  x <- gsub("[ÁÀÂÄ]", "A", x)
  x <- gsub("[ÉÈÊË]", "E", x)
  x <- gsub("[ÍÌÎÏ]", "I", x)
  x <- gsub("[ÓÒÔÖ]", "O", x)
  x <- gsub("[ÚÙÛÜ]", "U", x)
  x <- gsub("[Ñ]", "N", x)
  x
}
uruguay_sf$depto_norm <- normalize_depto(uruguay_sf$name)


# ============================================================
# VARIABLES GLOBALES PARA FILTROS
# ============================================================
años_delitos <- sort(unique(delitos_dt$ANIO))
delito_tipos <- sort(unique(delitos_dt$DELITO))
deptos_delitos <- sort(unique(delitos_dt$DEPTO))

años_hom <- sort(unique(homicidios_dt$ANIO))
deptos_hom <- sort(unique(homicidios_dt$DEPARTAMENTO))
motivos_hom <- sort(unique(homicidios_dt$MOTIVO_APARENTE))
sexos_hom <- sort(unique(homicidios_dt$SEXO))
armas_hom <- sort(unique(homicidios_dt$ARMAREC))

# Orden de días de la semana
dias_orden <- c("LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO", "DOMINGO")

# Paleta de colores sobrios (Sola paleta en escala de azules)
colores_delito <- c(
  "HURTO" = "#1d4ed8",                  # Blue 700
  "RAPIÑA" = "#2563eb",                 # Blue 600
  "VIOLENCIA DOMÉSTICA" = "#3b82f6",    # Blue 500
  "LESIONES" = "#60a5fa",               # Blue 400
  "ABIGEATO" = "#93c5fd"                # Blue 300
)

# Configuración global para gráficamente hacer default un layout oscuro
plot_bg_color <- "transparent"
paper_bg_color <- "transparent"
font_color_dark <- "#94a3b8"
grid_color_dark <- "#334155"
