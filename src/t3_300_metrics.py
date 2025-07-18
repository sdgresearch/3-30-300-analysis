"""
Module: src/t3_300_metrics.py
Description: Functions for processing the T3_300 metrics at building level.
Author: Andrés C. Zúñiga-González
Date: 2025-07-16
"""

from utils.paths import t3_300_metrics_parquet, t3_300_parquet

import numpy as np
import pandas as pd
from scipy.optimize import curve_fit
from pyspark.sql.session import SparkSession
from pyspark.sql.functions import udf, col 
from pyspark.sql.functions import round as spark_round
from pyspark.sql.types import DoubleType

# Define a UDF to calculate the slope of the exponential regression
def calculate_slope(*tree_counts):
    """
    Calculates the slope of the exponential regression using the different buffer sizes.
    Args:
        tree_counts (list): The list of tree counts.
    Returns:
        float: The slope of the exponential regression.
    """

    # Extract x values from the column names
    x_values = np.array([0, 10, 25, 50, 75, 100])  # Corresponding to tree_count_10m, tree_count_25m, etc.
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

def process_data(sedona: SparkSession) -> pd.DataFrame:
    """
    Processes the data using Spark operations.
    Args:
        sedona (SparkSession): The Spark session.
    Returns:
        pd.DataFrame: The processed dataframe.
    """

    t3_300_sdf = sedona.read.format("parquet").load(str(t3_300_parquet))
    t3_300_sdf.createOrReplaceTempView('t3_300')
    tree_count_columns = ["tree_count_10m", "tree_count_25m", "tree_count_50m", "tree_count_75m", "tree_count_100m"]
    t3_300_sdf = t3_300_sdf.fillna({col: 0 for col in tree_count_columns})

    # Register the UDF
    slope_udf = udf(calculate_slope, DoubleType())

    # Apply the UDF to calculate the slope
    t3_300_new_sdf = t3_300_sdf.withColumn(
        "tree_count_slope",
        slope_udf(
            col("tree_count_10m"),
            col("tree_count_25m"),
            col("tree_count_50m"),
            col("tree_count_75m"),
            col("tree_count_100m")
        )
    )

    # Add columns for ratio and difference
    t3_300_new_sdf = t3_300_new_sdf.withColumn(
        "park_distance_ratio",
        spark_round(col("distance_manhattan") / col("distance_euclidean"), 3)
    ).withColumn(
        "park_distance_diff",
        spark_round(col("distance_manhattan") - col("distance_euclidean"), 1)
    )
    t3_300_new_df = t3_300_new_sdf.toPandas()

    t3_300_new_df.to_parquet(str(t3_300_metrics_parquet), index=False)