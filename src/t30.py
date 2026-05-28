
from utils.paths import T30_dir, T30_buildings_dir
from utils.constants import PROJECT_CRS
from utils.data_processing import generate_tile_paths, get_geometries, filter_buffer_geometries

import time
import logging
import numpy as np
import pandas as pd
import geopandas as gpd
import xarray as xr
import rioxarray as rxr
from rioxarray.merge import merge_arrays
from rasterstats import zonal_stats
from pyspark.sql.session import SparkSession
from sedona.utils.adapter import Adapter
from sedona.core.enums import GridType, IndexType

def binarise_tiles(vom_paths_lst: list, low_threshold: float, high_threshold: float) -> xr.DataArray:
    """
    Binarise the canopy height model (CHM) tiles based on given thresholds.

    This function reads a list of CHM files, merges them into a single xarray DataArray,
    and then binarises the merged array based on the provided low and high thresholds.
    The resulting binary array will have values of 1 where the CHM values are within the
    specified range, and 0 otherwise.

    Args:
        selected_chm_path_lst (list): List of file paths to the CHM tiles to be processed.
        low_threshold (float): The lower threshold for binarisation.
        high_threshold (float): The upper threshold for binarisation.

    Returns:
        xr.DataArray: A binary xarray DataArray where values are 1 if within the threshold range, and 0 otherwise.
    """

    logging.info(f"Binarising {len(vom_paths_lst)} VOM tiles")

    chm_xr_lst = []
    for file in vom_paths_lst:
        try:
            temp_rast = rxr.open_rasterio(file)
            temp_rast.values
            chm_xr_lst.append(temp_rast)
            
        except Exception as e:
            logging.error(f"Error reading file: {file} - {e}")
    merged_chm_xr = merge_arrays(chm_xr_lst)

    binary_merged_chm_xr = (merged_chm_xr >= low_threshold) & (merged_chm_xr <= high_threshold)
    binary_merged_chm_xr = binary_merged_chm_xr.astype(int).fillna(0)

    return binary_merged_chm_xr

def get_canopy_cover(subgeo_filt_gdf: gpd.GeoDataFrame, binary_merged_chm_xr: xr.DataArray) -> pd.DataFrame:
    """
    Calculate the canopy cover percentage for each geometry in the given GeoDataFrame.

    Args:
        subgeo_filt_gdf (gpd.GeoDataFrame): A GeoDataFrame containing the geometries for which the canopy cover is to be calculated.
        binary_merged_chm_xr (xr.DataArray): A DataArray containing binary canopy height model data.

    Returns:
        pd.DataFrame: A DataFrame containing the original geometries and their corresponding canopy cover percentages.
    """

    logging.debug("Calculating canopy cover")

    zs_categorical = zonal_stats(subgeo_filt_gdf, binary_merged_chm_xr[0].values, 
                                affine=binary_merged_chm_xr.rio.transform(), categorical=True)

    # subgeo_filt_gdf['canopy_cover'] = [round(100 * z.get(1, 0) / (z.get(0, 0) + z.get(1, 0)), 3) for z in zs_categorical]
    subgeo_filt_gdf['canopy_cover'] = [round(100 * z.get(1, 0) / sum(z.values()), 3) if z else np.nan for z in zs_categorical]
    subgeo_filt_gdf['total_pixels'] = [z.get(0, 0) + z.get(1, 0) for z in zs_categorical]

    geo_canopy_cover_df = subgeo_filt_gdf.copy()
    
    return geo_canopy_cover_df

