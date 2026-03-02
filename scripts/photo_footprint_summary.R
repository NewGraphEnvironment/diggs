#!/usr/bin/env Rscript
#
# photo_footprint_summary.R
#
# Quick summary of airphoto footprint sizes and date ranges.
#
# Usage: Rscript scripts/photo_footprint_summary.R

library(sf)
library(dplyr)

source("R/utils_photos.R")

photos <- sf::st_read("data/l_photo_centroids.geojson", quiet = TRUE)
summary_tbl <- flood_photo_summary(photos)

# Print markdown table
cat("\n| Scale | Photos | Footprint (m) | Half (m) | Years |\n")
cat("|-------|--------|---------------|----------|-------|\n")
for (i in seq_len(nrow(summary_tbl))) {
  r <- summary_tbl[i, ]
  cat(sprintf("| %s | %s | %s | %s | %s–%s |\n",
              r$scale, format(r$photos, big.mark = ","),
              format(r$footprint_m, big.mark = ","),
              format(r$half_m, big.mark = ","),
              r$year_min, r$year_max))
}

cat(sprintf("\nTotal photos: %s\n", format(sum(summary_tbl$photos), big.mark = ",")))
cat(sprintf("Half-footprint range: %s–%s m\n",
            format(min(summary_tbl$half_m), big.mark = ","),
            format(max(summary_tbl$half_m), big.mark = ",")))
