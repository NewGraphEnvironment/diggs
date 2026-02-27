#' Validate and repair geometries
#'
#' @param layer An sf object
#' @return An sf object with only valid geometries
validate_geometry <- function(layer) {
  layer <- sf::st_make_valid(layer)
  layer[sf::st_is_valid(layer), ]
}


#' Estimate photo footprint polygons from centroids and scale
#'
#' Creates rectangular polygons representing the estimated ground coverage
#' of each airphoto, based on a 9" x 9" negative and the reported scale.
#'
#' @param centroids_sf An sf point object with a `scale` column (e.g. "1:31680")
#' @return An sf polygon object with footprint rectangles
estimate_footprint <- function(centroids_sf) {
  centroids_sf |>
    sf::st_transform(crs = 32609) |>
    dplyr::mutate(
      scale_parsed = as.numeric(stringr::str_remove(scale, "1:")),
      width_m = 9 * scale_parsed * 0.0254,
      height_m = 9 * scale_parsed * 0.0254
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      geometry = list({
        center <- sf::st_coordinates(geometry)
        w <- width_m / 2
        h <- height_m / 2
        corners <- matrix(c(
          center[1] - w, center[2] - h,
          center[1] + w, center[2] - h,
          center[1] + w, center[2] + h,
          center[1] - w, center[2] + h,
          center[1] - w, center[2] - h
        ), ncol = 2, byrow = TRUE)
        sf::st_polygon(list(corners))
      })
    ) |>
    dplyr::ungroup() |>
    sf::st_as_sf(sf_column_name = "geometry") |>
    sf::st_set_crs(32609) |>
    sf::st_transform(crs = 4326)
}


#' Convert leaflet draw toolbar GeoJSON to sf polygon
#'
#' @param feature The feature object from input$map_draw_new_feature
#' @return An sf polygon object in WGS84
drawn_feature_to_sf <- function(feature) {
  coords <- feature$geometry$coordinates[[1]]
  coords_mat <- do.call(rbind, lapply(coords, function(c) c(c[[1]], c[[2]])))
  poly <- sf::st_polygon(list(coords_mat))
  sf::st_sfc(poly, crs = 4326) |> sf::st_sf()
}
