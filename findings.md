# Findings: diggs scaffold

## golem structure mapping

| airbc current | diggs golem |
|---------------|-------------|
| `app.R` (ui + server) | `R/app_ui.R` + `R/app_server.R` |
| `R/mod_*.R` | `R/mod_*.R` (same pattern) |
| `R/utils_*.R` | `R/utils_*.R` or `R/fct_*.R` |
| `www/logo.png` | `inst/app/www/logo.png` |
| `scripts/cache_data.R` | `data-raw/cache_data.R` |
| `data/` (gitignored) | `inst/app/data/` or keep `data/` gitignored |
| nothing | `inst/golem-config.yml` for AOI params |
| nothing | `tests/testthat/` |
| nothing | `vignettes/` |

## Current module dependencies

- `mod_map.R` depends on: leaflet, leaflet.extras, sf, fly (fly_footprint)
- `mod_filters.R` depends on: sf, dplyr, fly (fly_filter, fly_select, fly_footprint)
- `mod_table.R` depends on: DT, sf, dplyr
- `utils_data.R` depends on: fs, sf, purrr
- `utils_geo.R` depends on: sf (just drawn_feature_to_sf + validate_geometry)

## Files to port

Keep: mod_map.R, mod_filters.R, mod_table.R, utils_data.R, utils_geo.R
Move to data-raw: cache_data.R, floodplain_neexdzii_co.R
Delete: photos_select_priority.R (app does this), explore_stream_network.R, network_extract.R
