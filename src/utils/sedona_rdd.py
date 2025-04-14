from sedona.utils.adapter import Adapter
from sedona.core.enums import GridType, IndexType
from sedona.core.spatialOperator import JoinQueryRaw
from pyspark.sql.session import SparkSession

import logging

def create_spatial_rdds(query_sdf, object_sdf, build_on_spatial_partitioned_rdd = True):

    logging.debug("Creating Spatial RDDs for two spatial dataframes")

    query_rdd  = Adapter.toSpatialRdd(query_sdf, 'geometry')
    object_rdd = Adapter.toSpatialRdd(object_sdf, 'geometry')
    
    query_rdd.analyze()
    object_rdd.analyze()

    object_rdd.spatialPartitioning(GridType.KDBTREE)
    query_rdd.spatialPartitioning(object_rdd.getPartitioner())
    
    query_rdd.buildIndex(IndexType.QUADTREE, build_on_spatial_partitioned_rdd)

    return query_rdd, object_rdd

def count_trees_rdd(sedona: SparkSession, query_rdd, object_rdd, query_column, using_index = True):

    logging.debug("Counting trees for each area using RDD")

    query_result = JoinQueryRaw.SpatialJoinQueryFlat(object_rdd, query_rdd, using_index, True)

    query_result_sdf = Adapter.toDf(query_result, [query_column], ["treeID"], sedona)

    # query_result_df = query_result_sdf.toPandas().sort_values(by=query_column)

    # geo_tree_count_df = query_result_df.groupby(query_column).size().reset_index(name='tree_count')

    geo_tree_count_df = (
        query_result_sdf
        .groupBy(query_column)
        .count()
        .withColumnRenamed("count", "tree_count")
        .orderBy(query_column)
    )

    return geo_tree_count_df
