# ============================================================
# Shiny App — Estadísticas de Criminalidad Uruguay (AECA)
# Archivo Principal (Entry Point)
# ============================================================

# 1. Cargar dependencias y datos globales
source("global.R", encoding = "UTF-8")

# 2. Cargar los módulos (UI y Server)
source("R/mod_delitos.R", encoding = "UTF-8")
source("R/mod_homicidios.R", encoding = "UTF-8")
source("R/mod_comparativa.R", encoding = "UTF-8")
source("R/mod_seccionales.R", encoding = "UTF-8")

# ============================================================
# INTERFAZ DE USUARIO PRINCIPAL
# ============================================================

ui <- page_navbar(
  title = tags$span(
    tags$i(class = "fas fa-shield-alt", style = "margin-right: 8px;"),
    "Estadísticas de Criminalidad — Uruguay (AECA)"
  ),
  theme = bs_theme(
    version = 5,
    bg = "#0f172a",          # Base Slate 900
    fg = "#e2e8f0",          # Text Slate 200
    primary = "#1e293b",     # Primary (Cards/Backgrounds)
    secondary = "#64748b",   # Slate 500
    base_font = font_google("Roboto"),
    heading_font = font_google("Roboto")
  ),
  header = tags$head(
    tags$link(
      rel = "stylesheet",
      href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"
    ),
    tags$style(HTML("
      /* Minimalismo Oscuro (Slate) */
      body { font-family: 'Roboto', sans-serif; background-color: #0f172a; color: #e2e8f0; }
      .navbar { background-color: #0f172a !important; border-bottom: 1px solid #1e293b; padding: 1rem; }
      .sidebar { background-color: #0f172a !important; border-right: 1px solid #1e293b; }
      
      /* Cards limpias y sin distracciones */
      .card { 
        background-color: #1e293b !important; 
        border: 1px solid #334155; 
        border-radius: 6px;
        box-shadow: none;
        margin-bottom: 15px; 
      }
      .card-header { background-color: #1e293b !important; color: #cbd5e1; border-bottom: 1px solid #334155; font-weight: 500; }
      
      /* Value Boxes Estrictas (Tamaño Reducido) */
      .value-box { 
        margin-bottom: 15px; 
        border-radius: 6px;
        background-color: #1e293b !important;
        border: 1px solid #334155 !important;
        color: #e2e8f0 !important;
        padding: 10px 15px;
      }
      .value-box-title {
        font-size: 0.85rem !important;
        color: #94a3b8 !important;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-bottom: 5px;
      }
      .value-box-value {
        font-size: 1.6rem !important;
        font-weight: 600;
      }
      .value-box-showcase {
        opacity: 0.2;
      }
      
      /* Pestañas (Nav Underline) */
      .nav-underline { margin-bottom: 20px; border-bottom: 1px solid #334155; }
      .nav-underline .nav-link { color: #94a3b8; font-size: 0.95rem; }
      .nav-underline .nav-link:hover { color: #e2e8f0; }
      .nav-underline .nav-link.active { 
        color: #3b82f6; 
        font-weight: 500; 
        border-bottom-color: #3b82f6; 
      }
      
      /* DataTables dark mode override */
      table.dataTable tbody tr { background-color: transparent !important; }
      .dataTables_wrapper .dataTables_length, .dataTables_wrapper .dataTables_filter, .dataTables_wrapper .dataTables_info, .dataTables_wrapper .dataTables_processing, .dataTables_wrapper .dataTables_paginate { color: #94a3b8 !important; font-size: 0.85rem; }
      table.dataTable { font-size: 0.85rem; }
    "))
  ),

  # Pestaña Principal 1
  nav_panel(
    title = "Delitos Generales",
    icon = icon("chart-line"),
    mod_delitos_ui("delitos")
  ),

  # Pestaña Principal 2
  nav_panel(
    title = "Homicidios Dolosos",
    icon = icon("skull-crossbones"),
    mod_homicidios_ui("homicidios")
  ),

  # Pestaña Principal 3
  nav_panel(
    title = "Comparativa Departamental",
    icon = icon("map"),
    mod_comparativa_ui("comparativa")
  ),

  # Pestaña Principal 4 — el nivel geográfico más fino de la fuente
  nav_panel(
    title = "Seccionales Policiales",
    icon = icon("map-location-dot"),
    mod_seccionales_ui("seccionales")
  ),

  # Espacio y Footer
  nav_spacer(),
  nav_item(
    tags$span(
      style = "color: #95a5a6; font-size: 0.85em; display: flex; align-items: center; height: 100%; padding-right: 15px;",
      "Fuente: Ministerio del Interior — AECA"
    )
  )
)

# ============================================================
# LÓGICA DEL SERVIDOR (Llamando módulos)
# ============================================================

server <- function(input, output, session) {
  
  # Inicializar cada módulo con su namespace correspondiente
  mod_delitos_server("delitos")
  mod_homicidios_server("homicidios")
  mod_comparativa_server("comparativa")
  mod_seccionales_server("seccionales")
  
}

# ============================================================
# EJECUTAR LA APP
# ============================================================
shinyApp(ui = ui, server = server)