def get_canopy_cover_buildings(sedona: SparkSession, vom_paths_lst: list, geo_code: str,
                               low_threshold: float=3, high_threshold: float=60) -> pd.DataFrame:
    """
    Calculate per-building canopy cover using Sedona RS_ZonalStats.

    Requires 'buildings_buffers' Sedona temp view to be registered before calling
    (done by filter_buffer_geometries()). All tiles are binarized and loaded into a
    single multi-row Sedona DataFrame so Spark distributes the full (building x tile)
    join across all workers in one job. VOM tiles are non-overlapping, so SUM across
    tiles correctly assembles pixel counts for buildings whose buffers span a boundary.

    Args:
        sedona (SparkSession): The Spark session.
        vom_paths_lst (list): List of VOM CHM tile paths to process.
        low_threshold (float): Lower height threshold for tree classification.
        high_threshold (float): Upper height threshold for tree classification.

    Returns:
        pd.DataFrame: verisk_premise_id, tree_pixels, total_pixels, canopy_cover.
    """

    logging.debug(f"Loading {len(vom_paths_lst)} raw VOM tiles into Sedona")

    raster_sdf = (
        sedona.read.format("binaryFile")
        .load(vom_paths_lst)
        .selectExpr("RS_FromGeoTiff(content) AS raster")
    )
    raster_sdf.createOrReplaceTempView(f"raw_tiles_{geo_code}")

    # Tile-explode large rasters into 512×512 chunks, then binarize in-SQL:
    # pixels with CHM height in [low_threshold, high_threshold] → 1.0 (tree), else → 0.0
    binary_sdf = sedona.sql(f"""
        SELECT RS_MapAlgebra(tile, 'D',
            'out = (rast[0] >= {low_threshold} && rast[0] <= {high_threshold}) ? 1.0 : 0.0;') AS tile
        FROM (
            SELECT RS_TileExplode(raster, 512, 512) AS (x_idx, y_idx, tile)
            FROM raw_tiles_{geo_code}
        )
    """)
    binary_sdf.createOrReplaceTempView(f"binary_tiles_{geo_code}")

    buildings_sdf = sedona.sql(
        f"SELECT verisk_premise_id, ST_SetSRID(geometry, 27700) AS geometry FROM buildings_buffers_{geo_code}"
    )
    buildings_rdd = Adapter.toSpatialRdd(buildings_sdf, 'geometry')
    buildings_rdd.analyze()
    buildings_rdd.spatialPartitioning(GridType.KDBTREE)
    buildings_rdd.buildIndex(IndexType.QUADTREE, True)
    buildings_partitioned_sdf = Adapter.toDf(buildings_rdd, ['verisk_premise_id'], sedona)
    # Adapter.toDf() strips SRID; re-apply so RS_Intersects matches the raster's EPSG:27700
    buildings_partitioned_sdf = buildings_partitioned_sdf.selectExpr(
        "verisk_premise_id",
        "ST_SetSRID(geometry, 27700) AS geometry"
    )
    buildings_partitioned_sdf.createOrReplaceTempView(f"buildings_partitioned_{geo_code}")

    # On the binary raster: 'sum' = tree pixels (1.0 values), 'count' = all valid pixels.
    # SUM() across tiles is correct because VOM tiles are non-overlapping.
    result_sdf = sedona.sql(f"""
        SELECT
            b.verisk_premise_id,
            SUM(RS_ZonalStats(bt.tile, b.geometry, 1, 'sum',   true)) AS tree_pixels,
            SUM(RS_ZonalStats(bt.tile, b.geometry, 1, 'count', true)) AS total_pixels
        FROM buildings_partitioned_{geo_code} b, binary_tiles_{geo_code} bt
        WHERE RS_Intersects(bt.tile, b.geometry)
        GROUP BY b.verisk_premise_id
    """)

    result_df = result_sdf.toPandas()
    logging.debug(f"RS_ZonalStats returned {len(result_df)} buildings before filtering")

    if result_df.empty:
        return pd.DataFrame(columns=['verisk_premise_id', 'tree_pixels', 'total_pixels', 'canopy_cover'])

    # Drop buildings where the geometry fell entirely in NoData regions of the raster
    # (total_pixels is NULL/0 = no usable VOM data, treat same as missing tile)
    result_df = result_df[result_df['total_pixels'] > 0].copy()
    result_df['tree_pixels'] = result_df['tree_pixels'].fillna(0)
    result_df['canopy_cover'] = (100.0 * result_df['tree_pixels'] / result_df['total_pixels']).round(3)

    logging.debug(f"{len(result_df)} buildings retained after filtering out no-data geometries")
    return result_df


def process_geo_code(sedona: SparkSession, geo_level: str, geo_code: str, output_areas_os_tile_overlay_df: pd.DataFrame,
                     vom_raster_paths_df: pd.DataFrame, tree_vector_paths_df: pd.DataFrame,
                     low_threshold: int=3, high_threshold: int=60,
                     per_building: bool=False, buffer: int=50, overwrite: bool=True) -> pd.DataFrame:
    """
    Processes a given geo_code for T30.

    Args:
        sedona (SparkSession): The Spark session.
        geo_level (str): The geo level.
        geo_code (str): The geo code.
        output_areas_os_tile_overlay_df (pd.DataFrame): The output areas OS tile overlay dataframe.
        vom_raster_paths_df (pd.DataFrame): The VOM raster paths dataframe.
        tree_vector_paths_df (pd.DataFrame): The tree vector paths dataframe.
        low_threshold (int): The low threshold for binarisation.
        high_threshold (int): The high threshold for binarisation.
        per_building (bool): Whether to calculate canopy cover per building instead of per geography.
        buffer (int): Buffer radius in metres around each building (used when per_building=True).
        overwrite (bool): Whether to overwrite the existing file.

    Returns:
        pd.DataFrame: The canopy cover dataframe.
    """

    start_time = time.time()
    logging.info(f"Processing data for {geo_code}")

    if per_building:
        geo_canopy_cover_path = T30_buildings_dir / f"T30_buildings_{geo_code}_{buffer}m.csv"
    else:
        geo_canopy_cover_path = T30_dir / f"T30_{geo_code}.csv"

    if not geo_canopy_cover_path.exists() or overwrite:
        try:
            geo_tiles_df = generate_tile_paths(geo_level, geo_code, output_areas_os_tile_overlay_df, vom_raster_paths_df, tree_vector_paths_df)
            vom_paths_lst = geo_tiles_df.groupby('TILE_NAME').first().reset_index()['path_vom'].tolist()

            if per_building:
                get_geometries(sedona, geo_level, geo_code, True)
                filter_buffer_geometries(sedona, geo_level, geo_code, 'buildings', buffer)

                geo_canopy_cover_df = get_canopy_cover_buildings(sedona, vom_paths_lst, geo_code, low_threshold, high_threshold)
                geo_canopy_cover_df.to_csv(geo_canopy_cover_path, index=False)

            else:
                binary_merged_chm_xr = binarise_tiles(vom_paths_lst, low_threshold, high_threshold)
                geo_boundary_sdf = get_geometries(sedona, geo_level, geo_code, False)
                geo_boundary_gdf = gpd.GeoDataFrame(geo_boundary_sdf.toPandas(), geometry='geometry', crs=PROJECT_CRS)
                geo_canopy_cover_df = get_canopy_cover(geo_boundary_gdf, binary_merged_chm_xr)
                geo_canopy_cover_df = geo_canopy_cover_df[['OA21CD', 'LSOA21CD', 'MSOA21CD', 'LAD22CD', 'RGN22CD', 'canopy_cover', 'total_pixels']]
                geo_canopy_cover_df.to_csv(geo_canopy_cover_path, index=False)

            end_time = time.time()
            logging.info(f"Processing for {geo_code} with {len(geo_canopy_cover_df)} records took {end_time - start_time:.2f} seconds")

            return geo_canopy_cover_df

        except Exception as e:
            logging.error(f"Error processing {geo_code}: {e}")