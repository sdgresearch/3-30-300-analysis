# Data Processing Module Documentation

## Overview

The Data Processing module provides utility functions for spatial data processing, file management, and data transformation in the 3-30-300 analysis framework. This module handles tile name translation, spatial filtering, geometry operations, and file format conversions.

## Module Information

::: src.utils.data_processing
    handler: python
    selection:
      members:
        - translate_tile_name
        - get_overlapping_grid_tiles
        - generate_tile_paths
        - filter_buffer_geometries
        - get_geometries
        - save_csv_as_parquet
        - save_temp_file
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for data processing involves:

1. **Tile name translation** - Converting between different tile naming formats
2. **Spatial filtering** - Extracting geometries for specific geographic areas
3. **Path generation** - Creating file paths for VOM and tree data
4. **File conversion** - Converting between different file formats

### Example: Translating Tile Names

```python
from src.utils.data_processing import translate_tile_name

# Convert from numeric to directional format
numeric_tile = "TL0045"
directional_tile = translate_tile_name(numeric_tile)
print(f"{numeric_tile} -> {directional_tile}")  # TL0045 -> TL04NW

# Convert from directional to numeric format
directional_tile = "TL04NW"
numeric_tile = translate_tile_name(directional_tile)
print(f"{directional_tile} -> {numeric_tile}")  # TL04NW -> tl0045
```

### Example: Getting Overlapping Grid Tiles

```python
from src.utils.data_processing import get_overlapping_grid_tiles

# Get overlapping tiles for a geographic area
overlapping_tiles = get_overlapping_grid_tiles(
    output_areas_boundaries_gdf=boundaries_gdf,
    os_tile_boundaries_gdf=tiles_gdf,
    geo_level="LAD22CD",
    geo_code="E06000001",
    tile_level="TILE_NAME_5KM"
)
```

### Example: Generating Tile Paths

```python
from src.utils.data_processing import generate_tile_paths

# Generate paths for VOM and tree data
tile_paths_df = generate_tile_paths(
    geo_level="LAD22CD",
    geo_code="E06000001",
    output_areas_os_tile_overlay_df=overlay_df,
    vom_raster_paths_df=vom_paths_df,
    tree_vector_paths_df=tree_paths_df
)
```

### Example: Filtering Buffer Geometries

```python
from src.utils.data_processing import filter_buffer_geometries

# Filter buildings with buffer
buildings_buffer_sdf = filter_buffer_geometries(
    sedona=sedona,
    geo_level="LAD22CD",
    geo_code="E06000001",
    table_name="buildings",
    buffer=100
)
```

### Example: Getting Geometries

```python
from src.utils.data_processing import get_geometries

# Get dissolved geometries for an area
boundary_sdf = get_geometries(
    sedona=sedona,
    geo_level="LAD22CD",
    geo_code="E06000001",
    dissolve=True
)
```

### Example: Saving Files

```python
from src.utils.data_processing import save_temp_file, save_csv_as_parquet
from pathlib import Path

# Save Spark DataFrame as single file
output_path = Path("output/data.parquet")
pandas_df = save_temp_file(
    spark_df=result_sdf,
    output_path=output_path,
    coalesce=1,
    file_format="parquet"
)

# Convert CSV files to parquet
csv_df = save_csv_as_parquet(
    in_directory=Path("input/"),
    path_pattern="*.csv",
    out_path=Path("output/combined.parquet")
)
```

## Tile Name Translation

### Tile Name Formats

#### Format 1: Numeric Coordinates
- **Pattern**: `TL0045` (where '0045' represents coordinates)
- **Structure**: 2-letter prefix + 4-digit numeric code
- **Example**: `TL0045`, `SU1234`, `SP5678`

#### Format 2: Directional Codes
- **Pattern**: `TL04NW` (where 'NW' represents directions)
- **Structure**: 2-letter prefix + 2-digit number + 2-letter direction
- **Example**: `TL04NW`, `SU12SE`, `SP56NE`

### Translation Logic

