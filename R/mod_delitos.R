# Módulo: Delitos Generales
# ============================================================

mod_delitos_ui <- function(id) {
  ns <- NS(id)
  
  layout_sidebar(
    sidebar = sidebar(
      title = "Filtros",
      width = 300,
      sliderInput(
        ns("anio_delitos"), "Rango de años:",
        min = min(años_delitos), max = max(años_delitos),
        value = c(min(años_delitos), max(años_delitos)),
        sep = "", step = 1
      ),
      checkboxGroupInput(
        ns("tipo_delito"), "Tipo de delito:",
        choices = delito_tipos,
        selected = delito_tipos
      ),
      selectInput(
        ns("depto_delitos"), "Departamento:",
        choices = c("Todos los departamentos" = "TODOS", deptos_delitos),
        selected = "TODOS"
      ),
      radioButtons(
        ns("tentativa"), "Tentativa:",
        choices = c(
          "Ambos" = "AMBOS",
          "Solo consumados" = "NO",
          "Solo tentativas" = "SI"
        ),
        selected = "AMBOS"
      )
    ),
    
    # KPIs Fijos arriba
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box(
        title = "Total de eventos",
        value = textOutput(ns("kpi_total")),
        showcase = icon("hashtag")
      ),
      value_box(
        title = "Delito más frecuente",
        value = textOutput(ns("kpi_freq")),
        showcase = icon("exclamation-triangle")
      ),
      value_box(
        title = "Depto. con más eventos",
        value = textOutput(ns("kpi_depto")),
        showcase = icon("map-marker-alt")
      ),
      value_box(
        title = "% de tentativas",
        value = textOutput(ns("kpi_tentativas")),
        showcase = icon("percentage")
      )
    ),
    
    # Pestañas para Gráficos y Tablas
    navset_card_underline(
      title = "Análisis Detallado",
      
      nav_panel(
        "Tendencias",
        icon = icon("chart-line"),
        withSpinner(plotlyOutput(ns("plot_evol"), height = "500px"), type = 4)
      ),
      
      nav_panel(
        "Distribución Temporal",
        icon = icon("clock"),
        withSpinner(plotlyOutput(ns("plot_heatmap"), height = "500px"), type = 4)
      ),
      
      nav_panel(
        "Geografía",
        icon = icon("map-pin"),
        withSpinner(plotlyOutput(ns("plot_ranking"), height = "500px"), type = 4)
      ),
      
      nav_panel(
        "Tabla de Datos",
        icon = icon("table"),
        withSpinner(DTOutput(ns("tabla_datos")), type = 4)
      )
    )
  )
}

