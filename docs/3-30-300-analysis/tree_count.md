# Tree Count Module Documentation

## Overview

The Tree Count module provides functions for counting the total number of trees within geographic boundaries. This module is part of the 3-30-300 analysis framework for England using big spatial data, focusing on comprehensive tree inventory and spatial analysis using Apache Sedona for distributed processing.

## Module Information

::: src.tree_count
    handler: python
    selection:
      members:
        - concatenate_trees_for_boundary
        - process_geo_code
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for tree counting involves:

1. **Concatenating tree data** - Combining tree data from multiple tiles for a geographic area
2. **Spatial RDD creation** - Creating distributed spatial datasets for efficient processing
3. **Tree counting** - Calculating total tree counts within geographic boundaries
4. **Processing geographic areas** - Running the complete analysis for specific geographic codes

### Example: Processing a Geographic Area

```python
from src.tree_count import process_geo_code
from pyspark.sql.session import SparkSession
import pandas as pd

# Initialize Spark session
sedona = SparkSession.builder.appName("Tree_Count_Analysis").getOrCreate()

# Load required data
output_areas_os_tile_overlay_df = pd.read_csv("path/to/overlay.csv")
tree_vector_paths_df = pd.read_csv("path/to/tree_paths.csv")

# Process tree count for a specific geographic area
result_df = process_geo_code(
    sedona=sedona,
    geo_level="LAD22CD",
    sub_geo_level="LSOA21CD",
    geo_code="E06000001",
    output_areas_os_tile_overlay_df=output_areas_os_tile_overlay_df,
    tree_vector_paths_df=tree_vector_paths_df,
    overwrite=True
)
```

### Example: Concatenating Trees for Boundary

```python
from src.tree_count import concatenate_trees_for_boundary

# Concatenate tree data for a specific boundary
trees_sdf = concatenate_trees_for_boundary(
    sedona=sedona,
    geo_level="LAD22CD",
    geo_code="E06000001",
    output_areas_os_tile_overlay_df=overlay_df,
    tree_vector_paths_df=tree_paths_df
)
```

## Data Processing Components

### Tree Data Sources

- **Vector files**: Tree data stored in GeoPackage format
- **Tile-based organization**: Data organized by 5km OS tiles
- **Spatial indexing**: Optimized for efficient spatial queries
- **Coordinate system**: Uses project's coordinate reference system

### Geographic Boundaries

- **Sub-geographic levels**: Processing at LSOA, MSOA, or other levels
- **Spatial filtering**: Extracting boundaries for specific geographic codes
- **Geometry handling**: Managing complex polygon geometries
- **CRS consistency**: Ensuring coordinate system compatibility

### Spatial RDD Processing

- **Distributed computing**: Using Apache Sedona for large-scale processing
- **Spatial partitioning**: Optimized spatial data distribution
- **Index-based queries**: Efficient spatial intersection calculations
- **Memory optimization**: Handling large tree datasets efficiently

## Key Parameters

### Geographic Parameters

- **geo_level**: Primary geographic level (e.g., "LAD22CD", "MSOA21CD")
- **sub_geo_level**: Sub-geographic level for tree counting (e.g., "LSOA21CD", "OA21CD")
- **geo_code**: Specific geographic code to process

### Processing Parameters

- **overwrite**: Whether to overwrite existing output files
- **build_on_spatial_partitioned_rdd**: Whether to use spatial partitioning (default: True)
- **using_index**: Whether to use spatial indexing for queries (default: True)

### Data Source Parameters

- **output_areas_os_tile_overlay_df**: DataFrame mapping geographic areas to OS tiles
- **tree_vector_paths_df**: DataFrame containing paths to tree vector files

## Output Format

The processed data includes:

- **Geographic identifiers**: Sub-geographic level codes
- **Tree counts**: Total number of trees within each boundary
- **Spatial metadata**: Geometry information for each area
- **File format**: CSV files with geographic code in filename

## Data Processing Steps

### 1. Tile Identification

- **Overlay analysis**: Identifies relevant OS tiles for geographic area
- **Tile filtering**: Selects only tiles that intersect with target area
- **Path resolution**: Maps tile names to actual file paths

### 2. Tree Data Concatenation

- **File reading**: Loads tree data from multiple GeoPackage files
- **Data merging**: Combines tree datasets from multiple tiles
- **CRS validation**: Ensures coordinate system consistency
- **ID assignment**: Creates unique tree identifiers

### 3. Spatial RDD Creation

- **Boundary extraction**: Gets geographic boundaries for processing
- **Spatial partitioning**: Distributes data across cluster nodes
- **Index building**: Creates spatial indices for efficient queries
- **Memory optimization**: Handles large datasets efficiently

### 4. Tree Counting

- **Spatial intersection**: Calculates which trees fall within boundaries
- **Aggregation**: Counts trees per geographic area
- **Result formatting**: Organizes output data structure
- **File output**: Saves results to CSV format

## Performance Optimizations

### Spatial Partitioning

- **Distributed processing**: Uses Apache Sedona's spatial partitioning
- **Load balancing**: Distributes computational load across cluster
- **Memory efficiency**: Reduces memory requirements for large datasets
- **Scalability**: Handles datasets larger than available memory

### Spatial Indexing

- **Query optimization**: Uses spatial indices for faster intersection tests
- **Reduced computation**: Minimizes unnecessary spatial calculations
- **Index maintenance**: Automatically manages spatial index lifecycle
- **Performance monitoring**: Tracks query performance metrics

### Data Organization

- **Tile-based processing**: Processes data in manageable chunks
- **Incremental updates**: Supports overwriting existing results
- **Error handling**: Graceful handling of missing or corrupted data
- **Progress tracking**: Logs processing progress and timing

## Dependencies

This module requires:

- `pyspark` for distributed computing
- `geopandas` for spatial data handling
- `pandas` for data manipulation
- Apache Sedona for spatial RDD operations
- `shapely` for geometric operations

## Performance Considerations

- **Memory Usage**: Large tree datasets can consume significant memory
- **Processing Time**: Spatial operations are computationally intensive
- **Network Overhead**: Distributed processing requires network communication
- **Storage Requirements**: Temporary files may require substantial disk space

## Error Handling

The module includes comprehensive error handling for:

- **Missing files**: Graceful handling of missing tree data files
- **Corrupted data**: Validation of tree geometry and attributes
- **Memory issues**: Automatic memory management and cleanup
- **Network failures**: Retry mechanisms for distributed operations

## Notes

- The module uses Apache Sedona for scalable distributed spatial processing
- Tree data is organized by OS 5km tiles for efficient processing
- All spatial operations use the project's coordinate reference system
- The module includes comprehensive logging for debugging and monitoring
- Output files are organized by geographic code for easy integration
- Spatial RDDs provide significant performance improvements for large datasets
- The module supports incremental processing with overwrite options