- **Numeric to Directional**: Converts coordinate numbers to directional codes
- **Directional to Numeric**: Converts directional codes to coordinate numbers
- **Case Handling**: Maintains appropriate case for each format
- **Validation**: Ensures input tile names are 6 characters long

## Spatial Operations

### Grid Tile Overlap

- **Spatial Intersection**: Finds tiles that overlap with geographic areas
- **Efficient Filtering**: Uses spatial indexing for performance
- **Result Aggregation**: Returns unique tile names for processing
- **Coordinate System**: Works with project coordinate reference system

### Geometry Filtering

- **Spatial Joins**: Uses ST_Intersects for spatial relationships
- **Buffer Operations**: Creates spatial buffers around geometries
- **Dissolution**: Combines multiple geometries into single boundary
- **Temporary Views**: Creates Spark SQL views for efficient querying

## File Management

### Path Generation

- **Tile Matching**: Matches geographic areas with available data tiles
- **Year Sorting**: Orders data by year (newest first)
- **Duplicate Removal**: Eliminates duplicate tile-year combinations
- **Path Validation**: Ensures file paths exist and are accessible

### File Format Conversion

- **CSV to Parquet**: Converts CSV files to efficient parquet format
- **Spark to Pandas**: Converts Spark DataFrames to Pandas DataFrames
- **Single File Output**: Ensures single output file instead of directory
- **Format Validation**: Supports multiple output formats

## Key Parameters

### Tile Translation Parameters

- **tile_name**: 6-character tile name to translate
- **format**: Source format (numeric or directional)
- **case**: Output case (upper or lower)

### Spatial Operation Parameters

- **geo_level**: Geographic level (LAD22CD, MSOA21CD, etc.)
- **geo_code**: Specific geographic code
- **buffer**: Buffer distance in meters
- **dissolve**: Whether to dissolve geometries

### File Operation Parameters

- **output_path**: Target file path
- **file_format**: Output format (parquet, csv)
- **coalesce**: Number of partitions for output
- **path_pattern**: File pattern for glob matching

## Data Flow

### Input Data

- **Geographic Boundaries**: Output area boundaries and tile boundaries
- **VOM Data**: Raster file paths and metadata
- **Tree Data**: Vector file paths and metadata
- **Building Data**: Building geometries and attributes

### Processing Steps

1. **Tile Name Translation**: Converts between naming formats
2. **Spatial Filtering**: Extracts relevant geographic areas
3. **Path Generation**: Creates file paths for data access
4. **Geometry Operations**: Performs spatial analysis
5. **File Conversion**: Converts between file formats

### Output Data

- **Translated Names**: Tile names in target format
- **Filtered Geometries**: Spatial data for specific areas
- **File Paths**: Organized paths for data access
- **Converted Files**: Data in target format

## Performance Optimizations

### Spatial Operations

- **Spatial Indexing**: Uses spatial indices for efficient queries
- **Partitioning**: Distributes processing across cluster nodes
- **Caching**: Caches frequently accessed geometries
- **Batch Processing**: Processes multiple areas efficiently

### File Operations

- **Coalescing**: Reduces number of output files
- **Compression**: Uses efficient file compression
- **Parallel Processing**: Processes files in parallel
- **Memory Management**: Optimizes memory usage for large files

## Error Handling

The module includes comprehensive error handling for:

- **Invalid tile names**: Validates tile name format and length
- **Missing files**: Handles missing data files gracefully
- **Spatial errors**: Manages spatial operation failures
- **File system issues**: Handles file permission and path issues
- **Memory errors**: Manages large dataset memory requirements

## Dependencies

This module requires:

- `pandas` for data manipulation
- `geopandas` for spatial data handling
- `pyspark` for distributed processing
- `pathlib` for cross-platform path handling
- `tempfile` for temporary file management
- `shutil` for file operations

## Notes

- The module provides standardized data processing utilities
- All spatial operations use the project's coordinate reference system
- Tile name translation supports OS (Ordnance Survey) conventions
- File operations are optimized for large-scale processing
- The module includes comprehensive error handling and validation
- Supports both local and distributed processing scenarios
- Maintains data integrity throughout processing pipeline
