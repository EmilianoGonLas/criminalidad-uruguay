# ============================================================
# Módulo: Seccionales Policiales
# ============================================================
# El nivel de detalle geográfico más fino que publica la fuente: 280
# seccionales, contra 19 departamentos. La denuncia trae la jurisdicción
# como texto ("SECCIONAL 10"), que se repite entre departamentos; la clave
# real es departamento + número, acá `sec_id`.

mod_seccionales_ui <- function(id) {
  ns <- NS(id)

  layout_sidebar(
    sidebar = sidebar(
      title = "Filtros",
      width = 320,

      sliderInput(ns("periodo"), "Período:",
                  min = min(años_delitos), max = max(años_delitos),
                  value = c(max(años_delitos) - 1, max(años_delitos)),
                  step = 1, sep = "", ticks = FALSE),

      checkboxGroupInput(ns("delitos"), "Delitos:",
                         choices = delito_tipos, selected = delito_tipos),

      selectInput(ns("depto"), "Departamento:",
                  choices = c("Todo el país", deptos_delitos),
                  selected = "Todo el país"),

      radioButtons(ns("tentativa"), "Tentativas:",
                   choices = c("Incluir" = "todas",
                               "Sólo consumados" = "no",
                               "Sólo tentativas" = "si"),
                   selected = "todas"),

      hr(),
      div(style = "font-size:0.78rem; color:#94a3b8; line-height:1.45;",
          tags$b("Sobre estos datos"), tags$br(),
          "280 seccionales. Son conteos, no tasas: la fuente no publica ",
          "población por seccional.", tags$br(), tags$br(),
          if (anio_incompleto)
            tags$span(style = "color:#fbbf24;",
                      sprintf("%d está incompleto: los datos llegan al %s.",
                              anio_max, format(fecha_max, "%d/%m/%Y")))
      )
    ),

    navset_card_underline(
      title = "Detalle por seccional policial",

      nav_panel("Mapa", icon = icon("map"),
                withSpinner(leafletOutput(ns("mapa"), height = "640px"), type = 4)),

      nav_panel("Ranking", icon = icon("chart-bar"),
                withSpinner(plotlyOutput(ns("ranking"), height = "640px"), type = 4)),

      nav_panel("Evolución", icon = icon("chart-line"),
                withSpinner(plotlyOutput(ns("evolucion"), height = "640px"), type = 4)),

      nav_panel("Día × hora", icon = icon("clock"),
                div(style = "font-size:0.82rem; color:#94a3b8; margin-bottom:10px;",
                    "Sólo rapiña, lesiones y violencia doméstica registran hora. ",
                    "Al hurto se lo descubre después y la víctima no sabe cuándo ",
                    "ocurrió: no trae hora en el 88% de los casos, y el abigeato ",
                    "en el 100%. Por eso quedan afuera de este gráfico."),
                withSpinner(plotlyOutput(ns("heatmap"), height = "560px"), type = 4)),

      nav_panel("Barrios de Montevideo", icon = icon("city"),
                div(style = "font-size:0.82rem; color:#94a3b8; margin-bottom:10px;",
                    "El barrio sólo existe para Montevideo en la fuente."),
                withSpinner(plotlyOutput(ns("barrios"), height = "620px"), type = 4)),

      nav_panel("Tabla", icon = icon("table"),
                div(style = "margin-bottom:10px;",
                    downloadButton(ns("bajar"), "Descargar CSV", class = "btn-sm")),
                withSpinner(DTOutput(ns("tabla")), type = 4))
    )
  )
}

