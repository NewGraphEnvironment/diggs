# airbc

BC Historic Airphoto Explorer — interactive Shiny app for selecting historic orthophoto imagery from the [BC Data Catalogue](https://catalogue.data.gov.bc.ca/dataset/airphoto-centroids).

Draw polygons to define your area of interest, filter by year/media/scale, view estimated photo footprints, and export your selection to CSV.

## Setup

1. Cache the data layers (run once):

```r
source("scripts/cache_data.R")
```

2. Launch the app:

```r
shiny::runApp()
```

## Dependencies

**Runtime:** shiny, bslib, leaflet, leaflet.extras, sf, DT, dplyr, stringr, purrr, fs

**Cache script:** rfp, fwapgr, bcdata, janitor
