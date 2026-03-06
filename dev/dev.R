# Package setup tracking
# Run these interactively — they are NOT idempotent

# 1. Package scaffold
usethis::create_package(".")
usethis::use_mit_license("New Graph Environment Ltd.")

# 2. Testing
usethis::use_testthat(edition = 3)

# 3. Documentation site
usethis::use_pkgdown()
usethis::use_github_action("pkgdown")

# 4. Dev directory (self-referential)
usethis::use_directory("dev")
usethis::use_directory("data-raw")

# 5. Hex sticker (reads package name from DESCRIPTION — zero edits needed)
source("data-raw/make_hexsticker.R")

# 6. Dependencies
usethis::use_package("bslib")
usethis::use_package("config", min_version = "0.3.1")
usethis::use_package("dplyr")
usethis::use_package("DT")
usethis::use_package("fly")
usethis::use_package("fs")
usethis::use_package("golem", min_version = "0.4.0")
usethis::use_package("leaflet")
usethis::use_package("leaflet.extras")
usethis::use_package("purrr")
usethis::use_package("sf")
usethis::use_package("shiny", min_version = "1.7.4")
usethis::use_package("stringr")
usethis::use_package("knitr", type = "Suggests")
usethis::use_package("rmarkdown", type = "Suggests")
usethis::use_package("testthat", type = "Suggests", min_version = "3.0.0")

# 7. Build
devtools::document()
devtools::test()
devtools::check()
