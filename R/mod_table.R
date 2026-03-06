#' Table module UI
#' @param id Module namespace id
#' @noRd
mod_table_ui <- function(id) {
  ns <- shiny::NS(id)
  DT::DTOutput(ns("table"))
}

#' Table module server
#' @param id Module namespace id
#' @param filters Return value from mod_filters_server
#' @noRd
mod_table_server <- function(id, filters) {
  shiny::moduleServer(id, function(input, output, session) {

    output$table <- DT::renderDT(server = FALSE, {
      dat <- filters$filtered_data()
      if (is.null(dat) || nrow(dat) == 0) return(NULL)

      # Prepare for display
      display <- dat |>
        sf::st_drop_geometry() |>
        dplyr::select(
          airp_id, photo_year, photo_date, media, scale,
          flying_height, nts_tile, photo_tag, film_roll, frame_number,
          dplyr::any_of(c("thumbnail_image_url", "flight_log_url"))
        )

      DT::datatable(
        display,
        filter = "top",
        extensions = c("Buttons", "ColReorder"),
        options = list(
          dom = "Brtip",
          buttons = c("csv", "excel"),
          pageLength = 5,
          scrollX = TRUE,
          scrollY = "200px",
          colReorder = TRUE
        ),
        escape = FALSE,
        rownames = FALSE
      )
    })
  })
}
