#!/usr/bin/env python3

import re, json, argparse, os, time, concurrent.futures

from constants import *
from logging_config import *
from utils import *
from sedona_config import *

import pandas as pd
import geopandas as gpd
from tqdm import tqdm

def translate_tile_name(tile_name: str) -> str:
    """
    Translates a tile name between two formats:
    - Format 1: TL0045 (where '0045' represents coordinates)
    - Format 2: TL04NW (where 'NW' represents directions)
    The function converts:
    - From Format 1 to Format 2 by interpreting the numeric coordinates and converting them to directional codes.
    - From Format 2 to Format 1 by interpreting the directional codes and converting them to numeric coordinates.
    Parameters:
        tile_name (str): The tile name to be translated. It should be a string of length 6.
    Returns:
        str: The translated tile name in the opposite format.
    Raises:
        AssertionError: If the input tile_name is not of length 6.
        ValueError: If the numeric part of the tile name cannot be converted to an integer when expected.
    """
    
    NS_dict = {'S': '0', 'N': '5'}
    EW_dict = {'W': '0', 'E': '5'} 

    assert len(tile_name) == 6
    
    code = tile_name[2:6].upper()
    try: # If input is like TL0045
        int(code)
        NS_dict = {v: k for k, v in NS_dict.items()}
        EW_dict = {v: k for k, v in EW_dict.items()}
        ns_id = code[3]
        ew_id = code[1]
        direction_code = code[0] + code[2] + NS_dict[ns_id] + EW_dict[ew_id]
        trans_tile_name = tile_name[:2].upper() + direction_code
    except ValueError: # If input is like TL04NW
        ns_id = code[2]
        ew_id = code[3]
        number_code = code[0] + EW_dict[ew_id] + code[1] + NS_dict[ns_id]
        trans_tile_name = tile_name[:2].lower() + number_code

    return trans_tile_name

def create_vom_trees_dataframe(trees_dir):

    trees_paths = list(trees_dir.glob("*.gpkg"))

    trees_data = []

    for path in trees_paths:
        match = re.search(r'VOM_trees_(\w+)_(\d{4})', path.stem)
        if match:
            code, year = match.groups()
            trees_data.append({'path': path, 'TILE_NAME': code, 'year': year})

    def translate_code_50km(code):
        ew = 'W' if int(code[2]) < 5 else 'E'
        ns = 'S' if int(code[3]) < 5 else 'N'
        return code[:2] + ns + ew

    trees_df = pd.DataFrame(trees_data)
    trees_df['TILE_NAME_5KM'] = trees_df['TILE_NAME'].apply(translate_tile_name)
    trees_df['TILE_NAME_10KM'] = trees_df['TILE_NAME_5KM'].apply(lambda x: x[:4])
    trees_df['TILE_NAME_50KM'] = trees_df['TILE_NAME_5KM'].apply(translate_code_50km)
    trees_df['TILE_NAME_100KM'] = trees_df['TILE_NAME_5KM'].apply(lambda x: x[:2])
    trees_df = trees_df.sort_values(by=['TILE_NAME', 'year'], ascending=[True, False]).reset_index(drop=True)
    
    trees_unique_df = trees_df.drop_duplicates(subset='TILE_NAME', keep='first')
    
    return trees_unique_df

def process_vom_tiles(trees_path_lst: list, tree_area: int=10, tree_height: int=3) -> gpd.GeoDataFrame:

    logging.warning(f"Reading {len(trees_path_lst)} Tree VOM tiles")
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

    return geo_trees_gdf

def process_grid_tiles(trees_unique_df, tile_level, tile_name):

    trees_path_lst = trees_unique_df[trees_unique_df[tile_level] == tile_name]['path'].tolist()
    
    geo_trees_gdf = process_vom_tiles(trees_path_lst, tree_area=10, tree_height=3)

    geo_trees_path = trees_geoparquet_dir / f"VOM_Trees_{tile_name}.geoparquet"
    
    if geo_trees_gdf is not None:
        geo_trees_gdf.to_parquet(geo_trees_path)

    return geo_trees_gdf

if __name__ == '__main__':


    parser = argparse.ArgumentParser(description='This script groups VOM Tree files following the GB National Grid and converts them into geoparquet files')
    parser.add_argument('--tile_level', type=str, required=False, default='TILE_NAME_50KM', help='Name/Code of the desired geography')
    parser.add_argument('--tile_name', type=str, required=False, default='TLNW', help='Geographical variable name')
    parser.add_argument('--parallel', action='store_true', help='Run job in parallel')
    parser.add_argument('--n_workers', type=int, required=False, default=2, help='Number of workers')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')

    args = parser.parse_args()

    tile_level = args.tile_level
    tile_name = args.tile_name
    parallel = args.parallel
    n_workers = args.n_workers
    log_level = args.log_level

    project_crs = 'EPSG:27700'

    T3_30_300_DIR = VECTOR_OUT_DIR / "3-30-300"
    T3_dir = T3_30_300_DIR / "T3"
    trees_dir = T3_30_300_DIR / "VOM_Trees" 
    trees_geoparquet_dir = T3_30_300_DIR / "VOM_Trees_geoparquet"
    trees_geoparquet_dir.mkdir(parents=True, exist_ok=True)

    log_path = Path("logs/VOM_trees_geoparquet.log")
    setup_logger(log_path=log_path, log_level=log_level)
    logging.warning("Converting VOM Trees to Geoparquet")
    
    trees_unique_df = create_vom_trees_dataframe(trees_dir)
    tile_level_names = trees_unique_df[tile_level].unique()    
    # tile_level_names = ['TLNW']

    if parallel:
        logging.warning("Running in parallel")

        with concurrent.futures.ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = [executor.submit(process_grid_tiles, trees_unique_df, tile_level, tile_name) for tile_name in tile_level_names]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions Processed"):
                try:
                    future.result()                
                except Exception as e:
                    logging.error(f"Error processing: {e}")

    else:
        logging.warning("Running sequentially")

        for tile_name in tqdm(tile_level_names, desc='Regions Processed'):   
            process_grid_tiles(trees_unique_df, tile_level, tile_name)