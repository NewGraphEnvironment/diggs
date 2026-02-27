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
library(rfp)
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

# --- Reference layers ---
message("Downloading streams...")
l_streams <- rfp::rfp_bcd_get_data(
  bcdata_record_id = "whse_basemapping.fwa_stream_networks_sp",
  col_filter = "watershed_group_code",
  col_filter_value = "BULK",
  col_extract = c(
    "linear_feature_id", "stream_order", "gnis_name",
    "downstream_route_measure", "blue_line_key", "length_metre"
  )
) |>
  sf::st_transform(4326) |>
  janitor::clean_names() |>
  dplyr::filter(stream_order >= 4)

message("Downloading railways...")
l_rail <- rfp::rfp_bcd_get_data(
  bcdata_record_id = "whse_basemapping.gba_railway_tracks_sp"
) |>
  sf::st_transform(4326) |>
  janitor::clean_names()

message("Downloading NTS 50k grid...")
l_imagery_grid <- rfp::rfp_bcd_get_data(
  bcdata_record_id = "WHSE_BASEMAPPING.NTS_50K_GRID"
) |>
  sf::st_transform(4326)

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

l_photo_centroids <- rfp::rfp_bcd_get_data(
  bcdata_record_id = "WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP",
  col_filter = "nts_tile",
  col_filter_value = nts_tiles
) |>
  sf::st_transform(4326)

l_photo_centroids <- validate_geometry(l_photo_centroids)
l_photo_centroids <- sf::st_intersection(l_photo_centroids, aoi_buffered)

save_layer(l_photo_centroids, "l_photo_centroids")

message("\nDone! Cached layers in ", data_dir, "/")
message("Photo centroids: ", nrow(l_photo_centroids), " records")
message("Date range: ", paste(range(l_photo_centroids$photo_date), collapse = " to "))
