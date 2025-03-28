"""
Module: file_operations.py
Description: Utility functions for file handling in My Project.
Author: Your Name
Date: YYYY-MM-DD
"""

from src.utils.constants import INPUT_DIR, OUTPUT_DIR

# IN paths
vom_dir = INPUT_DIR / "Defra" / "VOM"
vom_lad_dir = vom_dir / "LADs"
vom_unzipped_dir = vom_dir / "unzipped_tiles"
chm_lad_tiles_path = vom_lad_dir / "LAD_CHM_tiles_paths.json"

# # CDRC
imd_england_2019_path = INPUT_DIR / "CDRC" / "IMD" / "English IMD 2019" / "IMD_2019.shp"

# # Office for National Statistics (ONS)
oa_2021_lookup_path = INPUT_DIR / "ONS" / "Output_Area_to_Lower_layer_Super_Output_Area_to_Middle_layer_Super_Output_Area_to_Local_Authority_District_(December_2021)_Lookup_in_England_and_Wales_v3.csv"
oa_2021_boundaries_path = INPUT_DIR / "ONS" / "Output_Areas_(December_2021)_Boundaries_EW_BFE_(V9).geojson"
oa_rgn_lookup_path = INPUT_DIR / "ONS" / "OA21_RGN22_LU.csv"
lsoa_2011_2021_lookup_path = INPUT_DIR / "ONS" / "LSOA_(2011)_to_LSOA_(2021)_to_Local_Authority_District_(2022)_Best_Fit_Lookup_for_EW_(V2).csv"
population_estimates_path = INPUT_DIR / "ONS" / "sapelsoabroadage20112022.xlsx"

# # Ordnance Survey (OS)
os_5km_boundaries_path = INPUT_DIR / "OS" / "National_Grid" / "5km_grid_region.shp"
green_space_path = INPUT_DIR / "OS" / "Green_Spaces" / "opgrsp_gb.gpkg"
roads_path = INPUT_DIR / "OS" / "Roads" / "oproad_gb.gpkg"

# # Verisk
buildings_path = INPUT_DIR / "Verisk" / "Buildings_6183" / "edition_17_0_new_format.gpkg"


# OUT paths
T3_30_300_DIR = OUTPUT_DIR / "3-30-300"
T3_dir = T3_30_300_DIR / "T3"
T30_dir = T3_30_300_DIR / "T30"
T300_dir = T3_30_300_DIR / "T300"
trees_dir = T3_30_300_DIR / "VOM_Trees"

## Parquet files
os_tile_boundaries_parquet = T3_30_300_DIR / "database" / "os_tile_boundaries.parquet"
output_areas_boundaries_parquet = T3_30_300_DIR / "database" / "output_areas_boundaries.parquet"
imd_lsoa_parquet = T3_30_300_DIR / "database" / "imd_england_2019.parquet"
std_population_estimates_parquet = T3_30_300_DIR / "database" / "population_estimates.parquet"
green_space_access_parquet = T3_30_300_DIR / "database" / "green_space_access.parquet"
green_space_site_parquet = T3_30_300_DIR / "database" / "green_space_site.parquet"
road_edges_parquet = T3_30_300_DIR / "database" / "road_edges.parquet"
road_nodes_parquet = T3_30_300_DIR / "database" / "road_nodes.parquet"
buildings_parquet = INPUT_DIR / "Verisk" / "Buildings_6183" / "Buildings_6183.parquet"
t3_30_300_path = T3_30_300_DIR / "T3_30_300.geojson"
imd_lsoa_bua_boundaries_path = OUTPUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"