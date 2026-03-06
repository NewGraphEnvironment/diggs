#' The application server-side
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # Load cached data

  layers <- load_cached_layers(get_golem_config("data_dir"))

  # Reactive for drawn AOI -- shared between map and filters
  drawn_aoi <- reactiveVal(NULL)

  # Filter module returns reactive filter values
  filters <- mod_filters_server("filters", layers, drawn_aoi)

  # Map module updates drawn_aoi
  mod_map_server("map", layers, filters, drawn_aoi)

  # Table module displays filtered data
  mod_table_server("table", filters)
}
