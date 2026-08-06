# =============================================================================
# deploy.R — Publica/actualiza esta app en shinyapps.io
# Cuenta: emilianogonzalez   ·   App: Denuncias  (¡ojo: el nombre en shinyapps
#         es "Denuncias", no "criminalidad-uruguay"!)
# URL:    https://emilianogonzalez.shinyapps.io/Denuncias/
#
# NO contiene credenciales: usa la cuenta ya registrada en la máquina
# (rsconnect::setAccountInfo, guardada en la config local de rsconnect).
#
# IMPORTANTE: este deploy incluye el CSV de ~347 MB (data/delitos_...csv), que
# NO está en git. Debe existir localmente en data/ para poder desplegar.
#
# Uso:   Rscript deploy.R      (desde la raíz de este repo)
# =============================================================================
rsconnect::deployApp(
  appDir   = ".",
  appFiles = c(
    "app.R", "global.R",
    "R/mod_delitos.R", "R/mod_homicidios.R", "R/mod_comparativa.R",
    "data/homicidios_dolosos_consumados.xlsx",
    "data/delitos_2013_2025tri4.csv"
  ),
  appName        = "Denuncias",
  account        = "emilianogonzalez",
  forceUpdate    = TRUE,
  launch.browser = FALSE
)
