# Filter module - sidebar controls and reactive filtered dataset

mod_filters_ui <- function(id, layers) {
  ns <- shiny::NS(id)

  centroids <- layers$l_photo_centroids
  year_range <- range(centroids$photo_year, na.rm = TRUE)
  media_types <- sort(unique(centroids$media))
  scale_values <- sort(unique(centroids$scale))

  shiny::tagList(
    shiny::sliderInput(
      ns("year_range"), "Year Range",
      min = year_range[1], max = year_range[2],
      value = year_range,
      sep = "", step = 1
    ),
    shiny::checkboxGroupInput(
      ns("media"), "Media Type",
      choices = media_types,
      selected = media_types
    ),
    shiny::selectInput(
      ns("scale_filter"), "Scale",
      choices = c("All" = "", scale_values),
      selected = ""
    ),
    shiny::radioButtons(
      ns("aoi_mode"), "Area of Interest",
      choices = c(
        "Built in" = "aoi",
        "Custom (draw or upload)" = "custom"
      ),
      selected = "aoi"
    ),
    shiny::conditionalPanel(
      condition = paste0("input['", ns("aoi_mode"), "'] == 'custom'"),
      shiny::fileInput(
        ns("upload_aoi"), "Upload AOI (geojson or gpkg)",
        accept = c(".geojson", ".gpkg", ".json")
      )
    ),
    shiny::actionButton(
      ns("show_footprints"), "Footprints",
      class = "btn-sm btn-outline-secondary"
    ),
    shiny::hr(),
    shiny::textOutput(ns("summary"))
  )
}

mod_filters_server <- function(id, layers, drawn_aoi = shiny::reactiveVal(NULL)) {
  shiny::moduleServer(id, function(input, output, session) {

    centroids <- layers$l_photo_centroids

    # Reactive for uploaded AOI polygon
    uploaded_aoi <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$upload_aoi, {
      req(input$upload_aoi)
      tryCatch({
        aoi <- sf::st_read(input$upload_aoi$datapath, quiet = TRUE)
        # Ensure WGS84
        if (sf::st_crs(aoi)$epsg != 4326) {
          aoi <- sf::st_transform(aoi, 4326)
        }
        aoi <- sf::st_make_valid(aoi)
        # Union to single polygon if multi-feature
        aoi <- sf::st_union(aoi) |> sf::st_sf()
        uploaded_aoi(aoi)
        shiny::showNotification("AOI uploaded successfully", type = "message")
      }, error = function(e) {
        shiny::showNotification(
          paste("Error reading file:", e$message),
          type = "error"
        )
      })
    })

    # Combined custom AOI: uploaded takes precedence, then drawn
    custom_aoi <- shiny::reactive({
      up <- uploaded_aoi()
      dr <- drawn_aoi()
      if (!is.null(up)) up else dr
    })

    filtered_data <- shiny::reactive({
      dat <- centroids

      # Year filter
      dat <- dat |>
        dplyr::filter(
          photo_year >= input$year_range[1],
          photo_year <= input$year_range[2]
        )

      # Media filter
      if (length(input$media) > 0 && length(input$media) < length(unique(centroids$media))) {
        dat <- dat |> dplyr::filter(media %in% input$media)
      } else if (length(input$media) == 0) {
        return(dat[0, ])
      }

      # Scale filter
      if (!is.null(input$scale_filter) && input$scale_filter != "") {
        dat <- dat |> dplyr::filter(scale == input$scale_filter)
      }

      # AOI spatial filter (data already clipped to buffered AOI at cache time)
      aoi <- switch(input$aoi_mode,
        "custom" = custom_aoi(),
        "aoi" = NULL
      )

      if (!is.null(aoi)) {
        dat <- suppressWarnings(sf::st_intersection(dat, aoi))
      }

      dat
    })

    output$summary <- shiny::renderText({
      dat <- filtered_data()
      n <- if (is.null(dat)) 0L else nrow(dat)
      yrs <- if (n > 0) length(unique(dat$photo_year)) else 0
      paste0(n, " photos across ", yrs, " years")
    })

    list(
      filtered_data = filtered_data,
      custom_aoi = custom_aoi,
      show_footprints = shiny::reactive(input$show_footprints)
    )
  })
}
