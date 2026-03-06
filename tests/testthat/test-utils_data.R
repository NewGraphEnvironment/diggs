test_that("load_cached_layers errors when no geojson files found", {
  tmp <- tempdir()
  empty_dir <- file.path(tmp, "empty_layers")
  dir.create(empty_dir, showWarnings = FALSE)

  expect_error(
    load_cached_layers(empty_dir),
    "No geojson files found"
  )
})

test_that("load_cached_layers returns named list of sf objects", {
  tmp <- tempdir()
  test_dir <- file.path(tmp, "test_layers")
  dir.create(test_dir, showWarnings = FALSE)

  # Write a small test geojson
  pt <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(sf::st_point(c(-125, 54)), crs = 4326)
  )
  sf::st_write(pt, file.path(test_dir, "my_layer.geojson"),
               delete_dsn = TRUE, quiet = TRUE)

  result <- load_cached_layers(test_dir)

  expect_type(result, "list")
  expect_named(result, "my_layer")
  expect_s3_class(result$my_layer, "sf")
})
