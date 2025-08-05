# VOM Processing Module Documentation

## Overview

The VOM Processing module provides functions for processing Vegetation Object Model (VOM) data files. This module handles file classification, metadata extraction, and path generation for both raster (CHM) and vector (tree) VOM data, supporting the 3-30-300 analysis framework.

## Module Information

::: src.utils.vom_processing
    handler: python
    selection:
      members:
        - extract_vom_type
        - extract_vom_type_udf
        - extract_grid_reference
        - extract_grid_reference_udf
        - extract_year
        - extract_year_udf
        - generate_vom_paths_df
        - generate_tree_paths_df
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for VOM processing involves:

1. **File classification** - Identifying VOM file types (CHM vs HS)
2. **Metadata extraction** - Extracting grid references and years from filenames
3. **Path generation** - Creating organized DataFrames of file paths
4. **Data organization** - Sorting and filtering VOM data by tile and year

### Example: Generating VOM Paths DataFrame

```python
from src.utils.vom_processing import generate_vom_paths_df
from pyspark.sql.session import SparkSession

# Initialize Spark session
sedona = SparkSession.builder.appName("VOM_Processing").getOrCreate()

# Generate VOM paths DataFrame
vom_paths_df = generate_vom_paths_df(sedona)
```

### Example: Generating Tree Paths DataFrame

```python
from src.utils.vom_processing import generate_tree_paths_df
from pathlib import Path

# Generate tree paths DataFrame
trees_dir = Path("path/to/trees/directory")
tree_paths_df = generate_tree_paths_df(trees_dir)
```

### Example: Extracting VOM Type

```python
from src.utils.vom_processing import extract_vom_type

# Classify VOM file type
file_name = "VOM_HS_AB1234_2023.tif"
vom_type = extract_vom_type(file_name)  # Returns 'HS'

file_name = "VOM_CHM_CD5678_2022.tif"
vom_type = extract_vom_type(file_name)  # Returns 'CHM'
```

### Example: Extracting Grid Reference

```python
from src.utils.vom_processing import extract_grid_reference

# Extract grid reference from filename
filename = "VOM_HS_AB1234_2023.tif"
grid_ref = extract_grid_reference(filename)  # Returns 'AB1234'
```

### Example: Extracting Year

```python
from src.utils.vom_processing import extract_year

# Extract year from file path
file_path = "/data/2023/VOM_HS_AB1234_2023.tif"
year = extract_year(file_path)  # Returns 2023
```

## VOM Data Types

### CHM (Canopy Height Model)

- **Purpose**: Represents tree canopy height information
- **File Pattern**: `VOM_CHM_[GRIDREF]_[YEAR].tif`
- **Use Case**: Primary data source for T30 canopy cover analysis
- **Processing**: Raster-based height model analysis

### HS (Height Structure)

- **Purpose**: Represents detailed height structure information
- **File Pattern**: `VOM_HS_[GRIDREF]_[YEAR].tif`
- **Use Case**: Supplementary height structure analysis
- **Processing**: Detailed structural information

## Key Parameters

### File Classification Parameters

- **file_name**: Filename or path to classify
- **filename**: Filename to extract grid reference from
- **file_path**: File path to extract year from

### Processing Parameters

- **sedona**: Spark session for distributed processing
- **trees_dir**: Directory containing tree vector files
- **vom_unzipped_dir**: Directory containing unzipped VOM raster files

## Output Data Structure

### VOM Paths DataFrame

The `generate_vom_paths_df()` function creates a DataFrame with:

- **path**: Full file path to VOM raster file
- **file_type**: VOM type classification ('CHM' or 'HS')
- **TILE_NAME**: Grid reference extracted from filename
- **year**: Year extracted from file path

### Tree Paths DataFrame

The `generate_tree_paths_df()` function creates a DataFrame with:

- **TILE_NAME**: Grid reference extracted from filename
- **year**: Year extracted from filename
- **path**: Full file path to tree vector file

## Data Processing Steps

### 1. File Discovery

- **Binary file loading**: Uses Spark's binaryFile format to discover VOM files
- **Pattern matching**: Identifies VOM files using regex patterns
- **Path resolution**: Converts file URIs to local file paths

### 2. Metadata Extraction

- **Type classification**: Distinguishes between CHM and HS file types
- **Grid reference extraction**: Extracts OS grid references from filenames
- **Year extraction**: Extracts year information from file paths

### 3. Data Organization

- **Filtering**: Focuses on CHM files for canopy analysis
- **Sorting**: Orders files by tile name and year (newest first)
- **Index management**: Resets DataFrame indices for clean output

### 4. Output Generation

- **Parquet storage**: Saves organized DataFrames to parquet format
- **Path standardization**: Ensures consistent file path formatting
- **Metadata preservation**: Maintains all extracted metadata

## Spark Integration

### UDF Functions

The module provides Spark UDF wrappers for:

- **extract_vom_type_udf**: Classifies VOM file types in Spark DataFrames
- **extract_grid_reference_udf**: Extracts grid references in Spark DataFrames
- **extract_year_udf**: Extracts years in Spark DataFrames

### Distributed Processing

- **Binary file loading**: Uses Spark's distributed file reading capabilities
- **Column operations**: Applies UDFs across distributed DataFrames
- **Filtering**: Performs distributed filtering operations
- **Sorting**: Handles large-scale sorting operations

## File Naming Conventions

### VOM Raster Files

- **Pattern**: `VOM_[TYPE]_[GRIDREF]_[YEAR].tif`
- **Example**: `VOM_CHM_AB1234_2023.tif`
- **Components**:
  - `VOM`: Vegetation Object Model identifier
  - `[TYPE]`: CHM (Canopy Height Model) or HS (Height Structure)
  - `[GRIDREF]`: OS grid reference (2 letters + 4 digits)
  - `[YEAR]`: Year of data collection
  - `.tif`: GeoTIFF format

### Tree Vector Files

- **Pattern**: `VOM_trees_[GRIDREF]_[YEAR].gpkg`
- **Example**: `VOM_trees_AB1234_2023.gpkg`
- **Components**:
  - `VOM_trees`: Tree vector identifier
  - `[GRIDREF]`: OS grid reference (2 letters + 4 digits)
  - `[YEAR]`: Year of data collection
  - `.gpkg`: GeoPackage format

## Dependencies

This module requires:

- `pyspark` for distributed computing
- `pandas` for data manipulation
- `pathlib` for file path handling
- `re` for regular expression operations
- Apache Spark for distributed file processing

## Performance Considerations

- **Distributed processing**: Uses Spark for large-scale file discovery
- **Memory efficiency**: Processes files in distributed manner
- **Pattern matching**: Optimized regex operations for metadata extraction
- **Sorting optimization**: Efficient sorting of large datasets

## Error Handling

The module includes comprehensive error handling for:

- **Missing files**: Graceful handling of missing VOM data
- **Invalid patterns**: Robust regex pattern matching
- **Path issues**: File path validation and correction
- **Data type issues**: Type conversion error handling

## Notes

- The module supports both raster (CHM/HS) and vector (tree) VOM data
- All file operations use distributed processing for scalability
- Grid references follow OS (Ordnance Survey) naming conventions
- Files are automatically sorted by tile and year for efficient processing
- The module creates standardized DataFrames for downstream analysis
- Comprehensive logging tracks processing progress and identifies issues
- UDF functions enable efficient Spark DataFrame operations
