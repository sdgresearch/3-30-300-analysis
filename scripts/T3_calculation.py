#!/usr/bin/env python3

import re, json, argparse, os, time, concurrent.futures

from constants import *
from logging_config import *
from utils import *
from sedona_config import *

import pandas as pd
import geopandas as gpd
from tqdm import tqdm

def extract_grid_reference(filename: str) -> str|None:
    """
    Extracts a grid reference from a given filename.
    The function searches for a pattern in the filename that matches 'VOM' or 'VOM_HS'
    followed by an underscore, a two-letter code, a four-digit number, and another underscore.
    If such a pattern is found, it returns the grid reference (the two-letter code and the four-digit number).
    If no match is found, it returns None.
    Parameters:
        filename (str | Path): The name of the file from which to extract the grid reference.
    Returns:
        str | None: The extracted grid reference if a match is found, otherwise None.
    """

    match = re.search(r'VOM_([A-Z]{2}\d{4})_', filename)
    if match:
        return match.group(1)
    return None

def check_tree_vom_pair(chm_path: str|Path, trees_dir: str|Path) -> bool:
    """
    Check if a CHM file has a corresponding tree file.
    Parameters:
        chm_path (str | Path): The path to the CHM file.
        trees_dir (str | Path): The directory containing the tree files.
    Returns:
        bool: True if a corresponding tree file exists, otherwise False.
    """

    tile_name = extract_grid_reference(chm_path)
    chm_path = chm_path if isinstance(chm_path, Path) else Path(chm_path)
    year = chm_path.parent.name

    trees_path = trees_dir / f"VOM_trees_{tile_name}_{year}.gpkg"

    if trees_path.exists():
        return str(trees_path)
    
def process_vom_tiles(trees_path_lst: list, tree_area: int=10, tree_height: int=3) -> gpd.GeoDataFrame:

    logging.warning(f"Reading {len(trees_path_lst)} VOM tiles")
    if len(trees_path_lst) > 1:
        
        trees_gdf_lst = [gpd.read_file(tree_path) for tree_path in trees_path_lst]
        merged_trees_gdf = gpd.GeoDataFrame(pd.concat(trees_gdf_lst, ignore_index=True))
    elif len(trees_path_lst) == 1: 
        merged_trees_gdf = gpd.read_file(trees_path_lst[0])

    else:
        return None

    geo_trees_gdf = merged_trees_gdf[(merged_trees_gdf.area > tree_area) & (merged_trees_gdf.height > tree_height)].reset_index(drop=True)
    geo_trees_gdf['treeID'] = range(len(geo_trees_gdf))

    return geo_trees_gdf

def process_buildings(geo_level: str, geo_code: str) -> None:

    logging.warning(f"Filtering buildings for {geo_code}")

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
        """
            SELECT ST_Buffer(b.geometry, 100) AS geometry, b.verisk_premise_id
            FROM geo_buildings b
        """)
    geo_buildings_buffer_sdf.createOrReplaceTempView("building_buffers")

def count_trees(geo_level: str, geo_code: str) -> pd.DataFrame:

    logging.warning(f"Counting trees for each building in {geo_code}")

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

def get_overlapping_tiles(imd_lsoa_bua_buffer_gdf, os_5km_boundaries_gdf, geo_level, geo_code):
    # Select one feature from imd_lsoa_bua_buffer_gdf
    selected_feature = imd_lsoa_bua_buffer_gdf[imd_lsoa_bua_buffer_gdf[geo_level] == geo_code]

    # Get the overlapping features
    overlapping_tiles_lst = gpd.overlay(selected_feature, os_5km_boundaries_gdf, how='intersection')['TILE_NAME'].unique().tolist()

    return overlapping_tiles_lst

def get_vom_trees_paths(overlapping_tiles_lst: list, vom_tree_pair_dict: dict) -> list:

    vom_trees_path_lst = [path_pair[1] for _,v in vom_tree_pair_dict.items() for path_pair in v if path_pair[1] is not None]
    for tile_name in overlapping_tiles_lst:
        translated_tile_name = translate_tile_name(tile_name).upper()
        trees_path_lst = [path for path in vom_trees_path_lst if translated_tile_name in path]

        return trees_path_lst


