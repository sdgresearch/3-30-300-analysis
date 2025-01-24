import argparse, time

from constants import *
from logging_config import *
from utils import *

import ee, eemont
# import pandas as pd
import geopandas as gpd
from shapely.geometry import shape

# Function to calculate mean NDVI for each feature
def calculate_median_index(image_collection: ee.image.Image, geometries: ee.featurecollection.FeatureCollection, 
                           scale: float=10.0, tile_scale: int=4) -> ee.featurecollection.FeatureCollection:
    """
    Calculate the median index of an image collection over specified geometries.
    Args:
        image_collection (ee.image.Image): The image collection to process.
        geometries (ee.featurecollection.FeatureCollection): The geometries over which to calculate the median index.
        scale (float, optional): The scale in meters at which to perform the reduction. Default is 10.0.
        tile_scale (int, optional): A scaling factor used to reduce aggregation tile size; may help avoid memory errors. Default is 4.
    Returns:
        ee.featurecollection.FeatureCollection: A FeatureCollection containing the median index values for each geometry.
    """

    mean_dict = image_collection.reduceRegions(
        collection=geometries,
        reducer=ee.Reducer.median(), scale=scale, tileScale=tile_scale
    )
    return mean_dict

def calculate_zonal_statistics(imd_lsoa_bua_boundaries_ee: ee.featurecollection.FeatureCollection, iter_span: int=100) -> list:
    """
    Calculate zonal statistics for a given Earth Engine FeatureCollection.
    This function processes the input FeatureCollection in chunks, calculates the median spectral index
    for each chunk, and aggregates the results into a list.
    Args:
        imd_lsoa_bua_boundaries_ee (ee.featurecollection.FeatureCollection): The input FeatureCollection
            containing the geometries for which zonal statistics are to be calculated.
        iter_span (int, optional): The number of features to process in each iteration. Defaults to 100.
    Returns:
        list: A list of dictionaries containing the calculated zonal statistics for each feature.
    """

    start_time = time.time()
    spectral_results_lst = []
    for i in range(0, imd_lsoa_bua_boundaries_ee.size().getInfo(), iter_span):
        limited_geometries = imd_lsoa_bua_boundaries_ee.toList(iter_span, i)
        limited_geometries_fc = ee.FeatureCollection(limited_geometries)
        retry_count = 0
        while retry_count < 3:
            try:
                median_index_features = calculate_median_index(image_collection, limited_geometries_fc)
                median_index_dict = median_index_features.getInfo()['features']
                # temp_features = [row['properties'] for row in median_index_dict]
                spectral_results_lst.extend(median_index_dict)
                break
            except ee.ee_exception.EEException as e:
                logging.warning(f"Attempt {retry_count + 1} failed with error: {e}")
                retry_count += 1
                time.sleep(5)  # Wait before retrying

    end_time = time.time()
    logging.info(f"Calculating spectral zonal statistics took {end_time - start_time:.2f} seconds")

    return spectral_results_lst

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Description of your script.')
    parser.add_argument('--start_date', type=str, required=False, default='2024-01-01', help='Start date for querying remote sensing data')
    parser.add_argument('--end_date', type=str, required=False, default='2025-01-01', help='End date for querying remote sensing data')
    parser.add_argument('--imagery', type=str, required=False, default='COPERNICUS/S2_HARMONIZED', help='Imagery name from GEE')
    parser.add_argument('--cloud_coverage', type=float, required=False, default=10.0, help='Cloud Pixel Percentage')
    parser.add_argument('--indexes', type=str, nargs='+', required=False, default=['NDVI', 'NDWI', 'NDBI'], help='List of indexes to calculate')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')

    args = parser.parse_args()

    start_date = args.start_date
    end_date = args.end_date
    imagery = args.imagery
    cloud_coverage = args.cloud_coverage
    indexes = args.indexes
    log_level = args.log_level

    project_crs = 'EPSG:27700'

    T3_30_300_DIR = VECTOR_OUT_DIR / "3-30-300"
    imd_lsoa_bua_boundaries_ee_path = "projects/ee-phd-thesis/assets/English_IMD_2019_BUA_filtered_boundaries"
    spectral_indexes_path = T3_30_300_DIR / "spectral_indexes.geojson"

    log_path = Path("logs/spectral_indexes_calculation.log")
    setup_logger(log_path=log_path, log_level=log_level)
    logging.info("Calculating spectral indexes for all geographies")

    logging.debug("Initializing GEE")
    ee.Authenticate()
    ee.Initialize(project=GEE_PROJECT_NAME, opt_url='https://earthengine-highvolume.googleapis.com')

    logging.debug("Querying GEE for spectral indexes")
    imd_lsoa_bua_boundaries_ee = ee.FeatureCollection(imd_lsoa_bua_boundaries_ee_path)
    england_boundaries = ee.FeatureCollection("FAO/GAUL/2015/level1") \
        .filter(ee.Filter.eq('ADM1_NAME', 'England'))
    england_geometry = england_boundaries.geometry()

    # Request Sentinel-2 data with low cloud coverage
    image_collection = (ee.ImageCollection(imagery) \
        .filterDate(start_date, end_date) \
        .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', cloud_coverage)) \
        .filterBounds(england_geometry) \
        .spectralIndices(indexes).median() \
        .select(indexes))

    spectral_results_lst = calculate_zonal_statistics(imd_lsoa_bua_boundaries_ee)    
    geometry = [shape(feature['geometry']) for feature in spectral_results_lst]
    properties = [feature['properties'] for feature in spectral_results_lst]

    spectral_index_gdf = gpd.GeoDataFrame(properties, geometry=geometry, crs='EPSG:4326').to_crs(project_crs)
    spectral_index_gdf.to_file(spectral_indexes_path)
    # spectral_results_df = pd.DataFrame(spectral_results_lst)
    # spectral_results_df.to_csv(spectral_indexes_path, index=False)