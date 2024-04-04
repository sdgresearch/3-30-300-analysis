import os
from dotenv import load_dotenv
from pathlib import Path
from scripts.raster_operations import *

if __name__ == "__main__":

    load_dotenv()  # take environment variables from .env.

    DATA_FOLDER = Path(os.getenv("DATA_FOLDER")) 
    IMAGERY_FOLDER = DATA_FOLDER / "imagery" 
    MASK_FOLDER = DATA_FOLDER / "geopackages"
    uk_planet_folder = IMAGERY_FOLDER / "UK_planet_height"

    input_rasters = list(uk_planet_folder.glob('*.tif'))
    # uk_planet_tif = uk_planet_folder / "UK_planet_height.tif"
    # uk_planet_vrt = uk_planet_folder / "UK_planet_height.vrt"
    # uk_planet_clipped_vrt = uk_planet_folder / "UK_planet_height_clipped.vrt"
    # uk_built_up_dissolved_mask = DATA_FOLDER / "geopackages" / "BUA_2022_GB_3186007556224938771_dissolved.gpkg"
    # merge_rasters(input_rasters, output_raster)
    # create_vrt(input_rasters, uk_planet_folder)
    # clip_by_mask(uk_planet_vrt, uk_built_up_dissolved_mask, uk_planet_clipped_vrt)

    # Example usage
    mask_path = MASK_FOLDER / "BUA_2022_GB_3186007556224938771_dissolved.gpkg"
    min_val, max_val = 3, 70 # Example value range
    field_name = 'height'

    for i, raster_path in enumerate(input_rasters):
        print(i)
        out_name = raster_path.stem + "_processed"
            
        output_path = IMAGERY_FOLDER / "UK_planet_height_dissolved" / f"{out_name}_masked.tif"
        vector_path = MASK_FOLDER / "UK_planet_height_dissolved" / f"{out_name}_dissolved.gpkg"
        
        # clip_and_mask_raster(raster_path, mask_path, output_path, min_val, max_val)

        vectorise_raster(output_path, vector_path, field_name)

