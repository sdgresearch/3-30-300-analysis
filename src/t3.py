"""
Module: src/t3.py
Description: Functions for calculating the number of trees within a buffer of a building (T3).
Author: Andrés C. Zúñiga-González
Date: 2025-07-16
"""

from utils.paths import T3_30_300_DIR, T3_dir
from utils.data_processing import generate_tile_paths, get_overlapping_grid_tiles, filter_buffer_geometries, get_geometries
from utils.sedona_rdd import create_spatial_rdds, count_trees_rdd

import time
import glob
import shutil
import logging
import tempfile
import pandas as pd
import geopandas as gpd
from pyspark.sql.dataframe import DataFrame
from pyspark.sql.session import SparkSession
from pyspark.sql.functions import monotonically_increasing_id

# TODO: Merge process_vom_tiles with read_vom_trees_geoparquet so that it reads geopackages based on tile_level using tree_vector_paths_df
def process_vom_tiles(sedona: SparkSession, trees_path_lst: list, tree_area: int=10, tree_height: int=3) -> gpd.GeoDataFrame:
    """
    Processes the VOM tiles to create a GeoDataFrame of the trees.
    Args:
        sedona (SparkSession): The Spark session.
        trees_path_lst (list): The list of paths to the VOM tiles.
        tree_area (int): The area of the tree.
        tree_height (int): The height of the tree.
    Returns:
        gpd.GeoDataFrame: The GeoDataFrame of the trees.
    """
    
    logging.debug(f"Reading {len(trees_path_lst)} VOM tiles")

    if len(trees_path_lst) > 1:
        
        trees_gdf_lst = [gpd.read_file(tree_path) for tree_path in trees_path_lst]
        merged_trees_gdf = gpd.GeoDataFrame(pd.concat(trees_gdf_lst, ignore_index=True))
    elif len(trees_path_lst) == 1: 
        merged_trees_gdf = gpd.read_file(trees_path_lst[0])

    else:
        return None

    geo_trees_gdf = merged_trees_gdf[(merged_trees_gdf.area > tree_area) & (merged_trees_gdf.height > tree_height)].reset_index(drop=True)
    geo_trees_gdf['treeID'] = range(len(geo_trees_gdf))

    geo_trees_gdf['geometry'] = geo_trees_gdf['geometry'].centroid

    geo_trees_sdf = sedona.createDataFrame(geo_trees_gdf)
    geo_trees_sdf.createOrReplaceTempView("geo_trees")

    return geo_trees_gdf

# TODO: Figure out how to integrate the creation of the VOM_Trees geoparquet with the new version of the code
def read_vom_trees_geoparquet(sedona: SparkSession, overlapping_tiles_lst: list) -> DataFrame:
    """
    Reads the VOM trees geoparquet files.
    Args:
        sedona (SparkSession): The Spark session.
        overlapping_tiles_lst (list): The list of overlapping tiles.
    Returns:
        DataFrame: The VOM trees dataframe.
    """

    vom_trees_dir = T3_30_300_DIR / "VOM_Trees_geoparquet"
    vom_trees_paths = [str(path) for path in vom_trees_dir.glob("*.geoparquet") if any(tile_name in path.name for tile_name in overlapping_tiles_lst)]
    geo_trees_sdf = sedona.read.format("geoparquet").load(vom_trees_paths)

    geo_trees_sdf.withColumn("treeID", monotonically_increasing_id()).createOrReplaceTempView("geo_trees")

    return geo_trees_sdf

def count_trees(sedona: SparkSession, geo_code: str) -> pd.DataFrame:
    """
    Counts the trees for each building.
    Args:
        sedona (SparkSession): The Spark session.
        geo_code (str): The geo code.
    Returns:
        pd.DataFrame: The dataframe with the tree counts.
    """

    logging.debug(f"Counting trees for each building in {geo_code}")

    trees_within_buffer_sdf = sedona.sql(
        """
            SELECT b.verisk_premise_id, COUNT(t.treeID) AS tree_count
            FROM building_buffers b
            LEFT JOIN geo_trees t
            ON ST_Intersects(b.geometry, t.geometry)
            GROUP BY b.verisk_premise_id
        """)
    
    geo_tree_count_df = trees_within_buffer_sdf.toPandas()

    return geo_tree_count_df

