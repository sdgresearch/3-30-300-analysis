#!/usr/bin/env python3

import logging, re
from pathlib import Path
import pandas as pd
import geopandas as gpd

def classify_vom_type(file_name: str|Path) -> str:
    """
    Classifies the type of VOM (Volatile Organic Matter) based on the file name.
    Parameters:
        file_name (str | Path): The name of the file to classify.
    Returns:
        str: 'HS' if the file name contains 'VOM_HS_', otherwise 'CHM'.
    """

    if 'VOM_HS_' in file_name:
        return 'HS'
    else:
        return 'CHM'
    
def extract_grid_reference(filename: str|Path) -> str|None:
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

    logging.debug("Generating tile paths")

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

    logging.debug("Selecting CHM files")

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