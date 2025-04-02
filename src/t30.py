"""
Module: data_processing.py
Description: Functions for cleaning and transforming data in My Project.
Author: Your Name
Date: YYYY-MM-DD
"""

from src.utils.paths import *
from src.utils.constants import *
from src.utils.logging_config import *
from src.utils.data_processing import generate_tile_paths

import time, logging
import pandas as pd
import geopandas as gpd
import xarray as xr
import rioxarray as rxr
from rioxarray.merge import merge_arrays
from rasterstats import zonal_stats

# def select_chm_files(geo_tiles_df: pd.DataFrame) -> list:
#     """
#     Selects CHM (Canopy Height Model) files based on the provided GeoDataFrames and DataFrame of file paths.
#     Parameters:
#         geo_tiles_df (pd.DataFrame): DataFrame containing VOM tiles with columns 'TILE_NAME' and 'year'.
#     Returns:
#         list: A list of Path objects pointing to the selected CHM files.
#     """

#     logging.debug("Selecting CHM files")

#     vom_raster_paths_df = pd.read_parquet(vom_raster_paths_parquet)

#     geo_selected_tiles_df = geo_tiles_df.groupby(['TILE_NAME']).first().reset_index()

#     selected_chm_path_lst = []
#     for row in geo_selected_tiles_df.itertuples():
#         tile_name = translate_tile_name(row.TILE_NAME).upper()
#         year = row.year
#         temp_df = vom_raster_paths_df[(vom_raster_paths_df['TILE_NAME'] == tile_name) & (vom_raster_paths_df['year'] == year)]
#         if len(temp_df) == 1:
#             selected_chm_path_lst.append(Path(temp_df.path_vom.iloc[0]))
#         else:
#             tile_df = geo_tiles_df[geo_tiles_df['TILE_NAME'] == row.TILE_NAME]
#             tile_years_lst = tile_df.year.tolist()
#             tile_years_lst.remove(year)
#             ind = 0
#             while len(tile_years_lst) > 0 and ind < len(tile_years_lst):
#                 temp_df = vom_raster_paths_df[(vom_raster_paths_df['TILE_NAME'] == tile_name) & (vom_raster_paths_df['year'] == tile_years_lst[ind])]
#                 if len(temp_df) == 1:
#                     selected_chm_path_lst.append(Path(temp_df.path_vom.iloc[0]))
#                     ind = len(tile_years_lst) + 1
#                 else:
#                     ind += 1

#     return selected_chm_path_lst

def binarise_tiles(vom_paths_lst, low_threshold, high_threshold) -> xr.DataArray:
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

    logging.warning(f"Binarising {len(vom_paths_lst)} VOM tiles")

    chm_xr_lst = []
    for file in vom_paths_lst:
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
    subgeo_filt_gdf['total_pixels'] = [z.get(0, 0) + z.get(1, 0) for z in zs_categorical]

    subgeo_canopy_cover_df = subgeo_filt_gdf.copy()
    
    return subgeo_canopy_cover_df

def process_geo_code(geo_level: str, geo_code: str, output_areas_boundaries_gdf: gpd.GeoDataFrame, 
                     output_areas_os_tile_overlay_df, vom_raster_paths_df, tree_vector_paths_df,
                     low_threshold: int=3, high_threshold: int=60) -> None:
    """
    Processes geographical data for a given geographical code and level, and calculates the canopy cover.

    Parameters:
        geo_level (str): The geographical level (e.g., LSOA, BUA).
        geo_code (str): The geographical code corresponding to the geo_level.
        output_areas_boundaries_gdf (gpd.GeoDataFrame): A GeoDataFrame containing geographical data.
        low_threshold (int, optional): The lower threshold for binarizing canopy height model tiles. Default is 3.
        high_threshold (int, optional): The upper threshold for binarizing canopy height model tiles. Default is 60.

    Returns:
        None
    """
    start_time = time.time()
    logging.info(f"Processing data for {geo_code}")

    try:
        canopy_cover_path = T30_dir / f"T30_{geo_code}.csv"
        
        subgeo_filt_gdf = output_areas_boundaries_gdf.copy()[output_areas_boundaries_gdf[geo_level].isin([geo_code])].reset_index(drop=True)
        geo_tiles_df = generate_tile_paths(geo_level, geo_code, output_areas_os_tile_overlay_df, vom_raster_paths_df, tree_vector_paths_df)
        # selected_chm_path_lst = select_chm_files(geo_tiles_df)
        vom_paths_lst = geo_tiles_df.groupby('TILE_NAME').first().reset_index()['path_vom'].tolist()
        binary_merged_chm_xr = binarise_tiles(vom_paths_lst, low_threshold, high_threshold)
        subgeo_canopy_cover_df = get_canopy_cover(subgeo_filt_gdf, binary_merged_chm_xr)

        subgeo_canopy_cover_df.to_csv(canopy_cover_path)

        logging.info(f"Saving file for {geo_code} with {len(subgeo_canopy_cover_df)} records")

        end_time = time.time()
        logging.info(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")

        return subgeo_canopy_cover_df

    except Exception as e:
        logging.error(f"Error processing {geo_code}: {e}")