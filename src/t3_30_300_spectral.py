"""
Module: src/t3_30_300_spectral.py
Description: Functions for gathering the T3, T30, T300, and spectral indices dataframes.
Author: Andrés C. Zúñiga-González
Date: 2025-07-16
"""

import logging
from utils.paths import database_dir, t30_parquet, t300_parquet, tree_count_parquet, buildings_parquet, output_areas_boundaries_parquet, output_areas_buildings_parquet
from utils.paths import spectral_parquet, tree_count_parquet, t3_30_300_spectral_parquet, t3_30_300_spectral_buildings_parquet, t3_30_300_buildings_parquet, T3_dir, T30_dir, T30_buildings_dir, T300_dir, Spectral_dir, tree_count_dir
from utils.sedona_config import get_spark
from utils.logging_config import setup_logger
from utils.data_processing import save_temp_file

import logging
import argparse
import numpy as np
import pandas as pd
from pathlib import Path
from pyspark.sql.dataframe import DataFrame
from pyspark.sql.session import SparkSession
from scipy.optimize import curve_fit
from pyspark.sql.session import SparkSession
from pyspark.sql.functions import col
from pyspark.sql.functions import round as spark_round
from pyspark.sql.types import DoubleType

def merge_output_csv(sedona: SparkSession, t3_buffer_lst: list[int], t30_buffer_lst: list[int], file_format: str="parquet") -> None:
    """
    Merges the output CSV files into parquet files.
    Args:
        sedona (SparkSession): The Spark session.
        t3_buffer_lst (list[int]): Buffer sizes for T3 tree-count data.
        t30_buffer_lst (list[int]): Buffer sizes for per-building T30 canopy-cover data.
    """

    logging.info("Merging output CSV files into parquet files")

    for buffer in t3_buffer_lst:
        t3_buffer_parquet = database_dir / f"T3_{buffer}m.parquet"

        t3_sdf = sedona.read.format("csv").option("header", True).load(str(T3_dir) + f"/*{buffer}m.csv")
        t3_sdf = t3_sdf.withColumnRenamed("tree_count", f"tree_count_{buffer}m")
        t3_sdf.createOrReplaceTempView(f"t3_{buffer}m")
        t3_df = save_temp_file(t3_sdf, t3_buffer_parquet, coalesce=1, file_format=file_format)

    for buffer in t30_buffer_lst:
        t30_buildings_buffer_parquet = database_dir / f"T30_buildings_{buffer}m.parquet"
        t30_buildings_sdf = sedona.read.format("csv").option("header", True).load(str(T30_buildings_dir) + f"/*_{buffer}m.csv")
        t30_buildings_sdf = (t30_buildings_sdf
                             .withColumnRenamed("canopy_cover", f"canopy_cover_{buffer}m")
                             .drop("tree_pixels", "total_pixels"))
        t30_buildings_sdf.createOrReplaceTempView(f"t30_buildings_{buffer}m")
        save_temp_file(t30_buildings_sdf, t30_buildings_buffer_parquet, coalesce=1, file_format=file_format)

    t30_sdf = sedona.read.format("csv").option("header", True).load(str(T30_dir))
    t30_sdf.createOrReplaceTempView("t30")
    t30_df = save_temp_file(t30_sdf, t30_parquet, coalesce=1, file_format=file_format)
    t300_sdf = sedona.read.format("csv").option("header", True).load(str(T300_dir))
    t300_sdf.createOrReplaceTempView("t300")
    t300_df = save_temp_file(t300_sdf, t300_parquet, coalesce=1, file_format=file_format)
    spectral_sdf = sedona.read.format("csv").option("header", True).load(str(Spectral_dir))
    spectral_sdf.createOrReplaceTempView("spectral")
    spectral_df = save_temp_file(spectral_sdf, spectral_parquet, coalesce=1, file_format=file_format)
    tree_count_sdf = sedona.read.format("csv").option("header", True).load(str(tree_count_dir))
    tree_count_sdf.createOrReplaceTempView("tree_count")
    tree_count_df = save_temp_file(tree_count_sdf, tree_count_parquet, coalesce=1, file_format=file_format)

