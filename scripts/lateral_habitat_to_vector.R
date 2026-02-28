#!/usr/bin/env Rscript
#
# lateral_habitat_to_vector.R
#
# Convert habitat_lateral.tif to a vector polygon, clip to the cached AOI,
# and save as geojson for use as a custom AOI in the airbc app.
#
# Raster values: 0 = not habitat, 1 = lateral habitat, 2 = lateral habitat (type 2)
# We keep values >= 1 (all habitat).
#
# Usage: Rscript scripts/lateral_habitat_to_vector.R

library(terra)
library(sf)

raster_path <- "/Users/airvine/Projects/gis/restoration_wedzin_kwa/habitat_lateral.tif"
aoi_path <- "data/aoi.geojson"
output_path <- "data/lateral_habitat.geojson"

message("Reading raster...")
r <- terra::rast(raster_path)

# Reclassify: keep habitat (values >= 1) as 1, set 0 to NA
message("Reclassifying...")
r_binary <- terra::classify(r, matrix(c(0, NA, 1, 1, 2, 1), ncol = 2, byrow = TRUE))

# Polygonize
message("Converting to polygons (this may take a minute)...")
polys <- terra::as.polygons(r_binary, dissolve = TRUE)

# Convert to sf
polys_sf <- sf::st_as_sf(polys) |>
  sf::st_transform(4326) |>
  sf::st_make_valid()

message("Habitat polygons: ", nrow(polys_sf), " features")

# Load AOI and clip
message("Clipping to AOI...")
aoi <- sf::st_read(aoi_path, quiet = TRUE)
polys_clipped <- suppressWarnings(sf::st_intersection(polys_sf, aoi))
polys_clipped <- sf::st_make_valid(polys_clipped)

message("Clipped features: ", nrow(polys_clipped))

# Save
sf::st_write(polys_clipped, output_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", output_path)
message("Upload this file in the airbc app as a custom AOI.")
