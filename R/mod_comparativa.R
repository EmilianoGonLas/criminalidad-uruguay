# ============================================================
# Módulo: Comparativa Departamental
# ============================================================
# El problema de este nivel es el denominador. En cantidades absolutas
# Montevideo encabeza siempre —concentra el 37% de la población— y el mapa
# termina mostrando dónde vive la gente, no dónde hay delito. Acá la medida
# por defecto es la tasa cada 100.000 habitantes, con población del Censo 2023.

mod_comparativa_ui <- function(id) {
  ns <- NS(id)

  layout_sidebar(
    sidebar = sidebar(
      title = "Filtros",
      width = 320,

      radioButtons(ns("medida"), "Medida:",
                   choices = c("Tasa cada 100.000 habitantes" = "tasa",
                               "Cantidad de denuncias" = "cantidad"),
                   selected = "tasa"),

      sliderInput(ns("periodo"), "Período:",
                  min = min(años_delitos), max = ANIO_COMPLETO,
                  value = c(ANIO_COMPLETO, ANIO_COMPLETO),
                  step = 1, sep = "", ticks = FALSE),

      checkboxGroupInput(ns("delitos"), "Delitos:",
                         choices = delitos_comparables,
                         selected = setdiff(delitos_comparables, ETIQUETA_HOMICIDIOS)),

      hr(),
      div(style = "font-size:0.78rem; color:#94a3b8; line-height:1.45;",
          tags$b("Por qué tasas"), tags$br(),
          "En cantidades, Montevideo encabeza cualquier ranking porque ",
          "concentra el 37% de la población. La tasa deja comparar ",
          "departamentos de tamaños muy distintos.", tags$br(), tags$br(),
          "Población: Censo 2023 (INE), ",
          format(POBLACION_PAIS, big.mark = "."), " personas.", tags$br(),
          sprintf("El período llega hasta %d, el último año completo.", ANIO_COMPLETO))
    ),

    navset_card_underline(
      title = "Comparación entre departamentos",

      nav_panel("Mapa", icon = icon("map"),
                withSpinner(leafletOutput(ns("mapa"), height = "620px"), type = 4)),

      nav_panel("Ranking", icon = icon("chart-bar"),
                withSpinner(plotlyOutput(ns("ranking"), height = "620px"), type = 4)),

      nav_panel("Evolución", icon = icon("chart-line"),
                div(style = "font-size:0.82rem; color:#94a3b8; margin-bottom:10px;",
                    "Cada línea es un departamento; la blanca gruesa es el total ",
                    "del país. Esta vista muestra siempre la serie completa: ",
                    "el período elegido en el panel queda sombreado."),
                withSpinner(plotlyOutput(ns("evolucion"), height = "580px"), type = 4)),

      nav_panel("Composición", icon = icon("layer-group"),
                div(style = "font-size:0.82rem; color:#94a3b8; margin-bottom:10px;",
                    "Qué peso tiene cada delito dentro de cada departamento. ",
                    "Al ser porcentajes, el tamaño del departamento no influye: ",
                    "es la comparación más limpia que permite este nivel."),
                withSpinner(plotlyOutput(ns("composicion"), height = "580px"), type = 4)),

      nav_panel("Tabla", icon = icon("table"),
                div(style = "margin-bottom:10px;",
                    downloadButton(ns("bajar"), "Descargar CSV", class = "btn-sm")),
                withSpinner(DTOutput(ns("tabla")), type = 4))
    )
  )
}

