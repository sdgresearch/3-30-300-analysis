# Sedona Config Module Documentation

## Overview

The Sedona Config module provides functions for setting up and configuring Apache Sedona Spark sessions for distributed spatial processing. This module handles Spark configuration, memory management, and Sedona integration for the 3-30-300 analysis framework.

## Module Information

::: src.utils.sedona_config
    handler: python
    selection:
      members:
        - get_spark
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for Sedona configuration involves:

1. **Environment setup** - Setting JAVA_HOME and other environment variables
2. **Spark configuration** - Configuring Spark session with Sedona packages
3. **Memory optimization** - Setting appropriate memory limits for spatial processing
4. **Session creation** - Creating and returning configured Spark session

### Example: Getting Configured Spark Session

```python
from src.utils.sedona_config import get_spark

# Get configured Apache Sedona Spark session
sedona = get_spark()

# Use the session for spatial operations
# sedona.sql("SELECT * FROM spatial_table")
```

### Example: Using Spark Session in Analysis

```python
from src.utils.sedona_config import get_spark
from src.utils.sedona_rdd import create_spatial_rdds

# Get configured session
sedona = get_spark()

# Use for spatial RDD operations
query_rdd, object_rdd = create_spatial_rdds(
    query_sdf=boundaries_sdf,
    object_sdf=trees_sdf,
    build_on_spatial_partitioned_rdd=True
)
```

## Spark Configuration

### Core Configuration

- **JAVA_HOME**: Sets Java home directory for Spark
- **Sedona Packages**: Includes all necessary Sedona and GeoTools packages
- **Repository Configuration**: Configures package repositories for dependencies

### Memory Configuration

- **Executor Memory**: 32GB for worker node processing
- **Driver Memory**: 64GB for driver node operations
- **Max Result Size**: 15GB for large result handling
- **Parallelism**: 200 default partitions for distributed processing

### Performance Optimizations

- **Debug Configuration**: Extended string field limits for WKT data
- **Partition Management**: Disables automatic partition coalescing
- **Task Management**: Configures concurrent tasks and failure handling
- **Local Mode**: Optimized for local development with 10 concurrent tasks

## Package Dependencies

### Apache Sedona

- **sedona-spark-3.5_2.12:1.7.0**: Core Sedona Spark integration
- **geotools-wrapper:1.7.0-28.5**: GeoTools spatial library wrapper
- **postgis-jdbc:2021.1.0**: PostgreSQL spatial database driver
- **postgis-geometry:2021.1.0**: PostGIS geometry handling
- **postgresql:42.5.4**: PostgreSQL database driver

### Repository Sources

- **Unidata Repository**: Primary source for geospatial packages
- **Maven Central**: Standard Java package repository
- **Local Cache**: Optimized package resolution

## Configuration Parameters

### Environment Variables

- **JAVA_HOME**: Java installation directory
- **SPARK_HOME**: Spark installation directory (auto-detected)
- **SEDONA_HOME**: Sedona installation directory (auto-detected)

### Spark Settings

- **spark.jars.packages**: Sedona and geospatial package dependencies
- **spark.jars.repositories**: Package repository configuration
- **spark.sql.debug.maxToStringFields**: Extended debug information
- **spark.default.parallelism**: Default partition count
- **spark.sql.adaptive.coalescePartitions.enabled**: Partition management
- **spark.executor.memory**: Worker node memory allocation
- **spark.driver.memory**: Driver node memory allocation
- **spark.driver.maxResultSize**: Maximum result size limit

### Local Development Settings

- **master**: Local mode with 10 concurrent tasks
- **maxFailures**: 0 failures allowed in development
- **taskLimit**: 10 concurrent tasks for resource management

## Memory Management

### Memory Allocation Strategy

- **Executor Memory (32GB)**: Sufficient for large spatial datasets
- **Driver Memory (64GB)**: Handles complex spatial operations
- **Max Result Size (15GB)**: Accommodates large spatial results
- **Partition Management**: Prevents automatic coalescing for large data

### Memory Optimization

- **Spatial Partitioning**: Distributes memory load across nodes
- **Index Management**: Optimizes memory usage for spatial indices
- **Garbage Collection**: Automatic memory cleanup for spatial operations
- **Caching Strategy**: Strategic data caching for repeated operations

## Performance Considerations

### Distributed Processing

- **Parallelism**: 200 default partitions for large datasets
- **Task Management**: 10 concurrent tasks for local development
- **Network Optimization**: Minimizes data transfer between nodes
- **Fault Tolerance**: Handles node failures gracefully

### Spatial Operations

- **Spatial Partitioning**: KDB-tree algorithm for efficient distribution
- **Index Building**: QuadTree indices for fast spatial queries
- **Join Optimization**: Index-based spatial join operations
- **Memory Efficiency**: Optimized for large spatial datasets

## Error Handling

The module includes comprehensive error handling for:

- **Memory issues**: Automatic memory management and cleanup
- **Package resolution**: Robust dependency management
- **Configuration errors**: Validation of Spark configuration
- **Environment issues**: JAVA_HOME and environment variable handling

## Dependencies

This module requires:

- `pyspark` for Spark session management
- `sedona` for Apache Sedona integration
- Java 8 or higher for Spark and Sedona
- Apache Spark for distributed computing framework
- Apache Sedona for spatial processing capabilities

## Development vs Production

### Development Configuration

- **Local Mode**: Single-node processing for development
- **Limited Tasks**: 10 concurrent tasks for resource management
- **Debug Information**: Extended logging and debugging
- **Quick Setup**: Optimized for rapid development cycles

### Production Configuration

- **Cluster Mode**: Multi-node distributed processing
- **High Parallelism**: 200+ partitions for large datasets
- **Memory Optimization**: Optimized memory allocation
- **Fault Tolerance**: Robust error handling and recovery

## Notes

- The module provides a standardized Spark configuration for spatial processing
- Memory settings are optimized for large spatial datasets
- Local mode configuration is suitable for development and testing
- All spatial operations use the configured coordinate reference system
- The module includes comprehensive error handling and logging
- Configuration supports both development and production environments
- Package dependencies are automatically managed and resolved
