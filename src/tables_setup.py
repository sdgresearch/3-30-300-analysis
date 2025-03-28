"""
Module: file_operations.py
Description: Utility functions for file handling in My Project.
Author: Your Name
Date: YYYY-MM-DD
"""

import logging
import pandas as pd
import geopandas as gpd
from src.utils.constants import PROJECT_CRS
from src.utils.paths import *
from src.utils.data_processing import translate_tile_name

def setup_parquet_files():

    imd_england_columns = ['lsoa11cd', 'IMD_Rank', 'IMD_Decile', 'IMDScore', 'IncScore', 
                       'IncRank', 'IncDec', 'EmpScore', 'EmpRank', 'EmpDec', 'EduScore',
                       'EduRank', 'EduDec', 'HDDScore', 'HDDRank', 'HDDDec', 'CriScore', 
                       'CriRank', 'CriDec', 'BHSScore', 'BHSRank', 'BHSDec', 'EnvScore', 
                       'EnvRank', 'EnvDec']
    imd_england_2019_gdf = gpd.read_file(imd_england_2019_path)[imd_england_columns].rename(columns={'lsoa11cd': 'LSOA11CD'})
    lsoa_2011_2021_lookup_df = pd.read_csv(lsoa_2011_2021_lookup_path)
    oa_2021_lookup_df = pd.read_csv(oa_2021_lookup_path)
    oa_2021_boundaries_gdf = gpd.read_file(oa_2021_boundaries_path)
    oa_rgn_lookup_df = pd.read_csv(oa_rgn_lookup_path)
    oa_rgn_lookup_df.columns = oa_rgn_lookup_df.columns.str.upper()
    population_estimates_df = pd.read_excel(population_estimates_path, sheet_name='Mid-2022 LSOA 2021', skiprows=3)
    os_5km_boundaries_gdf = gpd.read_file(os_5km_boundaries_path).to_crs(PROJECT_CRS)
    green_space_access_gdf = gpd.read_file(green_space_path, layer='access_point')
    green_space_site_gdf = gpd.read_file(green_space_path, layer='greenspace_site').drop(columns=["distinctive_name_3", "distinctive_name_4"])
    road_edges_gdf = gpd.read_file(roads_path, layer='road_link')
    road_nodes_gdf = gpd.read_file(roads_path, layer='road_node')
    buildings_columns = ['verisk_building_id', 'verisk_premise_id', 'premise_year', 'premise_use', 
                        'premise_type', 'premise_floor_count', 'height', 'building_area', 
                        'distance_building', 'distance_water', 'map_use', 'map_simple_use', 'geometry']
    buildings_gdf = gpd.read_file(buildings_path, layer='edition_17_0_new_format', columns=buildings_columns)

    output_areas_boundaries_columns = ['OA21CD', 'LSOA21CD', 'LSOA21NM', 'MSOA21CD', 'MSOA21NM', 
                                   'LAD22CD', 'LAD22NM', "RGN22CD", "RGN22NM", "area", "geometry"]
    output_areas_boundaries_gdf = oa_2021_boundaries_gdf.merge(oa_2021_lookup_df, on=["OA21CD", "LSOA21CD", "LSOA21NM"]) \
        .merge(oa_rgn_lookup_df, on="OA21CD") 
    output_areas_boundaries_gdf = output_areas_boundaries_gdf[output_areas_boundaries_gdf.RGN22CD != 'W92000004']
    output_areas_boundaries_gdf['area'] = output_areas_boundaries_gdf.geometry.area / 1_000_000
    output_areas_boundaries_gdf = output_areas_boundaries_gdf[output_areas_boundaries_columns]
    std_population_estimates_df = process_population_data(population_estimates_df)
    imd_lsoa_gdf = imd_england_2019_gdf.merge(lsoa_2011_2021_lookup_df[["LSOA11CD", "LSOA21CD"]], on="LSOA11CD")
    imd_lsoa_gdf = imd_lsoa_gdf[["LSOA11CD", "LSOA21CD"] + imd_lsoa_gdf.columns[1:-1].tolist()]
    os_tile_boundaries_gdf = expand_national_grid(os_5km_boundaries_gdf)

    output_areas_boundaries_gdf.to_parquet(output_areas_boundaries_parquet, index=False)
    std_population_estimates_df.to_parquet(std_population_estimates_parquet, index=False)
    imd_lsoa_gdf.to_parquet(imd_lsoa_parquet, index=False)
    os_tile_boundaries_gdf.to_parquet(os_tile_boundaries_parquet, index=False)
    green_space_access_gdf.to_parquet(green_space_access_parquet, index=False)
    green_space_site_gdf.to_parquet(green_space_site_parquet, index=False)
    road_edges_gdf.to_parquet(road_edges_parquet, index=False)
    road_nodes_gdf.to_parquet(road_nodes_parquet, index=False)
    buildings_gdf.to_parquet(buildings_parquet, index=False)
    logging.debug("Parquet files created successfully")

