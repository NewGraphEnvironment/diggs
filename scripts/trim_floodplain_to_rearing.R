#!/usr/bin/env Rscript
#
# trim_floodplain_to_rearing.R
#
# Trim a floodplain polygon lengthwise to only keep areas alongside
# named streams with modelled coho rearing habitat, then buffer for
# airphoto centroid capture.
#
# Requires: SSH tunnel to newgraph DB on localhost:63333
#
# Usage:
#   source("scripts/trim_floodplain_to_rearing.R")
#
#   # Focus on mainstem + key tribs
#   trim_floodplain(
#     stream_names = c("Bulkley River", "Buck Creek", "Richfield Creek", "Byman Creek"),
#     floodplain_width = 2000,
#     photo_buffer = 1800
#   )
#
#   # Or use stream order as a broader filter
#   trim_floodplain(min_stream_order = 4)

library(sf)
library(DBI)
library(RPostgres)
library(dplyr)

#' Trim floodplain to rearing habitat alongside target streams
#'
#' @param stream_names Character vector of GNIS stream names to include.
#'   If NULL, falls back to min_stream_order filter.
#' @param min_stream_order Minimum Strahler order (used when stream_names is NULL).
#' @param floodplain_width Buffer distance (m) perpendicular to streams.
#'   Should be wide enough to capture the full floodplain width.
#'   Uses flat end caps so it doesn't extend past stream endpoints.
#' @param photo_buffer Buffer (m) around trimmed floodplain to capture
#'   photo centroids whose footprints overlap the floodplain.
#'   Set to 0 to skip (output = trimmed floodplain only).
#' @param floodplain_path Path to the floodplain polygon (geojson).
#' @param output_path Where to save the result.
#' @param wsgroup Watershed group code for bcfishpass query.
trim_floodplain <- function(
    stream_names = NULL,
    min_stream_order = 4,
    floodplain_width = 2000,
    photo_buffer = 1800,
    floodplain_path = "data/lateral_habitat.geojson",
    output_path = "data/floodplain_rearing.geojson",
    wsgroup = "BULK"
) {

  # --- Connect to newgraph DB ---
  message("Connecting to newgraph database...")
  conn <- DBI::dbConnect(
    RPostgres::Postgres(),
    host = "localhost", port = 63333,
    dbname = "bcfishpass", user = "newgraph"
  )
  on.exit(DBI::dbDisconnect(conn))

  # --- Build query based on stream_names or min_stream_order ---
  if (!is.null(stream_names)) {
    names_sql <- paste0("'", stream_names, "'", collapse = ", ")
    filter_clause <- glue::glue("AND gnis_name IN ({names_sql})")
    message("Querying rearing streams: ", paste(stream_names, collapse = ", "))
  } else {
    filter_clause <- glue::glue("AND stream_order >= {min_stream_order}")
    message("Querying rearing streams (order >= ", min_stream_order, ")...")
  }

  sql <- glue::glue("
    SELECT segmented_stream_id, blue_line_key, gnis_name, stream_order,
           channel_width, rearing_co, spawning_co, access_co,
           ST_Transform(geom, 4326) as geom
    FROM bcfishpass.streams_vw
    WHERE watershed_group_code = '{wsgroup}'
      AND rearing_co = 1
      {filter_clause}
  ")

  streams <- sf::st_read(conn, query = sql) |>
    sf::st_zm(drop = TRUE)
  message("  ", nrow(streams), " stream segments")

  # --- Load floodplain ---
  message("Loading floodplain polygon...")
  floodplain <- sf::st_read(floodplain_path, quiet = TRUE)

  # --- Project to BC Albers for accurate buffering ---
  streams_albers <- sf::st_transform(streams, 3005)
  floodplain_albers <- sf::st_transform(floodplain, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()

  # --- Flat-cap buffer: extends perpendicular to stream, not past endpoints ---
  message("Buffering streams by ", floodplain_width, "m (flat cap)...")
  streams_buffered <- sf::st_buffer(streams_albers, dist = floodplain_width,
                                    endCapStyle = "FLAT") |>
    sf::st_union() |>
    sf::st_make_valid()

  # --- Intersect with floodplain ---
  message("Intersecting with floodplain...")
  trimmed <- sf::st_intersection(streams_buffered, floodplain_albers) |>
    sf::st_make_valid()

  # --- Photo capture buffer ---
  if (photo_buffer > 0) {
    message("Adding ", photo_buffer, "m photo capture buffer...")
    result <- sf::st_buffer(trimmed, dist = photo_buffer) |>
      sf::st_make_valid() |>
      sf::st_transform(4326)
  } else {
    result <- trimmed |> sf::st_transform(4326)
  }

  # --- Build output ---
  result_sf <- sf::st_sf(
    name = "floodplain_coho_rearing",
    geometry = sf::st_geometry(result)
  )

  # --- Summary ---
  area_orig <- as.numeric(sf::st_area(floodplain_albers)) / 1e6
  area_trimmed <- as.numeric(sf::st_area(trimmed)) / 1e6
  area_final <- as.numeric(sum(sf::st_area(result))) / 1e6
  message("\nOriginal floodplain:  ", round(area_orig, 1), " km2")
  message("Trimmed floodplain:   ", round(area_trimmed, 1), " km2 (",
          round((1 - area_trimmed / area_orig) * 100), "% reduction)")
  if (photo_buffer > 0) {
    message("Photo capture zone:   ", round(area_final, 1), " km2")
  }

  # --- Save ---
  sf::st_write(result_sf, output_path, delete_dsn = TRUE, quiet = TRUE)
  message("\nSaved: ", output_path)
  message("Upload this file in the airbc app as a custom AOI.")

  invisible(result_sf)
}
