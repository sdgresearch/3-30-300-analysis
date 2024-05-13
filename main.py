import os
from pathlib import Path
from tqdm import tqdm
import pandas as pd

from shapely.geometry import box

from scripts.constants import *
from scripts.utils import *
from scripts.raster_operations import *
from scripts.vector_operations import *

if __name__ == "__main__":
    pass

    # IN paths
    bua_path = BUA_IN_DIR / "OS_Open_Built_Up_Areas.gpkg"
    pch_vrt_path = PCH_IN_DIR / "ps_PSScene4Band_2019.vrt"
    pch_paths = list(sorted(PCH_IN_DIR.glob('*.tif')))
    gbg_5km_path = GBG_IN_DIR / "5km_grid_region.shp"
    bhf_paths = list(sorted(BHF_IN_DIR.rglob('*9.gdbtable')))
    ogs_path = OGS_IN_DIR / "GB_GreenspaceSite.shp"

    # OUT paths
    bua_dissolved_path = BUA_OUT_DIR / "bua_dissolved.geojson"
    pch_masked_dir = PCH_OUT_DIR / "pch_bua_masked"
    pch_masked_dir.mkdir(parents=True, exist_ok=True)
    pch_masked_vrt_path = pch_masked_dir / "ps_PSScene4Band_2019_masked.vrt"
    pch_masked_tile_dir = PCH_OUT_DIR / "pch_bua_masked_gbg_tile"
    pch_masked_r_tile_dir = pch_masked_tile_dir / "raster_tile"
    pch_masked_r_tile_dir.mkdir(parents=True, exist_ok=True)
    pch_masked_v_tile_dir = pch_masked_tile_dir / "vector_tile"
    pch_masked_v_tile_dir.mkdir(parents=True, exist_ok=True)
    bhf_dissolved_tile_dir = BHF_OUT_DIR / "bhf_dissolved_tile"
    bhf_dissolved_tile_dir.mkdir(parents=True, exist_ok=True)
    bhf_distance_tile_dir = BHF_OUT_DIR / "bhf_distance_tile"
    bhf_distance_tile_dir.mkdir(parents=True, exist_ok=True)

    pch_masked_paths = list(sorted(pch_masked_dir.glob('*.tif')))
    print(pch_masked_paths)
    create_vrt(pch_masked_paths, pch_masked_vrt_path)