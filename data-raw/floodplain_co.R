#!/usr/bin/env Rscript
#
# floodplain_co.R
#
# Generate floodplain polygons for coho habitat using the flooded VCA pipeline
# with fresh for stream network queries. Includes waterbody fill, dual stream
# order for connectivity, and falls exclusion.
#
# Parameters (blk, drm) define the downstream reference point — adjust to
# target a different watershed.
#
# Requires:
#   - SSH tunnel: ssh -L 63333:<db_host>:5432 <ssh_host>
#   - R packages: flooded, fresh, sf, terra
#
# Output (4 AOI variants + supporting layers):
#   data/floodplain_co_vca.geojson          — raw VCA + waterbodies (no patch cleanup)
#   data/floodplain_co_anchor4.geojson      — patch cleanup with order 4+ anchor
#   data/floodplain_co.geojson              — patch cleanup with order 2+ anchor (full)
#   data/floodplain_co_accessible.geojson   — order 2+ anchor, falls excluded
#   data/floodplain_co.tif                  — raster (order 2+ anchor)
#   data/falls.geojson                      — falls points
#   data/ws_upstream_falls.geojson          — upstream watersheds to exclude

library(flooded)
library(fresh)
library(sf)
library(terra)

# --- Parameters ---
# Neexdzii Kwah / Wedzin Kwa confluence on the Bulkley mainstem
blk <- 360873822
drm <- 166030.4
min_order_vca <- 4     # stream order for VCA input
min_order_anchor <- 2  # stream order for connectivity check
buf <- 2000            # buffer around streams for DEM crop (metres)

# Falls — natural barriers defining accessible habitat
falls <- list(
  list(name = "Bulkley Falls", lon = -126.2492, lat = 54.46086),
  list(name = "Buck Falls", lon = -126.504281, lat = 54.188549)
)

# Source rasters from bcfishpass
dem_path <- "/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/dem.tif"
slope_path <- "/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/slope.tif"

fs::dir_create(here::here("data"))

# ==========================================================================
# 1. Stream network queries
# ==========================================================================

message("Querying order ", min_order_vca, "+ streams (VCA input)...")
streams_vca <- frs_network_prune(
  blue_line_key = blk, downstream_route_measure = drm,
  stream_order_min = min_order_vca, watershed_group_code = "BULK",
  table = "bcfishpass.streams_co_vw",
  cols = c("segmented_stream_id", "blue_line_key", "waterbody_key",
           "downstream_route_measure", "upstream_area_ha",
           "map_upstream", "gnis_name", "stream_order", "channel_width",
           "mapping_code", "rearing", "spawning", "access", "geom"),
  wscode_col = "wscode", localcode_col = "localcode"
) |> sf::st_zm(drop = TRUE)
message("  ", nrow(streams_vca), " segments")

message("Querying order ", min_order_anchor, "+ streams (connectivity anchor)...")
streams_anchor <- frs_network_prune(
  blue_line_key = blk, downstream_route_measure = drm,
  stream_order_min = min_order_anchor, watershed_group_code = "BULK",
  table = "bcfishpass.streams_co_vw",
  cols = c("segmented_stream_id", "blue_line_key", "upstream_area_ha",
           "stream_order", "geom"),
  wscode_col = "wscode", localcode_col = "localcode"
) |> sf::st_zm(drop = TRUE)
message("  ", nrow(streams_anchor), " segments")

message("Querying waterbodies (lakes + wetlands)...")
wb <- frs_network(
  blue_line_key = blk, downstream_route_measure = drm,
  tables = list(
    lakes = "whse_basemapping.fwa_lakes_poly",
    wetlands = "whse_basemapping.fwa_wetlands_poly"
  )
)
waterbodies <- rbind(
  wb$lakes[, "geom"] |> sf::st_zm(drop = TRUE),
  wb$wetlands[, "geom"] |> sf::st_zm(drop = TRUE)
)
message("  ", nrow(waterbodies), " waterbodies")

# ==========================================================================
# 2. VCA with waterbodies + channel buffer
# ==========================================================================

message("Loading DEM and slope...")
dem <- terra::crop(terra::rast(dem_path), terra::ext(terra::vect(streams_vca)) + buf)
slope <- terra::crop(terra::rast(slope_path), terra::ext(terra::vect(streams_vca)) + buf)

message("Rasterizing streams...")
precip_r <- fl_stream_rasterize(streams_vca, dem, field = "map_upstream")

message("Running VCA (with waterbodies + channel buffer)...")
valleys <- fl_valley_confine(
  dem, streams_vca,
  field = "upstream_area_ha",
  slope = slope, slope_threshold = 9, max_width = 2000,
  cost_threshold = 2500, flood_factor = 6, precip = precip_r,
  size_threshold = 5000, hole_threshold = 2500,
  waterbodies = waterbodies
)

n_vca <- sum(terra::values(valleys) == 1, na.rm = TRUE)
cell_area <- prod(terra::res(dem))
message("  VCA: ", n_vca, " cells (", round(n_vca * cell_area / 10000, 1), " ha)")

# Write raw VCA output (variant 1)
message("Writing raw VCA + waterbodies output...")
vca_poly <- fl_valley_poly(valleys)
sf::st_write(sf::st_transform(vca_poly, 4326),
             here::here("data", "floodplain_co_vca.geojson"),
             delete_dsn = TRUE, quiet = TRUE)

