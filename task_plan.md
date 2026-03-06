# Task: Scaffold diggs as golem Shiny package

**Goal:** Migrate airbc into a golem-structured Shiny package called `diggs` (Delineation-Informed Geographic Ground Selection). Work on scaffold branch, PR with SRED ref.

**Tracking:** NewGraphEnvironment/airbc#18

## Phases

### Phase 1: Rename repo and golem scaffold `pending`
- [ ] Rename `NewGraphEnvironment/airbc` → `NewGraphEnvironment/diggs` on GitHub
- [ ] Rename local dir `/Users/airvine/Projects/repo/airbc` → `diggs`
- [ ] Update git remote URL
- [ ] Create `scaffold` branch
- [ ] Run golem scaffold in-place (add DESCRIPTION, app_ui/app_server, config)
- [ ] Verify scaffold runs (`golem::run_dev()`)

### Phase 2: Port modules and utilities `pending`
- [ ] Copy `mod_map.R`, `mod_filters.R`, `mod_table.R` to `R/`
- [ ] Copy `utils_data.R`, `utils_geo.R` to `R/`
- [ ] Wire modules into `app_ui.R` and `app_server.R`
- [ ] Add fly, sf, leaflet, DT etc. to DESCRIPTION Imports
- [ ] Move `cache_data.R` to `data-raw/`
- [ ] Move `floodplain_neexdzii_co.R` to `data-raw/` (project-specific, document as example)
- [ ] Verify app runs with `golem::run_dev()`

### Phase 3: Clean up `pending`
- [ ] Remove dead code (validate_geometry duplication, stale references)
- [ ] Delete scripts/ that are now redundant (photos_select_priority.R — app does this)
- [ ] Delete explore_stream_network.R, network_extract.R (one-off utilities, not diggs core)
- [ ] Update .gitignore
- [ ] Hex sticker
- [ ] README with diggs branding
- [ ] CLAUDE.md

### Phase 4: Tests `pending`
- [ ] testthat setup (`usethis::use_testthat(edition = 3)`)
- [ ] Test filter logic (year, media, scale filtering)
- [ ] Test fly integration (fly_filter, fly_select called correctly)
- [ ] Test utils_data (load_cached_layers)
- [ ] Test utils_geo (drawn_feature_to_sf)
- [ ] shinytest2 for basic app startup if feasible

### Phase 5: Vignette `pending`
- [ ] Vignette: configure AOI → cache data → explore → select → export
- [ ] Document the two-tier AOI concept (regional window vs refinement)
- [ ] Show priority selection workflow end-to-end
- [ ] Screenshots or static plots of key steps

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
