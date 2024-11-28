#!/usr/bin/env python3
import sys, requests, argparse
from pathlib import Path
import pandas as pd
import geopandas as gpd
# sys.path.append('..')  # Adjust the path as per your directory structure

from constants import *

def download_file(url: str, filename: str, folder_path: Path) -> int:
    
    # Get the filename from the URL
    file_path = folder_path / filename
    
    # Download the file
    response = requests.get(url)
    # response.raise_for_status()  # Check if the request was successful

    if response.status_code == 200 and not os.path.exists(file_path):
         # Ensure the folder exists
        folder_path.mkdir(parents=True, exist_ok=True)
        
        # Save the file
        with open(file_path, 'wb') as file:
            file.write(response.content)

    return response.status_code

def translate_tile_name(tile_name: str) -> str:
    
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

def filter_geographies(roi_gdf: gpd.GeoDataFrame, grid_gdf: gpd.GeoDataFrame, target_crs: str = 'EPSG:27700') -> gpd.GeoDataFrame:

    if 'EPSG:' + str(roi_gdf.crs.to_epsg()) != target_crs:
        roi_gdf = roi_gdf.to_crs(target_crs)

    if 'EPSG:' + str(grid_gdf.crs.to_epsg()) != target_crs:
        grid_gdf = grid_gdf.to_crs(target_crs)

    # Perform spatial join to find overlapping features
    overlapping_tiles_gdf = gpd.sjoin(grid_gdf, roi_gdf, how='inner')

    return overlapping_tiles_gdf[['TILE_NAME', 'geometry']]

def download_tiles_geography(tile_list: list[str], url: str, folder_path: Path) -> pd.DataFrame:

    years = ['2018', '2019', '2020', '2021', '2022', '2023']
    # first_number = ['0','1','2','3','4','5']
    # second_number = ['6', '7', '8', '9']
    # directions = ['SW', 'SE', 'NE', 'NW']
    # tile_names = ['TQ' + a + b + c for a in first_number for b in second_number for c in directions]
    tile_log_df = pd.DataFrame()
    print(tile_list)
    for tile in tile_list:
        for year in years:
            try: 
                year_folder_path = folder_path / year
                tile_url = url.format(year, translate_tile_name(tile).upper())
                status = download_file(tile_url, f"lidar_vom_{tile}.zip", year_folder_path)

                if status == 200:
                    tile_df = pd.DataFrame({'TILE_NAME': [tile], 'year': [year]})

                    tile_log_df = pd.concat([tile_log_df, tile_df], ignore_index=True)
            except:
                continue
    return tile_log_df

def main():
    
    parser = argparse.ArgumentParser(description='Description of your script.')
    parser.add_argument('--geo_name', type=str, required=True, default='London', help='Geographical variable name')
    parser.add_argument('--geo_level', type=str, required=True, default='BUA22NM', help='Name/Code of the desired geography')

    args = parser.parse_args()
    vom_dir = RASTER_IN_DIR / "Defra" / "VOM"
    os_5km_boundaries_path = VECTOR_IN_DIR / "OS" / "National_Grid" / "5km_grid_region.shp"
    england_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"

    base_url = "https://api.agrimetrics.co.uk/tiles/collections/survey/national_lidar_programme_vom/{}/1/{}?subscription-key=public"

    os_5km_boundaries_gdf = gpd.read_file(os_5km_boundaries_path)
    england_lsoa_bua_boundaries_gdf = gpd.read_file(england_lsoa_bua_boundaries_path)

    geo_level = 'LAD22NM'#args.geo_level
    geo_name = args.geo_name

    for geo_name in england_lsoa_bua_boundaries_gdf[geo_level].unique():
        print(geo_name)
        # roi_dir = vom_dir / geo_name
        vom_dir.mkdir(parents=True, exist_ok=True)
        roi_vom_tiles_path = vom_dir / f"{geo_name}_VOM_tiles.csv"

        roi_boundaries_gdf = england_lsoa_bua_boundaries_gdf[england_lsoa_bua_boundaries_gdf[geo_level] == geo_name]

        roi_tiles_gdf = filter_geographies(roi_boundaries_gdf, os_5km_boundaries_gdf)

        roi_tiles_df = download_tiles_geography(roi_tiles_gdf['TILE_NAME'].unique(), base_url, vom_dir)
        roi_tiles_df.to_csv(roi_vom_tiles_path, index=False)

if __name__ == '__main__':
    
    main()

