# diggs (development)

- Replace raw SQL with fresh (`frs_network_prune()`, `frs_network()`) in data-raw scripts ([#20](https://github.com/NewGraphEnvironment/diggs/issues/20))
- Add waterbody fill, dual stream order anchor, and falls exclusion to floodplain pipeline
- Output 4 AOI variants (raw VCA, anchor 4+, anchor 2+, accessible) for app exploration
- Rename vignette to `floodplain-select` with generic title
- Show selected vs unselected footprints on map after priority selection (blue = kept, grey = dropped) ([#22](https://github.com/NewGraphEnvironment/diggs/issues/22))
- Add black NGE icon to app navbar
- Change AOI boundary color from yellow to red
- Guard Select button against >500 photos
- Clamp year inputs to valid range
- Debounce filter reactive to handle rapid input changes
- Add pkgdown site and GitHub Actions workflow

## 0.1.0

Initial release. Golem-based Shiny app for selecting historic airphotos from the BC Data Catalogue. Vignette documenting Neexdzii Kwah 1968 airphoto selection workflow including footprint vs centroid filtering, 95% coverage target optimization, and floodplain fragment pruning analysis.
