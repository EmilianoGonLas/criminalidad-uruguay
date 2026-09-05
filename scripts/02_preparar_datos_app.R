# Prepara los datos que carga la app.
#
# La app NO lee el CSV crudo de denuncias (376 MB). Lo convierte una vez a
# parquet, evento a evento y sin perder ninguna columna util: 2,5 M de filas
# entran en ~10 MB. Asi se conserva el maximo detalle (fecha exacta, hora,
# seccional, barrio) y el bundle de shinyapps.io queda chico.
#
# Entradas : data/otros-delitos.csv               (crudo, no versionado)
#            data/homicidios_dolosos_consumados.xlsx
#            data/seccionales_shp/SeccionalesPoliciales.shp
# Salidas  : data/app/*.parquet, data/app/*.rds

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(arrow); library(sf)
  library(stringi); library(readxl)
})

DATA <- "data"; APP <- file.path(DATA, "app")
dir.create(APP, showWarnings = FALSE, recursive = TRUE)

norm <- function(x) stri_trans_general(toupper(trimws(x)), "Latin-ASCII")

# El shapefile oficial escribe mal Tacuarembo. Sin corregirlo el departamento
# entero queda sin cruzar: unos 45.000 eventos, y el mapa lo dibuja vacio sin
# dar ningun error.
FIX_DEPTO <- c("TACUEREMBO" = "TACUAREMBO")

# --- geometria -------------------------------------------------------------
geo <- st_read(file.path(DATA, "seccionales_shp/SeccionalesPoliciales.shp"), quiet = TRUE)
geo$DEPARTAMEN <- dplyr::recode(geo$DEPARTAMEN, !!!FIX_DEPTO)

geo <- geo |>
  mutate(sec_id  = paste0(DEPARTAMEN, "|", SECCION),
         depto   = DEPARTAMEN,
         seccion = as.integer(SECCION),
         nombre  = NOMBRE_1) |>
  select(sec_id, depto, seccion, nombre) |>
  st_make_valid() |>
  st_transform(4326)

stopifnot(nrow(geo) == 280, !any(st_is_empty(geo)), all(st_is_valid(geo)))
saveRDS(geo, file.path(APP, "seccionales_full.rds"), compress = "xz")

# Version para dibujar: 25 m de tolerancia es invisible a cualquier zoom que
# muestre el navegador, y evita mandarle ~20 MB de GeoJSON al cliente.
geo_web <- geo |>
  st_transform(32721) |>
  st_simplify(dTolerance = 25, preserveTopology = TRUE) |>
  st_transform(4326)
saveRDS(geo_web, file.path(APP, "seccionales.rds"), compress = "xz")

# Departamentos: se disuelven de las seccionales, asi la app no depende de
# rnaturalearth (rnaturalearthhires no esta en CRAN y rompe el deploy).
deptos <- geo |> group_by(depto) |> summarise(.groups = "drop") |> st_make_valid()
saveRDS(deptos, file.path(APP, "departamentos.rds"), compress = "xz")

# --- denuncias, evento a evento --------------------------------------------
crudo <- file.path(DATA, "otros-delitos.csv")
d <- read_delim(crudo, delim = ";", locale = locale(encoding = "UTF-8"),
                col_types = cols(.default = col_character()), progress = FALSE)

ev <- d |>
  mutate(
    depto  = norm(DEPTO),
    secnum = stri_match_first_regex(JURISDICCION, "SECCIONAL\\s+(\\d+)")[, 2],
    sec_id = ifelse(is.na(secnum), NA_character_, paste0(depto, "|", secnum)),
    fecha  = as.Date(FECHA, format = "%d.%m.%Y"),
    # "SIN DATO" -> NA a proposito: el hurto no registra hora en el 88% de los
    # casos y el abigeato en el 100%. Rapina, lesiones y violencia domestica
    # la tienen siempre; el heatmap dia x hora solo aplica a esas tres.
    hora   = suppressWarnings(as.integer(HORA)),
    # BARRIO_MONTEVIDEO trae "NO CORRESPONDE" en los 1,3 M de denuncias que
    # no son de Montevideo. No es un barrio: es la marca de "aca no aplica".
    # Si se deja, encabeza cualquier ranking de barrios y aplasta al resto.
    barrio_limpio = ifelse(BARRIO_MONTEVIDEO == "NO CORRESPONDE",
                           NA_character_, BARRIO_MONTEVIDEO)
  ) |>
  transmute(
    fecha, anio = as.integer(format(fecha, "%Y")),
    delito = as.factor(DELITO), tentativa = as.factor(TENTATIVA),
    depto = as.factor(depto), sec_id = as.factor(sec_id),
    jurisdiccion = as.factor(JURISDICCION), barrio = as.factor(barrio_limpio),
    dia_semana = as.factor(DIA_SEMANA), hora,
    vict_rap = as.factor(VICT_RAP), vict_hur = as.factor(VICT_HUR)
  )

sin_poly <- sum(!ev$sec_id %in% geo$sec_id)
cat(sprintf("eventos: %s | sin poligono: %s (%.2f%%)\n",
            format(nrow(ev), big.mark = "."), format(sin_poly, big.mark = "."),
            100 * sin_poly / nrow(ev)))
cat("periodo:", format(min(ev$fecha, na.rm = TRUE)), "a",
    format(max(ev$fecha, na.rm = TRUE)), "\n")

write_parquet(ev, file.path(APP, "eventos.parquet"),
              compression = "zstd", compression_level = 9)

# --- homicidios ------------------------------------------------------------
h <- read_excel(file.path(DATA, "homicidios_dolosos_consumados.xlsx"))
names(h) <- tolower(names(h))
# La columna del anio viene con enie ("ano" con tilde); se renombra a mano para
# no depender del encoding del locale.
names(h)[grepl("^a.o$", names(h))] <- "anio"
h <- h |>
  mutate(depto  = norm(departamento),
         secnum = stri_match_first_regex(jurisdiccion, "SECCIONAL\\s+(\\d+)")[, 2],
         sec_id = ifelse(is.na(secnum), NA_character_, paste0(depto, "|", secnum)),
         anio   = as.integer(anio),
         edadcalc = suppressWarnings(as.numeric(edadcalc)))
write_parquet(h, file.path(APP, "homicidios.parquet"), compression = "zstd")
cat("homicidios:", nrow(h), "| hasta", max(h$anio, na.rm = TRUE), "\n")

info <- file.info(list.files(APP, full.names = TRUE))
cat("\n"); cat(sprintf("%-24s %7.2f MB\n", basename(rownames(info)), info$size / 1e6), sep = "")
cat(sprintf("%-24s %7.2f MB\n", "TOTAL", sum(info$size) / 1e6))
