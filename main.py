import os
from scripts.constants import *
from pathlib import Path
from tqdm import tqdm
from scripts.raster_operations import *
from scripts.vector_operations import *

if __name__ == "__main__":
    pass

    ## Process the building height data
    ## Dissolve adjacent polygons per tile in the grid and summarize their statistics
    # MASK_DIR = DATA_DIR / "vector"
    # uk_building_height_dir = MASK_DIR / "UK_building_height/gdb/"

    # input_vector_dirs = [dir for dir in uk_building_height_dir.glob('*/') if dir.is_dir]

    # for tile_dir in tqdm(input_vector_dirs, desc='UK'):
    #     # print(tile_dir.stem)
    #     tile_ouput_dir_name = MASK_DIR / "UK_building_height_dissolved" / tile_dir.stem
    #     tile_ouput_dir_name.mkdir(parents=True)

    #     tiles_dirs = [dir for dir in tile_dir.glob('*/') if dir.is_dir]

    #     for small_tile in tqdm(tiles_dirs, desc='Tile'):
    #         # print(small_tile.stem)

    #         out_name = tile_ouput_dir_name / f'{small_tile.stem}_dissolved.gpkg'

    #         geodatatable_path = [x for x in small_tile.glob("*9.gdbtable")][0]

    #         dissolve_adjacent(geodatatable_path, out_name)
