# 3-30-300 Analysis in England using Big Spatial Data

Code for the paper analysing the **3-30-300 urban forestry rule** in England from national-scale geospatial data. The 3-30-300 rule states that every citizen should be able to see at least **3 trees from their home**, have **30% canopy cover** in their neighbourhood, and live within **300 metres of a green space**.

## Repository layout

```
src/   Python pipeline (Apache Sedona / PySpark) that computes the raw metrics
R/     R scripts for tree segmentation, aggregation, modelling and figures
docs/  MkDocs documentation for the Python modules
```

### Python pipeline (`src/`)

`src/main.py` is the entry point. It runs one of the following processes for one or more areas (selected by geography code and level, e.g. a Local Authority District), sequentially or in parallel:

- **T3** (`src/t3.py`): counts trees around each building at several buffer radii
- **T30** (`src/t30.py`): estimates canopy cover per statistical geography from the Vegetation Object Model (VOM) canopy height model
- **T300** (`src/t300.py`): computes network distance from each building to the closest public green space using the road graph
- **Spectral** (`src/spectral.py`): computes NDVI/NDWI/NDBI per geography with Google Earth Engine
- **Tree_count** (`src/tree_count.py`): counts segmented trees per census geography

`src/tables_setup.py` converts the raw inputs into the parquet database the pipeline reads (run once first).

Standalone helper scripts:

- `src/t3_30_300_spectral.py`: joins the per-process outputs into the final combined tables
- `src/spectral_download.py`: exports the GEE spectral imagery to Google Drive as GeoTIFFs
- `src/clip_data.py`: clips trees, buildings, parks and roads to one geography's boundary
- `src/vom_trees_helper.py`: consolidates per-tile tree geopackages into a single geoparquet
- `src/utils/install_jdk.py`: installs the JDK required by Spark

### R analysis (`R/`)

Run in this order:

1. `R/chm_processing.R` — segments individual trees from the VOM canopy height model tiles with `lidR`
2. `R/data_processing.R` — aggregates building-level metrics to LSOA/MSOA/LAD/Region, computes Gini coefficients, writes the aggregated datasets and an `.RData` workspace
3. `R/data_modelling.R` — spatial regression models (OLS, spatial error, spatial lag) of inequality vs deprivation
4. `R/data_analysis.R` — produces the figures and tables in the paper

## Installation

### Python

Requires Python ≥3.10 and [uv](https://docs.astral.sh/uv/):

```bash
git clone <repository-url>
cd 3-30-300-analysis
uv sync

# Configure environment variables
cp .env.example .env
# Edit .env with your paths and GEE project
```

Dependencies are pinned in `uv.lock`. Spark/Sedona jars are resolved automatically from Maven on first run.

### R

The R environment is provided as a conda environment (Linux):

```bash
conda env create -f environment.yml
conda activate r-env
Rscript R/utils/project_setup.R   # installs the remaining CRAN/r-universe packages

# Configure environment variables
cp .Renviron.example .Renviron
# Edit .Renviron with your paths
```

### Google Earth Engine

The Spectral process requires a [Google Earth Engine](https://earthengine.google.com/) account. Authentication is interactive (`ee.Authenticate()`); set your cloud project as `GEE_PROJECT_NAME` in `.env` and upload the Output Area boundaries to your GEE project as the `GEE_BOUNDARIES_ASSET` asset.

## Usage

Run from the repository root:

```bash
# Build the parquet database from the raw inputs (once)
python src/tables_setup.py

# Run one process for one Local Authority District
python src/main.py --process T30 --geo_level LAD22CD --geo_code E06000031

# Run a process for all of England in parallel
python src/main.py --process T3 --parallel --n_workers 4

# See all options
python src/main.py --help
```

## Data

The input data are not distributed with this repository. All datasets are read from `$DATA_DIR/input` (see `src/utils/paths.py` and `R/utils/paths.R` for the expected layout) and outputs are written to `$DATA_DIR/output`:

- **Defra Vegetation Object Model (VOM)**: 1 m canopy height model for England
- **Ordnance Survey**: Open Roads, Open Greenspace and the 5 km national grid
- **Office for National Statistics**: Output Area boundaries, lookups, rural–urban classification, population estimates and the English Index of Multiple Deprivation
- **Verisk UKBuildings**: building footprints and attributes (licensed; obtain via Digimap)
- **Sentinel-2 (Copernicus)**: surface reflectance imagery via Google Earth Engine
- **Forest Research**: National Forest Inventory and Trees Outside Woodland (comparison analyses)

## Documentation

API documentation for the Python modules is built with MkDocs (`mkdocs serve`) and published via GitHub Actions.

## License

This project is licensed under the MIT License — see the LICENSE file for details.

## Citation

If you use this code, please cite the accompanying paper:

> Zúñiga-González, A.C., et al. (2026). *[Paper title]*. [Journal]. [DOI]

(Full reference to be added on publication.)
