# Tables Setup Module Documentation

## Overview

The Tables Setup module provides functions for initializing and managing the data infrastructure for the 3-30-300 analysis framework. This module handles data preprocessing, parquet file creation, directory structure setup, and table loading for the big spatial data analysis project.

## Module Information

::: src.tables_setup
    handler: python
    selection:
      members:
        - setup_parquet_files
        - create_in_out_folders
        - load_tables
        - process_population_data
        - expand_national_grid
        - overlay_output_areas_with_os_tiles
        - overlay_output_areas_with_buildings
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for tables setup involves:

1. **Creating directory structure** - Setting up input/output folders and project directories
2. **Setting up parquet files** - Converting raw data to efficient parquet format
3. **Loading tables** - Loading processed data into Spark DataFrames and GeoDataFrames
4. **Creating overlays** - Generating spatial relationships between different datasets

### Example: Complete Setup Process

```python
from src.tables_setup import create_in_out_folders, setup_parquet_files, load_tables
from pyspark.sql.session import SparkSession

# Initialize Spark session
sedona = SparkSession.builder.appName("Tables_Setup").getOrCreate()

# Create directory structure
create_in_out_folders()

# Set up parquet files from raw data
setup_parquet_files()

# Load all tables into memory
tables_dict = load_tables(sedona)
```

### Example: Creating Directory Structure

```python
from src.tables_setup import create_in_out_folders

# Create all necessary directories for the project
create_in_out_folders()
```

### Example: Setting up Parquet Files

```python
from src.tables_setup import setup_parquet_files

# Convert raw data files to parquet format
setup_parquet_files()
```

### Example: Loading Tables

```python
from src.tables_setup import load_tables

# Load all tables into a dictionary
tables = load_tables(sedona)

# Access specific tables
boundaries_gdf = tables["output_areas_boundaries_gdf"]
buildings_sdf = tables["buildings_sdf"]
road_edges_gdf = tables["road_edges_gdf"]
```

### Example: Processing Population Data

```python
from src.tables_setup import process_population_data
import pandas as pd

# Load raw population data
population_df = pd.read_excel("path/to/population_data.xlsx")

# Process population data with ratios
processed_population_df = process_population_data(population_df)
```

## Data Sources and Processing

### Input Data Sources

- **IMD (Index of Multiple Deprivation)**: England 2019 deprivation data
- **Population Estimates**: Mid-2022 LSOA population data
- **Geographic Boundaries**: OA, LSOA, MSOA, LAD, and Regional boundaries
- **OS Data**: Ordnance Survey 5km tiles, roads, and buildings
- **Green Space Data**: Public parks and access points
- **Lookup Tables**: Geographic code mappings and relationships

### Data Processing Components

#### Geographic Data Processing
- **Boundary merging**: Combining multiple geographic levels
- **CRS transformation**: Converting to project coordinate reference system
- **Area calculations**: Computing geographic area statistics
- **Spatial filtering**: Removing non-England areas (e.g., Wales)

#### Population Data Processing
- **Age group ratios**: Calculating demographic proportions
- **Gender ratios**: Computing male/female population ratios
- **Age range ratios**: Determining age distribution patterns
- **Standardization**: Creating consistent column naming

#### OS Tile Processing
- **Grid expansion**: Creating 10km, 50km, and 100km tile references
- **Tile naming**: Standardizing tile name formats
- **Spatial indexing**: Optimizing tile-based queries

## Key Parameters

### Directory Structure
- **INPUT_DIR**: Raw data input directory
- **OUTPUT_DIR**: Processed data output directory
- **T3_30_300_DIR**: Main analysis results directory
- **database_dir**: Parquet file storage directory

### Data Processing Parameters
- **PROJECT_CRS**: Coordinate reference system for spatial data
- **overwrite**: Whether to overwrite existing files
- **index**: Whether to include index in parquet files

### Geographic Parameters
- **geo_level**: Geographic level for processing (OA, LSOA, MSOA, LAD, RGN)
- **spatial_join**: Type of spatial relationship for overlays

## Output Data Structure

### Parquet Files Created

