#!/usr/bin/env Rscript
#
# network_extract.R
#
# Extract a stream network between two points using fresh.
# Uses frs_network() with upstream_measure for network subtraction:
# upstream_of(mouth) - upstream_of(cutoff).
#
# Template for fresh package workflows. The raw SQL version of this
# script is in git history (commit 950e86c).
#
# Requires: SSH tunnel to newgraph DB on localhost:63333

library(fresh)
library(leaflet)
library(htmlwidgets)

# --- Boundary points ---
mouth_blk <- 360873822
mouth_drm <- 216733
cutoff_drm <- 222000
min_order <- 4

# --- Extract network between two points ---
network <- frs_network(
  blue_line_key = mouth_blk,
  downstream_route_measure = mouth_drm,
  upstream_measure = cutoff_drm,
  tables = list(
    streams = list(
      table = "bcfishpass.streams_co_vw",
      cols = c("segmented_stream_id", "blue_line_key", "waterbody_key",
               "downstream_route_measure", "gnis_name", "stream_order",
               "channel_width", "mapping_code", "rearing", "spawning",
               "access", "geom"),
      wscode_col = "wscode",
      localcode_col = "localcode",
      extra_where = paste0("s.stream_order >= ", min_order)
    )
  )
)

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

out_html <- "data/extract_network.html"
saveWidget(m, file = normalizePath(out_html, mustWork = FALSE), selfcontained = TRUE)
message("Saved: ", out_html)
