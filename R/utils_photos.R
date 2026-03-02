#' Query bcfishpass for habitat streams
#'
#' @param conn DBI connection to bcfishpass database
#' @param wsgroup Watershed group code (e.g. "BULK", "LNIC")
#' @param habitat_type "rearing" or "spawning"
#' @param species_code Species code: "co", "ch", "sk", "bt", "st", "wct", "cm", "pk"
#' @param blue_line_keys Numeric vector of FWA blue_line_key values (preferred — unique per stream)
#' @param stream_names Character vector of GNIS stream names (convenience — scoped to wsgroup)
#' @param min_stream_order Minimum Strahler order (applied in addition to blk/name filters)
#' @return sf linestring object in WGS84 (EPSG:4326)
flood_query_habitat <- function(
    conn,
    wsgroup,
    habitat_type = "rearing",
    species_code = "co",
    blue_line_keys = NULL,
    stream_names = NULL,
    min_stream_order = NULL
) {
  habitat_col <- paste0(habitat_type, "_", species_code)

  # Validate column exists
  valid_cols <- DBI::dbGetQuery(conn,
    "SELECT column_name FROM information_schema.columns
     WHERE table_schema = 'bcfishpass' AND table_name = 'streams_vw'")$column_name
  if (!habitat_col %in% valid_cols) {
    stop("Column '", habitat_col, "' not found in bcfishpass.streams_vw. ",
         "Valid habitat columns: ",
         paste(grep("^(rearing|spawning)_", valid_cols, value = TRUE), collapse = ", "))
  }

  # Build WHERE clauses
  clauses <- c(
    glue::glue("watershed_group_code = '{wsgroup}'"),
    glue::glue("{habitat_col} = 1")
  )

  if (!is.null(blue_line_keys)) {
    blk_list <- paste(blue_line_keys, collapse = ", ")
    clauses <- c(clauses, glue::glue("blue_line_key IN ({blk_list})"))
    message("Querying ", habitat_col, " streams by blue_line_key (",
            length(blue_line_keys), " streams)...")
  } else if (!is.null(stream_names)) {
    names_list <- paste0("'", stream_names, "'", collapse = ", ")
    clauses <- c(clauses, glue::glue("gnis_name IN ({names_list})"))
    message("Querying ", habitat_col, " streams by name: ",
            paste(stream_names, collapse = ", "), "...")
  } else {
    message("Querying all ", habitat_col, " streams in ", wsgroup, "...")
  }

  if (!is.null(min_stream_order)) {
    clauses <- c(clauses, glue::glue("stream_order >= {min_stream_order}"))
  }

  where <- paste(clauses, collapse = "\n      AND ")

  sql <- glue::glue("
    SELECT segmented_stream_id, blue_line_key, gnis_name, stream_order,
           channel_width, {habitat_col}, access_{species_code},
           ST_Transform(geom, 4326) as geom
    FROM bcfishpass.streams_vw
    WHERE {where}
  ")

  result <- sf::st_read(conn, query = sql) |>
    sf::st_zm(drop = TRUE)
  message("  ", nrow(result), " stream segments")
  result
}


#' Trim floodplain to areas alongside target streams
#'
#' Uses flat-cap buffer to extend perpendicular to streams without extending
#' past stream endpoints. Optionally adds a photo capture buffer.
#'
#' @param floodplain_sf sf polygon — the floodplain/lateral habitat boundary
#' @param streams_sf sf linestring — pre-filtered streams (from flood_query_habitat or any source)
#' @param floodplain_width Buffer distance (m) perpendicular to streams. Should capture
#'   the full floodplain width. Uses flat end caps.
#' @param photo_buffer Buffer (m) around trimmed floodplain for photo centroid capture.
#'   Set to 0 to return the trimmed floodplain only.
#' @return sf polygon in WGS84 (EPSG:4326)
flood_trim_habitat <- function(
    floodplain_sf,
    streams_sf,
    floodplain_width = 2000,
    photo_buffer = 1800
) {
  streams_albers <- sf::st_transform(streams_sf, 3005)
  floodplain_albers <- sf::st_transform(floodplain_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()

  message("Buffering streams by ", floodplain_width, "m (flat cap)...")
  streams_buffered <- sf::st_buffer(streams_albers, dist = floodplain_width,
                                    endCapStyle = "FLAT") |>
    sf::st_union() |>
    sf::st_make_valid()

  message("Intersecting with floodplain...")
  trimmed <- sf::st_intersection(streams_buffered, floodplain_albers) |>
    sf::st_make_valid()

  if (photo_buffer > 0) {
    message("Adding ", photo_buffer, "m photo capture buffer...")
    result <- sf::st_buffer(trimmed, dist = photo_buffer) |>
      sf::st_make_valid()
  } else {
    result <- trimmed
  }

  result <- result |> sf::st_transform(4326)

  # Summary
  area_orig <- as.numeric(sf::st_area(floodplain_albers)) / 1e6
  area_trimmed <- as.numeric(sf::st_area(trimmed)) / 1e6
  area_final <- as.numeric(sum(sf::st_area(result))) / 1e6
  message("Original floodplain:  ", round(area_orig, 1), " km2")
  message("Trimmed floodplain:   ", round(area_trimmed, 1), " km2 (",
          round((1 - area_trimmed / area_orig) * 100), "% reduction)")
  if (photo_buffer > 0) {
    message("Photo capture zone:   ", round(area_final, 1), " km2")
  }

  sf::st_sf(geometry = sf::st_geometry(result))
}


#' Summarize photo footprint sizes and date ranges by scale
#'
#' @param photos_sf sf points with `scale` and `photo_year` columns
#' @return tibble with scale, photos, footprint_m, half_m, year_min, year_max
flood_photo_summary <- function(photos_sf) {
  photos_sf |>
    sf::st_drop_geometry() |>
    dplyr::mutate(
      scale_num = as.numeric(gsub(".*:", "", scale)),
      footprint_m = round(scale_num * 0.0254 * 9),
      half_m = round(.data$footprint_m / 2)
    ) |>
    dplyr::group_by(scale) |>
    dplyr::summarise(
      photos = dplyr::n(),
      footprint_m = dplyr::first(.data$footprint_m),
      half_m = dplyr::first(.data$half_m),
      year_min = min(photo_year, na.rm = TRUE),
      year_max = max(photo_year, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$footprint_m)
}


#' Check photo coverage of an AOI by group (year, roll, etc.)
#'
#' Builds footprint polygons for each photo, intersects with AOI, and
#' reports % coverage grouped by a column.
#'
#' @param photos_sf sf points with `scale` column
#' @param aoi_sf sf polygon to check coverage against
#' @param by Column name to group by (default "photo_year")
#' @return tibble with group, n_photos, covered_km2, coverage_pct
flood_photo_coverage <- function(photos_sf, aoi_sf, by = "photo_year") {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  aoi_albers <- sf::st_transform(aoi_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()
  aoi_area <- as.numeric(sf::st_area(aoi_albers))

  # Build footprints using estimate_footprint from utils_geo.R
  photos_with_fp <- photos_sf
  photos_with_fp$footprint_geom <- sf::st_geometry(
    estimate_footprint(photos_sf) |> sf::st_transform(3005)
  )

  groups <- sort(unique(photos_with_fp[[by]]))

  results <- purrr::map_dfr(groups, function(grp) {
    grp_data <- photos_with_fp[photos_with_fp[[by]] == grp, ]
    fp_union <- tryCatch(
      sf::st_union(grp_data$footprint_geom) |>
        sf::st_buffer(0) |>
        sf::st_make_valid(),
      error = function(e) {
        grp_data$footprint_geom |>
          sf::st_buffer(0.1) |>
          sf::st_union() |>
          sf::st_buffer(-0.1) |>
          sf::st_make_valid()
      }
    )
    covered <- tryCatch(
      sf::st_intersection(fp_union, aoi_albers) |> sf::st_make_valid(),
      error = function(e) {
        sf::st_intersection(sf::st_buffer(fp_union, 0),
                            sf::st_buffer(aoi_albers, 0)) |>
          sf::st_make_valid()
      }
    )
    covered_area <- as.numeric(sf::st_area(covered))
    dplyr::tibble(
      !!by := grp,
      n_photos = nrow(grp_data),
      covered_km2 = round(covered_area / 1e6, 1),
      coverage_pct = round(covered_area / aoi_area * 100, 1)
    )
  })

  results
}


#' Select minimum photo set to cover an AOI (greedy set cover)
#'
#' Iteratively picks the photo whose footprint covers the most uncovered
#' area until target coverage is reached.
#'
#' @param photos_sf sf points with `scale` column (pre-filtered to target year/scale)
#' @param aoi_sf sf polygon to cover
#' @param target_coverage Stop when this fraction is reached (default 0.95)
#' @return sf of selected photos with `selection_order` and `cumulative_coverage_pct` columns
flood_photo_select <- function(photos_sf, aoi_sf, target_coverage = 0.95) {
  sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(TRUE))

  aoi_albers <- sf::st_transform(aoi_sf, 3005) |>
    sf::st_union() |>
    sf::st_make_valid()
  aoi_area <- as.numeric(sf::st_area(aoi_albers))

  # Build all footprints
  footprints <- estimate_footprint(photos_sf) |> sf::st_transform(3005)
  footprints$photo_idx <- seq_len(nrow(footprints))

  uncovered <- aoi_albers
  selected_idx <- integer(0)
  coverage_pcts <- numeric(0)
  covered_so_far <- sf::st_sfc(sf::st_polygon(), crs = 3005)

  message("Selecting photos (target: ", target_coverage * 100, "% coverage)...")

  while (TRUE) {
    remaining <- footprints[!footprints$photo_idx %in% selected_idx, ]
    if (nrow(remaining) == 0) break

    # Find which photo covers the most uncovered area
    gains <- vapply(seq_len(nrow(remaining)), function(i) {
      fp <- sf::st_geometry(remaining[i, ])
      new_cover <- tryCatch({
        result <- sf::st_intersection(fp, uncovered) |> sf::st_make_valid()
        if (length(result) == 0) return(0)
        as.numeric(sf::st_area(sf::st_union(result)))
      }, error = function(e) 0)
      new_cover
    }, numeric(1))

    best <- which.max(gains)
    if (gains[best] <= 0) break

    best_idx <- remaining$photo_idx[best]
    selected_idx <- c(selected_idx, best_idx)

    # Update uncovered area
    best_fp <- sf::st_geometry(remaining[best, ])
    covered_so_far <- sf::st_union(covered_so_far, best_fp) |> sf::st_make_valid()
    covered_in_aoi <- tryCatch(
      sf::st_intersection(covered_so_far, aoi_albers) |> sf::st_make_valid(),
      error = function(e) covered_so_far
    )
    uncovered <- tryCatch(
      sf::st_difference(aoi_albers, covered_so_far) |> sf::st_make_valid(),
      error = function(e) aoi_albers
    )

    pct <- as.numeric(sf::st_area(covered_in_aoi)) / aoi_area
    coverage_pcts <- c(coverage_pcts, pct)

    if (length(selected_idx) %% 10 == 0 || pct >= target_coverage) {
      message("  ", length(selected_idx), " photos → ", round(pct * 100, 1), "% coverage")
    }

    if (pct >= target_coverage) break
  }

  message("Selected ", length(selected_idx), " of ", nrow(photos_sf),
          " photos for ", round(coverage_pcts[length(coverage_pcts)] * 100, 1), "% coverage")

  result <- photos_sf[selected_idx, ]
  result$selection_order <- seq_along(selected_idx)
  result$cumulative_coverage_pct <- round(coverage_pcts * 100, 1)
  result
}
