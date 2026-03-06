# Progress: diggs scaffold

## Session log

### 2026-03-06

- Created planning files
- Starting Phase 1: Create repo and golem scaffold
- Repo already renamed to diggs with correct remote
- Created scaffold branch
- Built golem structure: DESCRIPTION, NAMESPACE, app_ui.R, app_server.R, run_app.R, app_config.R, diggs-package.R
- Created inst/golem-config.yml with data_dir config
- Moved logo to inst/app/www/
- Namespace-qualified fly:: calls in modules
- Added roxygen headers to all modules and utils
- Replaced app.R with golem launcher (pkgload::load_all + run_app)
- Smoke test passes: package loads, config resolves, all 8 layers load
- Phase 1 COMPLETE
- Phase 2 mostly done (modules already in R/, wired up via golem)
- Moved cache_data.R to data-raw/
- Deleted scripts/ (photos_select_priority.R redundant with app, explore/network one-off)
- Removed old www/ (logo now in inst/app/www/)
- Phase 2 COMPLETE
- Regenerated hex sticker with "diggs" name
- Wrote README: ecosystem narrative (flooded → diggs → drift), install, quick start, custom AOI
- Screenshot placeholder — needs app screenshot added to man/figures/screenshot.png
- Updated CLAUDE.md with golem architecture and ecosystem links
- Phase 3 COMPLETE
- testthat edition 3 setup
- Tests for utils_geo (drawn_feature_to_sf, validate_geometry) and utils_data (load_cached_layers)
- 10/10 tests pass
- Phase 4 COMPLETE (reactive/shinytest2 tests deferred)
- Reinstalled flooded 0.1.0
- Created data-raw/vignette_neexdzii.R: full pipeline (bcfishpass query → flooded VCA → geojson)
- Ran live: 1165 stream segments, 4.6% valley cells, 1 polygon feature
- End-to-end test: 9388 centroids → 324 in 1968 → 40 within floodplain → CSV exported
- Scales: 1:12000, 1:31680
- photo_selection_neexdzii_1968.csv ready for Monday order
