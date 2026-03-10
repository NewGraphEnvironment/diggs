#!/usr/bin/env Rscript
#
# floodplain_co.R
#
# Generate floodplain polygons for coho habitat on 4th+ order streams using
# the flooded VCA pipeline. Stream network query uses fresh instead of raw SQL.
#
# Parameters (blk, drm) define the downstream reference point — adjust to
# target a different watershed.
#
# Requires:
#   - SSH tunnel: ssh -L 63333:<db_host>:5432 <ssh_host>
#   - R packages: flooded, fresh, sf, terra
#
# Output:
#   data/floodplain_co.tif   (raster)
#   data/floodplain_co.gpkg  (vector, BC Albers)
#   data/floodplain_co.geojson (vector, WGS84 for diggs app)

library(flooded)
library(fresh)
library(sf)
library(terra)

# --- Parameters ---
# Neexdzii Kwah / Wedzin Kwa confluence on the Bulkley mainstem
blk <- 360873822
drm <- 166030.4
min_order <- 4
buf <- 2000  # buffer around streams for DEM crop (metres, matches max_width)

# Source rasters from bcfishpass
dem_path <- "/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/dem.tif"
slope_path <- "/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/slope.tif"

# Output
out_raster  <- here::here("data", "floodplain_co.tif")
out_vector  <- here::here("data", "floodplain_co.gpkg")
out_geojson <- here::here("data", "floodplain_co.geojson")

# --- Query coho streams upstream of confluence, order >= 4 ---
message("Querying coho streams (order >= ", min_order, ")...")
streams <- frs_network_prune(
  blue_line_key = blk,
  downstream_route_measure = drm,
  stream_order_min = min_order,
  watershed_group_code = "BULK",
  extra_where = "(s.rearing > 0 OR s.spawning > 0)",
  table = "bcfishpass.streams_co_vw",
  cols = c("segmented_stream_id", "blue_line_key", "waterbody_key",
           "downstream_route_measure", "upstream_area_ha",
           "map_upstream", "gnis_name",
           "stream_order", "channel_width", "mapping_code",
           "rearing", "spawning", "access", "geom"),
  wscode_col = "wscode",
  localcode_col = "localcode"
)

message("  ", nrow(streams), " segments")
message("  Streams: ", paste(unique(na.omit(streams$gnis_name)), collapse = ", "))
message("  Orders: ", paste(sort(unique(streams$stream_order)), collapse = ", "))
message("  Upstream area range: ", paste(range(streams$upstream_area_ha), collapse = " - "), " ha")
message("  MAP range: ", paste(range(streams$map_upstream), collapse = " - "), " mm")

# --- Load and crop DEM/slope to stream extent ---
message("Loading DEM and slope...")
dem_full <- terra::rast(dem_path)
slope_full <- terra::rast(slope_path)

stream_ext <- terra::ext(terra::vect(streams)) + buf
dem <- terra::crop(dem_full, stream_ext)
slope <- terra::crop(slope_full, stream_ext)

message("  Cropped DEM: ", terra::ncol(dem), " x ", terra::nrow(dem), " pixels")

# --- Rasterize streams and precipitation ---
message("Rasterizing streams...")
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")

# --- Run VCA ---
message("Running valley confinement algorithm...")
valleys <- fl_valley_confine(
  dem, streams,
  field = "upstream_area_ha",
  slope = slope,
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = precip_r,
  size_threshold = 5000,
  hole_threshold = 2500
)

n_valley <- sum(terra::values(valleys) == 1, na.rm = TRUE)
message("  Valley cells: ", n_valley, " / ", terra::ncell(valleys),
        " (", round(100 * n_valley / terra::ncell(valleys), 1), "%)")

# --- Polygonize ---
message("Converting to polygons...")
valleys_poly <- fl_valley_poly(valleys)
message("  ", nrow(valleys_poly), " polygon features")

# --- Write outputs ---
fs::dir_create(dirname(out_raster))

terra::writeRaster(valleys, out_raster, overwrite = TRUE)
message("Saved raster: ", out_raster)

sf::st_write(valleys_poly, out_vector, delete_dsn = TRUE, quiet = TRUE)
message("Saved vector: ", out_vector)

valleys_4326 <- sf::st_transform(valleys_poly, 4326)
sf::st_write(valleys_4326, out_geojson, delete_dsn = TRUE, quiet = TRUE)
message("Saved geojson: ", out_geojson)

message("\nFloodplain AOI ready.")
message("Upload ", basename(out_geojson), " as custom AOI in diggs.")
