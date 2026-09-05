# =============================================================================
# deploy.R — Publica/actualiza esta app en shinyapps.io
# Cuenta: emilianogonzalez   ·   App: Denuncias  (¡ojo: el nombre en shinyapps
#         es "Denuncias", no "criminalidad-uruguay"!)
# URL:    https://emilianogonzalez.shinyapps.io/Denuncias/
#
# NO contiene credenciales: usa la cuenta ya registrada en la máquina
# (rsconnect::setAccountInfo, guardada en la config local de rsconnect).
#
# El bundle ya NO incluye el CSV crudo de 376 MB. La app lee los parquet de
# data/app/ (~20 MB en total), que conservan el detalle evento a evento.
# Si cambian los datos crudos, correr antes:
#
#   Rscript scripts/02_preparar_datos_app.R
#
# Uso:   Rscript scripts/deploy.R   (SIEMPRE desde la raíz del repo:
#        appDir = "." se resuelve contra el directorio de trabajo, no contra
#        la ubicación de este archivo)
# =============================================================================
rsconnect::deployApp(
  appDir   = ".",
  appFiles = c(
    "app.R", "global.R",
    "R/mod_delitos.R", "R/mod_homicidios.R", "R/mod_comparativa.R",
    "R/mod_seccionales.R",
    "data/app/eventos.parquet",
    "data/app/homicidios.parquet",
    "data/app/seccionales.rds",
    "data/app/departamentos.rds"
  ),
  appName        = "Denuncias",
  account        = "emilianogonzalez",
  forceUpdate    = TRUE,
  launch.browser = FALSE
)
