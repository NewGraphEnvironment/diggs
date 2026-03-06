#!/usr/bin/env Rscript
#
# vignette_neexdzii.R
#
# End-to-end pipeline: query stream network from bcfishpass, delineate
# 4th+ order floodplain via flooded VCA, cache as AOI for the diggs
# vignette. The resulting floodplain is the custom AOI used to select
# 1968 airphotos for ordering.
#
# Requires:
#   - SSH tunnel: ssh -L 63333:<db_host>:5432 <ssh_host>
#   - Local DEM/slope from bcfishpass habitat_lateral
#   - R packages: flooded, sf, terra, DBI, RPostgres, fwapgr
#
# Output:
#   data/floodplain_neexdzii_co_4th_order.geojson (vignette AOI)
#   data/floodplain_neexdzii_co_4th_order.tif     (raster)

library(flooded)
library(sf)
library(terra)
library(DBI)
library(RPostgres)

# --- Parameters ---
blk <- 360873822      # blue_line_key for Bulkley River
drm <- 166030.4       # downstream_route_measure at Neexdzii Kwa / Wedzin Kwa confluence
min_order <- 4
buf <- 2000           # buffer around streams for DEM crop (metres)

# Source rasters from bcfishpass
dem_path <- "/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/dem.tif"
slope_path <- "/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/slope.tif"

out_geojson <- here::here("data", "floodplain_neexdzii_co_4th_order.geojson")
out_raster <- here::here("data", "floodplain_neexdzii_co_4th_order.tif")

# --- Connect to bcfishpass DB ---
message("Connecting to bcfishpass DB...")
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# --- Query coho streams upstream of confluence, order >= 4 ---
sql <- glue::glue("
  WITH mouth AS (
    SELECT wscode, localcode
    FROM bcfishpass.streams_co_vw
    WHERE blue_line_key = {blk}
      AND downstream_route_measure <= {drm}
    ORDER BY downstream_route_measure DESC
    LIMIT 1
  )
  SELECT s.segmented_stream_id, s.blue_line_key, s.waterbody_key,
         s.downstream_route_measure, s.upstream_area_ha,
         s.map_upstream, s.gnis_name,
         s.stream_order, s.channel_width, s.mapping_code, s.rearing,
         s.spawning, s.access, s.geom
  FROM bcfishpass.streams_co_vw s, mouth m
  WHERE s.watershed_group_code = 'BULK'
    AND s.stream_order >= {min_order}
    AND FWA_Upstream(
      m.wscode, m.localcode,
      s.wscode, s.localcode
    )
")

message("Querying coho streams (order >= ", min_order, ")...")
streams <- sf::st_read(conn, query = sql) |>
  sf::st_zm(drop = TRUE)

DBI::dbDisconnect(conn)

message("  ", nrow(streams), " segments")
message("  Streams: ", paste(unique(na.omit(streams$gnis_name)), collapse = ", "))

# --- Load and crop DEM/slope ---
message("Loading DEM and slope...")
dem_full <- terra::rast(dem_path)
slope_full <- terra::rast(slope_path)

stream_ext <- terra::ext(terra::vect(streams)) + buf
dem <- terra::crop(dem_full, stream_ext)
slope <- terra::crop(slope_full, stream_ext)

message("  Cropped DEM: ", terra::ncol(dem), " x ", terra::nrow(dem), " pixels")

# --- Rasterize streams ---
message("Rasterizing streams...")
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

# --- Polygonize and write ---
message("Converting to polygons...")
valleys_poly <- fl_valley_poly(valleys)
message("  ", nrow(valleys_poly), " polygon features")

# Write geojson (WGS84 for diggs app)
valleys_4326 <- sf::st_transform(valleys_poly, 4326)
sf::st_write(valleys_4326, out_geojson, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", out_geojson)

# Write raster
terra::writeRaster(valleys, out_raster, overwrite = TRUE)
message("Saved: ", out_raster)

message("\nFloodplain AOI ready for diggs vignette.")
message("Next: launch diggs, upload ", basename(out_geojson), " as custom AOI, filter to 1968.")
