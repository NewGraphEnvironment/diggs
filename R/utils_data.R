#' Load all cached geojson layers from a directory
#'
#' @param data_dir Path to directory containing .geojson files
#' @return Named list of sf objects
load_cached_layers <- function(data_dir = "data") {
  layers_to_load <- fs::dir_ls(data_dir, glob = "*.geojson")

  if (length(layers_to_load) == 0) {
    stop(
      "No geojson files found in ", data_dir,
      ". Run scripts/cache_data.R first."
    )
  }

  layers_to_load |>
    purrr::map(\(x) sf::st_read(x, quiet = TRUE)) |>
    purrr::set_names(
      nm = tools::file_path_sans_ext(basename(names(layers_to_load)))
    )
}