# ==========================================================================
# 3. Patch cleanup — anchor order 4+ (variant 2)
# ==========================================================================

message("Building anchor raster from order ", min_order_vca, "+ streams...")
anchor_r4 <- fl_stream_rasterize(streams_vca, dem, field = "upstream_area_ha")

message("Cleaning with order ", min_order_vca, "+ anchor...")
valleys_a4 <- fl_patch_conn(valleys, anchor_r4)
valleys_a4 <- fl_patch_rm(valleys_a4, min_area = 5000)
n_a4 <- sum(terra::values(valleys_a4) == 1, na.rm = TRUE)
message("  Anchor 4+: ", round(n_a4 * cell_area / 10000, 1), " ha")

a4_poly <- fl_valley_poly(valleys_a4)
sf::st_write(sf::st_transform(a4_poly, 4326),
             here::here("data", "floodplain_co_anchor4.geojson"),
             delete_dsn = TRUE, quiet = TRUE)

# ==========================================================================
# 4. Patch cleanup — anchor order 2+ (variant 3, primary)
# ==========================================================================

message("Building anchor raster from order ", min_order_anchor, "+ streams...")
anchor_r <- fl_stream_rasterize(streams_anchor, dem, field = "upstream_area_ha")

message("Removing disconnected patches...")
valleys <- fl_patch_conn(valleys, anchor_r)
n_conn <- sum(terra::values(valleys) == 1, na.rm = TRUE)
message("  Kept ", round(n_conn * cell_area / 10000, 1), " ha (dropped ",
        round((n_vca - n_conn) * cell_area / 10000, 1), " ha disconnected)")

message("Removing small patches (< 5000 m²)...")
valleys <- fl_patch_rm(valleys, min_area = 5000)
n_clean <- sum(terra::values(valleys) == 1, na.rm = TRUE)
message("  Kept ", round(n_clean * cell_area / 10000, 1), " ha (dropped ",
        round((n_conn - n_clean) * cell_area / 10000, 1), " ha small)")

# ==========================================================================
# 5. Write primary floodplain outputs (order 2+ anchor)
# ==========================================================================

message("Polygonizing...")
valleys_poly <- fl_valley_poly(valleys)

terra::writeRaster(valleys, here::here("data", "floodplain_co.tif"), overwrite = TRUE)
valleys_4326 <- sf::st_transform(valleys_poly, 4326)
sf::st_write(valleys_4326, here::here("data", "floodplain_co.geojson"),
             delete_dsn = TRUE, quiet = TRUE)
message("  Full floodplain: ", round(n_clean * cell_area / 10000, 1), " ha")

# ==========================================================================
# 6. Falls exclusion — accessible habitat only (variant 4)
# ==========================================================================

message("\nSnapping falls and delineating upstream watersheds...")
ws_list <- lapply(falls, function(f) {
  snap <- frs_point_snap(f$lon, f$lat)
  message("  ", f$name, ": blk ", snap$blue_line_key,
          " drm ", round(snap$downstream_route_measure))
  ws <- frs_watershed_at_measure(snap$blue_line_key, snap$downstream_route_measure)
  ws$name <- f$name
  ws
})

ws_exclude <- do.call(rbind, ws_list)
ws_union <- sf::st_union(ws_exclude)

message("Subtracting upstream watersheds...")
fp_accessible <- sf::st_difference(valleys_poly, ws_union)
fp_accessible <- sf::st_make_valid(fp_accessible)

area_full <- round(as.numeric(sf::st_area(valleys_poly)) / 10000, 1)
area_accessible <- round(as.numeric(sf::st_area(fp_accessible)) / 10000, 1)
message("  Full: ", area_full, " ha")
message("  Accessible: ", area_accessible, " ha")
message("  Excluded: ", area_full - area_accessible, " ha")

# Write accessible output
fp_acc_4326 <- sf::st_transform(fp_accessible, 4326)
sf::st_write(fp_acc_4326, here::here("data", "floodplain_co_accessible.geojson"),
             delete_dsn = TRUE, quiet = TRUE)

# Write falls and exclusion zones
falls_pts <- sf::st_as_sf(
  data.frame(name = sapply(falls, `[[`, "name"),
             lon = sapply(falls, `[[`, "lon"),
             lat = sapply(falls, `[[`, "lat")),
  coords = c("lon", "lat"), crs = 4326
)
sf::st_write(falls_pts, here::here("data", "falls.geojson"),
             delete_dsn = TRUE, quiet = TRUE)
sf::st_write(sf::st_transform(ws_exclude, 4326),
             here::here("data", "ws_upstream_falls.geojson"),
             delete_dsn = TRUE, quiet = TRUE)

message("\nDone. 4 AOI variants in data/:")
message("  floodplain_co_vca.geojson        — raw VCA + waterbodies")
message("  floodplain_co_anchor4.geojson    — patch cleanup (order 4+ anchor)")
message("  floodplain_co.geojson            — patch cleanup (order 2+ anchor)")
message("  floodplain_co_accessible.geojson — order 2+ anchor, falls excluded")
message("  falls.geojson                    — falls locations")
message("  ws_upstream_falls.geojson        — excluded watersheds")
message("\nUpload any geojson as custom AOI in diggs.")
