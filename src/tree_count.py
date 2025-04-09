
from utils.paths import tree_count_dir
from utils.constants import PROJECT_CRS
from utils.sedona_rdd import create_spatial_rdds, count_trees_rdd

import time
import logging
import pandas as pd
import geopandas as gpd
from pyspark.sql.functions import monotonically_increasing_id

def concatenate_trees_for_boundary(sedona, geo_level, geo_code, output_areas_os_tile_overlay_df, tree_vector_paths_df):

    logging.debug(f"Getting trees for {geo_code}")

    geo_tile_lst = output_areas_os_tile_overlay_df[output_areas_os_tile_overlay_df[geo_level] == geo_code]['TILE_NAME_5KM_int'].str.upper().unique().tolist()

    tree_paths_lst = tree_vector_paths_df[tree_vector_paths_df['TILE_NAME'].isin(geo_tile_lst)]['path'].tolist()
    trees_gdf_lst = []
    for gpkg_path in tree_paths_lst:
        temp_gdf = gpd.read_file(gpkg_path)
        trees_gdf_lst.append(temp_gdf)
    
    geo_trees_gdf = gpd.GeoDataFrame(pd.concat(trees_gdf_lst, ignore_index=True), crs=PROJECT_CRS)
    geo_trees_sdf = sedona.createDataFrame(geo_trees_gdf)
    # TODO: Figure out why sedona can't read multiple geopackages at once
    # geo_trees_sdf = sedona.read.format("geopackage").option('tableName','trees').load(tree_paths_lst)
    geo_trees_sdf.createOrReplaceTempView("geo_trees")
    
    geo_trees_sdf.withColumn("treeID", monotonically_increasing_id()).createOrReplaceTempView("geo_trees")

    return geo_trees_sdf

def process_geo_code(sedona, geo_level, sub_geo_level, geo_code, 
                     output_areas_os_tile_overlay_df, tree_vector_paths_df, overwrite: bool=True):

    start_time = time.time()
    logging.info(f"Processing data for {geo_code}")

    geo_tree_count_path = tree_count_dir / f"Tree_count_{geo_code}.csv"

    if not geo_tree_count_path.exists() or overwrite:
        try:
            sub_geo_code_sdf = sedona.sql(f"""SELECT {sub_geo_level}, geometry
                                            FROM boundaries
                                            WHERE {geo_level} = '{geo_code}'""")
            

            geo_trees_sdf = concatenate_trees_for_boundary(sedona, geo_level, geo_code, output_areas_os_tile_overlay_df, tree_vector_paths_df)
            sub_geo_code_rdd, geo_trees_rdd = create_spatial_rdds(sub_geo_code_sdf, geo_trees_sdf, build_on_spatial_partitioned_rdd = True)
            geo_tree_count_df = count_trees_rdd(sedona, sub_geo_code_rdd, geo_trees_rdd, sub_geo_level, using_index = True)

            geo_tree_count_df.to_csv(geo_tree_count_path, index=False)
                
            end_time = time.time()
            logging.info(f"Processing for {geo_code} with {len(geo_tree_count_df)} records took {end_time - start_time:.2f} seconds")

            return geo_tree_count_df

        except Exception as e:
            logging.error(f"Error processing {geo_code}: {e}")