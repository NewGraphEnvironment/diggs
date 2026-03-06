# diggs <img src="man/figures/logo.png" align="right" height="139" alt="diggs hex sticker"/>

**Delineation-Informed Geographic Ground Selection** — an interactive Shiny app for selecting historic orthophoto imagery from the [BC Data Catalogue](https://catalogue.data.gov.bc.ca/dataset/airphoto-centroids).

Historic airphotos are ground truth for understanding what floodplains looked like before roads, railways, agriculture, and forestry reshaped them. Was that rangeland always rangeland — or was it an old growth cottonwood forest-wetland complex? diggs helps you find the photos to answer that question.

Filter by year, media type, and scale. Draw or upload an AOI. View estimated photo footprints. Run resolution-prioritized selection to get the best coverage with the fewest photos. Export to CSV and order from the [BC Air Photo Warehouse](https://www2.gov.bc.ca/gov/content/data/geographic-data-services/air-photos).

<br>

<p align="center">
  <img src="man/figures/screenshot.png" width="90%" alt="diggs app screenshot showing photo centroids and footprints over the Neexdzii Kwah watershed"/>
</p>

## Install

```r
# install.packages("pak")
pak::pak("NewGraphEnvironment/diggs")
```

## Quick Start

```r
# 1. Cache data layers for your watershed (one-time, ~5 min)
#    Edit data-raw/cache_data.R to set blk/drm for your watershed
source(system.file("data-raw/cache_data.R", package = "diggs"))

# 2. Launch
diggs::run_app()
```

### Configure Your Watershed

Open `data-raw/cache_data.R` and change three parameters:

```r
blk <- 360873822    # blue_line_key — unique stream ID
drm <- 166030.4     # downstream_route_measure — how far upstream (metres)
buf <- 1500         # buffer around watershed (metres)
```

Find `blk` and `drm` for your stream on the [FWA Stream Network map](https://features.hillcrestgeo.ca/fwa/index.html) — click a stream and read the popup.

### Custom AOI

Skip the watershed entirely — switch to **Custom** mode in the app to:

- **Draw** a polygon directly on the map
- **Upload** a GeoJSON or GeoPackage (e.g. a floodplain polygon from QGIS)

## How It Works

1. **Filter** — narrow by year range, media type (B&W, colour, infrared), and scale
2. **Explore** — clustered centroids on the map with popups showing photo metadata
3. **Footprints** — estimate photo coverage rectangles from scale and focal length
4. **Select** — resolution-prioritized greedy set-cover: picks all photos at the finest scale first, then backfills remaining AOI gaps with coarser scales
5. **Export** — download selection as CSV for ordering

Selection uses [fly](https://github.com/NewGraphEnvironment/fly) under the hood for spatial photo operations (footprint estimation, filtering, coverage-based selection).

## Part of the Ecosystem

diggs is one piece of a larger floodplain analysis workflow:

| Package | Role |
|---------|------|
| [flooded](https://github.com/NewGraphEnvironment/flooded) | Delineate floodplain extents from DEMs and stream networks |
| **diggs** | Select historic airphotos covering those floodplains |
| [drift](https://github.com/NewGraphEnvironment/drift) | Track land cover change within floodplains over time (satellite imagery) |
| [fly](https://github.com/NewGraphEnvironment/fly) | Spatial operations on airphoto centroids (used by diggs internally) |

Together: delineate the floodplain (flooded), find what it looked like historically (diggs + ordered airphotos), and measure what changed since (drift). The combination answers questions like: *where were the wetlands before this became pasture? Where did cottonwood galleries disappear? What was the riparian condition when salmon populations were healthy?*
