#!/usr/bin/env python3
"""
Script: vom_trees_helper.py
Description: Consolidates the per-tile VOM tree geopackages in trees_unique_dir
    into a single centroided geoparquet dataset (WGS84) for the web app.
Author: Andrés C. Zúñiga-González
"""
from utils.constants import PROJECT_CRS
from utils.paths import trees_unique_dir, T3_30_300_DIR

from utils.sedona_config import get_spark

from pyspark.sql.functions import monotonically_increasing_id

if __name__ == '__main__':

    sedona = get_spark()

    # Save files as geoparquet in WGS84 projection and centroided
    trees_sdf = sedona.read.format("geopackage").option("tableName", "trees").load(str(trees_unique_dir))
    trees_sdf.createOrReplaceTempView("trees")

    trees_sdf = sedona.sql(f"""SELECT treeID, height, area, ST_Transform(ST_Centroid(geom), "{PROJECT_CRS}", "EPSG:4326") AS geometry FROM trees""")
    trees_sdf = trees_sdf.withColumn("treeID", monotonically_increasing_id())

    trees_sdf.coalesce(50).write.format("geoparquet").save(str(T3_30_300_DIR / "App_files" / "Trees"))
