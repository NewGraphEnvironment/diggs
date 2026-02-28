# airbc

BC Historic Airphoto Explorer — interactive Shiny app for selecting historic orthophoto imagery from the [BC Data Catalogue](https://catalogue.data.gov.bc.ca/dataset/airphoto-centroids).

Draw polygons or upload a custom AOI to define your area of interest, filter by year/media/scale, view estimated photo footprints, and export your selection to CSV.

## Setup

1. Cache the data layers (run once — downloads from BC Data Catalogue):

```r
source("scripts/cache_data.R")
```

2. Launch the app:

```r
shiny::runApp()
```

## Built-in Area of Interest

The "Built in" AOI shown in the app is configured in `scripts/cache_data.R`. By default it's the Neexdzii Kwah (Upper Bulkley) watershed with a 1500m buffer. To change it, edit the `blk` (blue_line_key) and `drm` (downstream_route_measure) parameters at the top of that script and re-run it.

## Custom AOI

Switch to "Custom" mode to either:
- **Draw** a polygon directly on the map
- **Upload** a geojson or geopackage file (e.g. a floodplain polygon prepared in QGIS)

See `scripts/lateral_habitat_to_vector.R` for an example of generating a custom AOI from a raster.

## Dependencies

**Runtime:** shiny, bslib, leaflet, leaflet.extras, sf, DT, dplyr, stringr, purrr, fs

**Cache script:** fwapgr, bcdata, janitor
