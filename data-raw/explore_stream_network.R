#!/usr/bin/env Rscript
#
# explore_stream_network.R
#
# Interactive map of rearing streams with blue_line_key and
# downstream_route_measure in popups. Click segments to identify
# the boundary points for network extraction.
#
# Requires: SSH tunnel to newgraph DB on localhost:63333
#
# Usage: Rscript scripts/explore_stream_network.R

library(sf)
library(DBI)
library(RPostgres)
library(leaflet)
library(htmlwidgets)

source("R/utils_photos.R")

# --- Connect and query ---
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# All coho rearing streams in BULK, order 4+
streams <- flood_query_habitat(conn, "BULK",
  habitat_type = "rearing",
  species_code = "co",
  min_stream_order = 4
)

DBI::dbDisconnect(conn)

# --- Build popup with blk + drm ---
streams$popup <- paste0(
  "<b>", ifelse(is.na(streams$gnis_name), "(unnamed)", streams$gnis_name), "</b><br>",
  "blk: ", streams$blue_line_key, "<br>",
  "drm: ", round(streams$downstream_route_measure), "<br>",
  "order: ", streams$stream_order, "<br>",
  "seg: ", streams$segmented_stream_id
)

# Color by stream order
pal <- colorFactor(
  palette = c("#4575b4", "#74add1", "#abd9e9", "#fee090", "#f46d43", "#d73027"),
  domain = sort(unique(streams$stream_order))
)

# --- Map ---
m <- leaflet(streams) |>
  addProviderTiles("Esri.WorldTopoMap") |>
  addPolylines(
    color = ~pal(stream_order),
    weight = ~stream_order,
    opacity = 0.8,
    popup = ~popup,
    label = ~paste0(ifelse(is.na(gnis_name), "", gnis_name),
                    " [blk:", blue_line_key, " drm:", round(downstream_route_measure), "]")
  ) |>
  addLegend(pal = pal, values = ~stream_order, title = "Stream order")

out <- "data/explore_streams.html"
saveWidget(m, file = normalizePath(out, mustWork = FALSE), selfcontained = TRUE)
message("Saved: ", out)
message("\nClick stream segments to see blk + drm values.")
message("Identify two points:")
message("  1. Downstream end of Neexdzii Kwah (mouth)")
message("  2. Upstream end of mainstem (where to cut off headwaters)")
message("\nThen we'll extract: upstream_of(mouth) - upstream_of(cutoff)")