def process_geo_code(geo_level: str, geo_code: str, vom_tree_pair_dict: dict,
                     imd_lsoa_bua_buffer_gdf: gpd.GeoDataFrame, os_5km_boundaries_gdf: gpd.GeoDataFrame,
                     tree_area: int=10, tree_height: int=3) -> None:

    start_time = time.time()

    T3_dir = VECTOR_OUT_DIR / "3-30-300" / "T3"
    T3_dir.mkdir(parents=True, exist_ok=True)
    tree_count_path = T3_dir / f"T3_{geo_code}.csv"
    if not tree_count_path.exists():
        try:
            overlapping_tiles_lst = get_overlapping_tiles(imd_lsoa_bua_buffer_gdf, os_5km_boundaries_gdf, geo_level, geo_code)
            trees_path_lst = get_vom_trees_paths(overlapping_tiles_lst, vom_tree_pair_dict)
            # trees_path_lst = get_vom_trees_paths(geo_code, vom_tree_pair_dict)

            geo_trees_gdf = process_vom_tiles(trees_path_lst, tree_area=tree_area, tree_height=tree_height)
            geo_trees_sdf = sedona.createDataFrame(geo_trees_gdf)
            geo_trees_sdf.createOrReplaceTempView("geo_trees")

            process_buildings(geo_level, geo_code)

            trees_within_buffer_df = count_trees(geo_level, geo_code)

            trees_within_buffer_df.to_csv(tree_count_path, index=False)
            
            logging.warning(f"Saving file for {geo_code} with {len(trees_within_buffer_df)} records")

            end_time = time.time()
            logging.warning(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")

        except Exception as e:
            logging.error(f"Error processing {geo_code}: {e}")
    
if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='This script calculates the tree count (3) for all buildings in a given geographical level (i.e. LSOA or LAD)')
    parser.add_argument('--geo_level', type=str, required=True, default='LAD22CD', help='Name/Code of the desired geography')
    parser.add_argument('--geo_code', type=str, required=False, default='E07000008', help='Geographical variable name')
    parser.add_argument('--parallel', action='store_true', help='Run job in parallel')
    parser.add_argument('--n_workers', type=int, required=False, default=2, help='Number of workers')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')
    parser.add_argument('--buffer', type=int, required=False, default=100, help='Buffer size in meters')

    args = parser.parse_args()

    geo_level = args.geo_level
    geo_code = args.geo_code
    parallel = args.parallel
    n_workers = args.n_workers
    log_level = args.log_level
    buffer = args.buffer

    project_crs = 'EPSG:27700'

    # IN paths
    vom_dir = RASTER_IN_DIR / "Defra" / "VOM"
    vom_lad_dir = vom_dir / "LADs"
    chm_lad_tiles_path = vom_lad_dir / "LAD_CHM_tiles_paths.json"
    T3_30_300_DIR = VECTOR_OUT_DIR / "3-30-300"
    T3_dir = T3_30_300_DIR / "T3"
    trees_dir = T3_30_300_DIR / "VOM_Trees"
    os_5km_boundaries_path = VECTOR_IN_DIR / "OS" / "National_Grid" / "5km_grid_region.shp"
    imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"
    buildings_path = VECTOR_IN_DIR / "EDINA" / "Buildings_6183" / "Buildings_6183.parquet"

    log_path = Path("logs/T3_calculation.log")
    setup_logger(log_path=log_path, log_level=log_level)
    logging.warning("Calculating the 3 metric for all geographies")
    logging.warning("Reading files")

    chm_lad_tiles_dict = json.load(open(chm_lad_tiles_path))
    os_5km_boundaries_gdf = gpd.read_file(os_5km_boundaries_path).to_crs(project_crs)
    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path)
    imd_lsoa_bua_buffer_gdf = imd_lsoa_bua_gdf.copy()
    imd_lsoa_bua_buffer_gdf['geometry'] = imd_lsoa_bua_buffer_gdf['geometry'].buffer(buffer)
    geo_level_codes = imd_lsoa_bua_gdf[geo_level].unique()
  
    logging.warning("Setting up Apache Sedona")
    os.environ["JAVA_HOME"] = JAVA_HOME
    sedona = get_spark()

    vom_tree_pair_dict = {k: [(chm_path, check_tree_vom_pair(chm_path, trees_dir)) for chm_path in v] for k, v in chm_lad_tiles_dict.items()}

    boundaries_sdf = sedona.createDataFrame(imd_lsoa_bua_gdf.drop(columns=['LSOA21NMW', 'LAD22NMW', 'BUA22NMG', 'BUA22NMW', 'RGN22NMW'], axis=1))
    boundaries_sdf.createOrReplaceTempView('boundaries')
    buildings_sdf = sedona.read.format("geoparquet").load(str(buildings_path))
    buildings_sdf.createOrReplaceTempView("buildings")

    if parallel:
        logging.warning("Running in parallel")

        with concurrent.futures.ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = [executor.submit(process_geo_code, geo_level, geo_code, vom_tree_pair_dict, imd_lsoa_bua_buffer_gdf, os_5km_boundaries_gdf) for geo_code in geo_level_codes]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions Processed"):
                try:
                    future.result()                
                except Exception as e:
                    logging.error(f"Error processing: {e}")

    else:
        logging.warning("Running sequentially")

        for geo_code in tqdm(geo_level_codes, desc='Regions Processed'):   
            process_geo_code(geo_level, geo_code, vom_tree_pair_dict, imd_lsoa_bua_buffer_gdf, os_5km_boundaries_gdf)