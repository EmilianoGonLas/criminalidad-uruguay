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
    # El título largo medía 454 px en una pantalla de 390 y empujaba la
    # página entera 164 px hacia la derecha. En celular se usa el corto.
    tags$span(class = "titulo-largo", "Estadísticas de Criminalidad — Uruguay (AECA)"),
    tags$span(class = "titulo-corto", "Criminalidad · Uruguay")
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

      /* ---------- Pantallas angostas ---------- */
      .titulo-corto { display: none; }
      .navbar-brand, .navbar-brand > span { white-space: normal; }

      @media (max-width: 767.98px) {
        .titulo-largo { display: none; }
        .titulo-corto { display: inline; }
        .navbar { padding: 0.5rem 0.75rem; }

        /* Las sub-pestañas se apilaban: seis ocupaban ~380 px, casi media
           pantalla, antes de mostrar nada. Ahora se deslizan de costado. */
        .nav-underline, .navset-card-underline .nav, .card .nav-tabs {
          flex-wrap: nowrap;
          overflow-x: auto;
          overflow-y: hidden;
          -webkit-overflow-scrolling: touch;
          scrollbar-width: none;
        }
        .nav-underline::-webkit-scrollbar { display: none; }
        .nav-underline .nav-link, .navset-card-underline .nav .nav-link {
          white-space: nowrap;
          padding-left: 0.6rem;
          padding-right: 0.6rem;
        }

        /* Objetivos táctiles: mínimo 44 px. */
        .navbar-toggler { min-width: 44px; min-height: 44px; padding: 0.4rem 0.6rem; }
        .bslib-sidebar-layout > .collapse-toggle {
          width: 44px !important; height: 44px !important;
        }
        .leaflet-control-zoom a {
          width: 40px !important; height: 40px !important; line-height: 40px !important;
          font-size: 1.3rem !important;
        }

        /* Mapas y gráficos con alto fijo ocupaban más de media pantalla. */
        .leaflet-container { height: 62vh !important; min-height: 320px; }
        .html-widget.plotly, .plotly.html-widget { height: 60vh !important; min-height: 300px; }

        /* La leyenda tapaba el 80% del ancho del mapa, justo sobre Montevideo. */
        .leaflet-control.info.legend, .leaflet-bottom.leaflet-right .info {
          font-size: 0.68rem; max-width: 44vw; padding: 5px 7px; line-height: 1.15;
        }
        .leaflet-control.info.legend i { width: 12px; height: 12px; }

        /* La barra de herramientas de plotly se montaba sobre el título. */
        .modebar { display: none !important; }

        .value-box { padding: 8px 12px; }
        .value-box-value { font-size: 1.35rem !important; }

        /* El título de la tarjeta le robaba la mitad del ancho a las
           sub-pestañas, que ya vienen justas. */
        .card-header.bslib-navs-card-title > span:not([class]) { display: none; }
        .card-header.bslib-navs-card-title { padding: 0.25rem 0.5rem; }

        /* El botón de filtros era una flecha sin texto: nadie adivina que
           ahí están los controles. */
        .bslib-sidebar-layout > .collapse-toggle::after {
          content: 'Filtros';
          font-size: 0.72rem;
          color: #94a3b8;
          display: block;
          margin-top: 1px;
          letter-spacing: 0.02em;
        }
        .bslib-sidebar-layout > .collapse-toggle {
          width: auto !important;
          min-width: 44px;
          height: 44px !important;
          display: flex !important;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 0 6px;
        }
      }
    ")),
    tags$script(HTML("
      // bslib emite el navbar con markup de Bootstrap 3 (.navbar-toggle, y el
      // navbar sin navbar-expand-*), pero el tema es Bootstrap 5, que estiliza
      // .navbar-toggler. Resultado en celular: el botón queda invisible y los
      // cuatro tabs miden 0x0, o sea que no se puede navegar a ninguna sección.
      function arreglarNavbar() {
        var nav = document.querySelector('.navbar');
        if (nav && !/navbar-expand/.test(nav.className)) {
          nav.classList.add('navbar-expand-lg');
        }
        var t = document.querySelector('.navbar-toggle, .navbar-toggler');
        if (t) {
          t.classList.remove('navbar-toggle');
          t.classList.add('navbar-toggler');
          t.setAttribute('aria-label', 'Abrir el menú de secciones');
          if (!t.querySelector('.navbar-toggler-icon')) {
            var i = document.createElement('span');
            i.className = 'navbar-toggler-icon';
            t.appendChild(i);
          }
        }
        // El botón que abre los filtros no decía qué hacía.
        document.querySelectorAll('.bslib-sidebar-layout > .collapse-toggle')
          .forEach(function (b) {
            b.setAttribute('aria-label', 'Mostrar u ocultar los filtros');
            b.setAttribute('title', 'Filtros');
          });
        // Elegir una sección cierra el menú desplegado.
        document.querySelectorAll('.navbar .nav-link').forEach(function (a) {
          a.addEventListener('click', function () {
            var c = document.querySelector('.navbar-collapse.show');
            if (c && window.bootstrap) {
              bootstrap.Collapse.getOrCreateInstance(c).hide();
            }
          });
        });
      }

      // El ancho llega al servidor para calcular márgenes y cuántas barras
      // mostrar. Se manda al conectar y en cada resize, con freno.
      function mandarAncho() {
        if (window.Shiny && Shiny.setInputValue) {
          Shiny.setInputValue('ancho_px', window.innerWidth, {priority: 'event'});
        }
      }
      $(document).on('shiny:connected', function () { arreglarNavbar(); mandarAncho(); });
      document.addEventListener('DOMContentLoaded', arreglarNavbar);
      var frenoResize;
      window.addEventListener('resize', function () {
        clearTimeout(frenoResize);
        frenoResize = setTimeout(mandarAncho, 250);
      });
    "))
  ),

  nav_panel(
    title = "Seccionales Policiales",
    icon = icon("map-location-dot"),
    mod_seccionales_ui("seccionales")
  ),

  nav_panel(
    title = "Delitos Generales",
    icon = icon("chart-line"),
    mod_delitos_ui("delitos")
  ),

  nav_panel(
    title = "Homicidios Dolosos",
    icon = icon("skull-crossbones"),
    mod_homicidios_ui("homicidios")
  ),

  nav_panel(
    title = "Comparativa Departamental",
    icon = icon("map"),
    mod_comparativa_ui("comparativa")
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
  ancho <- reactive(input$ancho_px)

  mod_delitos_server("delitos", ancho)
  mod_homicidios_server("homicidios", ancho)
  mod_comparativa_server("comparativa", ancho)
  mod_seccionales_server("seccionales", ancho)
  
}

# ============================================================
# EJECUTAR LA APP
# ============================================================
shinyApp(ui = ui, server = server)
