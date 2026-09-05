# Módulo: Comparativa Departamental
# ============================================================

mod_comparativa_ui <- function(id) {
  ns <- NS(id)
  
  layout_sidebar(
    sidebar = sidebar(
      title = "Filtros",
      width = 300,
      selectInput(
        ns("anio_comp"), "Año:",
        choices = años_delitos,
        selected = max(años_delitos)
      ),
      selectInput(
        ns("indicador_comp"), "Indicador principal:",
        choices = c(
          "Total delitos",
          "Homicidios",
          "Rapiñas",
          "Hurtos",
          "Violencia doméstica",
          "Lesiones"
        ),
        selected = "Total delitos"
      )
    ),
    
    # Pestañas
    navset_card_underline(
      title = "Análisis Geográfico",
      
      nav_panel(
        "Mapa Coroplético",
        icon = icon("map"),
        withSpinner(leafletOutput(ns("mapa_comp"), height = "600px"), type = 4)
      ),
      
      nav_panel(
        "Ranking Departamental",
        icon = icon("chart-bar"),
        withSpinner(plotlyOutput(ns("plot_ranking"), height = "600px"), type = 4)
      ),
      
      nav_panel(
        "Tabla Comparativa General",
        icon = icon("table"),
        withSpinner(DTOutput(ns("tabla_comp")), type = 4)
      )
    )
  )
}

mod_comparativa_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    datos_comp <- reactive({
      anio_sel <- as.integer(input$anio_comp)
      indicador <- input$indicador_comp

      if (indicador == "Homicidios") {
        d <- homicidios_dt[ANIO == anio_sel, .N, by = DEPARTAMENTO]
        setnames(d, c("DEPTO", "VALOR"))
      } else {
        if (indicador == "Total delitos") {
          d <- delitos_dt[ANIO == anio_sel, .N, by = DEPTO]
        } else if (indicador == "Rapiñas") {
          d <- delitos_dt[ANIO == anio_sel & DELITO == "RAPIÑA", .N, by = DEPTO]
        } else if (indicador == "Hurtos") {
          d <- delitos_dt[ANIO == anio_sel & DELITO == "HURTO", .N, by = DEPTO]
        } else if (indicador == "Violencia doméstica") {
          d <- delitos_dt[ANIO == anio_sel & DELITO == "VIOLENCIA DOMÉSTICA", .N, by = DEPTO]
        } else if (indicador == "Lesiones") {
          d <- delitos_dt[ANIO == anio_sel & DELITO == "LESIONES", .N, by = DEPTO]
        }
        setnames(d, c("DEPTO", "VALOR"))
      }

      d$depto_norm <- normalize_depto(d$DEPTO)
      d
    })

    # --- Mapa coroplético ---
    output$mapa_comp <- renderLeaflet({
      d <- datos_comp()

      map_data <- merge(uruguay_sf, d, by = "depto_norm", all.x = TRUE)
      map_data$VALOR[is.na(map_data$VALOR)] <- 0

      pal <- colorNumeric(
        palette = "Blues",
        domain = map_data$VALOR
      )

      leaflet(map_data) %>%
        agregar_mapa_base() %>%
        setView(lng = -56.0, lat = -33.0, zoom = 6) %>%
        addPolygons(
          fillColor = ~pal(VALOR),
          fillOpacity = 0.7,
          weight = 2,
          color = "#2c3e50",
          opacity = 0.8,
          popup = ~paste0(
            "<b>", name, "</b><br>",
            input$indicador_comp, ": ",
            format(VALOR, big.mark = ".", decimal.mark = ",")
          ),
          highlightOptions = highlightOptions(
            weight = 4,
            color = "#e74c3c",
            fillOpacity = 0.9,
            bringToFront = TRUE
          )
        ) %>%
        addLegend(
          pal = pal,
          values = ~VALOR,
          title = input$indicador_comp,
          position = "bottomright",
          labFormat = labelFormat(big.mark = ".")
        )
    })

    # --- Ranking departamentos ---
    output$plot_ranking <- renderPlotly({
      d <- datos_comp()
      if (nrow(d) == 0) return(plotly_empty())

      d <- d[order(VALOR)]
      d$DEPTO <- factor(d$DEPTO, levels = d$DEPTO)

      plot_ly(d, y = ~DEPTO, x = ~VALOR, type = "bar",
              orientation = "h",
              marker = list(color = "#3b82f6"),
              hovertemplate = "<b>%{y}</b><br>Cantidad: %{x:,.0f}<extra></extra>") %>%
        layout(
          xaxis = list(title = input$indicador_comp, separatethousands = TRUE, gridcolor = grid_color_dark, zerolinecolor = grid_color_dark),
          yaxis = list(title = "", gridcolor = "transparent", zerolinecolor = "transparent"),
          margin = list(l = 130),
          title = paste("Ranking por", input$indicador_comp),
          plot_bgcolor = plot_bg_color,
          paper_bgcolor = paper_bg_color,
          font = list(color = font_color_dark)
        )
    })

    # --- Tabla comparativa ---
    output$tabla_comp <- renderDT({
      anio_sel <- as.integer(input$anio_comp)

      # Todos los indicadores para el año
      total <- delitos_dt[ANIO == anio_sel, .N, by = DEPTO]
      setnames(total, c("Departamento", "Total Delitos"))

      hurtos <- delitos_dt[ANIO == anio_sel & DELITO == "HURTO", .N, by = DEPTO]
      setnames(hurtos, c("Departamento", "Hurtos"))

      rapinas <- delitos_dt[ANIO == anio_sel & DELITO == "RAPIÑA", .N, by = DEPTO]
      setnames(rapinas, c("Departamento", "Rapiñas"))

      vd <- delitos_dt[ANIO == anio_sel & DELITO == "VIOLENCIA DOMÉSTICA", .N, by = DEPTO]
      setnames(vd, c("Departamento", "Violencia Doméstica"))

      lesiones <- delitos_dt[ANIO == anio_sel & DELITO == "LESIONES", .N, by = DEPTO]
      setnames(lesiones, c("Departamento", "Lesiones"))

      hom <- homicidios_dt[ANIO == anio_sel, .N, by = DEPARTAMENTO]
      setnames(hom, c("Departamento", "Homicidios"))

      # Merge todo
      result <- Reduce(function(a, b) merge(a, b, by = "Departamento", all = TRUE),
                       list(total, hurtos, rapinas, vd, lesiones, hom))
      result[is.na(result)] <- 0
      result <- result[order(-`Total Delitos`)]

      datatable(
        result,
        options = list(
          pageLength = 20,
          language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json")
        ),
        rownames = FALSE
      ) %>%
        formatRound(
          columns = c("Total Delitos", "Hurtos", "Rapiñas",
                       "Violencia Doméstica", "Lesiones", "Homicidios"),
          digits = 0, mark = "."
        )
    })

  })
}
