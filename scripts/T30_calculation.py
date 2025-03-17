#!/usr/bin/env python3

import sys, re, argparse, time, concurrent.futures
# sys.path.append('..')  # Adjust the path as per your directory structure

from constants import *
from logging_config import *

import pandas as pd
import geopandas as gpd
import numpy as np
import xarray as xr
import rioxarray as rxr
from rioxarray.merge import merge_arrays
import rasterio as rio
from rasterstats import zonal_stats
from tqdm import tqdm

def classify_vom_type(file_name: str|Path) -> str:
    """
    Classifies the type of VOM (Vegetation Object Model) based on the file name.
    Parameters:
        file_name (str | Path): The name of the file to classify.
    Returns:
        str: 'HS' if the file name contains 'VOM_HS_', otherwise 'CHM'.
    """

    if 'VOM_HS_' in file_name:
        return 'HS'
    else:
        return 'CHM'
    
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

    match = re.search(r'VOM(?:_HS)?_([A-Z]{2}\d{4})_', filename)
    if match:
        return match.group(1)
    return None

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

def generate_tiles_paths(geo_level: str, geo_code: str, imd_lsoa_bua_gdf: gpd.GeoDataFrame) -> tuple:
    """
    Generates tile paths and associated dataframes for a given geographical level and code.
    Parameters:
        geo_level (str): The geographical level (e.g., LSOA, BUA).
        geo_code (str): The geographical code corresponding to the geo_level.
        imd_lsoa_bua_gdf (gpd.GeoDataFrame): A GeoDataFrame containing geographical data.
    Returns:
        tuple: A tuple containing the following elements:
            - subgeo_filt_gdf (gpd.GeoDataFrame): A filtered GeoDataFrame for the specified geo_level and geo_code.
            - geo_boundary_gdf (gpd.GeoDataFrame): A dissolved GeoDataFrame containing the boundary geometry for the specified geo_level.
            - geo_selected_vom_tiles_df (pd.DataFrame): A DataFrame containing selected VOM tiles for the specified geo_code.
            - tif_paths_df (pd.DataFrame): A DataFrame containing paths to .tif files, along with their year, tile name, and file type.
    """

    logging.warning("Generating tile paths")

    subgeo_filt_gdf = imd_lsoa_bua_gdf.copy()[imd_lsoa_bua_gdf[geo_level].isin([geo_code])].reset_index(drop=True)

    geo_vom_tiles_path = vom_lad_dir / f"VOM_tiles_{geo_code}.csv"
    geo_vom_tiles_df = pd.read_csv(geo_vom_tiles_path).sort_values(['TILE_NAME', 'year'], ascending=[True, False])
    geo_selected_vom_tiles_df = geo_vom_tiles_df.groupby(['TILE_NAME']).first().reset_index()
    
    return subgeo_filt_gdf, geo_vom_tiles_df, geo_selected_vom_tiles_df

def select_chm_files(geo_vom_tiles_df: pd.DataFrame, geo_selected_vom_tiles_df: pd.DataFrame, tif_paths_df: pd.DataFrame) -> list:
    """
    Selects CHM (Canopy Height Model) files based on the provided GeoDataFrames and DataFrame of file paths.
    Parameters:
        geo_selected_vom_tiles_df (pd.DataFrame): DataFrame containing selected VOM tiles with columns 'TILE_NAME' and 'year'.
        geo_vom_tiles_df (pd.DataFrame): DataFrame containing VOM tiles with columns 'TILE_NAME' and 'year'.
        tif_paths_df (pd.DataFrame): DataFrame containing file paths with columns 'TILE_NAME', 'year', 'file_type', and 'path'.
    Returns:
        list: A list of Path objects pointing to the selected CHM files.
    """

    logging.warning("Selecting CHM files")

    selected_chm_path_lst = []
    for row in geo_selected_vom_tiles_df.itertuples():
        tile_name = translate_tile_name(row.TILE_NAME).upper()
        year = row.year
        temp_df = tif_paths_df[((tif_paths_df['TILE_NAME'] == tile_name) & (tif_paths_df['year'] == str(year))) & (tif_paths_df['file_type'] == 'CHM')]
        if len(temp_df) == 1:
            selected_chm_path_lst.append(Path(temp_df.path.iloc[0]))
        else:
            tile_df = geo_vom_tiles_df[geo_vom_tiles_df['TILE_NAME'] == row.TILE_NAME]
            tile_years_lst = tile_df.year.tolist()
            tile_years_lst.remove(year)
            ind = 0
            while len(tile_years_lst) > 0 and ind < len(tile_years_lst):
                temp_df = tif_paths_df[((tif_paths_df['TILE_NAME'] == tile_name) & (tif_paths_df['year'] == str(tile_years_lst[ind]))) & (tif_paths_df['file_type'] == 'CHM')]
                if len(temp_df) == 1:
                    selected_chm_path_lst.append(Path(temp_df.path.iloc[0]))
                    ind = len(tile_years_lst) + 1
                else:
                    ind += 1

    # assert len(geo_selected_vom_tiles_df) == len(selected_chm_path_lst)

    return selected_chm_path_lst

