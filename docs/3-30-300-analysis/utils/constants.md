# Constants Module Documentation

## Overview

The Constants module defines all project-wide constants and configuration values for the 3-30-300 analysis framework. This module centralizes configuration management, environment variable handling, and project settings to ensure consistency across all analysis components.

## Module Information

::: src.utils.constants
    handler: python
    selection:
      members:
        - DATA_DIR
        - INPUT_DIR
        - OUTPUT_DIR
        - JAVA_HOME
        - GEE_PROJECT_NAME
        - PROJECT_CRS
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for constants usage involves:

1. **Environment setup** - Loading environment variables from .env file
2. **Path configuration** - Setting up data directories and file paths
3. **System configuration** - Configuring Java and Google Earth Engine
4. **Spatial configuration** - Setting coordinate reference system

### Example: Accessing Data Directories

```python
from src.utils.constants import DATA_DIR, INPUT_DIR, OUTPUT_DIR

# Access main data directory
data_directory = DATA_DIR

# Access input and output directories
input_directory = INPUT_DIR
output_directory = OUTPUT_DIR

print(f"Data directory: {data_directory}")
print(f"Input directory: {input_directory}")
print(f"Output directory: {output_directory}")
```

### Example: Using Java Configuration

```python
from src.utils.constants import JAVA_HOME

# Access Java home directory
java_home = JAVA_HOME
print(f"Java home: {java_home}")

# Use in Spark configuration
import os
os.environ["JAVA_HOME"] = JAVA_HOME
```

### Example: Using Google Earth Engine Configuration

```python
from src.utils.constants import GEE_PROJECT_NAME

# Access GEE project name
project_name = GEE_PROJECT_NAME
print(f"GEE project: {project_name}")

# Use in GEE initialization
import ee
ee.Initialize(project=project_name)
```

### Example: Using Coordinate Reference System

```python
from src.utils.constants import PROJECT_CRS

# Access project CRS
crs = PROJECT_CRS
print(f"Project CRS: {crs}")

# Use in spatial operations
import geopandas as gpd
gdf = gdf.to_crs(PROJECT_CRS)
```

## Configuration Constants

### Directory Structure

- **DATA_DIR**: Root data directory from environment variable
- **INPUT_DIR**: Input data directory (DATA_DIR/input)
- **OUTPUT_DIR**: Output data directory (DATA_DIR/output)

### System Configuration

- **JAVA_HOME**: Java Development Kit installation path
- **GEE_PROJECT_NAME**: Google Earth Engine project name

### Spatial Configuration

- **PROJECT_CRS**: Coordinate reference system for all spatial data

## Environment Variables

### Required Environment Variables

The module expects the following environment variables in a `.env` file:

```env
# Data directory
DATA_DIR=/path/to/data/directory

# Java configuration
JDK_HOME=jdk-8.0.0

# Google Earth Engine
GEE_PROJECT_NAME=your-gee-project-name
```

### Environment Variable Loading

- **dotenv**: Automatically loads environment variables from .env file
- **Fallback**: Uses default values if environment variables are missing
- **Validation**: Ensures required environment variables are present
- **Path Resolution**: Converts string paths to Path objects

## Directory Structure

### Data Directory Layout

```
DATA_DIR/
├── input/
│   ├── Defra/
│   ├── CDRC/
│   ├── ONS/
│   ├── OS/
│   └── Verisk/
└── output/
    └── 3-30-300/
        ├── T3/
        ├── T30/
        ├── T300/
        ├── Spectral/
        └── database/
```

### Java Directory Layout

```
.jdk/
└── jdk-8.0.0/
    ├── bin/
    ├── lib/
    └── ...
```

## Coordinate Reference System

### OSGB 1936 / British National Grid

- **EPSG Code**: 27700
- **Projection**: Transverse Mercator
- **Datum**: OSGB 1936
- **Units**: Meters
- **Coverage**: Great Britain

### Usage in Spatial Operations

- **Data Loading**: All spatial data converted to this CRS
- **Analysis**: All spatial operations use this CRS
- **Output**: All results in this CRS
- **Compatibility**: Compatible with OS (Ordnance Survey) data

## Configuration Management

### Environment-Based Configuration

- **Development**: Uses local environment variables
- **Production**: Uses production environment variables
- **Testing**: Uses test environment variables
- **Flexibility**: Easy to switch between environments

### Path Management

- **Cross-Platform**: Uses pathlib for platform independence
- **Validation**: Ensures directories exist and are accessible
- **Creation**: Automatically creates directories if needed
- **Permissions**: Handles file system permissions

## Integration with Other Modules

### Paths Module Integration

```python
from src.utils.constants import INPUT_DIR, OUTPUT_DIR
from src.utils.paths import vom_dir, T3_30_300_DIR

# Constants used in path definitions
vom_dir = INPUT_DIR / "Defra" / "VOM"
T3_30_300_DIR = OUTPUT_DIR / "3-30-300"
```

### Sedona Config Integration

```python
from src.utils.constants import JAVA_HOME
from src.utils.sedona_config import get_spark

# Java home used in Spark configuration
os.environ["JAVA_HOME"] = JAVA_HOME
sedona = get_spark()
```

### Spectral Module Integration

```python
from src.utils.constants import GEE_PROJECT_NAME
from src.utils.spectral import setup_gee

# GEE project name used in spectral analysis
ee.Initialize(project=GEE_PROJECT_NAME)
```

## Error Handling

The module includes comprehensive error handling for:

- **Missing environment variables**: Provides default values or clear error messages
- **Invalid paths**: Validates directory paths and permissions
- **CRS issues**: Ensures coordinate reference system is valid
- **Java configuration**: Validates Java installation and configuration

## Dependencies

This module requires:

- `os` for environment variable access
- `pathlib` for cross-platform path handling
- `dotenv` for environment file loading
- Python 3.6+ for pathlib support

## Notes

- The module provides centralized configuration management
- Environment variables enable flexible deployment across environments
- All paths use pathlib for cross-platform compatibility
- Coordinate reference system ensures spatial data consistency
- Java configuration supports Spark and Sedona requirements
- Google Earth Engine configuration enables remote sensing analysis
- The module supports both development and production environments 