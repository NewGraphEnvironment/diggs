#!/usr/bin/env Rscript
#
# explore_stream_network.R
#
# Interactive map of rearing streams with blue_line_key and
# downstream_route_measure in popups. Click segments to identify
# boundary points for network extraction.
#
# Template for fresh package workflows. The raw SQL version of this
# script is in git history (commit 950e86c).
#
# Requires: SSH tunnel to newgraph DB on localhost:63333

library(fresh)
library(leaflet)
library(htmlwidgets)

# All coho rearing streams in BULK, order 4+
streams <- frs_network_prune(
  blue_line_key = 360873822,
  downstream_route_measure = 166030.4,
  stream_order_min = 4,
  watershed_group_code = "BULK",
  table = "bcfishpass.streams_co_vw",
  cols = c("segmented_stream_id", "blue_line_key", "waterbody_key",
           "downstream_route_measure", "gnis_name", "stream_order",
           "channel_width", "mapping_code", "rearing", "spawning",
           "access", "geom"),
  wscode_col = "wscode",
  localcode_col = "localcode"
)

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