def binarise_tiles(selected_chm_path_lst, low_threshold, high_threshold) -> xr.DataArray:
    """
    Binarise the canopy height model (CHM) tiles based on given thresholds.

    This function reads a list of CHM files, merges them into a single xarray DataArray,
    and then binarises the merged array based on the provided low and high thresholds.
    The resulting binary array will have values of 1 where the CHM values are within the
    specified range, and 0 otherwise.
    Parameters:
        selected_chm_path_lst (list of str): List of file paths to the CHM tiles to be processed.
        low_threshold (float): The lower threshold for binarisation.
        high_threshold (float): The upper threshold for binarisation.
    Returns:
        xr.DataArray: A binary xarray DataArray where values are 1 if within the threshold range, and 0 otherwise.
    """

    logging.warning(f"Binarising {len(selected_chm_path_lst)} VOM tiles")

    # chm_xr_lst = [rxr.open_rasterio(file) for file in selected_chm_path_lst]
    chm_xr_lst = []
    for file in selected_chm_path_lst:
        try:
            temp_rast = rxr.open_rasterio(file)
            temp_rast.values
            chm_xr_lst.append(temp_rast)
        except Exception as e:
            logging.error(f"Error reading file: {file} - {e}")
    merged_chm_xr = merge_arrays(chm_xr_lst)

    binary_merged_chm_xr = (merged_chm_xr >= low_threshold) & (merged_chm_xr <= high_threshold)
    binary_merged_chm_xr = binary_merged_chm_xr.astype(int).fillna(0)

    return binary_merged_chm_xr

def get_canopy_cover(subgeo_filt_gdf: gpd.GeoDataFrame, binary_merged_chm_xr: xr.DataArray) -> pd.DataFrame:
    """
    Calculate the canopy cover percentage for each geometry in the given GeoDataFrame.
    Parameters:
        subgeo_filt_gdf (gpd.GeoDataFrame): A GeoDataFrame containing the geometries for which the canopy cover is to be calculated.
        binary_merged_chm_xr (xr.DataArray): A DataArray containing binary canopy height model data.
    Returns:
        pd.DataFrame: A DataFrame containing the original geometries and their corresponding canopy cover percentages.
    """

    logging.warning("Calculating canopy cover")

    zs_categorical = zonal_stats(subgeo_filt_gdf, binary_merged_chm_xr[0].values, 
                                affine=binary_merged_chm_xr.rio.transform(), categorical=True)

    subgeo_filt_gdf['canopy_cover'] = [round(100 * z.get(1, 0) / (z.get(0, 0) + z.get(1, 0)), 2) for z in zs_categorical]

    variables_to_keep = ['LSOA11CD', 'LSOA21CD', geo_level ,'canopy_cover']

    subgeo_canopy_cover_df = subgeo_filt_gdf.copy()[variables_to_keep]
    
    return subgeo_canopy_cover_df

