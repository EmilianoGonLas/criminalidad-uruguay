# Población por departamento, para poder calcular tasas.
#
# Sin denominador, cualquier mapa departamental de delito es un mapa de dónde
# vive la gente: Montevideo tiene 40.000 denuncias al año y Flores 1.000, y no
# porque Flores sea 40 veces más segura. La fuente del Ministerio del Interior
# no publica población, así que sale del Censo 2023 del INE.
#
# Se usa el ponderador W del microdato, que es lo que expande la muestra
# efectivamente censada a la población estimada. Da 3.499.451 personas para el
# total del país.
#
# Entrada : microdato del Censo 2023 (fuera de este repo, ver CENSO abajo)
# Salida  : data/poblacion_departamento.csv   (19 filas, versionado)

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(stringi)
})

CENSO  <- "/mnt/Mec/Claude/censo/censo_app/datos/personas_slim.parquet"
NOMBRE <- "/mnt/Mec/Claude/censo/censo_app/datos/departamentos.csv"
SALIDA <- "data/poblacion_departamento.csv"

if (!file.exists(CENSO)) {
  stop("Falta el microdato del Censo 2023. La salida ya está versionada en ",
       SALIDA, ": este script sólo hace falta para reconstruirla.")
}

norm <- function(x) stri_trans_general(toupper(trimws(x)), "Latin-ASCII")

personas <- as.data.table(read_parquet(CENSO, col_select = c("DEPARTAMENTO", "W")))
nombres  <- fread(NOMBRE, colClasses = c(DPTO_CODIGO = "character"))

pob <- personas[, .(poblacion = round(sum(W, na.rm = TRUE))), by = DEPARTAMENTO]
pob <- merge(pob, nombres, by.x = "DEPARTAMENTO", by.y = "DPTO_CODIGO", all.x = TRUE)
pob[, depto := norm(DPTO_NOMBRE)]
pob <- pob[, .(depto, poblacion)][order(-poblacion)]

stopifnot(nrow(pob) == 19, !any(is.na(pob$depto)), all(pob$poblacion > 0))
cat("total país:", format(sum(pob$poblacion), big.mark = "."), "\n")
print(head(pob, 5))

fwrite(pob, SALIDA)
cat("\nescrito:", SALIDA, "\n")
