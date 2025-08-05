# Paths Module Documentation

## Overview

The Paths module defines all file and directory paths used throughout the 3-30-300 analysis framework. This module centralizes path management for input data sources, output directories, and processed data files, ensuring consistent file organization across the project.

## Module Information

::: src.utils.paths
    handler: python
    selection:
      members:
        - vom_dir
        - vom_unzipped_dir
        - imd_england_2019_path
        - oa_2021_lookup_path
        - oa_2021_boundaries_path
        - oa_rgn_lookup_path
        - lsoa_2011_2021_lookup_path
        - population_estimates_path
        - os_5km_boundaries_path
        - green_space_path
        - roads_path
        - buildings_path
        - output_areas_boundaries_ee_path
        - T3_30_300_DIR
        - T3_dir
        - T30_dir
        - T300_dir
        - Spectral_dir
        - trees_dir
        - trees_unique_dir
        - trees_unique_parquet_dir
        - tree_count_dir
        - database_dir
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Directory Structure

### Input Data Sources

#### VOM (Vegetation Object Model) Data
- **vom_dir**: Main VOM data directory
- **vom_unzipped_dir**: Unzipped VOM tile files

#### CDRC (Consumer Data Research Centre)
- **imd_england_2019_path**: Index of Multiple Deprivation 2019 data

#### ONS (Office for National Statistics)
- **oa_2021_lookup_path**: Output Area to LSOA/MSOA/LAD lookup table
- **oa_2021_boundaries_path**: Output Area boundaries (GeoJSON)
- **oa_rgn_lookup_path**: Output Area to Region lookup table
- **lsoa_2011_2021_lookup_path**: LSOA 2011 to 2021 lookup table
- **population_estimates_path**: Population estimates by LSOA

#### OS (Ordnance Survey)
- **os_5km_boundaries_path**: 5km National Grid boundaries
- **green_space_path**: Green spaces and access points
- **roads_path**: Road network data

#### Verisk
- **buildings_path**: Building footprints and attributes

#### Google Earth Engine
- **output_areas_boundaries_ee_path**: Output area boundaries in GEE

### Output Directories

#### Main Analysis Directory
- **T3_30_300_DIR**: Root directory for all 3-30-300 analysis outputs

#### Component Directories
- **T3_dir**: Tree count analysis outputs
- **T30_dir**: Canopy cover analysis outputs
- **T300_dir**: Park distance analysis outputs
- **Spectral_dir**: Spectral indices analysis outputs

#### Data Processing Directories
- **trees_dir**: VOM tree vector data
- **trees_unique_dir**: Unique tree data files
- **trees_unique_parquet_dir**: Parquet format tree data
- **tree_count_dir**: Tree counting results
- **database_dir**: Processed parquet files

## Parquet File Paths

### Input Data Parquet Files
- **vom_raster_paths_parquet**: VOM raster file paths
- **tree_vector_paths_parquet**: Tree vector file paths
- **os_tile_boundaries_parquet**: OS tile boundaries
- **output_areas_boundaries_parquet**: Output area boundaries
- **output_areas_os_tile_overlay_parquet**: Area-tile overlay mapping
- **output_areas_buildings_parquet**: Area-building overlay mapping
- **imd_lsoa_parquet**: IMD data by LSOA
- **std_population_estimates_parquet**: Standardized population estimates
- **green_space_access_parquet**: Green space access points
- **green_space_site_parquet**: Green space site boundaries
- **road_edges_parquet**: Road network edges
- **road_nodes_parquet**: Road network nodes
- **buildings_parquet**: Building data

### Analysis Output Parquet Files
- **t30_parquet**: T30 canopy cover results
- **t300_parquet**: T300 park distance results
- **t3_300_parquet**: Combined T3 and T300 results
- **t3_300_metrics_parquet**: T3 and T300 metrics
- **spectral_parquet**: Spectral indices results
- **tree_count_parquet**: Tree count results
- **t3_30_300_spectral_parquet**: Complete analysis results

## Usage Examples

### Accessing Input Data Paths

```python
from src.utils.paths import (
    vom_unzipped_dir,
    imd_england_2019_path,
    oa_2021_boundaries_path,
    buildings_path
)

# Access VOM data directory
vom_data_dir = vom_unzipped_dir

# Access IMD data
imd_data_path = imd_england_2019_path

# Access geographic boundaries
boundaries_path = oa_2021_boundaries_path

# Access building data
building_data_path = buildings_path
```

### Accessing Output Directories

```python
from src.utils.paths import (
    T3_30_300_DIR,
    T3_dir,
    T30_dir,
    T300_dir,
    Spectral_dir,
    database_dir
)

# Access main analysis directory
main_dir = T3_30_300_DIR

# Access component directories
t3_output_dir = T3_dir
t30_output_dir = T30_dir
t300_output_dir = T300_dir
spectral_output_dir = Spectral_dir

# Access database directory
db_dir = database_dir
```

### Accessing Parquet File Paths

```python
from src.utils.paths import (
    vom_raster_paths_parquet,
    tree_vector_paths_parquet,
    output_areas_boundaries_parquet,
    buildings_parquet
)

# Access VOM data paths
vom_paths_file = vom_raster_paths_parquet
tree_paths_file = tree_vector_paths_parquet

# Access processed data
boundaries_file = output_areas_boundaries_parquet
buildings_file = buildings_parquet
```

## Data Source Organization

### Input Data Structure

```
INPUT_DIR/
├── Defra/
│   └── VOM/
│       └── unzipped_tiles/
├── CDRC/
│   └── IMD/
│       └── English IMD 2019/
├── ONS/
│   ├── Output_Area_*.csv
│   ├── Output_Areas_*.geojson
│   └── sapelsoabroadage*.xlsx
├── OS/
│   ├── National_Grid/
│   ├── Green_Spaces/
│   └── Roads/
└── Verisk/
    └── Buildings_6183/
```

### Output Data Structure

```
OUTPUT_DIR/
└── 3-30-300/
    ├── T3/
    ├── T30/
    ├── T300/
    ├── Spectral/
    ├── VOM_Trees/
    ├── VOM_Trees_unique/
    ├── VOM_Trees_parquet/
    ├── Tree_count/
    └── database/
        ├── *.parquet
        └── ...
```

## File Naming Conventions

### Input Files

- **Shapefiles**: `.shp` format for geographic boundaries
- **GeoJSON**: `.geojson` format for web-compatible geometries
- **GeoPackage**: `.gpkg` format for spatial data
- **CSV**: `.csv` format for lookup tables
- **Excel**: `.xlsx` format for complex data tables

### Output Files

- **Parquet**: `.parquet` format for efficient data storage
- **CSV**: `.csv` format for analysis results
- **GeoJSON**: `.geojson` format for spatial results

## Path Management

### Relative Paths

- All paths are relative to project root
- Uses `pathlib.Path` for cross-platform compatibility
- Automatic path resolution and validation

### Path Validation

- Checks for file existence before processing
- Creates directories if they don't exist
- Handles missing data gracefully

### Cross-Platform Compatibility

- Uses `pathlib.Path` for platform independence
- Handles Windows and Unix path separators
- Supports both absolute and relative paths

## Dependencies

This module requires:

- `pathlib` for cross-platform path handling
- `utils.constants` for base directory definitions
- Python 3.6+ for pathlib support

## Notes

- All paths are centralized for easy maintenance
- Path structure follows logical data organization
- Supports both development and production environments
- Includes comprehensive path validation and error handling
- Uses consistent naming conventions across the project
- Supports both local and distributed file systems
- Paths are optimized for Spark and distributed processing 