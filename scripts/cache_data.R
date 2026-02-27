#!/usr/bin/env Rscript
#
# cache_data.R
#
# One-time script to download and cache reference layers + photo centroids
# for the airbc Shiny app. Run this before launching the app.
#
# Usage: Rscript scripts/cache_data.R
#
# Parameters are set for the Neexdzii Kwah (Upper Bulkley) watershed.
# Adjust blk/drm to target a different watershed.

library(sf)
library(dplyr)
library(purrr)
library(fwapgr)
library(bcdata)
library(janitor)
library(fs)

# --- Parameters ---
blk <- 360873822          # blue_line_key for Bulkley River
drm <- 166030.4           # downstream_route_measure at Neexdzii Kwa / Wedzin Kwa confluence
buf <- 1500               # buffer in meters (approx half photo width)
data_dir <- "data"

fs::dir_create(data_dir)

# --- Helper ---
validate_geometry <- function(layer) {
  layer <- sf::st_make_valid(layer)
  layer[sf::st_is_valid(layer), ]
}

save_layer <- function(layer, name) {
  path <- fs::path(data_dir, name, ext = "geojson")
  sf::st_write(layer, path, delete_dsn = TRUE, quiet = TRUE)
  message("Saved: ", path)
}

# --- AOI ---
message("Generating watershed AOI...")
aoi_raw <- fwapgr::fwa_watershed_at_measure(
  blue_line_key = blk,
  downstream_route_measure = drm
) |>
  sf::st_transform(32609) |>
  dplyr::select(geometry)

aoi_buffered <- sf::st_buffer(aoi_raw, dist = buf) |>
  sf::st_transform(4326)

aoi_raw <- aoi_raw |> sf::st_transform(4326)

aoi_raw <- validate_geometry(aoi_raw)
aoi_buffered <- validate_geometry(aoi_buffered)

save_layer(aoi_raw, "aoi_raw")
save_layer(aoi_buffered, "aoi")

# --- Reference layers (using bcdata directly) ---
message("Downloading streams...")
l_streams <- bcdata::bcdc_query_geodata("92344413-8035-4c08-b996-65a9b3f62fca") |>
  bcdata::filter(WATERSHED_GROUP_CODE == "BULK") |>
  bcdata::select(
    LINEAR_FEATURE_ID, STREAM_ORDER, GNIS_NAME,
    DOWNSTREAM_ROUTE_MEASURE, BLUE_LINE_KEY, LENGTH_METRE
  ) |>
  bcdata::collect() |>
  sf::st_transform(4326) |>
  janitor::clean_names() |>
  dplyr::filter(stream_order >= 4)

message("Downloading railways...")
l_rail <- bcdata::bcdc_query_geodata("4ff93cda-9f58-4055-a372-98c22d04a9f8") |>
  bcdata::collect() |>
  sf::st_transform(4326) |>
  janitor::clean_names()

message("Downloading NTS 50k grid...")
l_imagery_grid <- bcdata::bcdc_query_geodata("f9483429-fedd-4704-89b9-49fd098d4bdb") |>
  bcdata::collect() |>
  sf::st_transform(4326) |>
  janitor::clean_names()

# --- Clip reference layers to AOI ---
message("Clipping layers to AOI...")
layers <- list(
  l_streams = l_streams,
  l_rail = l_rail,
  l_imagery_grid = l_imagery_grid
)

layers <- purrr::map(layers, validate_geometry)
layers <- purrr::map(layers, \(x) sf::st_intersection(x, aoi_buffered))

purrr::walk2(layers, names(layers), save_layer)

# --- Photo centroids (query by NTS tile) ---
message("Downloading photo centroids by NTS tile...")
nts_tiles <- layers$l_imagery_grid |>
  dplyr::pull(map_tile)

message("NTS tiles: ", paste(nts_tiles, collapse = ", "))

# Query centroids for each NTS tile and combine
l_photo_centroids <- purrr::map(nts_tiles, \(tile) {
  message("  Fetching tile: ", tile)
  bcdata::bcdc_query_geodata("0af7544c-f2ad-4553-bb37-889c94d4c571") |>
    bcdata::filter(NTS_TILE == !!tile) |>
    bcdata::collect()
}) |>
  dplyr::bind_rows() |>
  sf::st_transform(4326) |>
  janitor::clean_names()

l_photo_centroids <- validate_geometry(l_photo_centroids)
l_photo_centroids <- sf::st_intersection(l_photo_centroids, aoi_buffered)

save_layer(l_photo_centroids, "l_photo_centroids")

message("\nDone! Cached layers in ", data_dir, "/")
message("Photo centroids: ", nrow(l_photo_centroids), " records")
message("Date range: ", paste(range(l_photo_centroids$photo_date), collapse = " to "))