#### Geographic Data
- `output_areas_boundaries.parquet`: Complete geographic boundaries with all levels
- `os_tile_boundaries.parquet`: OS tile boundaries with multiple scales
- `output_areas_os_tile_overlay.parquet`: Geographic area to tile mapping

#### Infrastructure Data
- `road_edges.parquet`: Road network edges for routing
- `road_nodes.parquet`: Road network nodes for routing
- `buildings.parquet`: Building footprints and attributes
- `green_space_access.parquet`: Green space access points
- `green_space_site.parquet`: Green space site boundaries

#### Demographic Data
- `std_population_estimates.parquet`: Processed population data with ratios
- `imd_lsoa.parquet`: Index of Multiple Deprivation data

#### Analysis Data
- `vom_raster_paths.parquet`: Vegetation Object Model raster file paths
- `tree_vector_paths.parquet`: Tree vector file paths

### Table Dictionary Structure

The `load_tables()` function returns a dictionary containing:

- **GeoDataFrames**: Spatial data for boundaries, roads, buildings, green spaces
- **Spark DataFrames**: Large datasets optimized for distributed processing
- **Pandas DataFrames**: Smaller datasets for efficient local processing
- **Temporary Views**: Spark SQL views for querying

## Data Processing Pipeline

### Step 1: Directory Creation
- **Input/Output folders**: Creates project directory structure
- **Analysis folders**: Sets up T3, T30, T300, and Spectral directories
- **Data folders**: Creates VOM and tree data directories

### Step 2: Data Loading
- **Shapefile reading**: Loads geographic boundaries and infrastructure data
- **CSV/Excel reading**: Imports demographic and lookup data
- **CRS transformation**: Converts all spatial data to project CRS

### Step 3: Data Processing
- **Geographic merging**: Combines multiple geographic levels
- **Population processing**: Calculates demographic ratios and proportions
- **Tile expansion**: Creates multi-scale OS tile references
- **Spatial filtering**: Removes non-relevant areas

### Step 4: Parquet Creation
- **Efficient storage**: Converts all data to parquet format
- **Column selection**: Optimizes data structure for analysis
- **Index management**: Handles spatial and attribute indices
- **File organization**: Organizes files by data type and purpose

### Step 5: Table Loading
- **Spark DataFrames**: Loads large datasets for distributed processing
- **GeoDataFrames**: Maintains spatial data for local operations
- **Temporary views**: Creates SQL views for Spark queries
- **Memory optimization**: Manages data loading efficiently

## Spatial Operations

### Overlay Operations
- **Output areas with OS tiles**: Maps geographic areas to tile system
- **Output areas with buildings**: Links buildings to geographic boundaries
- **Spatial joins**: Performs efficient spatial relationship queries

### Coordinate System Management
- **CRS consistency**: Ensures all spatial data uses same coordinate system
- **Transformation**: Converts between different coordinate systems
- **Validation**: Verifies spatial data integrity

## Performance Optimizations

### Parquet Format
- **Compression**: Reduces file sizes significantly
- **Columnar storage**: Optimizes analytical queries
- **Schema evolution**: Supports data structure changes
- **Partitioning**: Enables efficient data partitioning

### Spark Integration
- **Distributed processing**: Handles large datasets efficiently
- **Memory management**: Optimizes memory usage for big data
- **Query optimization**: Uses Spark SQL for efficient queries
- **Caching**: Implements strategic data caching

## Dependencies

This module requires:

- `pyspark` for distributed computing
- `geopandas` for spatial data handling
- `pandas` for data manipulation
- `shapely` for geometric operations
- `fiona` for file format support
- `pyproj` for coordinate system transformations

## Error Handling

The module includes comprehensive error handling for:

- **Missing files**: Graceful handling of missing input data
- **Corrupted data**: Validation of data integrity
- **CRS issues**: Coordinate system transformation errors
- **Memory issues**: Large dataset memory management
- **File permissions**: Directory and file access issues

## Notes

- The module provides the foundation for all 3-30-300 analysis components
- All spatial operations use the project's coordinate reference system
- Parquet format provides significant performance improvements over CSV
- The module supports incremental updates and overwrite options
- Comprehensive logging tracks processing progress and identifies issues
- Spatial indexing optimizes query performance for large datasets
- The module creates a standardized data structure for consistent analysis
