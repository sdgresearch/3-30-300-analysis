import os
import subprocess
from osgeo import gdal
import rasterio
import numpy as np
import geopandas as gpd
import rioxarray as rxr
from rasterio.features import shapes
from shapely.geometry import box, shape
from geocube.vector import vectorize
from rasterio.mask import mask

def merge_rasters(input_rasters, output_raster):
    # Use gdal_merge utility; adjust options as needed
    options = gdal.WarpOptions(format='GTiff')
    out_ds = gdal.Warp(output_raster, input_rasters, options=options)
    
    if out_ds is None:
        print("Could not create merged raster")
        return
    
    out_ds = None  # Close the dataset
    print(f"Merged raster saved as {output_raster}")

def create_vrt(input_rasters, output_vrt, output_raster=None, band_number=1):

    # Create VRT
    vrt_options = gdal.BuildVRTOptions(resampleAlg='nearest', addAlpha=False)#True, bandList=[band_number] * len(input_rasters))
    vrt = gdal.BuildVRT(output_vrt, input_rasters, options=vrt_options)
    vrt = None  # Close the VRT
    if output_raster:
        # Optionally, convert VRT to a physical file if needed
        gdal.Translate(output_raster, output_vrt, format='GTiff')

def binarize_vrt(input_vrt_path, output_vrt_path, min_val, max_val):

    # Open the input raster using Rasterio
    with rasterio.open(input_vrt_path) as src:
        data = src.read(1)  # Assuming you want to modify the first band
        profile = src.profile

        # Set pixels outside the range to np.nan (or another no-data value defined in your profile)
        data[(data < min_val) | (data > max_val)] = np.nan
        data[(data > min_val) & (data < max_val)] = 1

    # Use GDAL to create a VRT that references the modified raster
    vrt_options = gdal.BuildVRTOptions(outputType=gdal.GDT_Int16)
    gdal.BuildVRT(output_vrt_path, output_vrt_path, options=vrt_options)

def clip_by_mask(input_vrt_path, mask_layer_path, output_vrt_path):

    # Build the gdalwarp command
    command = [
        'gdalwarp',
        '-of', 'VRT',  # Output format
        '-cutline', mask_layer_path,  # Mask layer
        '-crop_to_cutline',  # Ensures output is cropped to the boundaries of the cutline
        input_vrt_path,  # Input raster
        output_vrt_path  # Output raster
    ]

    # Execute the command
    subprocess.run(command, check=True)

def getFeatures(gdf):
    """Function to parse features from GeoDataFrame in such a manner that rasterio wants them"""
    import json
    return [json.loads(gdf.to_json())['features'][0]['geometry']]


def clip_and_mask_raster(raster_path, vector_mask, output_path, min_val, max_val):
    """
    Clips a raster with a vector mask, masks out values outside the specified range, 
    and saves the output to a new file.

    Parameters:
        raster_path (str): Path to the raster file.
        vector_path (str): Path to the vector mask file.
        output_path (str): Where to save the clipped and masked raster.
        min_val (float): Minimum value to keep.
        max_val (float): Maximum value to keep.
    """
    
    with rasterio.open(raster_path) as src:
        # Ensure the vector mask is in the same CRS as the raster
        vector_mask = vector_mask.to_crs(src.crs)
        
        # Clip the raster using the vector mask
        out_image, out_transform = mask(src, getFeatures(vector_mask), crop=True)
        
        # Retrieve nodata value from the raster metadata
        nodata = src.nodata
        
        # Mask out values outside the specified range
        out_image = np.where(
            (out_image < min_val) | (out_image > max_val),
            nodata,  # Use existing nodata value where condition is True
            out_image  # Keep original values where condition is False
        )
        
        # Prepare metadata for the output file
        out_meta = src.meta.copy()
        out_meta.update({
            "driver": "GTiff",
            "height": out_image.shape[1],
            "width": out_image.shape[2],
            "transform": out_transform
        })
    
    # Write the clipped and masked raster to a new file
    with rasterio.open(output_path, "w", **out_meta) as dest:
        dest.write(out_image)

# def vectorise_raster(raster_path, vector_path, field_name, mask_and_scale=True, dissolve=True):

#     raster = rxr.open_rasterio(raster_path, mask_and_scale=mask_and_scale).squeeze()
#     raster.name = field_name
#     vectorised_raster = vectorize(raster)

#     res = vectorised_raster

#     if dissolve:
#         dissolved_raster = vectorised_raster.dissolve()

#         res = dissolved_raster

#     res.to_file(vector_path)

#     return res

def vectorise_raster(raster_data, transform, field_name, crs, dissolve=True):
    # Generate vector shapes from raster
    mask = raster_data != raster_data.min()  # Mask to exclude the background/nodata values
    vector_shapes = shapes(raster_data, mask=mask, transform=transform)

    # Convert the shapes and values to a GeoDataFrame
    records = []
    for geom, value in vector_shapes:
        records.append({
            'geometry': shape(geom),
            field_name: value
        })

    # Convert the shapes and values to a GeoDataFrame
    if records:  # Check if there are any records to avoid creating an empty GeoDataFrame
        gdf = gpd.GeoDataFrame(records, crs=crs)
        gdf.set_geometry('geometry', inplace=True)  # Ensure 'geometry' is the geometry column
        gdf = gdf  # Assign CRS after confirming geometry presence

        # Optional dissolve step
        if dissolve:
            gdf = gdf.dissolve(by=field_name, as_index=False)

        return gdf
    else:
        return None  # Return None if no vector shapes were created