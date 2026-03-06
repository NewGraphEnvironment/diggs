#' Filter module UI
#' @param id Module namespace id
#' @param layers Named list of sf layers from load_cached_layers
#' @noRd
mod_filters_ui <- function(id, layers) {
  ns <- shiny::NS(id)

  centroids <- layers$l_photo_centroids
  year_range <- range(centroids$photo_year, na.rm = TRUE)
  media_types <- sort(unique(centroids$media))
  scale_values <- sort(unique(centroids$scale))

  shiny::tagList(
    shiny::fluidRow(
      shiny::column(6, shiny::numericInput(
        ns("year_min"), "Year From",
        value = year_range[1], min = year_range[1], max = year_range[2], step = 1
      )),
      shiny::column(6, shiny::numericInput(
        ns("year_max"), "Year To",
        value = year_range[2], min = year_range[1], max = year_range[2], step = 1
      ))
    ),
    shiny::checkboxGroupInput(
      ns("media"), "Media Type",
      choices = media_types,
      selected = media_types
    ),
    shiny::selectInput(
      ns("scale_filter"), "Scale",
      choices = c("All", scale_values),
      selected = "All"
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
      ),
      shiny::radioButtons(
        ns("filter_method"), "Filter Method",
        choices = c("Centroid" = "centroid", "Footprint" = "footprint"),
        selected = "centroid",
        inline = TRUE
      )
    ),
    shiny::actionButton(
      ns("show_footprints"), "Footprints",
      class = "btn-sm btn-outline-secondary"
    ),
    shiny::hr(),
    shiny::textOutput(ns("summary")),
    shiny::hr(),
    shiny::helpText(
      "Select best-resolution photos first, then fill remaining",
      "AOI with coarser scales. Photos are never discarded for",
      "overlapping each other — only for not adding new AOI coverage."
    ),
    shiny::sliderInput(
      ns("target_aoi_coverage"), "Target AOI Coverage (%)",
      min = 0, max = 100, value = 100, step = 5,
      post = "%"
    ),
    shiny::actionButton(
      ns("run_select"), "Select",
      class = "btn-sm btn-primary"
    ),
    shiny::textOutput(ns("select_summary")),
    shiny::uiOutput(ns("download_ui"))
  )
}

