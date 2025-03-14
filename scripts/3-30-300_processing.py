#!/usr/bin/env python3

import argparse, os, time, concurrent.futures

from constants import *
from logging_config import *
from utils import *
from sedona_config import *
from tqdm import tqdm
from pyspark.sql.functions import monotonically_increasing_id

import numpy as np
import geopandas as gpd

def create_schemas(sedona, imd_lsoa_bua_gdf, imd_england_gdf, spectral_indexes_gdf, buildings_path, T3_dir, T30_dir, T300_dir) -> None:

    logging.debug("Creating schemas")

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

    logging.debug("Running queries")

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
        SELECT t.*, s.NDVI_2016, s.NDWI_2016, s.NDBI_2016, s.NDVI_2024, s.NDWI_2024, s.NDBI_2024 FROM t3_30_300 t
        LEFT JOIN spectral_indexes s ON t.LSOA11CD = s.LSOA11CD_2016
        """
        )

    return t3_30_300_spectral_sdf

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

    return std_population_estimates_df

def format_os_national_grid(os_5km_boundaries_gdf, tile_level):

    def translate_code(code):
        ew = 'W' if int(code[2]) < 5 else 'E'
        ns = 'S' if int(code[3]) < 5 else 'N'
        return code[:2] + ns + ew
    
    os_5km_boundaries_gdf.rename(columns={'TILE_NAME': 'TILE_NAME_5KM'}, inplace=True)

    os_5km_boundaries_gdf['TILE_NAME_10KM'] = os_5km_boundaries_gdf['TILE_NAME_5KM'].apply(lambda x: x[:4])
    os_5km_boundaries_gdf['TILE_NAME_50KM'] = os_5km_boundaries_gdf['TILE_NAME_5KM'].apply(translate_code)
    os_5km_boundaries_gdf['TILE_NAME_100KM'] = os_5km_boundaries_gdf['TILE_NAME_5KM'].apply(lambda x: x[:2])
    os_5km_boundaries_gdf = os_5km_boundaries_gdf[['TILE_NAME_5KM', 'TILE_NAME_10KM', 'TILE_NAME_50KM', 'TILE_NAME_100KM', 'geometry']]

    os_tile_boundaries_gdf = os_5km_boundaries_gdf.dissolve(tile_level).reset_index()[[tile_level, 'geometry']]
    
    return os_tile_boundaries_gdf

def get_overlapping_grid_tiles(imd_lsoa_bua_buffer_gdf, os_tile_boundaries_gdf, geo_level, geo_code, tile_level):
    # Select one feature from imd_lsoa_bua_buffer_gdf
    # selected_feature = imd_lsoa_bua_buffer_gdf[imd_lsoa_bua_buffer_gdf[geo_level] == geo_code]

    overlapping_tiles_gdf = gpd.overlay(imd_lsoa_bua_buffer_gdf, os_tile_boundaries_gdf, how='intersection')
    overlapping_tiles_lst = overlapping_tiles_gdf[tile_level].unique().tolist()

    return overlapping_tiles_lst

def read_vom_trees_geoparquet(sedona, overlapping_tiles_lst):

    vom_trees_dir = T3_30_300_DIR / "VOM_Trees_geoparquet"
    vom_trees_paths = [str(path) for path in vom_trees_dir.glob("*.geoparquet") if any(tile_name in path.name for tile_name in overlapping_tiles_lst)]
    geo_trees_sdf = sedona.read.format("geoparquet").load(vom_trees_paths)

    geo_trees_sdf.withColumn("treeID", monotonically_increasing_id()).createOrReplaceTempView("geo_trees")

    return geo_trees_sdf

def create_spatial_rdds(t3_30_300_spectral_sdf, geo_trees_sdf):

    logging.debug("Creating spatial RDDs")

    t3_30_300_spectral_rdd  = Adapter.toSpatialRdd(t3_30_300_spectral_sdf, 'geometry')
    geo_trees_rdd = Adapter.toSpatialRdd(geo_trees_sdf, 'geometry')
    
    t3_30_300_spectral_rdd.analyze()
    geo_trees_rdd.analyze()

    return t3_30_300_spectral_rdd, geo_trees_rdd

def count_trees_rdd(sedona, t3_30_300_spectral_rdd, geo_trees_rdd, build_on_spatial_partitioned_rdd = True, using_index = True):

    logging.debug("Counting trees in RDD")

    geo_trees_rdd.spatialPartitioning(GridType.KDBTREE)
    t3_30_300_spectral_rdd.spatialPartitioning(geo_trees_rdd.getPartitioner())
    
    t3_30_300_spectral_rdd.buildIndex(IndexType.QUADTREE, build_on_spatial_partitioned_rdd)

    query_result = JoinQueryRaw.SpatialJoinQueryFlat(geo_trees_rdd, t3_30_300_spectral_rdd, using_index, True)

    query_result_sdf = Adapter.toDf(query_result, ["LSOA11CD"], ["treeID"], sedona)

    query_result_df = query_result_sdf.toPandas().sort_values(by='LSOA11CD')

    trees_within_area_df = query_result_df.groupby('LSOA11CD').size().reset_index(name='total_trees')

    return trees_within_area_df

def process_geo_code(geo_level, geo_code, tile_level, t3_30_300_gdf, os_5km_boundaries_gdf):

    logging.debug(f"Counting total trees for {geo_code}")

    start_time = time.time()

    # geo_level_sdf = sedona.sql(f"SELECT * FROM lsoa11 WHERE {geo_level} = '{geo_code}'")
    # geo_level_gdf = geo_level_sdf.toPandas().set_geometry('geometry').set_crs(project_crs)
    geo_level_gdf = t3_30_300_gdf[t3_30_300_gdf[geo_level] == geo_code][['LSOA11CD', 'geometry']]
    geo_level_sdf = sedona.createDataFrame(geo_level_gdf)
    os_tile_boundaries_gdf = format_os_national_grid(os_5km_boundaries_gdf, tile_level)
    overlapping_tiles_lst = get_overlapping_grid_tiles(geo_level_gdf, os_tile_boundaries_gdf, geo_level, geo_code, tile_level)

    geo_trees_sdf = read_vom_trees_geoparquet(sedona, overlapping_tiles_lst)
    t3_30_300_spectral_rdd, geo_trees_rdd = create_spatial_rdds(geo_level_sdf, geo_trees_sdf)
    trees_within_area_df = count_trees_rdd(sedona, t3_30_300_spectral_rdd, geo_trees_rdd)
    # trees_within_area_df = trees_within_area_df[['LSOA11CD', 'total_trees']]

    logging.warning(f"Regions processed: {len(trees_within_area_df)}")

    end_time = time.time()
    logging.warning(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")
    
    return trees_within_area_df


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Merge all the 3-30-300 metrics into one file with the spectral indexes')
    parser.add_argument('--geo_level', type=str, required=True, default='LAD22CD', help='Name/Code of the desired geography')
    parser.add_argument('--geo_code', type=str, required=False, default='E09000002', help='Geographical variable name')
    parser.add_argument('--tile_level', type=str, required=False, default='TILE_NAME_50KM', help='Name/Code of the desired geography')
    parser.add_argument('--parallel', action='store_true', help='Run job in parallel')
    parser.add_argument('--n_workers', type=int, required=False, default=2, help='Number of workers')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')

    args = parser.parse_args()
    geo_level = args.geo_level
    geo_code = args.geo_code
    tile_level = args.tile_level
    parallel = args.parallel
    n_workers = args.n_workers
    log_level = args.log_level

    project_crs = 'EPSG:27700'

    T3_30_300_DIR = VECTOR_OUT_DIR / "3-30-300"
    T3_dir = T3_30_300_DIR / "T3"
    T30_dir = T3_30_300_DIR / "T30"
    T300_dir = T3_30_300_DIR / "T300"
    t3_30_300_path = T3_30_300_DIR / "T3_30_300.geojson"
    imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"
    imd_england_path = VECTOR_IN_DIR / "IMD" / "English IMD 2019" / "IMD_2019.shp"
    os_5km_boundaries_path = VECTOR_IN_DIR / "OS" / "National_Grid" / "5km_grid_region.shp"
    buildings_path = VECTOR_IN_DIR / "EDINA" / "Buildings_6183" / "Buildings_6183.parquet"
    spectral_indexes_paths = [T3_30_300_DIR / "spectral_indexes_2016-01-01_2017-01-01.geojson", T3_30_300_DIR / "spectral_indexes_2024-01-01_2025-01-01.geojson"]
    population_estimates_path = TABULAR_IN_DIR / "ONS" / "sapelsoabroadage20112022.xlsx"
    log_path = Path("logs/3-30-300_aggregate.log")

    setup_logger(log_path=log_path, log_level=log_level)
    logging.info("Aggregating data for all geographies (3-30-300)")
    logging.debug("Reading files")
    start_time = time.time()
    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path).sort_values(by='RGN22CD').drop_duplicates(subset='LSOA11CD', keep='first')
    imd_england_columns = ['lsoa11cd', #'TotPop', 'DepChi', 'Pop16_59', 'Pop60+', 'WorkPop',
                       'IMD_Rank', 'IMD_Decile', 'IMDScore', 'IncScore', 'IncRank', 'IncDec', 
                       'EmpScore', 'EmpRank', 'EmpDec', 'EduScore', 'EduRank', 'EduDec', 
                       'HDDScore', 'HDDRank', 'HDDDec', 'CriScore', 'CriRank', 'CriDec', 
                       'BHSScore', 'BHSRank', 'BHSDec', 'EnvScore', 'EnvRank', 'EnvDec']
    imd_england_gdf = gpd.read_file(imd_england_path)[imd_england_columns].rename(columns={'lsoa11cd': 'LSOA11CD_imd'})
    os_5km_boundaries_gdf = gpd.read_file(os_5km_boundaries_path).to_crs(project_crs)
    spectral_indexes_2016_gdf = gpd.read_file(spectral_indexes_paths[0])
    spectral_indexes_2024_gdf = gpd.read_file(spectral_indexes_paths[1])
    spectral_indexes_gdf = spectral_indexes_2016_gdf.merge(spectral_indexes_2024_gdf, on='LSOA21CD', suffixes=('_2016', '_2024'))
    population_estimates_df = pd.read_excel(population_estimates_path, sheet_name='Mid-2022 LSOA 2021', skiprows=3)
    std_population_estimates_df = process_population_data(population_estimates_df)
    geo_level_codes = imd_lsoa_bua_gdf[geo_level].unique()
    # geo_level_codes = ['E09000002', 'E09000003'] # Example for testing

    logging.debug("Setting up Apache Sedona")
    os.environ["JAVA_HOME"] = JAVA_HOME
    sedona = get_spark()
    
    logging.debug("Running queries")
    
    create_schemas(sedona, imd_lsoa_bua_gdf, imd_england_gdf, spectral_indexes_gdf, buildings_path, T3_dir, T30_dir, T300_dir)
    t3_30_300_spectral_sdf = run_queries(sedona)
    # geo_trees_sdf = read_vom_trees_geoparquet(sedona)
    
    logging.debug("Saving final output")

    t3_30_300_df = t3_30_300_spectral_sdf.toPandas()
    t3_30_300_df = t3_30_300_df.replace([float('inf'), float('-inf')], np.nan)
    t3_30_300_gdf = t3_30_300_df.set_geometry('geometry')
    t3_30_300_gdf = t3_30_300_gdf.set_crs(project_crs)
    t3_30_300_gdf = t3_30_300_gdf.merge(std_population_estimates_df, left_on='LSOA21CD', right_on='LSOA_2021_Code', how='left')
    t3_30_300_gdf['Pop_density'] = t3_30_300_gdf['Total'] / t3_30_300_gdf['area']
    t3_30_300_gdf.drop(columns=['LSOA_2021_Code'], inplace=True)
    t3_30_300_gdf.drop_duplicates(subset=["LSOA11CD"], keep="first", inplace=True)
    t3_30_300_gdf.sort_values(by='LSOA11CD').reset_index(drop=True, inplace=True)
    # lsoa11_sdf = sedona.createDataFrame(t3_30_300_gdf[['LSOA11CD', 'geometry']])
    # lsoa11_sdf.createOrReplaceTempView('lsoa11')

    try:

        total_trees_lst = []

        if parallel:
            logging.warning("Running in parallel")

            with concurrent.futures.ThreadPoolExecutor(max_workers=n_workers) as executor:
                futures = [executor.submit(process_geo_code, geo_level, geo_code, tile_level, t3_30_300_gdf, os_5km_boundaries_gdf) for geo_code in geo_level_codes]
                
                for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions Processed"):
                    total_trees_lst.append(future.result())                

        else:
            logging.warning("Running sequentially")

            for geo_code in tqdm(geo_level_codes, desc='Regions Processed'):   
                trees_within_area_df = process_geo_code(geo_level, geo_code, tile_level, t3_30_300_gdf, os_5km_boundaries_gdf)
                total_trees_lst.append(trees_within_area_df)

        total_trees_df = pd.concat(total_trees_lst)
        t3_30_300_gdf = t3_30_300_gdf.merge(total_trees_df, on='LSOA11CD', how='outer')

    #     t3_30_300_spectral_rdd, geo_trees_rdd = create_spatial_rdds(lsoa11_sdf, geo_trees_sdf)
    #     trees_within_area_df = count_trees_rdd(sedona, t3_30_300_spectral_rdd, geo_trees_rdd)
        # t3_30_300_gdf = t3_30_300_gdf.merge(trees_within_area_df, left_on='LSOA21CD', right_on='LSOA21CD', how='left')

    except Exception as e:
        logging.error(f"Error in counting trees: {e}")
        
    t3_30_300_gdf.to_file(t3_30_300_path)

    end_time = time.time()
    logging.info(f"Processing 3-30-300 data took {end_time - start_time:.2f} seconds")
