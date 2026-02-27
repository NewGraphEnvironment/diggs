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
      ns("aoi_mode"), "AOI Filter",
      choices = c(
        "None (all centroids)" = "none",
        "Watershed (raw)" = "raw",
        "Watershed (buffered)" = "buffered",
        "Custom (drawn)" = "custom"
      ),
      selected = "buffered"
    ),
    shiny::hr(),
    shiny::textOutput(ns("summary"))
  )
}

mod_filters_server <- function(id, layers) {
  shiny::moduleServer(id, function(input, output, session) {

    centroids <- layers$l_photo_centroids

    filtered_data <- shiny::reactive({
      dat <- centroids

      # Year filter
      dat <- dat |>
        dplyr::filter(
          photo_year >= input$year_range[1],
          photo_year <= input$year_range[2]
        )

      # Media filter
      if (length(input$media) > 0) {
        dat <- dat |> dplyr::filter(media %in% input$media)
      }

      # Scale filter
      if (!is.null(input$scale_filter) && input$scale_filter != "") {
        dat <- dat |> dplyr::filter(scale == input$scale_filter)
      }

      # AOI spatial filter
      aoi <- switch(input$aoi_mode,
        "raw" = layers$aoi_raw,
        "buffered" = layers$aoi,
        "custom" = NULL, # TODO: wire to drawn polygon from map module
        "none" = NULL
      )

      if (!is.null(aoi)) {
        dat <- sf::st_intersection(dat, aoi)
      }

      dat
    })

    output$summary <- shiny::renderText({
      dat <- filtered_data()
      n <- if (is.null(dat)) 0L else nrow(dat)
      yrs <- if (n > 0) length(unique(dat$photo_year)) else 0
      paste0(n, " photos across ", yrs, " years")
    })

    list(filtered_data = filtered_data)
  })
}