def process_geo_code(geo_level: str, geo_code: str, imd_lsoa_bua_gdf: gpd.GeoDataFrame, low_threshold: int=3, high_threshold: int=60) -> None:
    """
    Processes geographical data for a given geographical code and level, and calculates the canopy cover.

    Parameters:
        geo_level (str): The geographical level (e.g., LSOA, BUA).
        geo_code (str): The geographical code corresponding to the geo_level.
        imd_lsoa_bua_gdf (gpd.GeoDataFrame): A GeoDataFrame containing geographical data.
        low_threshold (int, optional): The lower threshold for binarizing canopy height model tiles. Default is 3.
        high_threshold (int, optional): The upper threshold for binarizing canopy height model tiles. Default is 60.

    Returns:
        None
    """

    try:

        start_time = time.time()

        T30_dir = VECTOR_OUT_DIR / "3-30-300" / "T30"
        T30_dir.mkdir(parents=True, exist_ok=True)
        canopy_cover_path = T30_dir / f"T30_{geo_code}.csv"

        logging.warning(f"Processing data for {geo_code}")

        subgeo_filt_gdf, geo_vom_tiles_df, geo_selected_vom_tiles_df = generate_tiles_paths(geo_level, geo_code, imd_lsoa_bua_gdf)
        selected_chm_path_lst = select_chm_files(geo_vom_tiles_df, geo_selected_vom_tiles_df, tif_paths_df)
        binary_merged_chm_xr = binarise_tiles(selected_chm_path_lst, low_threshold, high_threshold)
        subgeo_canopy_cover_df = get_canopy_cover(subgeo_filt_gdf, binary_merged_chm_xr)

        subgeo_canopy_cover_df.to_csv(canopy_cover_path)

        logging.warning(f"Saving file for {geo_code} with {len(subgeo_canopy_cover_df)} records")

        end_time = time.time()
        logging.warning(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")

        return subgeo_canopy_cover_df

    except Exception as e:
        logging.error(f"Error processing {geo_code}: {e}")

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='This script calculates the canopy cover (30) for a given geographical level (i.e. LSOA or LAD)')
    parser.add_argument('--geo_level', type=str, required=True, default='LAD22CD', help='Name/Code of the desired geography')
    parser.add_argument('--geo_code', type=str, required=False, default='E07000008', help='Geographical variable name')
    parser.add_argument('--parallel', action='store_true', help='Run job in parallel')
    parser.add_argument('--n_workers', type=int, required=False, default=2, help='Number of workers')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')

    args = parser.parse_args()

    geo_level = args.geo_level
    geo_code = args.geo_code
    parallel = args.parallel
    n_workers = args.n_workers
    log_level = args.log_level

    # IN paths
    imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"
    vom_dir = RASTER_IN_DIR / "Defra" / "VOM"
    vom_lad_dir = vom_dir / "LADs"
    vom_unzipped_dir = vom_dir / "unzipped_tiles"

    log_path = Path("logs/T30_calculation.log")
    setup_logger(log_path=log_path, log_level=log_level)
    logging.warning("Calculating the 30 metric for all geographies")
    logging.warning("Reading files")

    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path).sort_values(by=geo_level)
    geo_level_codes = imd_lsoa_bua_gdf[geo_level].unique()
    geo_level_codes = ['E07000065', 'E07000215', 'E07000114', 'E07000228']

    tif_paths = list(vom_unzipped_dir.rglob("*.tif"))
    tif_paths_lst = [[path.parent.name, extract_grid_reference(path.name), classify_vom_type(path.name), str(path)] for path in tif_paths]

    tif_paths_df = pd.DataFrame(tif_paths_lst, columns=['year', 'TILE_NAME', 'file_type', 'path']).sort_values(['TILE_NAME', 'year']).reset_index(drop=True)

    if parallel:
        logging.warning("Running in parallel")

        with concurrent.futures.ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = [executor.submit(process_geo_code, geo_level, geo_code, imd_lsoa_bua_gdf) for geo_code in geo_level_codes]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions Processed"):
                    future.result()                

    else:
        logging.warning("Running sequentially")

        for geo_code in tqdm(geo_level_codes, desc='Regions Processed'):   
            process_geo_code(geo_level, geo_code, imd_lsoa_bua_gdf)
