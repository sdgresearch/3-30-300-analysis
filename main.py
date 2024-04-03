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
    gisa_folder = IMAGERY_FOLDER / "GISA-10m_v01_2016"

    input_rasters = list(uk_planet_folder.glob('*.tif'))
    uk_planet_tif = uk_planet_folder / "UK_planet_height.tif"
    uk_planet_vrt = uk_planet_folder / "UK_planet_height.vrt"
    uk_planet_clipped_vrt = uk_planet_folder / "UK_planet_height_clipped.vrt"
    uk_built_up_dissolved_mask = DATA_FOLDER / "geopackages" / "BUA_2022_GB_3186007556224938771_dissolved.gpkg"
    # merge_rasters(input_rasters, output_raster)
    # create_vrt(input_rasters, uk_planet_folder)
    # clip_by_mask(uk_planet_vrt, uk_built_up_dissolved_mask, uk_planet_clipped_vrt)

    # Example usage
    raster_path = uk_planet_folder / "ps_PSScene4Band_2019_00000_00058_154_265_composite_lshm.tif"
    # vector_path = MASK_FOLDER / "BUA_2022_GB_3186007556224938771_dissolved.gpk"
    vector_path = "/Users/ancazugo/Library/CloudStorage/GoogleDrive-acz25@cam.ac.uk/My Drive/PhD Thesis/data/geopackages/BUA_2022_GB_3186007556224938771_dissolved.gpkg"
    output_path = uk_planet_folder / "clipped_example.tif"
    min_val, max_val = 3, 70 # Example value range

    # Step 1: Read and mask the raster
    raster_array, raster_profile = read_and_mask_raster(raster_path, min_val, max_val)

    # Step 2 & 3: Clip the raster with the vector mask and save
    clip_raster_with_vector(raster_array, raster_profile, vector_path, output_path)

    print("Process completed successfully.")

