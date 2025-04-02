#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: train_model.py
Description: Trains a machine learning model using scikit-learn.
Author: Your Name
Date: YYYY-MM-DD
"""
from src.tables_setup import load_tables
from src.utils.logging_config import setup_logger
from src.utils.sedona_config import get_spark
from t3 import process_geo_code as process_geo_code_t3
from t30 import process_geo_code as process_geo_code_t30
from t300 import process_geo_code as process_geo_code_t300

import argparse, logging, inspect, concurrent.futures
from pathlib import Path
from tqdm import tqdm

def main(process, args_dict):

    # Define required arguments per process
    process_args = {
        "T3": inspect.signature(process_geo_code_t3).parameters.values(),
        "T30": inspect.signature(process_geo_code_t30).parameters.values(),
        "T300": inspect.signature(process_geo_code_t300).parameters.values(),
        "Spectral": ["geo_level", "geo_code", "log_level"]
    }

    if process not in process_args:
        raise ValueError(f"Unknown process: {process}")

    # Filter only required arguments
    filtered_args = {k: v for k, v in args_dict.items() if k in process_args[process]}

    # Call the appropriate function with filtered arguments
    if process == "T3":
        process_geo_code_t3(**filtered_args)
    elif process == "T30":
        process_geo_code_t30(**filtered_args)
    elif process == "T300":
        process_geo_code_t300(**filtered_args)
    elif process == "Spectral":
        process_spectral(**filtered_args)

if __name__ == "__main__":                     

    parser = argparse.ArgumentParser(description='This script calculates the tree count (3) for all buildings in a given geographical level (i.e. LSOA or LAD)')
    parser.add_argument('--process', type=str, required=True, choices=['T3', 'T30', 'T300', 'Spectral'], help='Name of the component of the module to run')
    parser.add_argument('--geo_level', type=str, required=False, default='LAD22CD', help='Name/Code of the desired geography')
    parser.add_argument('--geo_code', type=str, required=False, help='Geographical variable name')
    parser.add_argument('--tile_level', type=str, required=False, default='TILE_NAME_50KM', help='Name/Code of the desired geography')
    parser.add_argument('--query_method', type=str, required=False, default='rdd', choices=['sql', 'rdd'], help='Type of data to use with Apache Sedona')
    parser.add_argument('--parallel', action='store_true', help='Run job in parallel')
    parser.add_argument('--n_workers', type=int, required=False, default=2, help='Number of workers')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')
    parser.add_argument('--buffer', type=int, required=False, default=100, help='Buffer size in meters')
    parser.add_argument('--tree_area', type=int, required=False, default=10, help='Tree area in square meters')
    parser.add_argument('--tree_height', type=int, required=False, default=3, help='Tree height in meters')

    args = parser.parse_args()

    args_dict = vars(args)

    log_path = Path(f"logs/{args_dict['process']}_processing.log")
    setup_logger(log_path=log_path, log_level=args_dict.log_level)

    tables = load_tables()

    sedona = get_spark()
    
    args_dict['sedona'] = sedona
    args_dict['output_areas_boundaries_gdf'] = tables.output_areas_boundaries_gdf
    args_dict['os_tile_boundaries_gdf'] = tables.os_tile_boundaries_gdf
    # vom_tree_pair_dict - T3

    if args_dict.geo_code:
        geo_level_codes = [args_dict.geo_code]

    else:
        geo_level_codes = tables.output_areas_boundaries_gdf[args_dict.geo_level].unique()
        
    if args_dict.parallel:
        logging.debug("Running in parallel")

        with concurrent.futures.ThreadPoolExecutor(max_workers=args_dict.n_workers) as executor:
            futures = [executor.submit(main, args_dict['process'], args_dict) for geo_code in geo_level_codes]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc=f'{args_dict.geo_level} regions processed'):
                future.result()                

    else:
        logging.debug("Running sequentially")

        for geo_code in tqdm(geo_level_codes, desc=f'{args_dict.geo_level} regions processed'):   
            main(args_dict['process'], args_dict)