#' Filter module server
#' @param id Module namespace id
#' @param layers Named list of sf layers from load_cached_layers
#' @param drawn_aoi ReactiveVal for drawn AOI polygon
#' @noRd
mod_filters_server <- function(id, layers, drawn_aoi = shiny::reactiveVal(NULL)) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    centroids <- layers$l_photo_centroids

    uploaded_aoi <- shiny::reactiveVal(NULL)
    selected_result <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$upload_aoi, {
      req(input$upload_aoi)
      tryCatch({
        aoi <- sf::st_read(input$upload_aoi$datapath, quiet = TRUE)
        if (sf::st_crs(aoi)$epsg != 4326) {
          aoi <- sf::st_transform(aoi, 4326)
        }
        aoi <- sf::st_make_valid(aoi)
        aoi <- sf::st_union(aoi) |> sf::st_sf()
        uploaded_aoi(aoi)
        selected_result(NULL)
        shiny::showNotification("AOI uploaded successfully", type = "message")
      }, error = function(e) {
        shiny::showNotification(
          paste("Error reading file:", e$message),
          type = "error"
        )
      })
    })

    custom_aoi <- shiny::reactive({
      up <- uploaded_aoi()
      dr <- drawn_aoi()
      if (!is.null(up)) up else dr
    })

    filtered_data <- shiny::reactive({
      dat <- centroids

      yr_min <- input$year_min %||% min(centroids$photo_year)
      yr_max <- input$year_max %||% max(centroids$photo_year)
      dat <- dat |>
        dplyr::filter(photo_year >= yr_min, photo_year <= yr_max)

      if (length(input$media) > 0 && length(input$media) < length(unique(centroids$media))) {
        dat <- dat |> dplyr::filter(media %in% input$media)
      } else if (length(input$media) == 0) {
        return(dat[0, ])
      }

      if (!is.null(input$scale_filter) && input$scale_filter != "All") {
        dat <- dat |> dplyr::filter(scale == input$scale_filter)
      }

      aoi <- switch(input$aoi_mode,
        "custom" = custom_aoi(),
        "aoi" = NULL
      )

      if (!is.null(aoi)) {
        method <- input$filter_method %||% "centroid"
        dat <- fly::fly_filter(dat, aoi, method = method)
      }

      dat
    })

    # Priority selection — runs on button click, doesn't change map/table
    shiny::observeEvent(input$run_select, {
      dat <- filtered_data()
      aoi <- switch(input$aoi_mode,
        "custom" = custom_aoi(),
        "aoi" = layers$aoi
      )

      if (is.null(dat) || nrow(dat) == 0 || is.null(aoi)) {
        shiny::showNotification("No photos or AOI to select from", type = "warning")
        return()
      }

      target <- input$target_aoi_coverage / 100

      shiny::withProgress(message = "Selecting photos by resolution priority...", {
        sf::sf_use_s2(FALSE)
        on.exit(sf::sf_use_s2(TRUE))

        scale_nums <- sort(unique(as.numeric(gsub("1:", "", dat$scale))))

        aoi_albers <- sf::st_transform(aoi, 3005) |>
          sf::st_union() |> sf::st_make_valid()
        aoi_area <- as.numeric(sf::st_area(aoi_albers))
        result_all <- NULL
        remaining_aoi <- aoi_albers

        for (i in seq_along(scale_nums)) {
          sc_num <- scale_nums[i]
          sc <- paste0("1:", sc_num)
          photos_sc <- dat[dat$scale == sc, ]
          if (nrow(photos_sc) == 0) next

          remaining_sf <- sf::st_sf(geometry = sf::st_geometry(remaining_aoi)) |>
            sf::st_transform(4326) |> sf::st_make_valid()

          if (target >= 1) {
            sel <- fly::fly_select(photos_sc, remaining_sf, mode = "all")
          } else if (i == 1) {
            sel <- fly::fly_select(photos_sc, remaining_sf, mode = "all")
          } else {
            sel <- fly::fly_select(photos_sc, remaining_sf,
                              mode = "minimal", target_coverage = target)
          }

          if (nrow(sel) == 0) next

          fp <- fly::fly_footprint(sel) |> sf::st_transform(3005)
          fp_union <- sf::st_union(fp) |> sf::st_make_valid()
          remaining_aoi <- tryCatch(
            sf::st_difference(remaining_aoi, fp_union) |> sf::st_make_valid(),
            error = function(e) remaining_aoi
          )

          sel$priority_scale <- sc
          result_all <- dplyr::bind_rows(result_all, sel)

          covered_pct <- 1 - sum(as.numeric(sf::st_area(remaining_aoi))) / aoi_area
          if (covered_pct >= target) break
        }

        if (!is.null(result_all) && nrow(result_all) > 0) {
          covered_pct <- 1 - sum(as.numeric(sf::st_area(remaining_aoi))) / aoi_area
          attr(result_all, "aoi_coverage_pct") <- round(covered_pct * 100, 1)
          selected_result(result_all)
        } else {
          shiny::showNotification("No photos selected", type = "warning")
        }
      })
    })

    output$select_summary <- shiny::renderText({
      sel <- selected_result()
      if (is.null(sel)) return("")
      cov <- attr(sel, "aoi_coverage_pct") %||% "?"
      by_scale <- table(sel$priority_scale)
      scale_str <- paste(names(by_scale), by_scale, sep = ": ", collapse = ", ")
      paste0("Selected ", nrow(sel), " photos (", scale_str,
             ") \u2014 ", cov, "% AOI coverage")
    })

    output$download_ui <- shiny::renderUI({
      sel <- selected_result()
      if (is.null(sel)) return(NULL)
      shiny::downloadButton(ns("download_csv"), "Download CSV",
                            class = "btn-sm btn-outline-primary")
    })

    output$download_csv <- shiny::downloadHandler(
      filename = function() {
        paste0("photo_selection_", Sys.Date(), ".csv")
      },
      content = function(file) {
        sel <- selected_result()
        sel |>
          sf::st_drop_geometry() |>
          dplyr::select(
            airp_id, photo_year, scale, film_roll, frame_number,
            photo_tag, priority_scale,
            dplyr::any_of(c("selection_order", "cumulative_coverage_pct"))
          ) |>
          write.csv(file, row.names = FALSE)
      }
    )

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
