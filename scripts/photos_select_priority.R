#!/usr/bin/env Rscript
#
# photos_select_priority.R
#
# Select all photos at the best resolution, then backfill uncovered
# area with the minimum set of coarser-scale photos.
#
# Usage: Rscript scripts/photos_select_priority.R

library(sf)
library(dplyr)

source("R/utils_geo.R")
source("R/utils_photos.R")

# --- Parameters ---
aoi_path <- "data/floodplain_neexdzii_co_4th_order.gpkg"
photos_path <- "data/l_photo_centroids.geojson"
photo_year <- 1968
scales_priority <- c("1:12000", "1:31680")   # best resolution first
target_coverage <- 0.95
capture_buffer_m <- 3600                      # half max footprint width

# --- Load data ---
sf::sf_use_s2(FALSE)
aoi <- sf::st_read(aoi_path, quiet = TRUE) |> sf::st_make_valid()
if (sf::st_crs(aoi)$epsg != 4326) aoi <- sf::st_transform(aoi, 4326)

photos <- sf::st_read(photos_path, quiet = TRUE)

# --- Filter to year ---
photos_yr <- photos |> dplyr::filter(photo_year == !!photo_year)
message("Year ", photo_year, ": ", nrow(photos_yr), " photos (",
        paste(sort(unique(photos_yr$scale)), collapse = ", "), ")")

# --- Filter to capture zone ---
capture_zone <- sf::st_transform(aoi, 3005) |>
  sf::st_buffer(capture_buffer_m) |>
  sf::st_transform(4326) |>
  sf::st_make_valid()
inside <- sf::st_intersects(photos_yr, capture_zone, sparse = FALSE)[, 1]
photos_yr <- photos_yr[inside, ]
message("In capture zone (", capture_buffer_m, "m buffer): ", nrow(photos_yr), " photos")

# --- Footprint summary ---
message("\n--- Footprint Summary ---")
print(flood_photo_summary(photos_yr))

# --- Coverage by scale ---
message("\n--- Coverage by Scale ---")
print(flood_photo_coverage(photos_yr, aoi, by = "scale"))

# --- Priority selection: all best-resolution, backfill with coarser ---
message("\n--- Priority Selection ---")
aoi_albers <- sf::st_transform(aoi, 3005) |> sf::st_union() |> sf::st_make_valid()
aoi_area <- as.numeric(sf::st_area(aoi_albers))
selected_all <- NULL
remaining_aoi <- aoi_albers

for (i in seq_along(scales_priority)) {
  sc <- scales_priority[i]
  photos_sc <- photos_yr |> dplyr::filter(scale == sc)

  if (nrow(photos_sc) == 0) {
    message("  ", sc, ": no photos, skipping")
    next
  }

  if (i == 1) {
    # Best resolution: take ALL photos
    message("  ", sc, ": taking all ", nrow(photos_sc), " photos")
    sel <- photos_sc
    sel$selection_order <- seq_len(nrow(sel))
    sel$cumulative_coverage_pct <- NA_real_
  } else {
    # Coarser scales: greedy select to fill remaining uncovered area
    remaining_sf <- sf::st_sf(geometry = sf::st_geometry(remaining_aoi)) |>
      sf::st_transform(4326) |> sf::st_make_valid()
    sel <- flood_photo_select(photos_sc, remaining_sf, target_coverage = target_coverage)
  }

  if (nrow(sel) > 0) {
    # Update remaining uncovered area
    fp <- estimate_footprint(sel) |> sf::st_transform(3005)
    fp_union <- sf::st_union(fp) |> sf::st_make_valid()
    remaining_aoi <- tryCatch(
      sf::st_difference(remaining_aoi, fp_union) |> sf::st_make_valid(),
      error = function(e) remaining_aoi
    )
    covered_pct <- 1 - as.numeric(sf::st_area(remaining_aoi)) / aoi_area
    message("  -> selected ", nrow(sel), " photos at ", sc,
            " (cumulative: ", round(covered_pct * 100, 1), "%)")

    sel$priority_scale <- sc
    selected_all <- dplyr::bind_rows(selected_all, sel)
  }
}

# --- Summary ---
message("\n--- Final Selection ---")
message("Total photos: ", nrow(selected_all))
covered_pct <- 1 - as.numeric(sf::st_area(remaining_aoi)) / aoi_area
message("Coverage: ", round(covered_pct * 100, 1), "%")

message("\nBy scale:")
selected_all |> sf::st_drop_geometry() |> dplyr::count(priority_scale) |> print()
message("\nBy roll:")
selected_all |> sf::st_drop_geometry() |> dplyr::count(priority_scale, film_roll) |> print()

# --- Export ---
out_csv <- sub("\\.[^.]+$", "", basename(aoi_path)) |>
  paste0("_photos_", photo_year, ".csv")
out_csv <- file.path("data", out_csv)

selected_all |>
  sf::st_drop_geometry() |>
  dplyr::select(airp_id, photo_year, scale, film_roll, frame_number,
                photo_tag, priority_scale) |>
  write.csv(out_csv, row.names = FALSE)
message("\nSaved: ", out_csv)
