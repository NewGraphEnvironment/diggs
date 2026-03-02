#!/usr/bin/env Rscript
#
# trim_floodplain_to_rearing.R
#
# Worked example: trim the Bulkley floodplain to coho rearing habitat
# alongside key streams, then check photo coverage by decade.
#
# Requires: SSH tunnel to newgraph DB on localhost:63333
#
# Usage: Rscript scripts/trim_floodplain_to_rearing.R

library(sf)
library(DBI)
library(RPostgres)
library(dplyr)

source("R/utils_geo.R")
source("R/utils_photos.R")

# --- Parameters ---
floodplain_path <- "data/lateral_habitat.geojson"
output_path <- "data/floodplain_rearing.geojson"

# --- Connect and query ---
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# By name (convenience — unique within BULK)
streams <- flood_query_habitat(conn, "BULK",
  habitat_type = "rearing",
  species_code = "co",
  stream_names = c("Bulkley River", "Buck Creek", "Richfield Creek", "Byman Creek")
)

DBI::dbDisconnect(conn)

# --- Trim floodplain ---
floodplain <- sf::st_read(floodplain_path, quiet = TRUE)

trimmed <- flood_trim_habitat(floodplain, streams,
  floodplain_width = 2000,
  photo_buffer = 0          # no capture buffer — just the trimmed floodplain
)

sf::st_write(trimmed, output_path, delete_dsn = TRUE, quiet = TRUE)
message("\nSaved: ", output_path)

# --- Photo summary ---
photos <- sf::st_read("data/l_photo_centroids.geojson", quiet = TRUE)
message("\n--- Footprint Summary ---")
print(flood_photo_summary(photos))

# --- Coverage by year (1960s) ---
# Use the trimmed floodplain (no photo buffer) as the target
photos_60s <- photos |> dplyr::filter(photo_year <= 1969)

# Filter to photos whose centroids are within capture distance
capture_zone <- flood_trim_habitat(floodplain, streams,
  floodplain_width = 2000,
  photo_buffer = 1800
)
inside <- sf::st_intersects(photos_60s, capture_zone, sparse = FALSE)[, 1]
photos_60s <- photos_60s[inside, ]

message("\n--- 1960s Coverage ---")
print(flood_photo_coverage(photos_60s, trimmed))
