"""
Module: data_processing.py
Description: Functions for cleaning and transforming data in My Project.
Author: Your Name
Date: YYYY-MM-DD
"""

from src.utils.paths import *
from src.utils.constants import *
from src.utils.logging_config import *
from src.utils.data_processing import generate_tile_paths, get_overlapping_grid_tiles
# from src.utils.vom_processing import extract_grid_reference

from sedona.utils.adapter import Adapter
from sedona.core.enums import GridType
from sedona.core.enums import IndexType
from sedona.core.spatialOperator import JoinQueryRaw

import time
import pandas as pd
import geopandas as gpd

# def check_tree_vom_pair(chm_path: str|Path, trees_dir: str|Path) -> bool:
#     """
#     Check if a CHM file has a corresponding tree file.
#     Parameters:
#         chm_path (str | Path): The path to the CHM file.
#         trees_dir (str | Path): The directory containing the tree files.
#     Returns:
#         bool: True if a corresponding tree file exists, otherwise False.
#     """

#     logging.debug(f"Checking if {chm_path} has a corresponding tree file in {trees_dir}")

#     tile_name = extract_grid_reference(chm_path)
#     chm_path = chm_path if isinstance(chm_path, Path) else Path(chm_path)
#     trees_dir = trees_dir if isinstance(trees_dir, Path) else Path(trees_dir)
#     year = chm_path.parent.name

#     trees_path = trees_dir / f"VOM_trees_{tile_name}_{year}.gpkg"

#     if trees_path.exists():
#         return str(trees_path)
    
# def get_vom_trees_paths(overlapping_tiles_lst: list, vom_tree_pair_dict: dict) -> list:

#     logging.debug(f"Getting VOM trees paths for {len(overlapping_tiles_lst)} overlapping tiles")

#     vom_trees_path_lst = list(set([path_pair[1] for _,v in vom_tree_pair_dict.items() for path_pair in v if path_pair[1] is not None]))
#     trees_path_lst = []
#     for tile_name in overlapping_tiles_lst:
#         translated_tile_name = translate_tile_name(tile_name).upper()
#         tile_path = [path for path in vom_trees_path_lst if translated_tile_name in path]
#         trees_path_lst.append(tile_path[0])

#     return trees_path_lst

def process_vom_tiles(sedona, trees_path_lst: list, tree_area: int=10, tree_height: int=3) -> gpd.GeoDataFrame:

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

def process_buildings(sedona, geo_level: str, geo_code: str, buffer: int=100) -> None:

    logging.debug(f"Filtering buildings for {geo_code}")

    geo_boundary_sdf = sedona.sql(
        f"""
            SELECT ST_Union_Aggr(geometry) AS geometry
            FROM boundaries
            WHERE {geo_level} = '{geo_code}'
        """)
    geo_boundary_sdf.createOrReplaceTempView("geo_boundary")

    geo_buildings_sdf = sedona.sql(
        """
            SELECT b.* FROM buildings b, geo_boundary g 
            WHERE ST_Intersects(b.geometry, g.geometry)
        """)
    geo_buildings_sdf.createOrReplaceTempView("geo_buildings")

    geo_buildings_buffer_sdf = sedona.sql(
        f"""
            SELECT ST_Buffer(b.geometry, {buffer}) AS geometry, b.verisk_premise_id
            FROM geo_buildings b
        """)
    geo_buildings_buffer_sdf.createOrReplaceTempView("building_buffers")

    return geo_buildings_buffer_sdf

def count_trees(sedona, geo_code: str) -> pd.DataFrame:

    logging.debug(f"Counting trees for each building in {geo_code}")

    trees_within_buffer_sdf = sedona.sql(
        """
            SELECT b.verisk_premise_id, COUNT(t.treeID) AS tree_count
            FROM building_buffers b
            LEFT JOIN geo_trees t
            ON ST_Intersects(b.geometry, t.geometry)
            GROUP BY b.verisk_premise_id
        """)
    
    trees_within_buffer_df = trees_within_buffer_sdf.toPandas()

    return trees_within_buffer_df

def create_spatial_rdds(geo_buildings_buffer_sdf, geo_trees_sdf):

    logging.debug(f"Creating Spatial RDDs for buildings and trees")

    geo_buildings_buffer_rdd  = Adapter.toSpatialRdd(geo_buildings_buffer_sdf, 'geometry')
    geo_trees_rdd = Adapter.toSpatialRdd(geo_trees_sdf, 'geometry')
    
    geo_buildings_buffer_rdd.analyze()
    geo_trees_rdd.analyze()

    return geo_buildings_buffer_rdd, geo_trees_rdd

