# Task: Scaffold diggs as golem Shiny package

**Goal:** Migrate airbc into a golem-structured Shiny package called `diggs` (Delineation-Informed Geographic Ground Selection). Work on scaffold branch, PR with SRED ref.

**Tracking:** NewGraphEnvironment/airbc#18

## Phases

### Phase 1: Rename repo and golem scaffold `done`
- [x] Rename `NewGraphEnvironment/airbc` → `NewGraphEnvironment/diggs` on GitHub
- [x] Rename local dir `/Users/airvine/Projects/repo/airbc` → `diggs`
- [x] Update git remote URL
- [x] Create `scaffold` branch
- [x] Run golem scaffold in-place (add DESCRIPTION, app_ui/app_server, config)
- [x] Verify scaffold runs (`golem::run_dev()`)

### Phase 2: Port modules and utilities `done`
- [x] Copy `mod_map.R`, `mod_filters.R`, `mod_table.R` to `R/`
- [x] Copy `utils_data.R`, `utils_geo.R` to `R/`
- [x] Wire modules into `app_ui.R` and `app_server.R`
- [x] Add fly, sf, leaflet, DT etc. to DESCRIPTION Imports
- [x] Move `cache_data.R` to `data-raw/`
- [x] Move `floodplain_neexdzii_co.R` to `data-raw/` (already there)
- [x] Verify app runs with `golem::run_dev()`

### Phase 3: Clean up `done`
- [x] Remove dead code (validate_geometry duplication — kept in cache_data.R as standalone)
- [x] Delete scripts/ that are now redundant (photos_select_priority.R — app does this)
- [x] Delete explore_stream_network.R, network_extract.R (one-off utilities, not diggs core)
- [x] Update .gitignore
- [x] Hex sticker
- [x] README with diggs branding (screenshot placeholder — needs app screenshot)
- [x] CLAUDE.md

### Phase 4: Tests `done`
- [x] testthat setup (`usethis::use_testthat(edition = 3)`)
- [ ] Test filter logic (year, media, scale filtering) — deferred (reactive logic, needs shinytest2)
- [ ] Test fly integration (fly_filter, fly_select called correctly) — deferred (needs test data)
- [x] Test utils_data (load_cached_layers)
- [x] Test utils_geo (drawn_feature_to_sf, validate_geometry)
- [ ] shinytest2 for basic app startup if feasible — deferred

### Phase 5: Vignette `in progress`
- [x] Reinstall flooded from source (0.1.0)
- [x] `data-raw/vignette_neexdzii.R` — hit bcfishpass for network, run flooded VCA
- [x] Cache floodplain AOI as geojson (1 polygon, 4.6% of DEM extent)
- [x] Confirm app runs end-to-end: 40 photos (1968, 1:12000 + 1:31680) → CSV
- [ ] Write vignette .Rmd documenting the workflow
- [ ] Document two-tier AOI concept (watershed window vs floodplain refinement)

### Phase 6: PR and release `pending`
- [ ] Commit all on scaffold branch
- [ ] PR to main with `Relates to NewGraphEnvironment/sred-2025-2026#17`
- [ ] Merge, tag v0.1.0
- [ ] Archive airbc (update README to point to diggs)
- [ ] Update fly README reference (airbc → diggs)

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Package name | diggs | Delineation-Informed Geographic Ground Selection, hiphop crate-digging theme |
| Framework | golem | Tests, vignettes, deployment-ready, config for flexible AOI |
| Repo strategy | Rename in-place | Preserves history, GitHub redirects old URLs |
| Branch | scaffold | All work in one branch, one PR for SRED |
| Project-specific scripts | Keep in data-raw/ as examples | Document they're Neexdzii Kwah specific |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| (none yet) | | |
