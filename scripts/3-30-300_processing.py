#!/usr/bin/env python3

import argparse, os, time

from constants import *
from logging_config import *
from utils import *
from sedona_config import *

import geopandas as gpd

def create_schemas(sedona, imd_lsoa_bua_gdf, imd_england_gdf, buildings_path, T3_dir, T30_dir, T300_dir) -> None:

    boundaries_sdf = sedona.createDataFrame(imd_lsoa_bua_gdf.drop(columns=['LSOA21NMW', 'LAD22NMW', 'BUA22NMG', 'BUA22NMW', 'RGN22NMW'], axis=1))
    boundaries_sdf.createOrReplaceTempView('boundaries')
    imd_england_sdf = sedona.createDataFrame(imd_england_gdf)
    imd_england_sdf.createOrReplaceTempView('imd_england')
    buildings_sdf = sedona.read.format("geoparquet").load(str(buildings_path))
    buildings_sdf.createOrReplaceTempView("buildings")

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
    buildings_lsoa_sdf.createOrReplaceTempView("buildings")

    t30_imd_lsoa_sdf = sedona.sql(
    """
    SELECT b.*, ROUND(ST_Area(b.geometry), 2) AS area, i.*, t.canopy_cover
    FROM boundaries b
    LEFT JOIN imd_england i ON b.LSOA11CD = i.lsoa11cd
    LEFT JOIN t30 t ON b.LSOA11CD = t.LSOA11CD
    """
    )
    t30_imd_lsoa_sdf.createOrReplaceTempView("t30_imd_lsoa")

    t3_300_building_sdf = sedona.sql(
    """
    SELECT b.*, t3.tree_count, t300.closest_park_access_id, t300.distance
    FROM buildings b
    LEFT JOIN t3 ON b.verisk_premise_id = t3.verisk_premise_id
    LEFT JOIN t300 ON b.verisk_premise_id = t300.verisk_premise_id
    """
    )
    t3_300_building_sdf.createOrReplaceTempView("t3_300_building")

    t3_300_lsoa_sdf = sedona.sql(
    """
    SELECT LSOA11CD, ROUND(AVG(tree_count), 2) as tree_count, ROUND(AVG(distance), 2) as park_distance
    FROM t3_300_building
    GROUP BY LSOA11CD
    """
    )
    t3_300_lsoa_sdf.createOrReplaceTempView("t3_300_lsoa")

    t3_30_300_sdf = t30_imd_lsoa_sdf.join(t3_300_lsoa_sdf, on="LSOA11CD", how="inner")
    t3_30_300_sdf = t3_30_300_sdf.drop("lsoa11cd")
    t3_30_300_sdf.createOrReplaceTempView("t3_30_300")
    t3_30_300_sdf = sedona.sql(
    """
    SELECT *, (TotPop / area) AS TotPop_density,
    (DepChi / TotPop) AS DepChi_ratio,
    (Pop16_59 / TotPop) AS Pop16_59_ratio,
    (`Pop60+` / TotPop) AS Pop60_ratio,
    (WorkPop / TotPop) AS WorkPop_ratio
    FROM t3_30_300
    
    """
    )
    t3_30_300_sdf.createOrReplaceTempView("t3_30_300")

    return t3_30_300_sdf

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
    log_path = Path("logs/3-30-300_aggregate.log")

    setup_logger(log_path=log_path, log_level=log_level)
    logging.info("Aggregating data for all geographies (3-30-300)")
    logging.debug("Reading files")
    start_time = time.time()
    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path)
    imd_england_columns = ['lsoa11cd', 'TotPop', 'DepChi', 'Pop16_59', 'Pop60+', 'WorkPop',
                       'IMD_Rank', 'IMD_Decile', 'IMDScore', 'IncScore', 'IncRank', 'IncDec', 
                       'EmpScore', 'EmpRank', 'EmpDec', 'EduScore', 'EduRank', 'EduDec', 
                       'HDDScore', 'HDDRank', 'HDDDec', 'CriScore', 'CriRank', 'CriDec', 
                       'BHSScore', 'BHSRank', 'BHSDec', 'EnvScore', 'EnvRank', 'EnvDec']
    imd_england_gdf = gpd.read_file(imd_england_path)[imd_england_columns]
    
    logging.debug("Setting up Apache Sedona")
    os.environ["JAVA_HOME"] = JAVA_HOME
    sedona = get_spark()
    
    logging.debug("Running queries")
    
    create_schemas(sedona, imd_lsoa_bua_gdf, imd_england_gdf, buildings_path, T3_dir, T30_dir, T300_dir)
    t3_30_300_sdf = run_queries(sedona)

    logging.debug("Saving final output")

    t3_30_300_df = t3_30_300_sdf.toPandas()
    t3_30_300_df = t3_30_300_df.replace([float('inf'), float('-inf')], -99)
    t3_30_300_gdf = t3_30_300_df.set_geometry('geometry')
    t3_30_300_gdf = t3_30_300_gdf.set_crs(project_crs)
    t3_30_300_gdf.to_file(t3_30_300_path)

    end_time = time.time()
    logging.info(f"Processing 3-30-300 data took {end_time - start_time:.2f} seconds")