mod_delitos_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # --- Datos Reactivos ---
    datos_filtrados <- reactive({
      d <- delitos_dt[
        ANIO >= input$anio_delitos[1] & ANIO <= input$anio_delitos[2] &
        DELITO %in% input$tipo_delito
      ]
      if (input$depto_delitos != "TODOS") {
        d <- d[DEPTO == input$depto_delitos]
      }
      if (input$tentativa == "SI") {
        d <- d[TENTATIVA == "SI"]
      } else if (input$tentativa == "NO") {
        d <- d[TENTATIVA == "NO"]
      }
      d
    })

    # --- KPIs ---
    output$kpi_total <- renderText({
      format(nrow(datos_filtrados()), big.mark = ".", decimal.mark = ",")
    })

    output$kpi_freq <- renderText({
      d <- datos_filtrados()
      if (nrow(d) == 0) return("—")
      tbl <- d[, .N, by = DELITO][order(-N)]
      tbl$DELITO[1]
    })

    output$kpi_depto <- renderText({
      d <- datos_filtrados()
      if (nrow(d) == 0) return("—")
      tbl <- d[, .N, by = DEPTO][order(-N)]
      tbl$DEPTO[1]
    })

    output$kpi_tentativas <- renderText({
      d <- datos_filtrados()
      if (nrow(d) == 0) return("—")
      pct <- round(sum(d$TENTATIVA == "SI") / nrow(d) * 100, 1)
      paste0(pct, "%")
    })

    # --- Gráficos ---
    output$plot_evol <- renderPlotly({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(plotly_empty())

      agg <- d[, .N, by = .(ANIO, DELITO)]

      p <- plot_ly()
      for (del in unique(agg$DELITO)) {
        sub <- agg[DELITO == del][order(ANIO)]
        color <- ifelse(del %in% names(colores_delito), colores_delito[del], "#7f8c8d")
        p <- p %>% add_trace(
          data = sub, x = ~ANIO, y = ~N,
          type = "scatter", mode = "lines+markers",
          name = del,
          line = list(color = color, width = 2.5),
          marker = list(color = color, size = 6),
          hovertemplate = paste0(
            "<b>", del, "</b><br>",
            "Año: %{x}<br>",
            "Eventos: %{y:,.0f}<extra></extra>"
          )
        )
      }
      p %>% layout(
        xaxis = list(title = "Año", dtick = 1, gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
        yaxis = list(title = "Cantidad de eventos", separatethousands = TRUE, gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
        legend = list(orientation = "h", y = -0.2),
        hovermode = "x unified",
        margin = list(b = 80),
        plot_bgcolor = plot_bg_color,
        paper_bgcolor = paper_bg_color,
        font = list(color = font_color_dark)
      )
    })

    output$plot_ranking <- renderPlotly({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(plotly_empty())

      agg <- d[, .N, by = DEPTO][order(N)]
      agg$DEPTO <- factor(agg$DEPTO, levels = agg$DEPTO)

      plot_ly(agg, y = ~DEPTO, x = ~N, type = "bar",
              orientation = "h",
              marker = list(color = "#3b82f6"),
              hovertemplate = "<b>%{y}</b><br>Eventos: %{x:,.0f}<extra></extra>") %>%
        layout(
          xaxis = list(title = "Cantidad de eventos", separatethousands = TRUE, gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis = list(title = "", gridcolor = "transparent", zerolinecolor = "transparent"),
          margin = list(l = 130),
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    output$plot_heatmap <- renderPlotly({
      d <- datos_filtrados()
      d <- d[HORA != "SIN DATO" & !is.na(HORA_NUM)]
      if (nrow(d) == 0) return(plotly_empty())

      # Normalizar día de la semana para coincidir con la lista fija global
      d[, DIA_NORM := gsub("Á", "A", gsub("É", "E", toupper(DIA_SEMANA)))]
      
      agg <- d[, .N, by = .(DIA_NORM, HORA_NUM)]

      agg$DIA_NORM <- factor(agg$DIA_NORM, levels = rev(dias_orden))

      plot_ly(agg, x = ~HORA_NUM, y = ~DIA_NORM, z = ~N,
              type = "heatmap",
              colorscale = "Blues",
              hovertemplate = "Día: %{y}<br>Hora: %{x}:00<br>Eventos: %{z:,.0f}<extra></extra>") %>%
        layout(
          xaxis = list(title = "Hora del día", dtick = 1,
                       tickvals = 0:23, ticktext = paste0(0:23, "h"), gridcolor = "transparent", zerolinecolor = "transparent"),
          yaxis = list(title = "", gridcolor = "transparent", zerolinecolor = "transparent"),
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    output$tabla_datos <- renderDT({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(datatable(data.frame()))

      agg <- d[, .N, by = .(ANIO, DEPTO, DELITO)]
      setnames(agg, c("Año", "Departamento", "Tipo de Delito", "Cantidad"))
      agg <- agg[order(-Cantidad)]

      datatable(
        agg,
        options = list(
          pageLength = 15,
          language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json")
        ),
        rownames = FALSE,
        filter = "top"
      ) %>% formatRound("Cantidad", digits = 0, mark = ".")
    })

  })
}
