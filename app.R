library(shiny)
library(bslib)
library(leaflet)
library(leaflet.extras)
library(sf)
library(DT)
library(dplyr)
library(stringr)
library(purrr)
library(fs)

# Source modules and utilities
source("R/utils_data.R")
source("R/utils_geo.R")
source("R/mod_map.R")
source("R/mod_filters.R")
source("R/mod_table.R")

# Load cached data at startup
layers <- load_cached_layers("data")

ui <- bslib::page_sidebar(
  title = "airbc",
  sidebar = bslib::sidebar(
    width = 300,
    mod_filters_ui("filters", layers)
  ),
  bslib::layout_columns(
    col_widths = 12,
    mod_map_ui("map"),
    mod_table_ui("table")
  )
)

server <- function(input, output, session) {
  # Reactive for drawn AOI — shared between map and filters
  drawn_aoi <- shiny::reactiveVal(NULL)

  # Filter module returns reactive filter values
  filters <- mod_filters_server("filters", layers, drawn_aoi)

  # Map module updates drawn_aoi
  mod_map_server("map", layers, filters, drawn_aoi)

  # Table module displays filtered data
  mod_table_server("table", filters)
}

shinyApp(ui, server)
