#!/usr/bin/env python3

import re, json, argparse, os, time, concurrent.futures

from constants import *
from logging_config import *
from utils import *
from sedona_config import *

import pandas as pd
import geopandas as gpd
from tqdm import tqdm

def process_buildings(geo_level: str, geo_code: str) -> None:

    logging.info(f"Filtering buildings for {geo_code}")

    geo_boundary_sdf = sedona.sql(
        f"""
            SELECT ST_Union_Aggr(geometry) AS geometry
            FROM boundaries
            WHERE {geo_level} = '{geo_code}'
        """)
    geo_boundary_sdf.createOrReplaceTempView("geo_boundary")

    geo_buildings_sdf = sedona.sql(
        """
            SELECT b.* FROM buildings b, geo_boundary g 
            WHERE ST_Intersects(b.geometry, g.geometry)
        """)
    geo_buildings_sdf.createOrReplaceTempView("geo_buildings")

def get_water_distance(geo_level: str) -> pd.DataFrame:

    water_distance_agg_sdf = sedona.sql(
        f"""
            SELECT {geo_level}, MEAN(distance_water) AS WATER_DISTANCE FROM geo_buildings
        """)
    geo_water_distance_df = water_distance_agg_sdf.toPandas()
    return geo_water_distance_df

def process_geo_code(geo_level: str, geo_code: str) -> pd.DataFrame:
    """
    Process a single geo_code and return the resulting DataFrame.
    """
    start_time = time.time()

    try:
        process_buildings(geo_level, geo_code)
        geo_water_distance_df = get_water_distance(geo_level)
        end_time = time.time()
        logging.info(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")
        return geo_water_distance_df

    except Exception as e:
        logging.error(f"Error processing {geo_code}: {e}")
        return pd.DataFrame()

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Description of your script.')
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

    project_crs = 'EPSG:27700'

    # IN paths
    T3_30_300_DIR = VECTOR_OUT_DIR / "3-30-300"
    imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"
    buildings_path = VECTOR_IN_DIR / "EDINA" / "Buildings_6183" / "Buildings_6183.parquet"
    water_distance_path = T3_30_300_DIR / "water_distance.csv"

    log_path = Path("logs/water_calculation.log")
    setup_logger(log_path=log_path, log_level=log_level)
    logging.info("Extracting distance to water for all geographies")
    logging.debug("Reading files")

    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path)
    geo_level_codes = imd_lsoa_bua_gdf[geo_level].unique()
    logging.debug("Setting up Apache Sedona")
    os.environ["JAVA_HOME"] = JAVA_HOME
    sedona = get_spark()

    boundaries_sdf = sedona.createDataFrame(imd_lsoa_bua_gdf.drop(columns=['LSOA21NMW', 'LAD22NMW', 'BUA22NMG', 'BUA22NMW', 'RGN22NMW'], axis=1))
    boundaries_sdf.createOrReplaceTempView('boundaries')
    buildings_sdf = sedona.read.format("geoparquet").load(str(buildings_path))
    buildings_sdf.createOrReplaceTempView("buildings")

    water_distance_df = pd.DataFrame()

    if parallel:
        logging.debug("Running in parallel")

        with concurrent.futures.ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = [executor.submit(process_geo_code, geo_level, geo_code) for geo_code in geo_level_codes]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions Processed"):
                try:
                    geo_water_distance_df = future.result()
                    water_distance_df = pd.concat([water_distance_df, geo_water_distance_df], ignore_index=True)
                except Exception as e:
                    logging.error(f"Error processing: {e}")

    else:
        logging.debug("Running sequentially")

        for geo_code in tqdm(geo_level_codes, desc='Regions Processed'):   
            geo_water_distance_df = process_geo_code(geo_level, geo_code)
            water_distance_df = pd.concat([water_distance_df, geo_water_distance_df], ignore_index=True)

    # Save the final DataFrame to a file
    water_distance_df.to_csv(water_distance_path, index=False)