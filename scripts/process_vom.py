import rasterio
from rasterio.merge import merge
from rasterio.io import MemoryFile
import numpy as np
import glob

def merge_tifs(tif_files):
    src_files_to_mosaic = []
    for fp in tif_files:
        src = rasterio.open(fp)
        src_files_to_mosaic.append(src)
    
    mosaic, out_trans = merge(src_files_to_mosaic)
    return mosaic, src.profile

def binarize_array(array, threshold):
    binary_array = np.where(array > threshold, 1, 0)
    return binary_array

def save_vrt(array, profile, output_vrt):
    with MemoryFile() as memfile:
        with memfile.open(**profile) as dataset:
            dataset.write(array)
            dataset.close()
        with open(output_vrt, 'wb') as vrt_file:
            vrt_file.write(memfile.read())

def process_tifs(input_folder, threshold, output_vrt):
    tif_files = glob.glob(f"{input_folder}/*.tif")
    mosaic, profile = merge_tifs(tif_files)
    binary_mosaic = binarize_array(mosaic, threshold)
    
    profile.update(dtype=rasterio.uint8, count=1)
    save_vrt(binary_mosaic, profile, output_vrt)

if __name__ == "__main__":
    input_folder = "/path/to/tif/files"
    threshold = 100  # Example threshold value
    output_vrt = "/path/to/output.vrt"
    
    process_tifs(input_folder, threshold, output_vrt)