#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#' @import shiny
#' @noRd
app_ui <- function(request) {

  # Load cached data for UI initialization

  layers <- load_cached_layers(get_golem_config("data_dir"))

  bslib::page_sidebar(
    title = tags$a(
      href = "https://github.com/NewGraphEnvironment/diggs",
      tags$img(
        src = "www/logo.png",
        height = "46px",
        style = "margin-top: -8px;"
      )
    ),
    sidebar = bslib::sidebar(
      width = 300,
      mod_filters_ui("filters", layers)
    ),
    mod_map_ui("map"),
    mod_table_ui("table")
  )
}

#' Add external resources to the application
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path("www", app_sys("app/www"))

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "diggs"
    )
  )
}