def count_trees_rdd(sedona, geo_buildings_buffer_rdd, geo_trees_rdd, build_on_spatial_partitioned_rdd = True, using_index = True):

    logging.debug(f"Counting trees for each building using RDD")

    geo_trees_rdd.spatialPartitioning(GridType.KDBTREE)
    geo_buildings_buffer_rdd.spatialPartitioning(geo_trees_rdd.getPartitioner())
    
    geo_buildings_buffer_rdd.buildIndex(IndexType.QUADTREE, build_on_spatial_partitioned_rdd)

    query_result = JoinQueryRaw.SpatialJoinQueryFlat(geo_trees_rdd, geo_buildings_buffer_rdd, using_index, True)

    query_result_sdf = Adapter.toDf(query_result, ["verisk_premise_id"], ["treeID"], sedona)

    query_result_df = query_result_sdf.toPandas().sort_values(by='verisk_premise_id')

    trees_within_buffer_df = query_result_df.groupby('verisk_premise_id').size().reset_index(name='tree_count')

    return trees_within_buffer_df

def read_vom_trees_geoparquet(sedona, overlapping_tiles_lst):

    vom_trees_dir = T3_30_300_DIR / "VOM_Trees_geoparquet"
    vom_trees_paths = [str(path) for path in vom_trees_dir.glob("*.geoparquet") if any(tile_name in path.name for tile_name in overlapping_tiles_lst)]
    geo_trees_sdf = sedona.read.format("geoparquet").load(vom_trees_paths)
    geo_trees_sdf.createOrReplaceTempView("geo_trees")

def process_geo_code(sedona, query_method: str, geo_level: str, geo_code: str, tile_level: str,
                     output_areas_boundaries_gdf: gpd.GeoDataFrame, os_tile_boundaries_gdf: gpd.GeoDataFrame,
                     output_areas_os_tile_overlay_df, vom_raster_paths_df, tree_vector_paths_df,
                     tree_area: int=10, tree_height: int=3, buffer: int=100) -> None:

    start_time = time.time()

    logging.info(f"Processing {geo_code} with buffer {buffer}m")

    tree_count_path = T3_dir / f"T3_{geo_code}_{buffer}m.csv"
    if not tree_count_path.exists():
        try:
            geo_buildings_buffer_sdf = process_buildings(sedona, geo_level, geo_code, buffer)
            overlapping_tiles_lst = get_overlapping_grid_tiles(output_areas_boundaries_gdf, os_tile_boundaries_gdf, geo_level, geo_code, tile_level)
            if query_method == 'sql':

                logging.debug(f"Executing query using SQL")

                # trees_path_lst = get_vom_trees_paths(overlapping_tiles_lst, vom_tree_pair_dict)
                geo_tiles_df = generate_tile_paths(geo_level, geo_code, output_areas_os_tile_overlay_df, vom_raster_paths_df, tree_vector_paths_df)
                tree_paths_lst = geo_tiles_df.groupby('TILE_NAME').first().reset_index()['path_tree'].tolist()
                geo_trees_gdf = process_vom_tiles(sedona, tree_paths_lst, tree_area=tree_area, tree_height=tree_height)

                trees_within_buffer_df = count_trees(sedona, geo_level, geo_code)
            
            elif query_method == 'rdd':

                logging.debug(f"Executing query using Spatial RDD")
                
                geo_trees_sdf = read_vom_trees_geoparquet(sedona, overlapping_tiles_lst)
                geo_buildings_buffer_rdd, geo_trees_rdd = create_spatial_rdds(geo_buildings_buffer_sdf, geo_trees_sdf)
                trees_within_buffer_df = count_trees_rdd(sedona, geo_buildings_buffer_rdd, geo_trees_rdd, build_on_spatial_partitioned_rdd = True, using_index = True)

            trees_within_buffer_df.to_csv(tree_count_path, index=False)
            
            logging.info(f"Saving file for {geo_code} with {len(trees_within_buffer_df)} records")

            end_time = time.time()
            logging.info(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")

        except Exception as e:
            logging.error(f"Error processing {geo_code}: {e}")