def process_population_data(population_estimates_df):

    logging.debug("Processing population data")

    population_estimates_df.columns = population_estimates_df.columns.str.replace(' ', '_')
    # Calculate the ratio of each column compared to Total
    columns_to_calculate = ['F0_to_15', 'F16_to_29', 'F30_to_44', 'F45_to_64', 'F65_and_over', 
                            'M0_to_15', 'M16_to_29', 'M30_to_44', 'M45_to_64', 'M65_and_over']
    for column in columns_to_calculate:
        population_estimates_df[f'{column}_ratio'] = population_estimates_df[column] / population_estimates_df['Total']

    # Calculate the ratio of total F and total M
    population_estimates_df['Total_F'] = population_estimates_df[['F0_to_15', 'F16_to_29', 'F30_to_44', 'F45_to_64', 'F65_and_over']].sum(axis=1)
    population_estimates_df['Total_M'] = population_estimates_df[['M0_to_15', 'M16_to_29', 'M30_to_44', 'M45_to_64', 'M65_and_over']].sum(axis=1)
    population_estimates_df['F_ratio'] = population_estimates_df['Total_F'] / population_estimates_df['Total']
    population_estimates_df['M_ratio'] = population_estimates_df['Total_M'] / population_estimates_df['Total']

    # Calculate the ratio per age range
    age_ranges = ['0_to_15', '16_to_29', '30_to_44', '45_to_64', '65_and_over']
    for age_range in age_ranges:
        population_estimates_df[f'{age_range}_ratio'] = population_estimates_df[f'F{age_range}'] + population_estimates_df[f'M{age_range}']
        population_estimates_df[f'{age_range}_ratio'] /= population_estimates_df['Total']

    # Keep only the required columns
    columns_to_keep = ['LSOA_2021_Code', 'Total'] + [col for col in population_estimates_df.columns if col.endswith('_ratio')]
    std_population_estimates_df = population_estimates_df.copy()[columns_to_keep]
    std_population_estimates_df.rename(columns={'LSOA_2021_Code': 'LSOA11CD', 'Total': 'total_pop'}, inplace=True)

    return std_population_estimates_df

def expand_national_grid(os_5km_boundaries_gdf):

    def translate_code(code):
        ew = 'W' if int(code[2]) < 5 else 'E'
        ns = 'S' if int(code[3]) < 5 else 'N'
        return code[:2] + ns + ew
    
    os_tile_boundaries_gdf = os_5km_boundaries_gdf.copy()
    
    os_tile_boundaries_gdf.rename(columns={'TILE_NAME': 'TILE_NAME_5KM'}, inplace=True)
    os_tile_boundaries_gdf['TILE_NAME_5KM_int'] = os_tile_boundaries_gdf['TILE_NAME_5KM'].apply(lambda x: translate_tile_name(x))
    os_tile_boundaries_gdf['TILE_NAME_10KM'] = os_tile_boundaries_gdf['TILE_NAME_5KM'].apply(lambda x: x[:4])
    os_tile_boundaries_gdf['TILE_NAME_50KM'] = os_tile_boundaries_gdf['TILE_NAME_5KM'].apply(translate_code)
    os_tile_boundaries_gdf['TILE_NAME_100KM'] = os_tile_boundaries_gdf['TILE_NAME_5KM'].apply(lambda x: x[:2])
    os_tile_boundaries_gdf = os_tile_boundaries_gdf[['TILE_NAME_5KM', 'TILE_NAME_5KM_int', 'TILE_NAME_10KM', 'TILE_NAME_50KM', 'TILE_NAME_100KM', 'geometry']]
    
    return os_tile_boundaries_gdf