#!/usr/bin/env Rscript
#
# photo_footprint_summary.R
#
# Summarise airphoto footprint sizes by scale and date range.
# Assumes standard 9x9 inch (228mm) film format:
#   footprint (m) = scale_denominator * 0.228
#
# Usage: Rscript scripts/photo_footprint_summary.R

library(sf)
library(dplyr)

photos <- st_read("data/l_photo_centroids.geojson", quiet = TRUE)

summary_tbl <- photos |>
  st_drop_geometry() |>
  mutate(
    scale_num = as.numeric(gsub(".*:", "", scale)),
    footprint_m = round(scale_num * 0.228),
    half_m = round(footprint_m / 2)
  ) |>
  group_by(scale) |>
  summarise(
    photos = n(),
    footprint_m = first(footprint_m),
    half_m = first(half_m),
    years = paste0(min(photo_year, na.rm = TRUE), "–", max(photo_year, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  arrange(footprint_m)

# Print markdown table
cat("\n| Scale | Photos | Footprint (m) | Half (m) | Years |\n")
cat("|-------|--------|---------------|----------|-------|\n")
for (i in seq_len(nrow(summary_tbl))) {
  r <- summary_tbl[i, ]
  cat(sprintf("| %s | %s | %s | %s | %s |\n",
              r$scale, format(r$photos, big.mark = ","),
              format(r$footprint_m, big.mark = ","),
              format(r$half_m, big.mark = ","), r$years))
}

cat(sprintf("\nTotal photos: %s\n", format(sum(summary_tbl$photos), big.mark = ",")))
cat(sprintf("Half-footprint range: %s–%s m (median centre-to-edge distance)\n",
            format(min(summary_tbl$half_m), big.mark = ","),
            format(max(summary_tbl$half_m), big.mark = ",")))
