import json

from constants import *

import ee
# import xee
# import xarray as xr
# import rioxarray as rxr
# import geopandas as gpd
from dask.distributed import Client

# Trigger the authentication flow.
ee.Authenticate()
# Initialize the library.
ee.Initialize(project=GEE_PROJECT_NAME, opt_url='https://earthengine-highvolume.googleapis.com')
client = Client(n_workers=2, threads_per_worker=2, memory_limit='16GB')

england_boundaries = ee.FeatureCollection("FAO/GAUL/2015/level1") \
    .filter(ee.Filter.eq('ADM1_NAME', 'England'))
england_geometry = england_boundaries.geometry()
# Define the date range for the year 2019
start_date = '2023-01-01'
end_date = '2023-12-31'
sentinel2_ee_path = "COPERNICUS/S2"

# Request Sentinel-2 data with low cloud coverage
sentinel2_collection = ee.ImageCollection(sentinel2_ee_path) \
    .filterDate(start_date, end_date) \
    .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 10)) \
    .filterBounds(england_geometry)

def calculate_ndvi(image):
    ndvi = image.normalizedDifference(['B8', 'B4']).rename('NDVI')
    return image.addBands(ndvi)

# Add NDVI band to each image in the collection
sentinel2_with_ndvi = sentinel2_collection.map(calculate_ndvi)

# Function to calculate monthly NDVI
def monthly_ndvi(year, month):
    start_date = ee.Date.fromYMD(year, month, 1)
    end_date = start_date.advance(1, 'month')
    monthly_collection = sentinel2_with_ndvi.filterDate(start_date, end_date)
    monthly_ndvi = monthly_collection.select('NDVI').mean()
    return monthly_ndvi.set('year', year).set('month', month)

# List to store monthly NDVI images
monthly_ndvi_images = []

# Loop through each month of 2019
for month in range(1, 13):
    monthly_ndvi_image = monthly_ndvi(2023, month)
    monthly_ndvi_images.append(monthly_ndvi_image)

# Print the list of monthly NDVI images
print(monthly_ndvi_images)
# Combine monthly NDVI images into a single image with separate bands
combined_ndvi = ee.Image.cat(monthly_ndvi_images).rename(['NDVI_Jan', 'NDVI_Feb', 'NDVI_Mar', 'NDVI_Apr', 'NDVI_May', 'NDVI_Jun', 'NDVI_Jul', 'NDVI_Aug', 'NDVI_Sep', 'NDVI_Oct', 'NDVI_Nov', 'NDVI_Dec'])

imd_lsoa_bua_boundaries_ee = ee.FeatureCollection("projects/ee-phd-thesis/assets/English_IMD_2019_BUA_filtered_boundaries")
# Function to calculate mean NDVI for each feature
def calculate_mean_ndvi(band, geometries):
    mean_dict = combined_ndvi.select(band).reduceRegions(
        collection=geometries,
        reducer=ee.Reducer.mean(), scale=10, tileScale=1
    )
    return mean_dict

# List to store results
all_mean_ndvi_results = []
metadata = []

# Iterate over each band
bands = combined_ndvi.bandNames().getInfo()
for band in bands:
    # Iterate over every 1000 geometries
    for i in range(0, imd_lsoa_bua_boundaries_ee.size().getInfo(), 1000):
        limited_geometries = imd_lsoa_bua_boundaries_ee.toList(1000, i)
        limited_geometries_fc = ee.FeatureCollection(limited_geometries)
        mean_ndvi_features = calculate_mean_ndvi(band, limited_geometries_fc)
        mean_ndvi_dict = mean_ndvi_features.getInfo()
        all_mean_ndvi_results.append(mean_ndvi_dict)
        temp_metadata = {
            'band': band,
            'start': i,
            'end': i + 1000
        }
        metadata.append(temp_metadata)

with open('mean_ndvi_results.json', 'w') as f:
    json.dump(all_mean_ndvi_results, f)

with open('metadata.json', 'w') as f:
    json.dump(metadata, f)