mod_comparativa_server <- function(id, ancho = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {

    fmt <- function(x) {
      if (all(x == round(x))) format(round(x), big.mark = ".")
      else formatC(x, format = "f", digits = 1, big.mark = ".", decimal.mark = ",")
    }

    # --- conteos por departamento, delito y año ----------------------------
    # Los homicidios viven en otra tabla; se traen con la misma forma para
    # poder tratarlos como un delito más.
    conteos <- reactive({
      req(input$delitos, input$periodo)
      p <- input$periodo
      base <- data.table(depto = character(), delito = character(),
                         anio = integer(), n = integer())

      denuncias <- setdiff(input$delitos, ETIQUETA_HOMICIDIOS)
      if (length(denuncias)) {
        base <- rbind(base, delitos_dt[
          ANIO >= p[1] & ANIO <= p[2] & DELITO %in% denuncias,
          .(n = .N), by = .(depto = as.character(DEPTO),
                            delito = as.character(DELITO), anio = ANIO)])
      }
      if (ETIQUETA_HOMICIDIOS %in% input$delitos) {
        # La etiqueta se agrega después: data.table no acepta una constante
        # mezclada con columnas en el `by`.
        h <- homicidios_dt[ANIO >= p[1] & ANIO <= p[2],
                           .(n = .N), by = .(depto = as.character(DEPTO), anio = ANIO)]
        h[, delito := ETIQUETA_HOMICIDIOS]
        base <- rbind(base, h[, .(depto, delito, anio, n)])
      }
      base
    })

    # Años del período, para pasar de total a promedio anual: sin esto un rango
    # de cinco años daría una tasa cinco veces más alta que uno de un año.
    n_anios <- reactive(diff(input$periodo) + 1)
    es_tasa <- reactive(input$medida == "tasa")
    nombre_medida <- reactive(if (es_tasa()) "Tasa cada 100.000" else "Denuncias")
    periodo_txt <- reactive({
      p <- input$periodo
      if (p[1] == p[2]) as.character(p[1]) else paste0(p[1], "–", p[2])
    })

    por_depto <- reactive({
      d <- conteos()[, .(n = sum(n)), by = depto]
      d <- merge(poblacion_dt, d, by = "depto", all.x = TRUE)
      d[is.na(n), n := 0]
      d[, tasa := 1e5 * (n / n_anios()) / poblacion]
      d[, valor := if (es_tasa()) tasa else n]
      d[order(-valor)]
    })

    tasa_pais <- reactive(1e5 * (sum(conteos()$n) / n_anios()) / POBLACION_PAIS)

    # --- mapa ---------------------------------------------------------------
    output$mapa <- renderLeaflet({
      d <- por_depto()
      geo <- merge(uruguay_sf, d, by = "depto", all.x = TRUE)
      geo$valor[is.na(geo$valor)] <- 0

      # Escala por cuantiles: con la lineal que había antes, Montevideo se
      # llevaba todo el rango y los otros 18 departamentos quedaban en un único
      # tono pálido, indistinguibles entre sí.
      cortes <- unique(quantile(geo$valor, probs = seq(0, 1, 0.2), na.rm = TRUE))
      pal <- if (length(cortes) > 2) {
        colorBin("YlOrRd", domain = geo$valor, bins = cortes, pretty = FALSE)
      } else {
        colorNumeric("YlOrRd", domain = geo$valor)
      }
      bb <- as.numeric(sf::st_bbox(uruguay_sf))

      leaflet(geo) |>
        agregar_mapa_base() |>
        fitBounds(bb[1], bb[2], bb[3], bb[4]) |>
        addPolygons(
          fillColor = ~pal(valor), fillOpacity = 0.8,
          weight = 1, color = "#94a3b8", opacity = 0.9,
          label = ~lapply(sprintf(
            "<b>%s</b><br>%s cada 100.000<br>%s denuncias<br>%s habitantes<br><i>%s</i>",
            depto, fmt(tasa), fmt(n), format(poblacion, big.mark = "."),
            periodo_txt()), htmltools::HTML),
          highlightOptions = highlightOptions(weight = 3, color = "#f8fafc",
                                              fillOpacity = 0.95, bringToFront = TRUE)
        ) |>
        # digits = 0: la tasa viene con decimales y el separador de miles la
        # volvia ilegible (2506.027 se leia como dos millones y medio).
        addLegend(pal = pal, values = ~valor, position = "bottomleft",
                  title = paste0(nombre_medida(), "<br>", periodo_txt()),
                  opacity = 0.85,
                  labFormat = labelFormat(digits = 0, big.mark = "."))
    })

    # --- ranking ------------------------------------------------------------
    output$ranking <- renderPlotly({
      d <- por_depto()
      if (nrow(d) == 0) return(plotly_empty())
      d <- d[order(valor)]
      d[, depto := factor(depto, levels = depto)]

      p <- plot_ly(d, y = ~depto, x = ~valor, type = "bar", orientation = "h",
                   marker = list(color = "#3b82f6"),
                   customdata = ~paste0(fmt(n), " denuncias · ",
                                        format(poblacion, big.mark = "."), " hab."),
                   hovertemplate = "<b>%{y}</b><br>%{x:,.1f}<br>%{customdata}<extra></extra>") |>
        layout(title = list(text = paste(nombre_medida(), "·", periodo_txt()),
                            x = 0, xanchor = "left"),
               xaxis = list(title = nombre_medida(), separatethousands = TRUE,
                            gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
               yaxis = list(title = "", gridcolor = "transparent"),
               margin = list(l = margen_eje(ancho(), 140)),
               showlegend = FALSE,
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))

      # La referencia nacional es lo que convierte un ranking en una lectura:
      # sin ella no se sabe quién está por encima del país y quién por debajo.
      # Va como shape y no como serie: el eje Y es categórico y plotly no
      # mezcla datos discretos con continuos en el mismo eje.
      if (es_tasa()) {
        p <- p |> layout(
          shapes = list(list(type = "line", xref = "x", yref = "paper",
                             x0 = tasa_pais(), x1 = tasa_pais(), y0 = 0, y1 = 1,
                             line = list(color = "#f8fafc", width = 1.5, dash = "dot"))),
          annotations = list(list(x = tasa_pais(), y = 1, xref = "x", yref = "paper",
                                  text = paste0("país ", fmt(tasa_pais())),
                                  showarrow = FALSE, xanchor = "left", yanchor = "bottom",
                                  font = list(color = "#cbd5e1", size = 11))))
      }
      p
    })

    # --- evolución ----------------------------------------------------------
    # Esta vista NO usa el rango del período para el eje X: con el valor por
    # defecto (un solo año) cada departamento tenía un único punto y una línea
    # de un punto no dibuja nada, así que el panel salía vacío. Muestra
    # siempre la serie completa y sombrea el período elegido.
    conteos_todos <- reactive({
      req(input$delitos)
      base <- data.table(depto = character(), anio = integer(), n = integer())
      denuncias <- setdiff(input$delitos, ETIQUETA_HOMICIDIOS)
      if (length(denuncias)) {
        base <- rbind(base, delitos_dt[
          ANIO <= ANIO_COMPLETO & DELITO %in% denuncias,
          .(n = .N), by = .(depto = as.character(DEPTO), anio = ANIO)])
      }
      if (ETIQUETA_HOMICIDIOS %in% input$delitos) {
        base <- rbind(base, homicidios_dt[
          ANIO <= ANIO_COMPLETO,
          .(n = .N), by = .(depto = as.character(DEPTO), anio = ANIO)])
      }
      base[, .(n = sum(n)), by = .(depto, anio)]
    })

    output$evolucion <- renderPlotly({
      d <- conteos_todos()
      if (nrow(d) == 0) return(plotly_empty())
      d <- merge(d, poblacion_dt, by = "depto")
      d[, valor := if (es_tasa()) 1e5 * n / poblacion else n]
      setorder(d, depto, anio)

      pais <- d[, .(n = sum(n)), by = anio][order(anio)]
      pais[, valor := if (es_tasa()) 1e5 * n / POBLACION_PAIS else n]

      plot_ly() |>
        add_trace(data = d, x = ~anio, y = ~valor, color = ~depto,
                  colors = viridisLite::viridis(19, option = "turbo"),
                  type = "scatter", mode = "lines+markers",
                  line = list(width = 1.6), marker = list(size = 4), opacity = 0.85,
                  hovertemplate = "%{x}<br>%{y:,.1f}<extra>%{fullData.name}</extra>") |>
        add_trace(data = pais, x = ~anio, y = ~valor, name = "TOTAL PAÍS",
                  type = "scatter", mode = "lines+markers",
                  line = list(color = "#f8fafc", width = 3.5),
                  marker = list(color = "#f8fafc", size = 6),
                  hovertemplate = "%{x}<br>%{y:,.1f}<extra>Total país</extra>") |>
        layout(title = list(text = paste0(nombre_medida(), " por año · 2013–", ANIO_COMPLETO),
                            x = 0, xanchor = "left"),
               xaxis = list(title = "", gridcolor = grid_color_dark, dtick = 1),
               yaxis = list(title = nombre_medida(), separatethousands = TRUE,
                            gridcolor = grid_color_dark),
               legend = list(font = list(size = 10)),
               # El período elegido en el panel se marca acá, para que se vea
               # que el filtro existe aunque esta vista muestre todo.
               shapes = list(list(type = "rect", xref = "x", yref = "paper",
                                  x0 = input$periodo[1] - 0.5, x1 = input$periodo[2] + 0.5,
                                  y0 = 0, y1 = 1, layer = "below",
                                  fillcolor = "rgba(148,163,184,0.12)",
                                  line = list(width = 0))),
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))
    })

    # --- composición --------------------------------------------------------
    output$composicion <- renderPlotly({
      d <- conteos()[, .(n = sum(n)), by = .(depto, delito)]
      if (nrow(d) == 0) return(plotly_empty())
      d[, pct := 100 * n / sum(n), by = depto]

      orden <- d[delito == "RAPIÑA", .(p = sum(pct)), by = depto][order(p)]$depto
      faltan <- setdiff(unique(d$depto), orden)
      d[, depto := factor(depto, levels = c(faltan, orden))]

      plot_ly(d, y = ~depto, x = ~pct, color = ~delito,
              colors = colores_delito_categorico,
              type = "bar", orientation = "h", customdata = ~n,
              hovertemplate = "%{x:.1f}%<br>%{customdata:,.0f} casos<extra>%{fullData.name}</extra>") |>
        layout(barmode = "stack",
               title = list(text = paste("Composición del delito ·", periodo_txt()),
                            x = 0, xanchor = "left"),
               xaxis = list(title = "% de las denuncias del departamento",
                            ticksuffix = "%", gridcolor = grid_color_dark),
               yaxis = list(title = "", gridcolor = "transparent"),
               margin = list(l = margen_eje(ancho(), 140)),
               legend = list(orientation = "h", y = -0.12, font = list(size = 10)),
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))
    })

    # --- tabla --------------------------------------------------------------
    tabla_datos <- reactive({
      largo <- conteos()[, .(n = sum(n)), by = .(depto, delito)]
      ancho_d <- dcast(largo, depto ~ delito, value.var = "n", fill = 0)
      d <- merge(poblacion_dt, ancho_d, by = "depto", all.x = TRUE)
      cols <- setdiff(names(d), c("depto", "poblacion"))
      for (cl in cols) set(d, which(is.na(d[[cl]])), cl, 0)
      d[, Total := rowSums(.SD), .SDcols = cols]
      d[, Tasa := round(1e5 * (Total / n_anios()) / poblacion, 1)]
      setnames(d, c("depto", "poblacion", "Tasa"),
               c("Departamento", "Población", "Tasa c/100.000"))
      d[order(-`Tasa c/100.000`)]
    })

    output$tabla <- renderDT({
      datatable(tabla_datos(), rownames = FALSE,
                options = list(pageLength = 19, scrollX = TRUE, dom = "tip",
                               language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json"))) |>
        formatRound(columns = "Población", digits = 0, mark = ".") |>
        formatRound(columns = "Tasa c/100.000", digits = 1, mark = ".", dec.mark = ",")
    })

    output$bajar <- downloadHandler(
      filename = function() sprintf("comparativa_departamental_%s.csv",
                                    gsub("–", "-", periodo_txt())),
      content  = function(file) data.table::fwrite(tabla_datos(), file)
    )
  })
}