def read_parquet_files(sedona: SparkSession, t3_buffer_lst: list[int], t30_buffer_lst: list[int]) -> dict:
    """
    Reads the parquet files.
    Args:
        sedona (SparkSession): The Spark session.
        t3_buffer_lst (list[int]): Buffer sizes for T3 tree-count data.
        t30_buffer_lst (list[int]): Buffer sizes for per-building T30 canopy-cover data.
    Returns:
        dict: A dictionary containing the dataframes.
    """

    logging.debug("Reading parquet files")

    sdf_dict = {}

    t30_sdf = sedona.read.format("parquet").load(str(t30_parquet))
    t30_sdf.createOrReplaceTempView("t30")
    t300_sdf = sedona.read.format("parquet").load(str(t300_parquet))
    t300_sdf.createOrReplaceTempView("t300")
    spectral_sdf = sedona.read.format("parquet").load(str(spectral_parquet))
    spectral_sdf.createOrReplaceTempView("spectral")
    tree_count_sdf = sedona.read.format("parquet").load(str(tree_count_parquet))
    tree_count_sdf.createOrReplaceTempView("tree_count")
    buildings_sdf = sedona.read.format("parquet").load(str(buildings_parquet))
    buildings_sdf.createOrReplaceTempView("buildings")
    boundaries_sdf = sedona.read.format("parquet").load(str(output_areas_boundaries_parquet))
    boundaries_sdf.createOrReplaceTempView("boundaries")
    output_areas_buildings_overlay_sdf = sedona.read.format("parquet").load(str(output_areas_buildings_parquet))
    output_areas_buildings_overlay_sdf.createOrReplaceTempView("boundaries_buildings_overlay")

    sdf_dict["t30"] = t30_sdf
    sdf_dict["t300"] = t300_sdf
    sdf_dict["spectral"] = spectral_sdf
    sdf_dict["tree_count"] = tree_count_sdf

    for buffer in t3_buffer_lst:
        t3_buffer_parquet = database_dir / f"T3_{buffer}m.parquet"
        t3_sdf = sedona.read.format("parquet").load(str(t3_buffer_parquet))
        t3_sdf.createOrReplaceTempView(f"t3_{buffer}m")
        sdf_dict[f"t3_{buffer}m"] = t3_sdf

    for buffer in t30_buffer_lst:
        t30_buildings_buffer_parquet = database_dir / f"T30_buildings_{buffer}m.parquet"
        t30_buildings_sdf = sedona.read.format("parquet").load(str(t30_buildings_buffer_parquet))
        t30_buildings_sdf.createOrReplaceTempView(f"t30_buildings_{buffer}m")
        sdf_dict[f"t30_buildings_{buffer}m"] = t30_buildings_sdf

    return sdf_dict

def aggregate_t30(sedona: SparkSession, geo_level: str) -> DataFrame:
    """
    Aggregates the T30 data.
    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
    Returns:
        DataFrame: The aggregated T30 dataframe.
    """

    logging.debug("Aggregating T30 data")

    t30_agg_sdf = sedona.sql(f"""
    SELECT {geo_level},
    ROUND(SUM(canopy_cover * total_pixels) / SUM(total_pixels), 2) AS canopy_cover
    FROM t30 
    GROUP BY {geo_level}
    """)

    t30_agg_sdf.createOrReplaceTempView("t30_agg")

    return t30_agg_sdf

def aggregate_tree_count(sedona: SparkSession, geo_level: str, sub_geo_level: str) -> DataFrame:
    """
    Aggregates the tree count data.
    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
        sub_geo_level (str): The sub geo level.
    Returns:
        DataFrame: The aggregated tree count dataframe.
    """

    logging.debug("Aggregating tree count data")

    tree_count_agg_sdf = sedona.sql(f"""
    SELECT b.{geo_level}, SUM(t.tree_count) AS total_trees
    FROM tree_count t
    LEFT JOIN boundaries b ON t.{sub_geo_level} = b.{sub_geo_level}
    GROUP BY {geo_level}
    """)

    tree_count_agg_sdf.createOrReplaceTempView("tree_count_agg")

    return tree_count_agg_sdf

def merge_t30_and_spectral(sedona: SparkSession, geo_level: str) -> DataFrame:
    """
    Merges the T30 and spectral index dataframes.
    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
    Returns:
        DataFrame: The merged T30 and spectral index dataframe.
    """
    
    logging.debug("Merging T30 and spectral index dataframes")

    t30_spectral_sdf = sedona.sql(f"""
    SELECT s.*, t30_agg.canopy_cover
    FROM t30_agg
    RIGHT JOIN spectral s ON t30_agg.{geo_level} = s.{geo_level}
    """)
    t30_spectral_sdf.createOrReplaceTempView("t30_spectral")
    
    return t30_spectral_sdf

def calculate_slope(*tree_counts, buffer_lst: list[int]=[10, 25, 50, 75, 100]):
    """
    Calculates the slope of the exponential regression using the different buffer sizes.
    Args:
        tree_counts (list): The list of tree counts.
    Returns:
        float: The slope of the exponential regression.
    """

    logging.debug(f"Calculating slope for tree counts with buffers: {buffer_lst}")

    # Extract x values from the column names
    x_values = np.array([0] + buffer_lst)  # Corresponding to tree_count_10m, tree_count_25m, etc.
    y_values = np.array(tree_counts, dtype=np.float64) + 1
    y_values = np.insert(y_values, 0, 1)
    
    # Filter out rows with invalid or missing values
    valid_indices = ~np.isnan(y_values)
    y_values = y_values[valid_indices]
    
    if len(y_values) < 2:  # Not enough points to fit a regression
        return None
    elif y_values[-1] == 1:
        return float(0)
    
    # Perform exponential regression through the origin
    def model(x, b):
        return np.exp(b * x)

    # Fit the model
    popt, _ = curve_fit(model, x_values, y_values)

    return round(float(popt[0]), 4)  # Return the estimated slope

