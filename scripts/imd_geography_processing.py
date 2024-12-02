import pandas as pd
import geopandas as gpd

import sys
sys.path.append('..')  # Adjust the path as per your directory structure

from scripts.constants import *

# Define paths
# INPUT
lsoa_2011_to_2021_path = TABULAR_IN_DIR / "ONS" / "LSOA_(2011)_to_LSOA_(2021)_to_Local_Authority_District_(2022)_Best_Fit_Lookup_for_EW_(V2).csv"
lsoa_bua_lad_2021_path = TABULAR_IN_DIR / "ONS" / "LSOA_(2021)_to_Built_Up_Area_to_Local_Authority_District_to_Region_(December_2022)_Lookup_in_England_and_Wales_v2.csv"
bua_to_region_2022_path = TABULAR_IN_DIR / "ONS" / "Built_Up_Area_to_Region_(December_2022)_Lookup_in_Great_Britain.csv"
lsoa_prevalence_path = TABULAR_IN_DIR / "NHS" / "output_lsoa_prevalence.csv"

imd_england_path = VECTOR_IN_DIR / "IMD" / "English IMD 2019" / "IMD_2019.shp"
bua_2022_gb_path = VECTOR_IN_DIR / "ONS" / "BUA_2022_GB_6638829375457922612.geojson"
lsoa_2021_path = VECTOR_IN_DIR / "ONS" / "Lower_layer_Super_Output_Areas_(December_2021)_Boundaries_EW_BFC_(V10).geojson"

# OUTPUT
imd_lsoa_bua_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered.geojson"
imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"

# Variables
project_crs = "EPSG:27700"

# Input
lsoa_2011_to_2021_df = pd.read_csv(lsoa_2011_to_2021_path)
lsoa_bua_lad_2021_df = pd.read_csv(lsoa_bua_lad_2021_path)
bua_to_region_2022_df = pd.read_csv(bua_to_region_2022_path)
lsoa_prevalence_df = pd.read_csv(lsoa_prevalence_path)

imd_england_gdf = gpd.read_file(imd_england_path)
lsoa_2021_gdf = gpd.read_file(lsoa_2021_path)

# KEEP IMD LSOA boundaries (2019)

# England IMD df with reference to 2021 LSOA names
imd_england_merged_gdf = imd_england_gdf.merge(lsoa_2011_to_2021_df, left_on='lsoa11cd', right_on='LSOA11CD', how='inner')\
    .drop(columns=['lsoa11cd', 'lsoa11nm', 'lsoa11nmw', 'st_areasha', 'st_lengths', 'ObjectId', 'LSOA01NM', 'LADcd', 'LADnm'])

# Merge lsoa_2021_gdf with imd_england_merged_df
lsoa_2021_merged_gdf = imd_england_merged_gdf.merge(lsoa_2021_gdf.drop(columns=['geometry']), on='LSOA21CD', how='inner')\
    .drop(columns=['LSOA21NM_x', 'BNG_E', 'BNG_N', 'LAT', 'LONG', 'Shape__Area', 'Shape__Length', 'GlobalID', 'FID'])\
        .rename(columns={'LSOA21NM_y': 'LSOA21NM'})

bua_2021_merged_gdf = lsoa_2021_merged_gdf.merge(lsoa_bua_lad_2021_df, on='LSOA21CD', how='inner')\
    .drop(columns=['LAD22CD_x', 'LAD22NM_x', 'LAD22NMW_x', 'LSOA21NM_x', 'LSOA21NMW_x', 'ObjectId'])\
        .rename(columns={'LSOA21NM_y': 'LSOA21NM', 'LSOA21NMW_y': 'LSOA21NMW', 'LAD22CD_y': 'LAD22CD', 'LAD22NM_y': 'LAD22NM', 'LAD22NMW_y': 'LAD22NMW'})

# Merge bua_2021_merged_gdf with bua_to_region_2022_df
# There are more rows because there are Built Up Areas that can belong to different regions (e.g. East of England and London)
# bua_to_region_2022_df[bua_to_region_2022_df.duplicated(subset='BUA22CD', keep=False)].sort_values('BUA22CD')
region_merged_gdf = bua_2021_merged_gdf.merge(bua_to_region_2022_df, on='BUA22CD', how='left')\
    .drop(columns=['BUA22NM_x', 'BUA22NMW_x', 'RGN22CD_x', 'RGN22NM_x', 'WHOLE_PART', 'ObjectId'])\
    .rename(columns={'BUA22NM_y': 'BUA22NM', 'BUA22NMW_y': 'BUA22NMW', 'RGN22CD_y': 'RGN22CD', 'RGN22NM_y': 'RGN22NM'})

desired_order = ['LSOA11CD', 'LSOA11NM', 'LSOA21CD', 'LSOA21NM', 'LSOA21NMW',
                 'LAD22CD', 'LAD22NM', 'LAD22NMW', 'BUA22CD', 'BUA22NMW', 'BUA22NMG', 
                 'RGN22NMW', 'BUA22NM', 'RGN22CD', 'RGN22NM', 
                 'IMD_Rank', 'IMD_Decile', 'IMDScore', 'IMDRank0', 'IMDDec0', 'IncScore',
                 'IncRank', 'IncDec', 'EmpScore', 'EmpRank', 'EmpDec', 'EduScore',
                 'EduRank', 'EduDec', 'HDDScore', 'HDDRank', 'HDDDec', 'CriScore',
                 'CriRank', 'CriDec', 'BHSScore', 'BHSRank', 'BHSDec', 'EnvScore',
                 'EnvRank', 'EnvDec', 'IDCScore', 'IDCRank', 'IDCDec', 'IDOScore',
                 'IDORank', 'IDODec', 'CYPScore', 'CYPRank', 'CYPDec', 'ASScore',
                 'ASRank', 'ASDec', 'GBScore', 'GBRank', 'GBDec', 'WBScore', 'WBRank',
                 'WBDec', 'IndScore', 'IndRank', 'IndDec', 'OutScore', 'OutRank',
                 'OutDec', 'TotPop', 'DepChi', 'Pop16_59', 'Pop60+', 'WorkPop', 'geometry']

# Reorder the columns
region_merged_gdf = region_merged_gdf.reindex(columns=desired_order).to_crs(project_crs)
region_merged_gdf.to_file(imd_lsoa_bua_path)
region_merged_gdf[['LSOA11CD', 'LSOA11NM', 'LSOA21CD', 'LSOA21NM', 'LSOA21NMW', 'LAD22CD',
       'LAD22NM', 'LAD22NMW', 'BUA22CD', 'BUA22NMW', 'BUA22NMG', 'RGN22NMW',
       'BUA22NM', 'RGN22CD', 'RGN22NM', 'geometry']].to_file(imd_lsoa_bua_boundaries_path)