mod_seccionales_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # --- filtro común -------------------------------------------------------
    eventos <- reactive({
      req(input$delitos, input$periodo)
      d <- delitos_dt[ANIO >= input$periodo[1] & ANIO <= input$periodo[2] &
                        DELITO %in% input$delitos & !is.na(sec_id)]
      if (input$tentativa == "no")  d <- d[TENTATIVA == "NO"]
      if (input$tentativa == "si")  d <- d[TENTATIVA == "SI"]
      if (input$depto != "Todo el país") d <- d[DEPTO == input$depto]
      d
    })

    por_seccional <- reactive({
      d <- eventos()[, .(eventos = .N), by = .(sec_id = as.character(sec_id))]
      d[, etiqueta := ifelse(is.na(sec_label[sec_id]), sec_id, sec_label[sec_id])]
      d[order(-eventos)]
    })

    titulo <- reactive({
      p <- input$periodo
      if (p[1] == p[2]) as.character(p[1]) else paste0(p[1], "–", p[2])
    })

    # --- mapa ---------------------------------------------------------------
    output$mapa <- renderLeaflet({
      d <- por_seccional()
      geo <- seccionales_sf
      if (input$depto != "Todo el país") geo <- geo[geo$depto == input$depto, ]

      geo <- merge(geo, d, by = "sec_id", all.x = TRUE)
      geo$eventos[is.na(geo$eventos)] <- 0

      # Escala por cuantiles: unas pocas seccionales de Montevideo concentran
      # tantos casos que una escala lineal deja al resto del país en un solo tono.
      cortes <- unique(quantile(geo$eventos, probs = seq(0, 1, 0.125), na.rm = TRUE))
      pal <- if (length(cortes) > 2) {
        colorBin("YlOrRd", domain = geo$eventos, bins = cortes, pretty = FALSE)
      } else {
        colorNumeric("YlOrRd", domain = geo$eventos)
      }

      leaflet(geo) |>
        agregar_mapa_base() |>
        addPolygons(
          fillColor = ~pal(eventos), fillOpacity = 0.75,
          weight = 0.7, color = "#64748b", opacity = 0.9,
          label = ~lapply(sprintf(
            "<b>%s — Seccional %d</b><br>%s<br>%s denuncias<br><i>%s</i>",
            depto, seccion, ifelse(is.na(nombre), "", nombre),
            format(eventos, big.mark = "."), titulo()), htmltools::HTML),
          highlightOptions = highlightOptions(weight = 2.5, color = "#f8fafc",
                                              fillOpacity = 0.9, bringToFront = TRUE)
        ) |>
        addLegend(pal = pal, values = ~eventos, title = paste("Denuncias", titulo()),
                  position = "bottomright", opacity = 0.85,
                  labFormat = labelFormat(big.mark = "."))
    })

    # --- ranking ------------------------------------------------------------
    output$ranking <- renderPlotly({
      d <- head(por_seccional(), 30)
      if (nrow(d) == 0) return(plotly_empty())
      d <- d[order(eventos)]
      d[, etiqueta := factor(etiqueta, levels = etiqueta)]

      plot_ly(d, y = ~etiqueta, x = ~eventos, type = "bar", orientation = "h",
              marker = list(color = "#3b82f6"),
              hovertemplate = "<b>%{y}</b><br>%{x:,.0f} denuncias<extra></extra>") |>
        layout(title = paste("30 seccionales con más denuncias —", titulo()),
               xaxis = list(title = "Denuncias", separatethousands = TRUE,
                            gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
               yaxis = list(title = "", gridcolor = "transparent"),
               margin = list(l = 320),
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))
    })

    # --- evolución mensual --------------------------------------------------
    output$evolucion <- renderPlotly({
      d <- eventos()[, .(eventos = .N),
                     by = .(mes = as.Date(format(fecha, "%Y-%m-01")),
                            DELITO = as.character(DELITO))]
      if (nrow(d) == 0) return(plotly_empty())
      d <- d[!is.na(mes)][order(mes)]

      plot_ly(d, x = ~mes, y = ~eventos, color = ~DELITO, colors = colores_delito,
              type = "scatter", mode = "lines",
              hovertemplate = "%{x|%b %Y}<br>%{y:,.0f}<extra>%{fullData.name}</extra>") |>
        layout(title = "Denuncias por mes",
               xaxis = list(title = "", gridcolor = grid_color_dark),
               yaxis = list(title = "Denuncias", separatethousands = TRUE,
                            gridcolor = grid_color_dark),
               legend = list(orientation = "h", y = -0.15),
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))
    })

    # --- heatmap día × hora -------------------------------------------------
    output$heatmap <- renderPlotly({
      d <- eventos()[DELITO %in% delitos_con_hora & !is.na(hora)]
      if (nrow(d) == 0) {
        return(plotly_empty() |> layout(
          title = "Ningún delito seleccionado registra hora",
          paper_bgcolor = paper_bg_color, font = list(color = font_color_dark)))
      }
      d <- d[, .(eventos = .N), by = .(DIA_SEMANA = as.character(DIA_SEMANA), hora)]
      m <- dcast(d, DIA_SEMANA ~ hora, value.var = "eventos", fill = 0)
      m <- m[match(dias_orden, m$DIA_SEMANA)]
      m <- m[!is.na(DIA_SEMANA)]

      plot_ly(x = names(m)[-1], y = m$DIA_SEMANA,
              z = as.matrix(m[, -1]), type = "heatmap", colors = "YlOrRd",
              hovertemplate = "%{y} %{x}:00<br>%{z:,.0f} denuncias<extra></extra>") |>
        layout(title = paste("Rapiña, lesiones y violencia doméstica —", titulo()),
               xaxis = list(title = "Hora del día", dtick = 2),
               yaxis = list(title = "", autorange = "reversed"),
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))
    })

    # --- barrios de Montevideo ----------------------------------------------
    output$barrios <- renderPlotly({
      d <- eventos()[!is.na(barrio) & trimws(as.character(barrio)) != ""]
      if (nrow(d) == 0) {
        return(plotly_empty() |> layout(
          title = "Sin datos de barrio para la selección (sólo existe en Montevideo)",
          paper_bgcolor = paper_bg_color, font = list(color = font_color_dark)))
      }
      d <- d[, .(eventos = .N), by = .(barrio = as.character(barrio))][order(-eventos)]
      d <- head(d, 30)[order(eventos)]
      d[, barrio := factor(barrio, levels = barrio)]

      plot_ly(d, y = ~barrio, x = ~eventos, type = "bar", orientation = "h",
              marker = list(color = "#60a5fa"),
              hovertemplate = "<b>%{y}</b><br>%{x:,.0f} denuncias<extra></extra>") |>
        layout(title = paste("30 barrios con más denuncias —", titulo()),
               xaxis = list(title = "Denuncias", separatethousands = TRUE,
                            gridcolor = grid_color_dark),
               yaxis = list(title = "", gridcolor = "transparent"),
               margin = list(l = 200),
               plot_bgcolor = plot_bg_color, paper_bgcolor = paper_bg_color,
               font = list(color = font_color_dark))
    })

    # --- tabla y descarga ---------------------------------------------------
    tabla_datos <- reactive({
      d <- eventos()[, .(eventos = .N),
                     by = .(sec_id = as.character(sec_id), DELITO = as.character(DELITO))]
      w <- dcast(d, sec_id ~ DELITO, value.var = "eventos", fill = 0)
      w[, Total := rowSums(.SD), .SDcols = setdiff(names(w), "sec_id")]
      meta <- as.data.table(sf::st_drop_geometry(seccionales_sf))
      w <- merge(meta[, .(sec_id, Departamento = depto, Seccional = seccion,
                          Nombre = nombre)], w, by = "sec_id", all.y = TRUE)
      w[order(-Total)]
    })

    output$tabla <- renderDT({
      d <- copy(tabla_datos())[, sec_id := NULL]
      datatable(d, rownames = FALSE, extensions = "Buttons",
                options = list(pageLength = 25, scrollX = TRUE,
                               language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json")))
    })

    output$bajar <- downloadHandler(
      filename = function() sprintf("denuncias_seccional_%s.csv", gsub("–", "-", titulo())),
      content  = function(file) data.table::fwrite(tabla_datos(), file)
    )
  })
}
