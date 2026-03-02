#!/usr/bin/env Rscript
#
# extract_network.R
#
# Extract a stream network between two points on a mainstem using FWA
# linear referencing: upstream_of(mouth) - upstream_of(cutoff)
#
# Requires: SSH tunnel to newgraph DB on localhost:63333

library(sf)
library(DBI)
library(RPostgres)
library(leaflet)
library(htmlwidgets)

# --- Boundary points ---
mouth_blk <- 360873822
mouth_drm <- 188578

cutoff_blk <- 360873822
cutoff_drm <- 229690

min_order <- 4

# --- Connect ---
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# --- Extract network between two points ---
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
         s.channel_width, s.mapping_code, s.rearing, s.spawning, s.access,
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
         s.channel_width, s.mapping_code, s.rearing, s.spawning, s.access,
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

message("Querying network between drm ", mouth_drm, " and ", cutoff_drm,
        " on blk ", mouth_blk, " (order >= ", min_order, ")...")
network <- sf::st_read(conn, query = sql) |>
  sf::st_zm(drop = TRUE)

DBI::dbDisconnect(conn)

message("  ", nrow(network), " segments")
message("  Streams: ", paste(unique(na.omit(network$gnis_name)), collapse = ", "))
message("  Orders: ", paste(sort(unique(network$stream_order)), collapse = ", "))

# --- Map ---
network$popup <- paste0(
  "<b>", ifelse(is.na(network$gnis_name), "(unnamed)", network$gnis_name), "</b><br>",
  "blk: ", network$blue_line_key, "<br>",
  "drm: ", round(network$downstream_route_measure), "<br>",
  "order: ", network$stream_order
)

m <- leaflet(network) |>
  addProviderTiles("Esri.WorldTopoMap") |>
  addPolylines(
    color = "#08306b",
    weight = 3,
    opacity = 0.9,
    popup = ~popup
  )

out <- "data/extract_network.html"
saveWidget(m, file = normalizePath(out, mustWork = FALSE), selfcontained = TRUE)
message("\nSaved: ", out)
