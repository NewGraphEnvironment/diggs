#!/usr/bin/env Rscript
#
# floodplain_neexdzii_co.R
#
# Generate floodplain raster for Neexdzii Kwah (Upper Bulkley) coho habitat
# on 4th order or greater streams using the flooded package VCA pipeline.
#
# Uses:
#   - bcfishpass.streams_co_vw via SSH tunnel (localhost:63333)
#   - FWA_Upstream() to select all streams upstream of the Neexdzii Kwah /
#     Wedzin Kwa confluence (blk 360873822, drm 166030)
#   - BULK DEM and slope from bcfishpass habitat_lateral data
#   - fl_valley_confine() with precipitation (map_upstream) for realistic
#     flood depth
#
# Requires:
#   - SSH tunnel: ssh -L 63333:<db_host>:5432 <ssh_host>
#   - R packages: flooded, sf, DBI, RPostgres, terra
#
# Output:
#   data/floodplain_neexdzii_co_4th_order.tif  (raster)
#   data/floodplain_neexdzii_co_4th_order.gpkg (vector)

library(flooded)
library(sf)
library(terra)
library(DBI)
library(RPostgres)

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
out_raster <- here::here("data", "floodplain_neexdzii_co_4th_order.tif")
out_vector <- here::here("data", "floodplain_neexdzii_co_4th_order.gpkg")

# --- Connect to bcfishpass DB ---
message("Connecting to bcfishpass DB...")
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# --- Query coho streams upstream of confluence, order >= 4 ---
# Use FWA_Upstream() with the wscode/localcode at the confluence point
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

message("Querying coho streams upstream of blk ", blk, " drm ", drm,
        " (order >= ", min_order, ")...")
streams <- sf::st_read(conn, query = sql) |>
  sf::st_zm(drop = TRUE)

DBI::dbDisconnect(conn)

message("  ", nrow(streams), " segments")
message("  Streams: ", paste(unique(na.omit(streams$gnis_name)), collapse = ", "))
message("  Orders: ", paste(sort(unique(streams$stream_order)), collapse = ", "))
message("  Upstream area range: ", paste(range(streams$upstream_area_ha), collapse = " - "), " ha")
message("  MAP range: ", paste(range(streams$map_upstream), collapse = " - "), " mm")

# --- Load and crop DEM/slope to stream extent ---
message("Loading DEM and slope...")
dem_full <- terra::rast(dem_path)
slope_full <- terra::rast(slope_path)

# Buffer stream extent for DEM crop
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
