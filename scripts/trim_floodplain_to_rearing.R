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

# Neexdzii Kwah (Bulkley) mainstem boundary points
mouth_blk <- 360873822
mouth_drm <- 188578
cutoff_blk <- 360873822
cutoff_drm <- 229690
min_order <- 4

# --- Connect and query ---
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# Coho rearing streams within the Neexdzii Kwah reach, 4th order+
# Uses network extraction pattern: mainstem by DRM range, tribs by FWA_Upstream
sql <- glue::glue("
  WITH mouth AS (
    SELECT wscode, localcode
    FROM bcfishpass.streams_co_vw
    WHERE blue_line_key = {mouth_blk}
      AND downstream_route_measure <= {mouth_drm}
    ORDER BY downstream_route_measure DESC
    LIMIT 1
  ),
  cutoff AS (
    SELECT wscode, localcode
    FROM bcfishpass.streams_co_vw
    WHERE blue_line_key = {cutoff_blk}
      AND downstream_route_measure <= {cutoff_drm}
    ORDER BY downstream_route_measure DESC
    LIMIT 1
  )
  -- Mainstem: DRM range
  SELECT s.segmented_stream_id, s.blue_line_key, s.waterbody_key,
         s.downstream_route_measure, s.gnis_name, s.stream_order,
         s.channel_width,
         ST_Transform(s.geom, 4326) as geom
  FROM bcfishpass.streams_co_vw s
  WHERE s.blue_line_key = {mouth_blk}
    AND s.downstream_route_measure >= {mouth_drm}
    AND s.downstream_route_measure <= {cutoff_drm}
    AND s.stream_order >= {min_order}

  UNION ALL

  -- Tributaries: upstream of mouth, not upstream of cutoff
  SELECT s.segmented_stream_id, s.blue_line_key, s.waterbody_key,
         s.downstream_route_measure, s.gnis_name, s.stream_order,
         s.channel_width,
         ST_Transform(s.geom, 4326) as geom
  FROM bcfishpass.streams_co_vw s, mouth m
  WHERE s.watershed_group_code = 'BULK'
    AND s.blue_line_key != {mouth_blk}
    AND s.stream_order >= {min_order}
    AND FWA_Upstream(
      m.wscode, m.localcode,
      s.wscode, s.localcode
    )
    AND NOT EXISTS (
      SELECT 1 FROM cutoff c
      WHERE FWA_Upstream(
        c.wscode, c.localcode,
        s.wscode, s.localcode
      )
    )
")

message("Querying co rearing network (order >= ", min_order, ")...")
streams <- sf::st_read(conn, query = sql) |>
  sf::st_zm(drop = TRUE)
message("  ", nrow(streams), " segments")
message("  Streams: ", paste(unique(na.omit(streams$gnis_name)), collapse = ", "))

# Query lake polygons that intersect the rearing streams
lakes <- flood_query_lakes(conn, streams)

DBI::dbDisconnect(conn)

# --- Trim floodplain ---
floodplain <- sf::st_read(floodplain_path, quiet = TRUE)

# Trimmed floodplain (no buffer) — the actual AOI for coverage analysis
trimmed <- flood_trim_habitat(floodplain, streams,
  lakes_sf = lakes,
  floodplain_width = 2000,
  photo_buffer = 0
)

sf::st_write(trimmed, output_path, delete_dsn = TRUE, quiet = TRUE)
message("\nSaved: ", output_path)

# Buffered capture zone — centroids in here have footprints landing in the AOI
# Buffer = half the max footprint width (1:31680 → 3621m)
capture_path <- "data/floodplain_rearing_capture.geojson"
capture_zone <- flood_trim_habitat(floodplain, streams,
  lakes_sf = lakes,
  floodplain_width = 2000,
  photo_buffer = 3600
)

sf::st_write(capture_zone, capture_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", capture_path, " (upload to app for footprint-aware filtering)")
