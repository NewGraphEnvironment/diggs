#' Run the Shiny Application
#'
#' @param data_dir Path to directory containing cached .geojson layers.
#'   Defaults to the value in golem-config.yml.
#' @param ... Arguments to pass to golem_opts. See
#'   `?golem::get_golem_options` for more details.
#' @inheritParams shiny::shinyApp
#'
#' @export
run_app <- function(
    data_dir = NULL,
    onStart = NULL,
    options = list(),
    enableBookmarking = NULL,
    uiPattern = "/",
    ...) {
  golem::with_golem_options(
    app = shiny::shinyApp(
      ui = app_ui,
      server = app_server,
      onStart = onStart,
      options = options,
      enableBookmarking = enableBookmarking,
      uiPattern = uiPattern
    ),
    golem_opts = list(
      data_dir = data_dir,
      ...
    )
  )
}
