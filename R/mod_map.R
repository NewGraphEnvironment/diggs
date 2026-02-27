# Map module - leaflet with draw toolbar and reference layers

mod_map_ui <- function(id) {
  ns <- shiny::NS(id)
  leaflet::leafletOutput(ns("map"), height = "65vh")
}

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
          color = "yellow", weight = 2, fillOpacity = 0,
          group = "AOI (buffered)"
        ) |>
        leaflet::addPolygons(
          data = layers$aoi_raw,
          color = "black", weight = 2, fillOpacity = 0,
          group = "AOI (raw)"
        ) |>
        leaflet.extras::addDrawToolbar(
          targetGroup = "custom_aoi",
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
          overlayGroups = c("Streams", "Railway", "AOI (buffered)", "AOI (raw)",
                           "Centroids", "Footprints"),
          options = leaflet::layersControlOptions(collapsed = FALSE)
        ) |>
        leaflet::hideGroup("Footprints") |>
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

    # Update centroids on map when filters change
    shiny::observe({
      dat <- filters$filtered_data()
      if (is.null(dat) || nrow(dat) == 0) {
        leaflet::leafletProxy("map") |>
          leaflet::clearGroup("Centroids") |>
          leaflet::clearGroup("Footprints")
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

    list(drawn_aoi = drawn_aoi)
  })
}
