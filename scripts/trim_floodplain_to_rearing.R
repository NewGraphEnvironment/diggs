#!/usr/bin/env Rscript
#
# trim_floodplain_to_rearing.R
#
# Trim the lateral habitat (floodplain) polygon to areas near streams with
# modelled coho rearing habitat, using bcfishpass.streams_vw from the
# newgraph database.
#
# Requires: SSH tunnel to newgraph DB on localhost:63333
#
# Usage: Rscript scripts/trim_floodplain_to_rearing.R
#
# Output: data/floodplain_rearing.geojson — upload as custom AOI in airbc app

library(sf)
library(DBI)
library(RPostgres)
library(dplyr)

# --- Parameters ---
floodplain_path <- "data/lateral_habitat.geojson"
output_path <- "data/floodplain_rearing.geojson"
wsgroup <- "BULK"
min_stream_order <- 3        # drop order 1-2 headwaters (sparse rearing, outside floodplain)
stream_buffer_m <- 500       # buffer around rearing streams
outer_buffer_m <- 200        # extra buffer to catch overlapping photo footprints

# --- Connect to newgraph DB ---
message("Connecting to newgraph database...")
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)
on.exit(DBI::dbDisconnect(conn))

# --- Query coho rearing streams ---
message("Querying coho rearing streams (order >= ", min_stream_order, ")...")
sql <- glue::glue("
  SELECT segmented_stream_id, blue_line_key, gnis_name, stream_order,
         channel_width, rearing_co, spawning_co, access_co,
         ST_Transform(geom, 4326) as geom
  FROM bcfishpass.streams_vw
  WHERE watershed_group_code = '{wsgroup}'
    AND rearing_co = 1
    AND stream_order >= {min_stream_order}
")

streams <- sf::st_read(conn, query = sql) |>
  sf::st_zm(drop = TRUE)   # bcfishpass geometries have M/Z — GEOS needs XY only
message("  ", nrow(streams), " stream segments")

# --- Load floodplain ---
message("Loading floodplain polygon...")
floodplain <- sf::st_read(floodplain_path, quiet = TRUE)

# --- Buffer rearing streams ---
# Project to BC Albers for accurate buffering, then back to 4326
message("Buffering rearing streams by ", stream_buffer_m, "m...")
streams_albers <- sf::st_transform(streams, 3005)
streams_buffered <- sf::st_buffer(streams_albers, dist = stream_buffer_m) |>
  sf::st_union() |>
  sf::st_make_valid()

# --- Intersect with floodplain ---
message("Intersecting with floodplain...")
floodplain_albers <- sf::st_transform(floodplain, 3005) |>
  sf::st_union() |>
  sf::st_make_valid()

trimmed <- sf::st_intersection(streams_buffered, floodplain_albers) |>
  sf::st_make_valid()

# --- Add outer buffer for photo footprint capture ---
message("Adding ", outer_buffer_m, "m outer buffer...")
trimmed_buffered <- sf::st_buffer(trimmed, dist = outer_buffer_m) |>
  sf::st_make_valid()

# --- Re-clip to floodplain extent (buffer may exceed original bounds) ---
trimmed_final <- sf::st_intersection(trimmed_buffered, floodplain_albers) |>
  sf::st_make_valid() |>
  sf::st_transform(4326)

# Convert to sf data.frame for writing
trimmed_sf <- sf::st_sf(
  name = "floodplain_coho_rearing",
  geometry = sf::st_geometry(trimmed_final)
)

# --- Summary ---
area_orig <- as.numeric(sf::st_area(floodplain_albers)) / 1e6
area_trimmed <- as.numeric(sum(sf::st_area(trimmed_final))) / 1e6
message("\nFloodplain area: ", round(area_orig, 1), " km2")
message("Trimmed area:    ", round(area_trimmed, 1), " km2")
message("Reduction:       ", round((1 - area_trimmed / area_orig) * 100, 0), "%")

# --- Save ---
sf::st_write(trimmed_sf, output_path, delete_dsn = TRUE, quiet = TRUE)
message("\nSaved: ", output_path)
message("Upload this file in the airbc app as a custom AOI.")