def merge_t3_and_t300(sedona: SparkSession, t3_buffer_lst: list[int], t30_buffer_lst: list[int]) -> DataFrame:
    """
    Merges the T3, T300, and per-building T30 dataframes.
    Args:
        sedona (SparkSession): The Spark session.
        t3_buffer_lst (list[int]): Buffer sizes for T3 tree-count data.
        t30_buffer_lst (list[int]): Buffer sizes for per-building T30 canopy-cover data.
    Returns:
        DataFrame: The merged building-level dataframe.
    """

    logging.debug("Merging T3, T300, and per-building T30 dataframes")

    tree_count_columns = [f"tree_count_{buffer}m" for buffer in t3_buffer_lst]
    t30_building_selects = ", ".join([f"t30_buildings_{b}m.canopy_cover_{b}m" for b in t30_buffer_lst])

    sql_parts = [f"""SELECT t300.*, b.distance_water, b.map_use, b.building_area,
                 {', '.join([f"t3_{buffer}m.tree_count_{buffer}m" for buffer in t3_buffer_lst])},
                 {t30_building_selects}
                 FROM t300
                 JOIN buildings b ON t300.verisk_premise_id = b.verisk_premise_id"""]

    for buffer in t3_buffer_lst:
        sql_parts.append(f"FULL JOIN t3_{buffer}m ON t300.verisk_premise_id = t3_{buffer}m.verisk_premise_id")

    for buffer in t30_buffer_lst:
        sql_parts.append(f"LEFT JOIN t30_buildings_{buffer}m ON t300.verisk_premise_id = t30_buildings_{buffer}m.verisk_premise_id")

    final_query = "\n".join(sql_parts)
    t3_300_sdf = sedona.sql(final_query)
    t3_300_sdf.createOrReplaceTempView("t3_300")
    t3_300_sdf = t3_300_sdf.fillna({col: 0 for col in tree_count_columns})

    for c in tree_count_columns:
        t3_300_sdf = t3_300_sdf.withColumn(c, col(c).cast(DoubleType()))

    logging.info("Pulling t3_300 to driver for pandas-side slope computation")
    t3_300_df = t3_300_sdf.toPandas()

    t3_300_df["tree_count_slope"] = t3_300_df.apply(
        lambda row: calculate_slope(*[row[c] for c in tree_count_columns], buffer_lst=t3_buffer_lst),
        axis=1
    )

    t3_300_df.to_parquet(t3_30_300_buildings_parquet, index=False)
    logging.info("Saved t3_30_300_buildings_parquet")

    return t3_300_sdf

def aggregate_t3_300_by_boundaries(sedona: SparkSession, geo_level: str, t3_buffer_lst: list[int], t30_buffer_lst: list[int]) -> DataFrame:
    """
    Aggregates the T3, T300, and per-building T30 dataframes by boundaries.
    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
        t3_buffer_lst (list[int]): Buffer sizes for T3 tree-count data.
        t30_buffer_lst (list[int]): Buffer sizes for per-building T30 canopy-cover data.
    """

    logging.debug("Aggregating T3, T300, and per-building T30 data by boundaries")

    t3_300_boundaries_sdf = sedona.sql(f"""
    SELECT DISTINCT bbo.{geo_level}, t3_300.* FROM t3_300
    LEFT JOIN boundaries_buildings_overlay bbo ON t3_300.verisk_premise_id = bbo.verisk_premise_id
    """)
    t3_300_boundaries_sdf.createOrReplaceTempView("t3_300_boundaries")

    t30_building_aggs = ", ".join([f"ROUND(AVG(canopy_cover_{b}m), 2) as canopy_cover_{b}m" for b in t30_buffer_lst])

    t3_300_agg_sdf = sedona.sql(f"""
    SELECT {geo_level}, {', '.join([f"ROUND(AVG(tree_count_{buffer}m), 2) as tree_count_{buffer}m" for buffer in t3_buffer_lst])},
    {t30_building_aggs},
    ROUND(AVG(distance_manhattan), 2) as park_distance_manhattan, ROUND(AVG(distance_euclidean), 2) as park_distance_euclidean,
    ROUND(AVG(distance_water), 2) as water_distance
    FROM t3_300_boundaries
    GROUP BY {geo_level}
    """)

    t3_300_agg_sdf.createOrReplaceTempView("t3_300_agg")

    return t3_300_agg_sdf

