#!/usr/bin/env python3
import pandas as pd
import geopandas as gpd

import sys, argparse
sys.path.append('..')  # Adjust the path as per your directory structure

from scripts.constants import *

def pivot_health_data(dataframe: pd.DataFrame) -> pd.DataFrame:

    result_df = dataframe.pivot_table(
         index='lsoa_code', 
         columns='group_code', 
         values=['register', 'list', 'prevalence'], 
         aggfunc='first'
     )
    # Flatten the MultiIndex columns
    result_df.columns = ['_'.join(col).strip() for col in result_df.columns.values]
    result_df.reset_index(inplace=True)

    return result_df

def main():
    parser = argparse.ArgumentParser(description='Description of your script.')
    parser.add_argument('--geog', type=str, required=True, default='London', help='Geographical variable name')
    parser.add_argument('--name', type=str, required=True, default='BUA22NM', help='Name/Code of the desired geography')

    args = parser.parse_args()
    print(args)
    # Your code here
    print(f'param1: {args.geog}')
    print(f'param2: {args.name}')

if __name__ == '__main__':
    main()