#!/usr/bin/env python3

import argparse, os, time

from constants import *
from logging_config import *
from utils import *
from sedona_config import *

import geopandas as gpd

def create_schemas(sedona, imd_lsoa_bua_gdf, imd_england_gdf, spectral_indexes_gdf, buildings_path, T3_dir, T30_dir, T300_dir) -> None:

    boundaries_sdf = sedona.createDataFrame(imd_lsoa_bua_gdf.drop(columns=['LSOA21NMW', 'LAD22NMW', 'BUA22NMG', 'BUA22NMW', 'RGN22NMW'], axis=1))
    boundaries_sdf.createOrReplaceTempView('boundaries')
    imd_england_sdf = sedona.createDataFrame(imd_england_gdf)
    imd_england_sdf.createOrReplaceTempView('imd_england')
    buildings_sdf = sedona.read.format("geoparquet").load(str(buildings_path))
    buildings_sdf.createOrReplaceTempView("buildings")
    spectral_indexes_sdf = sedona.createDataFrame(spectral_indexes_gdf)
    spectral_indexes_sdf.createOrReplaceTempView("spectral_indexes")

    t3_sdf = sedona.read.csv(str(T3_dir), header=True, inferSchema=True)
    t3_sdf.createOrReplaceTempView("t3")
    t30_sdf = sedona.read.csv(str(T30_dir), header=True, inferSchema=True)
    t30_sdf.createOrReplaceTempView("t30")
    t300_sdf = sedona.read.csv(str(T300_dir), header=True, inferSchema=True)
    t300_sdf.createOrReplaceTempView("t300")

def run_queries(sedona):

    buildings_lsoa_sdf = sedona.sql(
    """
    SELECT b.*, l.LSOA11CD
    FROM buildings b
    JOIN boundaries l
    ON ST_Contains(l.geometry, b.geometry)
    """
    )
    buildings_lsoa_sdf.createOrReplaceTempView("buildings2")

    t30_imd_lsoa_sdf = sedona.sql(
    """
    SELECT b.*, ROUND(ST_Area(b.geometry), 2) AS area, i.*, t.canopy_cover
    FROM boundaries b
    LEFT JOIN imd_england i ON b.LSOA11CD = i.LSOA11CD_imd
    LEFT JOIN t30 t ON b.LSOA11CD = t.LSOA11CD
    """
    )
    t30_imd_lsoa_sdf = t30_imd_lsoa_sdf.drop("LSOA11CD_imd")
    t30_imd_lsoa_sdf.createOrReplaceTempView("t30_imd_lsoa")

    t3_300_building_sdf = sedona.sql(
    """
    SELECT b.*, t3.tree_count, t300.closest_park_access_id, t300.distance
    FROM buildings2 b
    LEFT JOIN t3 ON b.verisk_premise_id = t3.verisk_premise_id
    LEFT JOIN t300 ON b.verisk_premise_id = t300.verisk_premise_id
    """
    )
    t3_300_building_sdf.createOrReplaceTempView("t3_300_building")

    t3_300_lsoa_sdf = sedona.sql(
    """
    SELECT LSOA11CD, ROUND(AVG(tree_count), 2) as tree_count, ROUND(AVG(distance), 2) as park_distance, ROUND(AVG(distance_water), 2) as water_distance
    FROM t3_300_building
    GROUP BY LSOA11CD
    """
    )
    t3_300_lsoa_sdf.createOrReplaceTempView("t3_300_lsoa")

    t3_30_300_sdf = sedona.sql(
    """
    SELECT a.*, b.tree_count, b.park_distance, b.water_distance FROM t30_imd_lsoa a 
    INNER JOIN t3_300_lsoa b ON a.LSOA11CD = b.LSOA11CD
    """)
    t3_30_300_sdf.createOrReplaceTempView("t3_30_300")
    # t3_30_300_sdf = sedona.sql(
    # """
    # SELECT *, (TotPop / area) AS TotPop_density,
    # (DepChi / TotPop) AS DepChi_ratio,
    # (Pop16_59 / TotPop) AS Pop16_59_ratio,
    # (`Pop60+` / TotPop) AS Pop60_ratio,
    # (WorkPop / TotPop) AS WorkPop_ratio
    # FROM t3_30_300 
    # """
    # )
    # t3_30_300_sdf.createOrReplaceTempView("t3_30_300")
    
    t3_30_300_spectral_sdf = sedona.sql(
        """
        SELECT t.*, s.NDVI, s.NDWI, s.NDBI FROM t3_30_300 t
        LEFT JOIN spectral_indexes s ON t.LSOA11CD = s.LSOA11CD
        """
        )

    return t3_30_300_spectral_sdf

