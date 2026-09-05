# Módulo: Homicidios Dolosos
# ============================================================

mod_homicidios_ui <- function(id) {
  ns <- NS(id)
  
  layout_sidebar(
    sidebar = sidebar(
      title = "Filtros",
      width = 300,
      sliderInput(
        ns("anio_hom"), "Rango de años:",
        min = min(años_hom), max = max(años_hom),
        value = c(min(años_hom), max(años_hom)),
        sep = "", step = 1
      ),
      selectInput(
        ns("depto_hom"), "Departamento:",
        choices = c("Todos los departamentos" = "TODOS", deptos_hom),
        selected = "TODOS"
      ),
      checkboxGroupInput(
        ns("motivo_hom"), "Motivo aparente:",
        choices = motivos_hom,
        selected = motivos_hom
      ),
      checkboxGroupInput(
        ns("sexo_hom"), "Sexo de la víctima:",
        choices = sexos_hom,
        selected = sexos_hom
      ),
      checkboxGroupInput(
        ns("arma_hom"), "Tipo de arma:",
        choices = armas_hom,
        selected = armas_hom
      )
    ),
    
    # KPIs Fijos
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box(
        title = "Total de homicidios",
        value = textOutput(ns("kpi_total")),
        showcase = icon("skull")
      ),
      value_box(
        title = "Tasa de esclarecimiento",
        value = textOutput(ns("kpi_tasa")),
        showcase = icon("search")
      ),
      value_box(
        title = "Proporción H/M",
        value = textOutput(ns("kpi_prop")),
        showcase = icon("venus-mars")
      ),
      value_box(
        title = "Motivo más frecuente",
        value = textOutput(ns("kpi_motivo")),
        showcase = icon("question-circle")
      )
    ),
    
    # Pestañas
    navset_card_underline(
      title = "Análisis Detallado",
      
      nav_panel(
        "Evolución General",
        icon = icon("chart-area"),
        withSpinner(plotlyOutput(ns("plot_evol"), height = "450px"), type = 4)
      ),
      
      nav_panel(
        "Móviles y Armas",
        icon = icon("gun"),
        layout_columns(
          col_widths = c(6, 6),
          withSpinner(plotlyOutput(ns("plot_motivo"), height = "450px"), type = 4),
          withSpinner(plotlyOutput(ns("plot_arma"), height = "450px"), type = 4)
        )
      ),
      
      nav_panel(
        "Demografía y Vínculos",
        icon = icon("users"),
        layout_columns(
          col_widths = c(6, 6),
          withSpinner(plotlyOutput(ns("plot_edad"), height = "450px"), type = 4),
          withSpinner(plotlyOutput(ns("plot_rel"), height = "450px"), type = 4)
        )
      ),
      
      nav_panel(
        "Microdatos",
        icon = icon("table"),
        withSpinner(DTOutput(ns("tabla_hom")), type = 4)
      )
    )
  )
}

