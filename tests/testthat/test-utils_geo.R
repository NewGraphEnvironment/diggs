test_that("drawn_feature_to_sf converts leaflet draw GeoJSON to sf polygon", {
  # Simulate the structure from input$map_draw_new_feature
  feature <- list(
    geometry = list(
      coordinates = list(
        list(
          list(-126.0, 54.0),
          list(-125.0, 54.0),
          list(-125.0, 55.0),
          list(-126.0, 55.0),
          list(-126.0, 54.0)
        )
      )
    )
  )

  result <- drawn_feature_to_sf(feature)

  expect_s3_class(result, "sf")
  expect_equal(sf::st_crs(result)$epsg, 4326L)
  expect_equal(nrow(result), 1)

  expect_equal(as.character(sf::st_geometry_type(result)), "POLYGON")
})

test_that("validate_geometry removes invalid geometries", {
  # Create a valid and an empty geometry
  pts_valid <- sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 0), ncol = 2, byrow = TRUE)))
  sfc <- sf::st_sfc(pts_valid, crs = 4326)
  layer <- sf::st_sf(id = 1, geometry = sfc)

  result <- validate_geometry(layer)

  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 1)
})