def process_population_data(population_estimates_df):

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

    return std_population_estimates_df

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Description of your script.')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')

    args = parser.parse_args()

    log_level = args.log_level

    project_crs = 'EPSG:27700'

    T3_30_300_DIR = VECTOR_OUT_DIR / "3-30-300"
    T3_dir = T3_30_300_DIR / "T3"
    T30_dir = T3_30_300_DIR / "T30"
    T300_dir = T3_30_300_DIR / "T300"
    t3_30_300_path = T3_30_300_DIR / "T3_30_300.geojson"
    imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"
    imd_england_path = VECTOR_IN_DIR / "IMD" / "English IMD 2019" / "IMD_2019.shp"
    buildings_path = VECTOR_IN_DIR / "EDINA" / "Buildings_6183" / "Buildings_6183.parquet"
    spectral_indexes_path = T3_30_300_DIR / "spectral_indexes.geojson"
    population_estimates_path = TABULAR_IN_DIR / "ONS" / "sapelsoabroadage20112022.xlsx"
    log_path = Path("logs/3-30-300_aggregate.log")

    setup_logger(log_path=log_path, log_level=log_level)
    logging.info("Aggregating data for all geographies (3-30-300)")
    logging.debug("Reading files")
    start_time = time.time()
    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path).sort_values(by='RGN22CD').drop_duplicates(subset='LSOA11CD', keep='first')
    imd_england_columns = ['lsoa11cd', 'TotPop', 'DepChi', 'Pop16_59', 'Pop60+', 'WorkPop',
                       'IMD_Rank', 'IMD_Decile', 'IMDScore', 'IncScore', 'IncRank', 'IncDec', 
                       'EmpScore', 'EmpRank', 'EmpDec', 'EduScore', 'EduRank', 'EduDec', 
                       'HDDScore', 'HDDRank', 'HDDDec', 'CriScore', 'CriRank', 'CriDec', 
                       'BHSScore', 'BHSRank', 'BHSDec', 'EnvScore', 'EnvRank', 'EnvDec']
    imd_england_gdf = gpd.read_file(imd_england_path)[imd_england_columns].rename(columns={'lsoa11cd': 'LSOA11CD_imd'})
    spectral_indexes_gdf = gpd.read_file(spectral_indexes_path)
    population_estimates_df = pd.read_excel(population_estimates_path, sheet_name='Mid-2022 LSOA 2021', skiprows=3)
    std_population_estimates_df = process_population_data(population_estimates_df)

    logging.debug("Setting up Apache Sedona")
    os.environ["JAVA_HOME"] = JAVA_HOME
    sedona = get_spark()
    
    logging.debug("Running queries")
    
    create_schemas(sedona, imd_lsoa_bua_gdf, imd_england_gdf, spectral_indexes_gdf, buildings_path, T3_dir, T30_dir, T300_dir)
    t3_30_300_sdf = run_queries(sedona)

    logging.debug("Saving final output")

    t3_30_300_df = t3_30_300_sdf.toPandas()
    t3_30_300_df = t3_30_300_df.replace([float('inf'), float('-inf')], -99)
    t3_30_300_gdf = t3_30_300_df.set_geometry('geometry')
    t3_30_300_gdf = t3_30_300_gdf.set_crs(project_crs)
    t3_30_300_gdf = t3_30_300_gdf.merge(std_population_estimates_df, left_on='LSOA21CD', right_on='LSOA_2021_Code', how='left')
    t3_30_300_gdf['Pop_density'] = t3_30_300_gdf['Total'] / t3_30_300_gdf['area']
    t3_30_300_gdf.to_file(t3_30_300_path)

    end_time = time.time()
    logging.info(f"Processing 3-30-300 data took {end_time - start_time:.2f} seconds")