def merge_all(sedona: SparkSession, geo_level: str) -> DataFrame:
    """
    Merges all the dataframes.
    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
    Returns:
        DataFrame: The merged dataframe.
    """
    
    logging.debug("Merging T3, T30, T300, Spectral dataframes")

    t3_30_300_spectral_sdf = sedona.sql(f"""
    SELECT t3_300_agg.*, ts.canopy_cover, ROUND(ts.NDBI, 2) as NDBI, ROUND(ts.NDVI, 2) as NDVI, ROUND(ts.NDWI, 2) as NDWI, tca.total_trees
    FROM t3_300_agg
    JOIN t30_spectral ts ON t3_300_agg.{geo_level} = ts.{geo_level}
    JOIN tree_count_agg tca ON t3_300_agg.{geo_level} = tca.{geo_level}
    """)
    t3_30_300_spectral_sdf.createOrReplaceTempView("t3_30_300_spectral")

    return t3_30_300_spectral_sdf

def process_data(sedona: SparkSession, geo_level: str="LSOA21CD", sub_geo_level: str="OA21CD",
                 t3_buffer_lst: list[int]=[10, 25, 50, 75, 100],
                 t30_buffer_lst: list[int]=[100, 200, 300]) -> pd.DataFrame:
    """
    Processes the data.
    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
        sub_geo_level (str): The sub geo level.
        t3_buffer_lst (list[int]): Buffer sizes for T3 tree-count data.
        t30_buffer_lst (list[int]): Buffer sizes for per-building T30 canopy-cover data.
    Returns:
        pd.DataFrame: The processed dataframe.
    """

    logging.info("Starting data processing pipeline")

    # Step 1: Read parquet files
    sdf_dict = read_parquet_files(sedona, t3_buffer_lst, t30_buffer_lst)

    # Step 2: Aggregate T30 data
    t30_agg_sdf = aggregate_t30(sedona, geo_level)

    # Step 3: Aggregate tree count data
    tree_count_agg_sdf = aggregate_tree_count(sedona, geo_level, sub_geo_level)

    # Step 4: Merge T30 and spectral data
    t30_spectral_sdf = merge_t30_and_spectral(sedona, geo_level)

    # Step 5: Merge T3, T300, and per-building T30 data
    t3_300_sdf = merge_t3_and_t300(sedona, t3_buffer_lst, t30_buffer_lst)

    # Step 6: Aggregate by boundaries
    t3_300_agg_sdf = aggregate_t3_300_by_boundaries(sedona, geo_level, t3_buffer_lst, t30_buffer_lst)

    # Step 7: Merge all dataframes into the final result
    t3_30_300_spectral_sdf = merge_all(sedona, geo_level)

    t3_30_300_spectral_df = t3_30_300_spectral_sdf.toPandas()

    tree_count_columns = [f'tree_count_{buffer}m' for buffer in t3_buffer_lst]
    building_canopy_columns = [f'canopy_cover_{b}m' for b in t30_buffer_lst]
    t3_30_300_spectral_df[tree_count_columns] = t3_30_300_spectral_df[tree_count_columns].fillna(0)

    columns = ([geo_level, 'total_trees'] + tree_count_columns +
               ['canopy_cover'] + building_canopy_columns +
               ['park_distance_manhattan', 'park_distance_euclidean', 'water_distance', 'NDBI', 'NDVI', 'NDWI'])

    t3_30_300_spectral_df = t3_30_300_spectral_df[columns]

    t3_30_300_spectral_df.to_parquet(t3_30_300_spectral_buildings_parquet, index=False)

    logging.info("Data processing pipeline completed")

    return t3_30_300_spectral_df

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='This script executes the module to calculate the 3-30-300 metric and spectral indexes for all of England.')
    parser.add_argument('--geo_level', type=str, required=False, default='LSOA21CD', choices=['RGN22CD', 'MSOA21CD', 'LAD22CD', 'LSOA21CD'], help='Name/Code of the desired geography')
    parser.add_argument('--sub_geo_level', type=str, required=False, default='OA21CD', choices=['MSOA21CD', 'LAD22CD', 'LSOA21CD', 'OA21CD'], help='Name/Code of the desired geography')
    parser.add_argument('--log_level', type=str, required=False, default='INFO', help='Logging level')

    args = parser.parse_args()

    args_dict = vars(args)

    buffer_lst = [10, 25, 50, 75, 100]
    t30_buffer_lst = [100, 200, 300]
    log_path = Path(f"logs/T3_30_300_spectral_processing.log")
    setup_logger(log_path=log_path, log_level=args_dict['log_level'])

    sedona = get_spark()
    merge_output_csv(sedona, buffer_lst, t30_buffer_lst)
    process_data(sedona, args_dict['geo_level'], args_dict['sub_geo_level'], buffer_lst, t30_buffer_lst)