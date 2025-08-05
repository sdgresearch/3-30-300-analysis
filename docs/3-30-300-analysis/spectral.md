# Spectral Module Documentation

## Overview

The Spectral module provides functions for calculating spectral indices using Google Earth Engine (GEE). This module is part of the 3-30-300 analysis framework for England using big spatial data, focusing on remote sensing analysis to derive environmental indices like NDVI, NDBI, and NDWI.

## Module Information

::: src.spectral
    handler: python
    selection:
      members:
        - setup_gee
        - get_imagery
        - calculate_median_index
        - process_geo_code
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for spectral analysis involves:

1. **Setting up GEE** - Initializing Google Earth Engine authentication and project
2. **Getting imagery** - Querying satellite imagery with specified parameters
3. **Calculating indices** - Computing spectral indices for geographic areas
4. **Processing geographic codes** - Running the complete analysis for specific areas

### Example: Processing a Geographic Area

```python
from src.spectral import process_geo_code, setup_gee

# Initialize Google Earth Engine
setup_gee()

# Process spectral indices for a specific geographic area
result_df = process_geo_code(
    geo_code="E06000001",
    geo_level="LAD22CD",
    sub_geo_level="LSOA21CD",
    imagery_ee_path="COPERNICUS/S2_SR_HARMONIZED",
    start_date="2023-01-01",
    end_date="2023-12-31",
    cloud_coverage=20.0,
    spectral_indexes=["NDVI", "NDBI", "NDWI"],
    overwrite=True
)
```

### Example: Setting up Google Earth Engine

```python
from src.spectral import setup_gee

# Initialize GEE with project configuration
setup_gee()
```

### Example: Getting Imagery

```python
from src.spectral import get_imagery
import ee

# Create feature collection for your area of interest
geo_level_filt_fc = ee.FeatureCollection("path/to/your/feature/collection")

# Get imagery with specified parameters
imagery = get_imagery(
    geo_level_filt_fc=geo_level_filt_fc,
    imagery_ee_path="COPERNICUS/S2_SR_HARMONIZED",
    start_date="2023-01-01",
    end_date="2023-12-31",
    cloud_coverage=20.0,
    spectral_indexes=["NDVI", "NDBI", "NDWI"]
)
```

### Example: Calculating Median Index

```python
from src.spectral import calculate_median_index

# Calculate median spectral indices for geometries
median_results = calculate_median_index(
    imagery_ic=imagery,
    geometries=feature_collection,
    scale=10.0,
    tile_scale=4
)
```

## Spectral Indices

### NDVI (Normalized Difference Vegetation Index)

- **Purpose**: Measures vegetation health and density
- **Formula**: (NIR - Red) / (NIR + Red)
- **Range**: -1 to 1 (higher values indicate healthier vegetation)
- **Use Case**: Assessing urban greenery and vegetation cover

### NDBI (Normalized Difference Built-up Index)

- **Purpose**: Identifies built-up areas and urban development
- **Formula**: (SWIR - NIR) / (SWIR + NIR)
- **Range**: -1 to 1 (higher values indicate more built-up areas)
- **Use Case**: Mapping urban development and impervious surfaces

### NDWI (Normalized Difference Water Index)

- **Purpose**: Detects water bodies and moisture content
- **Formula**: (Green - NIR) / (Green + NIR)
- **Range**: -1 to 1 (higher values indicate more water/moisture)
- **Use Case**: Identifying water bodies and assessing moisture levels

## Key Parameters

### Geographic Parameters

- **geo_code**: Specific geographic code to process
- **geo_level**: Primary geographic level (e.g., "LAD22CD")
- **sub_geo_level**: Sub-geographic level for analysis (e.g., "LSOA21CD")

### Imagery Parameters

- **imagery_ee_path**: Path to imagery collection in Google Earth Engine
- **start_date**: Start date for imagery collection (YYYY-MM-DD)
- **end_date**: End date for imagery collection (YYYY-MM-DD)
- **cloud_coverage**: Maximum cloud coverage percentage (0-100)

### Processing Parameters

- **spectral_indexes**: List of spectral indices to calculate
- **scale**: Resolution in meters for calculations (default: 10.0)
- **tile_scale**: Scaling factor for aggregation (default: 4)
- **overwrite**: Whether to overwrite existing output files

## Data Sources

### Sentinel-2 Satellite Imagery

- **Source**: COPERNICUS/S2_SR_HARMONIZED
- **Resolution**: 10-20 meters
- **Coverage**: Global with frequent revisits
- **Bands**: Multiple spectral bands for various indices

### Google Earth Engine

- **Platform**: Cloud-based geospatial analysis platform
- **Processing**: Distributed computing for large-scale analysis
- **Authentication**: Requires GEE account and authentication
- **API**: Python client library for programmatic access

## Output Format

The processed data includes:

- **Geographic identifiers**: Sub-geographic level codes
- **Spectral indices**: Calculated NDVI, NDBI, NDWI values
- **Metadata**: Processing parameters and timestamps
- **File format**: CSV files with geographic code in filename

## Processing Steps

### 1. GEE Setup
- **Authentication**: Establishes connection to Google Earth Engine
- **Project initialization**: Sets up project-specific configuration
- **API access**: Enables programmatic access to GEE services

### 2. Imagery Collection
- **Date filtering**: Selects imagery within specified date range
- **Cloud filtering**: Removes images with excessive cloud coverage
- **Spatial filtering**: Limits imagery to area of interest
- **Index calculation**: Computes specified spectral indices

### 3. Spatial Analysis
- **Geometry processing**: Handles geographic boundaries and unions
- **Zonal statistics**: Calculates median values for each area
- **Data aggregation**: Combines results by geographic level

### 4. Output Generation
- **Data formatting**: Converts GEE results to pandas DataFrame
- **File saving**: Exports results to CSV format
- **Metadata tracking**: Records processing parameters and timing

## Dependencies

This module requires:

- `earthengine-api` for Google Earth Engine access
- `eemont` for enhanced Earth Engine functionality
- `pandas` for data manipulation
- `ee` for Earth Engine Python client
- Google Earth Engine account and authentication

## Performance Considerations

- **GEE Quotas**: Be aware of Google Earth Engine usage quotas
- **Processing Time**: Large areas may require significant processing time
- **Memory Usage**: High-resolution imagery can be memory-intensive
- **Network**: Requires stable internet connection for GEE access

## Authentication Setup

Before using this module, you need to:

1. **Create GEE Account**: Sign up for Google Earth Engine
2. **Enable APIs**: Enable Earth Engine API in Google Cloud Console
3. **Authenticate**: Run `earthengine authenticate` in terminal
4. **Set Project**: Configure your GEE project name in constants

## Notes

- The module uses Google Earth Engine for scalable cloud-based processing
- Spectral indices provide environmental context for urban forestry analysis
- All calculations use median values to reduce noise and outliers
- Processing is optimized for geographic areas with cloud coverage filtering
- Output files are organized by geographic code for easy integration
- The module includes comprehensive error handling and logging
- Authentication is required before running any GEE operations