def process_geo_code(sedona: SparkSession, query_method: str, geo_level: str, geo_code: str, tile_level: str,
                     output_areas_boundaries_gdf: gpd.GeoDataFrame, os_tile_boundaries_gdf: gpd.GeoDataFrame,
                     output_areas_os_tile_overlay_df: pd.DataFrame, vom_raster_paths_df: pd.DataFrame, 
                     tree_vector_paths_df: pd.DataFrame, buffer: int=100, tree_area: int=10, 
                     tree_height: int=3, overwrite: bool=True) -> pd.DataFrame:
    """
    Processes a given geo_code for T3.
    Args:
        sedona (SparkSession): The Spark session.
        query_method (str): The query method.
        geo_level (str): The geo level.
        geo_code (str): The geo code.
        tile_level (str): The tile level.   
        output_areas_boundaries_gdf (gpd.GeoDataFrame): The output areas boundaries dataframe.
        os_tile_boundaries_gdf (gpd.GeoDataFrame): The OS tile boundaries dataframe.
        output_areas_os_tile_overlay_df (pd.DataFrame): The output areas OS tile overlay dataframe.
        vom_raster_paths_df (pd.DataFrame): The VOM raster paths dataframe.
        tree_vector_paths_df (pd.DataFrame): The tree vector paths dataframe.
        buffer (int): The buffer size.  
        tree_area (int): The area of the tree.
        tree_height (int): The height of the tree.
        overwrite (bool): Whether to overwrite the existing file.
    Returns:
        pd.DataFrame: The dataframe with the tree counts.
    """

    start_time = time.time()
    logging.info(f"Processing data for {geo_code} with buffer {buffer}m")

    geo_tree_count_path = T3_dir / f"T3_{geo_code}_{buffer}m.csv"
    
    if not geo_tree_count_path.exists() or overwrite:
        try:
            get_geometries(sedona, geo_level, geo_code, True)
            geo_buildings_buffer_sdf = filter_buffer_geometries(sedona, geo_level, geo_code, 'buildings', buffer)
            overlapping_tiles_lst = get_overlapping_grid_tiles(output_areas_boundaries_gdf, os_tile_boundaries_gdf, geo_level, geo_code, tile_level)
            
            if query_method == 'sql':

                logging.debug("Executing query using SQL")

                geo_tiles_df = generate_tile_paths(geo_level, geo_code, output_areas_os_tile_overlay_df, vom_raster_paths_df, tree_vector_paths_df)
                tree_paths_lst = geo_tiles_df.groupby('TILE_NAME').first().reset_index()['path_tree'].tolist()
                process_vom_tiles(sedona, tree_paths_lst, tree_area=tree_area, tree_height=tree_height)

                geo_tree_count_df = count_trees(sedona, geo_level, geo_code)

                geo_tree_count_df.to_csv(geo_tree_count_path, index=False)
            
            elif query_method == 'rdd':

                logging.debug("Executing query using Spatial RDD")
                
                geo_trees_sdf = read_vom_trees_geoparquet(sedona, overlapping_tiles_lst)
                geo_buildings_buffer_rdd, geo_trees_rdd = create_spatial_rdds(geo_buildings_buffer_sdf, geo_trees_sdf, build_on_spatial_partitioned_rdd = True)
                geo_tree_count_df = count_trees_rdd(sedona, geo_buildings_buffer_rdd, geo_trees_rdd, 'verisk_premise_id', using_index = True)
                
                temp_dir = tempfile.TemporaryDirectory()

                geo_tree_count_df.coalesce(1) \
                    .write \
                    .option("header", True) \
                    .mode("overwrite") \
                    .csv(temp_dir.name)
                
                # Step 2: Find the part file Spark wrote
                part_file = glob.glob(temp_dir.name + "/part-*.csv")[0]
                
                # Step 3: Move and rename it to your target file
                shutil.move(part_file, str(geo_tree_count_path))

                # Step 4: Clean up temp folder
                temp_dir.cleanup()
                
                geo_tree_count_df = pd.read_csv(geo_tree_count_path)
                geo_tree_count_df.rename(columns={'tree_count': f'tree_count_{buffer}m'}, inplace=True)
            
            end_time = time.time()
            logging.info(f"Processing for {geo_code} with {len(geo_tree_count_df)} records took {end_time - start_time:.2f} seconds")

            return geo_tree_count_df

        except Exception as e:
            logging.error(f"Error processing {geo_code}: {e}")
            