#!/usr/bin/env Rscript
#
# photos_select_coverage.R
#
# Select minimum photo set to cover a trimmed floodplain AOI.
# Prioritizes smaller-scale (higher resolution) photos first,
# then backfills with larger-scale photos.
#
# Usage: Rscript scripts/photos_select_coverage.R

library(sf)
library(dplyr)

source("R/utils_geo.R")
source("R/utils_photos.R")

# --- Parameters ---
aoi_path <- "data/floodplain_rearing.geojson"
photos_path <- "data/l_photo_centroids.geojson"
photo_year <- 1968
scales_priority <- c("1:12000", "1:31680")   # best resolution first
target_coverage <- 0.95
capture_buffer_m <- 1800

# --- Load data ---
aoi <- sf::st_read(aoi_path, quiet = TRUE)
photos <- sf::st_read(photos_path, quiet = TRUE)

# --- Filter to year ---
photos_yr <- photos |> dplyr::filter(photo_year == !!photo_year)
message("Year ", photo_year, ": ", nrow(photos_yr), " photos (",
        paste(sort(unique(photos_yr$scale)), collapse = ", "), ")")

# --- Filter to capture zone ---
capture_zone <- sf::st_transform(aoi, 3005) |>
  sf::st_buffer(capture_buffer_m) |>
  sf::st_transform(4326)
inside <- sf::st_intersects(photos_yr, capture_zone, sparse = FALSE)[, 1]
photos_yr <- photos_yr[inside, ]
message("In capture zone (", capture_buffer_m, "m buffer): ", nrow(photos_yr), " photos")

# --- Footprint summary ---
message("\n--- Footprint Summary ---")
print(flood_photo_summary(photos_yr))

# --- Coverage by scale ---
message("\n--- Coverage by Scale ---")
print(flood_photo_coverage(photos_yr, aoi, by = "scale"))

# --- Priority selection: best resolution first, backfill with coarser ---
message("\n--- Priority Selection ---")
selected_all <- NULL
remaining_aoi <- sf::st_transform(aoi, 3005) |>
  sf::st_union() |>
  sf::st_make_valid()
aoi_area <- as.numeric(sf::st_area(remaining_aoi))
cumulative_pct <- 0

for (sc in scales_priority) {
  if (cumulative_pct >= target_coverage) break

  photos_sc <- photos_yr |> dplyr::filter(scale == sc)
  if (nrow(photos_sc) == 0) {
    message("  ", sc, ": no photos, skipping")
    next
  }

  message("  ", sc, ": ", nrow(photos_sc), " photos available")
  sel <- flood_photo_select(photos_sc, sf::st_sf(geometry = sf::st_geometry(remaining_aoi) |>
    sf::st_transform(4326)), target_coverage = target_coverage)

  if (nrow(sel) > 0) {
    # Update remaining uncovered area
    fp <- estimate_footprint(sel) |> sf::st_transform(3005)
    fp_union <- sf::st_union(fp) |> sf::st_make_valid()
    covered <- tryCatch(
      sf::st_intersection(fp_union, remaining_aoi) |> sf::st_make_valid(),
      error = function(e) fp_union
    )
    remaining_aoi <- tryCatch(
      sf::st_difference(remaining_aoi, fp_union) |> sf::st_make_valid(),
      error = function(e) remaining_aoi
    )

    covered_area <- aoi_area - as.numeric(sf::st_area(remaining_aoi))
    cumulative_pct <- covered_area / aoi_area
    message("  → selected ", nrow(sel), " photos at ", sc,
            " (cumulative: ", round(cumulative_pct * 100, 1), "%)")

    selected_all <- dplyr::bind_rows(selected_all, sel)
  }
}

# --- Summary ---
message("\n--- Final Selection ---")
message("Total photos: ", nrow(selected_all))
message("Coverage: ", round(cumulative_pct * 100, 1), "%")
message("\nBy scale:")
selected_all |>
  sf::st_drop_geometry() |>
  dplyr::count(scale) |>
  print()
message("\nBy roll:")
selected_all |>
  sf::st_drop_geometry() |>
  dplyr::count(scale, film_roll) |>
  print()