mod_homicidios_server <- function(id, ancho = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {
    
    # --- Datos Reactivos ---
    datos_filtrados <- reactive({
      d <- homicidios_dt[
        ANIO >= input$anio_hom[1] & ANIO <= input$anio_hom[2] &
        MOTIVO_APARENTE %in% input$motivo_hom &
        SEXO %in% input$sexo_hom &
        ARMAREC %in% input$arma_hom
      ]
      if (input$depto_hom != "TODOS") {
        d <- d[DEPARTAMENTO == input$depto_hom]
      }
      d
    })

    # --- KPIs ---
    output$kpi_total <- renderText({
      format(nrow(datos_filtrados()), big.mark = ".", decimal.mark = ",")
    })

    output$kpi_tasa <- renderText({
      d <- datos_filtrados()
      if (nrow(d) == 0) return("—")
      pct <- round(sum(d$ACLARADO == "ACLARADO", na.rm = TRUE) / nrow(d) * 100, 1)
      paste0(pct, "%")
    })

    output$kpi_prop <- renderText({
      d <- datos_filtrados()
      if (nrow(d) == 0) return("—")
      h <- sum(d$SEXO == "HOMBRE", na.rm = TRUE)
      m <- sum(d$SEXO == "MUJER", na.rm = TRUE)
      paste0(h, " H / ", m, " M")
    })

    output$kpi_motivo <- renderText({
      d <- datos_filtrados()
      if (nrow(d) == 0) return("—")
      tbl <- d[, .N, by = MOTIVO_APARENTE][order(-N)]
      tbl$MOTIVO_APARENTE[1]
    })

    # --- Gráficos ---
    output$plot_evol <- renderPlotly({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(plotly_empty())

      total_anual <- d[, .N, by = ANIO]
      escl_anual <- d[, .(
        pct_escl = round(sum(ACLARADO == "ACLARADO", na.rm = TRUE) / .N * 100, 1)
      ), by = ANIO]

      merged <- merge(total_anual, escl_anual, by = "ANIO")[order(ANIO)]

      plot_ly(merged) %>%
        add_trace(
          x = ~ANIO, y = ~N,
          type = "scatter", mode = "lines+markers",
          name = "Homicidios",
          line = list(color = "#3b82f6", width = 3),
          marker = list(color = "#3b82f6", size = 7),
          hovertemplate = "Año: %{x}<br>Homicidios: %{y}<extra></extra>"
        ) %>%
        add_trace(
          x = ~ANIO, y = ~pct_escl,
          type = "scatter", mode = "lines+markers",
          name = "% Esclarecimiento",
          yaxis = "y2",
          line = list(color = "#94a3b8", width = 2, dash = "dash"),
          marker = list(color = "#94a3b8", size = 6),
          hovertemplate = "Año: %{x}<br>Esclarecimiento: %{y}%<extra></extra>"
        ) %>%
        layout(
          xaxis = list(title = "Año", dtick = 1, gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis = list(title = "Cantidad de homicidios", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis2 = list(
            title = "% Esclarecimiento",
            overlaying = "y", side = "right",
            rangemode = "tozero", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark
          ),
          legend = list(orientation = "h", y = -0.2),
          hovermode = "x unified",
          margin = list(b = 80),
          title = "Evolución anual de homicidios y tasa de esclarecimiento",
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    output$plot_motivo <- renderPlotly({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(plotly_empty())

      agg <- d[, .N, by = .(ANIO, MOTIVO_APARENTE)]

      plot_ly(agg, x = ~ANIO, y = ~N, color = ~MOTIVO_APARENTE,
              type = "bar",
              hovertemplate = "<b>%{data.name}</b><br>Año: %{x}<br>Cantidad: %{y}<extra></extra>") %>%
        layout(
          barmode = "stack",
          xaxis = list(title = "Año", dtick = 1, gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis = list(title = "Cantidad", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          legend = list(orientation = "h", y = -0.3, font = list(size = 9)),
          margin = list(b = 120),
          title = "Distribución por motivo aparente",
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    output$plot_arma <- renderPlotly({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(plotly_empty())

      agg <- d[, .N, by = ARMAREC][order(N)]
      agg$ARMAREC <- factor(agg$ARMAREC, levels = agg$ARMAREC)

      plot_ly(agg, y = ~ARMAREC, x = ~N, type = "bar",
              orientation = "h",
              marker = list(color = "#1d4ed8"),
              hovertemplate = "<b>%{y}</b><br>Cantidad: %{x}<extra></extra>") %>%
        layout(
          xaxis = list(title = "Cantidad", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis = list(title = "", tickfont = list(size = 10), gridcolor = "transparent", zerolinecolor = "transparent"),
          margin = list(l = margen_eje(ancho(), 150)),
          title = "Distribución por arma",
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    output$plot_edad <- renderPlotly({
      d <- datos_filtrados()
      d <- d[!is.na(EDADCALC)]
      if (nrow(d) == 0) return(plotly_empty())

      colores_sexo <- c("HOMBRE" = "#3b82f6", "MUJER" = "#94a3b8", "SIN DATO" = "#475569")

      p <- plot_ly()
      for (s in unique(d$SEXO)) {
        sub <- d[SEXO == s]
        color <- ifelse(s %in% names(colores_sexo), colores_sexo[s], "#7f8c8d")
        p <- p %>% add_histogram(
          x = ~sub$EDADCALC,
          name = s,
          opacity = 0.6,
          marker = list(color = color),
          hovertemplate = "Edad: %{x}<br>Cantidad: %{y}<extra></extra>"
        )
      }
      p %>% layout(
        barmode = "overlay",
        xaxis = list(title = "Edad", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
        yaxis = list(title = "Cantidad", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
        legend = list(orientation = "h", y = -0.2),
        title = "Edad por Sexo",
        plot_bgcolor = plot_bg_color,
        paper_bgcolor = paper_bg_color,
        font = list(color = font_color_dark)
      )
    })

    output$plot_rel <- renderPlotly({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(plotly_empty())

      agg <- d[, .N, by = REL_VICT_AGRES][order(N)]
      agg$REL_VICT_AGRES <- factor(agg$REL_VICT_AGRES, levels = agg$REL_VICT_AGRES)

      plot_ly(agg, y = ~REL_VICT_AGRES, x = ~N, type = "bar",
              orientation = "h",
              marker = list(color = "#60a5fa"),
              hovertemplate = "<b>%{y}</b><br>Cantidad: %{x}<extra></extra>") %>%
        layout(
          xaxis = list(title = "Cantidad", gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis = list(title = "", tickfont = list(size = 10), gridcolor = "transparent", zerolinecolor = "transparent"),
          margin = list(l = margen_eje(ancho(), 150)),
          title = "Relación Víctima-Agresor",
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    # --- Tabla microdatos ---
    output$tabla_hom <- renderDT({
      d <- datos_filtrados()
      if (nrow(d) == 0) return(datatable(data.frame()))

      cols_sel <- c("ID_VICTIMA", "FECHA", "ANIO", "DEPARTAMENTO", "MOTIVO_APARENTE",
                    "ARMAREC", "SEXO", "EDADCALC", "ACLARADO", "REL_VICT_AGRES")
      cols_sel <- intersect(cols_sel, names(d))

      datatable(
        d[, ..cols_sel],
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json")
        ),
        rownames = FALSE,
        filter = "top"
      )
    })

  })
}
