#' Map module UI
#' @param id Module namespace id
#' @noRd
mod_map_ui <- function(id) {
  ns <- shiny::NS(id)
  leaflet::leafletOutput(ns("map"), height = "75vh")
}

#' Map module server
#' @param id Module namespace id
#' @param layers Named list of sf layers from load_cached_layers
#' @param filters Return value from mod_filters_server
#' @param drawn_aoi ReactiveVal for drawn AOI polygon
#' @noRd
mod_map_server <- function(id, layers, filters, drawn_aoi) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$map <- leaflet::renderLeaflet({
      # Fit map to AOI bounds
      aoi_bb <- sf::st_bbox(layers$aoi)

      leaflet::leaflet() |>
        leaflet::fitBounds(
          lng1 = aoi_bb[["xmin"]], lat1 = aoi_bb[["ymin"]],
          lng2 = aoi_bb[["xmax"]], lat2 = aoi_bb[["ymax"]]
        ) |>
        leaflet::addProviderTiles("Esri.WorldTopoMap", group = "Topo") |>
        leaflet::addProviderTiles("Esri.WorldImagery", group = "ESRI Aerial") |>
        leaflet::addPolylines(
          data = layers$l_streams,
          color = "blue", weight = 2, opacity = 0.75,
          group = "Streams"
        ) |>
        leaflet::addPolylines(
          data = layers$l_rail,
          color = "black", weight = 2, opacity = 0.75,
          group = "Railway"
        ) |>
        leaflet::addPolygons(
          data = layers$aoi,
          color = "red", weight = 2, fillOpacity = 0,
          group = "Area of Interest"
        ) |>
        leaflet.extras::addDrawToolbar(
          targetGroup = "Drawn AOI",
          polylineOptions = FALSE,
          circleOptions = FALSE,
          rectangleOptions = FALSE,
          markerOptions = FALSE,
          circleMarkerOptions = FALSE,
          editOptions = leaflet.extras::editToolbarOptions(
            selectedPathOptions = leaflet.extras::selectedPathOptions()
          )
        ) |>
        leaflet::addLayersControl(
          baseGroups = c("Topo", "ESRI Aerial"),
          overlayGroups = c("Streams", "Railway", "Area of Interest",
                           "Centroids", "Custom AOI",
                           "Footprints", "Footprints (selected)",
                           "Footprints (unselected)"),
          options = leaflet::layersControlOptions(collapsed = FALSE)
        ) |>
        leaflet.extras::addFullscreenControl() |>
        leaflet::addScaleBar(position = "bottomleft")
    })

    # Capture drawn polygon
    shiny::observeEvent(input$map_draw_new_feature, {
      drawn_aoi(drawn_feature_to_sf(input$map_draw_new_feature))
    })

    shiny::observeEvent(input$map_draw_deleted_features, {
      drawn_aoi(NULL)
    })

    # Display uploaded/custom AOI on map
    shiny::observe({
      custom <- filters$custom_aoi()
      leaflet::leafletProxy("map") |>
        leaflet::clearGroup("Custom AOI")

      if (!is.null(custom)) {
        leaflet::leafletProxy("map") |>
          leaflet::addPolygons(
            data = custom,
            color = "red", weight = 3, fillOpacity = 0.1,
            fillColor = "red",
            group = "Custom AOI"
          )
      }
    })

    # Update centroids on map when filters change
    shiny::observe({
      dat <- filters$filtered_data()
      if (is.null(dat) || nrow(dat) == 0) {
        leaflet::leafletProxy("map") |>
          leaflet::clearGroup("Centroids") |>
          leaflet::clearMarkerClusters()
        return()
      }

      leaflet::leafletProxy("map") |>
        leaflet::clearGroup("Centroids") |>
        leaflet::clearMarkerClusters() |>
        leaflet::addCircleMarkers(
          data = dat,
          radius = 2,
          fillColor = "red",
          color = "darkred",
          stroke = TRUE,
          fillOpacity = 0.7,
          weight = 1,
          opacity = 0.8,
          group = "Centroids",
          clusterOptions = leaflet::markerClusterOptions(
            maxClusterRadius = 40
          ),
          popup = ~paste0(
            "<b>", airp_id, "</b><br>",
            "Year: ", photo_year, "<br>",
            "Scale: ", scale, "<br>",
            "Media: ", media
          )
        )
    })

    # Show footprints on button click (button is in parent app.R sidebar)
    shiny::observeEvent(filters$show_footprints(), {
      bounds <- input$map_bounds
      dat <- filters$filtered_data()
      sel <- filters$selected_data()

      leaflet::leafletProxy("map") |>
        leaflet::clearGroup("Footprints") |>
        leaflet::clearGroup("Footprints (selected)") |>
        leaflet::clearGroup("Footprints (unselected)")

      if (is.null(bounds) || is.null(dat) || nrow(dat) == 0) return()

      # Clip to current viewport
      bbox <- sf::st_bbox(c(
        xmin = bounds$west, ymin = bounds$south,
        xmax = bounds$east, ymax = bounds$north
      ), crs = 4326)
      viewport <- sf::st_as_sfc(bbox)
      dat_visible <- suppressWarnings(
        dat[sf::st_intersects(dat, viewport, sparse = FALSE)[, 1], ]
      )

      if (nrow(dat_visible) == 0) {
        shiny::showNotification("No centroids in current view", type = "warning")
        return()
      }

      if (nrow(dat_visible) > 500) {
        shiny::showNotification(
          paste0("Too many points (", nrow(dat_visible), "). Zoom in or filter to < 500."),
          type = "warning"
        )
        return()
      }

      # If selection exists, split into selected vs unselected
      if (!is.null(sel) && nrow(sel) > 0) {
        selected_ids <- sel$airp_id
        dat_sel <- dat_visible[dat_visible$airp_id %in% selected_ids, ]
        dat_unsel <- dat_visible[!dat_visible$airp_id %in% selected_ids, ]

        make_popup <- function(d) {
          paste0("<b>", d$airp_id, "</b><br>",
                 "Year: ", d$photo_year, "<br>",
                 "Scale: ", d$scale)
        }

        shiny::withProgress(message = "Computing footprints...", {
          if (nrow(dat_sel) > 0) {
            fp_sel <- fly::fly_footprint(dat_sel)
            leaflet::leafletProxy("map") |>
              leaflet::addPolygons(
                data = fp_sel,
                color = "blue", weight = 1.5, fillOpacity = 0.08,
                fillColor = "blue",
                group = "Footprints (selected)",
                popup = make_popup(dat_sel)
              )
          }
          if (nrow(dat_unsel) > 0) {
            fp_unsel <- fly::fly_footprint(dat_unsel)
            leaflet::leafletProxy("map") |>
              leaflet::addPolygons(
                data = fp_unsel,
                color = "grey", weight = 0.5, fillOpacity = 0.03,
                fillColor = "grey",
                group = "Footprints (unselected)",
                popup = make_popup(dat_unsel)
              )
          }
        })

        shiny::showNotification(
          paste0(nrow(dat_sel), " selected + ", nrow(dat_unsel), " unselected footprints"),
          type = "message"
        )
      } else {
        # No selection — show all footprints
        shiny::withProgress(message = "Computing footprints...", {
          footprints <- fly::fly_footprint(dat_visible)
        })

        leaflet::leafletProxy("map") |>
          leaflet::addPolygons(
            data = footprints,
            color = "black", weight = 1, fillOpacity = 0,
            group = "Footprints",
            popup = ~paste0(
              "<b>", airp_id, "</b><br>",
              "Year: ", photo_year, "<br>",
              "Scale: ", scale
            )
          )

        shiny::showNotification(
          paste0("Showing ", nrow(dat_visible), " footprints"),
          type = "message"
        )
      }
    })
  })
}
