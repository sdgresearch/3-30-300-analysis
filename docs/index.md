# 3-30-300 Analysis in England using Big Spatial Data

## Overview

This project implements the **3-30-300 urban forestry rule** for England using big spatial data analysis. The 3-30-300 rule states that every citizen should be able to see at least **3 trees from their home**, have **30% canopy cover** in their neighborhood, and live within **300 meters of a park**.

## What is the 3-30-300 Rule?

The 3-30-300 rule is an urban forestry guideline that promotes healthy, accessible urban forests. This project measures each component with a proxy:

- **3 trees (tree proximity)**: number of trees within a buffer of each residential building (not the number of trees visible from it)
- **30% canopy cover**: share of tree canopy in the neighbourhood, from the binarised Vegetation Object Model
- **300 m to a park (park distance)**: shortest road-network distance from each building to the nearest public park access point (vehicle road network, not a walking route)

## Project Components

### Core Analysis Modules

- **[T3 Module](3-30-300-analysis/t3.md)**: Tree counting within building buffers
- **[T30 Module](3-30-300-analysis/t30.md)**: Canopy cover analysis using VOM data
- **[T300 Module](3-30-300-analysis/t300.md)**: Road-network park distance analysis
- **[Tree Count](3-30-300-analysis/tree_count.md)**: Comprehensive tree inventory
- **[Spectral Analysis](3-30-300-analysis/spectral.md)**: Remote sensing indices

### Data Infrastructure

- **[Tables Setup](3-30-300-analysis/tables_setup.md)**: Data preprocessing and organization
- **[Spectral Module](3-30-300-analysis/spectral.md)**: Google Earth Engine integration

### Utility Modules

- **[Constants](3-30-300-analysis/utils/constants.md)**: Project configuration and constants
- **[Data Processing](3-30-300-analysis/utils/data_processing.md)**: Spatial data utilities
- **[Install JDK](3-30-300-analysis/utils/install_jdk.md)**: Java installation for Spark/Sedona
- **[Logging Config](3-30-300-analysis/utils/logging_config.md)**: Logging setup and management
- **[Paths](3-30-300-analysis/utils/paths.md)**: File path management
- **[Sedona Config](3-30-300-analysis/utils/sedona_config.md)**: Apache Sedona configuration
- **[Sedona RDD](3-30-300-analysis/utils/sedona_rdd.md)**: Distributed spatial processing

## Data Sources

### Spatial Data
- **VOM (Vegetation Object Model)**: High-resolution tree and canopy data from Defra
- **OS (Ordnance Survey)**: Road networks, buildings, and green spaces
- **ONS (Office for National Statistics)**: Geographic boundaries and population data
- **Verisk**: Building footprints and attributes

### Remote Sensing
- **Sentinel-2**: Satellite imagery for spectral analysis
- **Google Earth Engine**: Cloud-based remote sensing processing

## Technology Stack

### Distributed Computing
- **Apache Spark**: Distributed data processing
- **Apache Sedona**: Spatial extensions for Spark
- **PySpark**: Python interface for Spark

### Spatial Analysis
- **GeoPandas**: Spatial data manipulation
- **Rasterio**: Raster data processing
- **Shapely**: Geometric operations

### Remote Sensing
- **Google Earth Engine**: Cloud-based geospatial analysis
- **Earth Engine Python API**: Programmatic access to GEE

## Quick Start

### Prerequisites
1. **Java 8+**: Required for Apache Spark
2. **Python 3.8+**: Core programming language
3. **Google Earth Engine Account**: For remote sensing analysis

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd 3-30-300-analysis

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration
```

### Basic Usage
```python
from src.utils.sedona_config import get_spark
from src.t3 import process_geo_code

# Initialize Spark session
sedona = get_spark()

# Process T3 analysis for a geographic area
result = process_geo_code(
    sedona=sedona,
    geo_level="LAD22CD",
    geo_code="E06000001",
    # ... other parameters
)
```

## Analysis Workflow

### 1. Data Preparation
- Load and preprocess spatial data
- Convert to efficient parquet format
- Set up geographic boundaries and overlays

### 2. T3 Analysis (Tree Counting)
- Count trees within building buffers (tree proximity)
- Generate tree density statistics

### 3. T30 Analysis (Canopy Cover)
- Process VOM canopy height data
- Calculate canopy cover percentages
- Analyze vegetation density

### 4. T300 Analysis (Park Distance)
- Calculate road-network distances to parks
- Generate park-distance statistics

### 5. Spectral Analysis
- Calculate NDVI, NDBI, NDWI indices
- Analyze environmental conditions
- Integrate remote sensing data

### 6. Integration
- Combine all analysis components
- Generate comprehensive reports
- Create final datasets

## Output Data

### Analysis Results
- **Tree counts**: Number of trees per geographic area
- **Canopy cover**: Percentage of canopy coverage
- **Park distances**: Network and Euclidean distances to parks
- **Spectral indices**: Environmental indicators
- **Integrated metrics**: Combined 3-30-300 analysis

### File Formats
- **Parquet**: Efficient columnar storage
- **CSV**: Standard tabular format
- **GeoJSON**: Spatial data for web applications
- **Shapefile**: Traditional GIS format

## Performance Considerations

### Scalability
- **Distributed processing**: Handles large datasets across cluster
- **Spatial partitioning**: Optimizes spatial operations
- **Memory management**: Efficient memory usage for big data

### Optimization
- **Spatial indexing**: Accelerates spatial queries
- **Data compression**: Reduces storage requirements
- **Parallel processing**: Maximizes computational resources

## Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

### Code Standards
- Follow PEP 8 style guidelines
- Add comprehensive docstrings
- Include unit tests for new functions
- Update documentation for changes

## Documentation

This documentation provides comprehensive coverage of:

- **Module Documentation**: Detailed API reference for all modules
- **Usage Examples**: Practical code examples
- **Configuration Guide**: Setup and configuration instructions
- **Performance Tips**: Optimization and best practices
- **Troubleshooting**: Common issues and solutions

