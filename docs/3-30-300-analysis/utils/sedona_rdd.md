# Sedona RDD Module Documentation

## Overview

The Sedona RDD module provides functions for creating and managing Apache Sedona Spatial RDDs (Resilient Distributed Datasets) for distributed spatial processing. This module handles spatial partitioning, indexing, and join operations for large-scale spatial analysis in the 3-30-300 framework.

## Module Information

::: src.utils.sedona_rdd
    handler: python
    selection:
      members:
        - create_spatial_rdds
        - count_trees_rdd
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for Sedona RDD operations involves:

1. **Creating Spatial RDDs** - Converting Spark DataFrames to Spatial RDDs
2. **Spatial partitioning** - Distributing spatial data across cluster nodes
3. **Index building** - Creating spatial indices for efficient queries
4. **Spatial joins** - Performing distributed spatial operations

### Example: Creating Spatial RDDs

```python
from src.utils.sedona_rdd import create_spatial_rdds
from pyspark.sql.session import SparkSession

# Initialize Spark session
sedona = SparkSession.builder.appName("Sedona_RDD").getOrCreate()

# Create Spatial RDDs from DataFrames
query_rdd, object_rdd = create_spatial_rdds(
    query_sdf=boundaries_sdf,
    object_sdf=trees_sdf,
    build_on_spatial_partitioned_rdd=True
)
```

### Example: Counting Trees with RDD

```python
from src.utils.sedona_rdd import count_trees_rdd

# Count trees for each geographic area
tree_counts_df = count_trees_rdd(
    sedona=sedona,
    query_rdd=boundaries_rdd,
    object_rdd=trees_rdd,
    query_column="LSOA21CD",
    using_index=True
)
```

## Spatial RDD Operations

### RDD Creation Process

1. **DataFrame Conversion**: Converts Spark DataFrames to Spatial RDDs
2. **Geometry Analysis**: Analyzes spatial extent and properties
3. **Spatial Partitioning**: Distributes data using KDB-tree partitioning
4. **Index Building**: Creates QuadTree spatial indices

### Spatial Partitioning

- **KDB-tree Partitioning**: Uses K-dimensional binary tree for spatial distribution
- **Load Balancing**: Distributes computational load across cluster nodes
- **Memory Optimization**: Reduces memory requirements for large datasets
- **Scalability**: Handles datasets larger than available memory

### Spatial Indexing

- **QuadTree Index**: Hierarchical spatial index for efficient queries
- **Index Building**: Creates spatial indices on partitioned RDDs
- **Query Optimization**: Accelerates spatial join operations
- **Memory Management**: Optimizes index memory usage

## Key Parameters

### RDD Creation Parameters

- **query_sdf**: Spark DataFrame containing query geometries
- **object_sdf**: Spark DataFrame containing object geometries
- **build_on_spatial_partitioned_rdd**: Whether to build index on partitioned RDD

### Tree Counting Parameters

- **sedona**: Spark session for distributed processing
- **query_rdd**: Spatial RDD containing query geometries
- **object_rdd**: Spatial RDD containing tree geometries
- **query_column**: Column name for grouping results
- **using_index**: Whether to use spatial index for joins

## Spatial Join Operations

### Join Types

- **SpatialJoinQueryFlat**: Performs spatial intersection joins
- **Index-based Joins**: Uses spatial indices for efficient operations
- **Distributed Processing**: Leverages cluster resources for large datasets

### Join Process

1. **Spatial Analysis**: Analyzes spatial relationships between datasets
2. **Index Utilization**: Uses spatial indices to optimize join operations
3. **Result Aggregation**: Groups and counts results by geographic areas
4. **DataFrame Conversion**: Converts results back to Spark DataFrames

## Performance Optimizations

### Spatial Partitioning

- **KDB-tree Algorithm**: Efficient spatial partitioning algorithm
- **Load Distribution**: Balances computational load across nodes
- **Memory Efficiency**: Reduces memory requirements per node
- **Scalability**: Handles datasets larger than single node memory

### Index Optimization

- **QuadTree Index**: Hierarchical spatial index structure
- **Index Building**: Creates indices on partitioned data
- **Query Acceleration**: Speeds up spatial join operations
- **Memory Management**: Optimizes index storage and retrieval

### Distributed Processing

- **Cluster Utilization**: Leverages all available cluster nodes
- **Parallel Operations**: Performs spatial operations in parallel
- **Network Optimization**: Minimizes data transfer between nodes
- **Fault Tolerance**: Handles node failures gracefully

## Data Flow

### Input Data

- **Query DataFrames**: Geographic boundaries and areas of interest
- **Object DataFrames**: Spatial objects (trees, buildings, etc.)
- **Geometry Columns**: Spatial geometry data in WKT or WKB format

### Processing Steps

1. **RDD Creation**: Converts DataFrames to Spatial RDDs
2. **Spatial Analysis**: Analyzes spatial properties and extents
3. **Partitioning**: Distributes data using KDB-tree algorithm
4. **Index Building**: Creates QuadTree spatial indices
5. **Spatial Joins**: Performs distributed spatial operations
6. **Result Aggregation**: Groups and counts spatial relationships

### Output Data

- **Tree Counts**: Number of trees per geographic area
- **Spatial Relationships**: Spatial intersection results
- **Aggregated Data**: Grouped results by specified columns

## Dependencies

This module requires:

- `pyspark` for distributed computing
- `sedona` for spatial RDD operations
- Apache Sedona for spatial processing
- Apache Spark for distributed computing framework

## Performance Considerations

- **Memory Usage**: Large spatial datasets can consume significant memory
- **Processing Time**: Spatial operations are computationally intensive
- **Network Overhead**: Distributed processing requires network communication
- **Index Maintenance**: Spatial indices require memory and processing overhead

## Error Handling

The module includes comprehensive error handling for:

- **Memory issues**: Automatic memory management and cleanup
- **Network failures**: Retry mechanisms for distributed operations
- **Data type issues**: Geometry validation and conversion
- **Partitioning errors**: Spatial partitioning failure recovery

## Notes

- The module uses Apache Sedona for scalable distributed spatial processing
- KDB-tree partitioning provides efficient spatial data distribution
- QuadTree indexing accelerates spatial join operations
- All spatial operations use the project's coordinate reference system
- The module includes comprehensive logging for debugging and monitoring
- Spatial RDDs provide significant performance improvements for large datasets
- Distributed processing enables analysis of datasets larger than available memory
