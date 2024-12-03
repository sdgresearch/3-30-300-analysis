#!/usr/bin/env python3

import sys, argparse, time, concurrent.futures
# sys.path.append('..')  # Adjust the path as per your directory structure

from constants import *
from logging_config import *

import pandas as pd
import geopandas as gpd
import networkx as nx
import osmnx as ox
from tqdm import tqdm

def filter_features(road_nodes_gdf: gpd.GeoDataFrame, road_edges_gdf: gpd.GeoDataFrame, 
                    public_park_site_gdf: gpd.GeoDataFrame, public_park_access_gdf: gpd.GeoDataFrame, 
                    buildings_gdf: gpd.GeoDataFrame, geo_boundary_gdf: gpd.GeoDataFrame) -> dict:
    
    logging.debug("Filtering GeoDataFrames by spatial join")

    geo_road_edges_gdf = gpd.sjoin(road_edges_gdf, geo_boundary_gdf)\
        .rename(columns={'start_node': 'u', 'end_node': 'v', 'id': 'key'})\
        .set_index(['u', 'v', 'key'])
    geo_road_nodes_gdf = road_nodes_gdf[(road_nodes_gdf['id'].isin(geo_road_edges_gdf.index.get_level_values(0))) | (road_nodes_gdf['id'].isin(geo_road_edges_gdf.index.get_level_values(1)))].set_index('id')

    geo_road_nodes_gdf['x'] = geo_road_nodes_gdf.geometry.x
    geo_road_nodes_gdf['y'] = geo_road_nodes_gdf.geometry.y

    geo_public_park_site_gdf = gpd.sjoin(public_park_site_gdf, geo_boundary_gdf).reset_index(drop=True)
    geo_public_park_access_gdf = gpd.sjoin(public_park_access_gdf, geo_boundary_gdf).reset_index(drop=True)
    geo_buildings_gdf = gpd.sjoin(buildings_gdf, geo_boundary_gdf).set_index(['verisk_premise_id'])

    result_dict = {'nodes': geo_road_nodes_gdf, 
                   'edges': geo_road_edges_gdf, 
                   'public_park_sites': geo_public_park_site_gdf, 
                   'public_park_access': geo_public_park_access_gdf, 
                   'buildings': geo_buildings_gdf}
    
    return result_dict

def get_closest_park(geo_graph: nx.MultiGraph, geo_buildings_gdf: gpd.GeoDataFrame, geo_public_park_access_gdf: gpd.GeoDataFrame) -> pd.DataFrame:

    logging.debug("Getting closest park to each building")

    # Create a list to store the distances
    distances = []

    # Iterate over each building
    for building in geo_buildings_gdf.iloc[:].itertuples():
        building_node = building.nearest_road_node
        building_id = building.Index
        min_distance = float('inf')
        closest_park_access_id = None
        
        # Iterate over each park access point
        for park_access in geo_public_park_access_gdf.itertuples():
            park_access_node = park_access.nearest_road_node
            
            # Calculate the shortest path distance
            try:
                distance = nx.shortest_path_length(geo_graph, source=building_node, target=park_access_node, weight='length')
                
                if distance < min_distance:
                    min_distance = distance
                    closest_park_access_id = park_access.id
            except nx.NetworkXNoPath:

                logging.error(f"Closest park couldn't be calculated for building: {building_id}")
                continue

        distances.append((building_id, closest_park_access_id, min_distance))

    # Convert the distances to a DataFrame
    distances_df = pd.DataFrame(distances, columns=['verisk_premise_id', 'closest_park_access_id', 'distance'])

    return distances_df

def process_geo_code(geo_code: str, geo_level: str, imd_lsoa_bua_gdf: gpd.GeoDataFrame, road_nodes_gdf: gpd.GeoDataFrame, 
                     road_edges_gdf: gpd.GeoDataFrame, public_park_site_gdf: gpd.GeoDataFrame,
                      public_park_access_gdf: gpd.GeoDataFrame, buildings_gdf: gpd.GeoDataFrame) -> None:
    
    start_time = time.time()
    
    T300_dir = VECTOR_OUT_DIR / "3-30-300" / "T300"
    T300_dir.mkdir(parents=True, exist_ok=True)
    geo_building_park_distance_path = T300_dir / f"{geo_code}_T300.csv"

    geo_boundary_gdf = imd_lsoa_bua_gdf[imd_lsoa_bua_gdf[geo_level] == geo_code].dissolve()[['geometry', geo_level]]

    geo_road_nodes_gdf, geo_road_edges_gdf, geo_public_park_site_gdf, geo_public_park_access_gdf, geo_buildings_gdf = filter_features(road_nodes_gdf, road_edges_gdf, public_park_site_gdf, public_park_access_gdf, buildings_gdf, geo_boundary_gdf).values()

    logging.debug(f"Generating graph for {geo_code}")

    geo_graph = ox.graph_from_gdfs(geo_road_nodes_gdf, geo_road_edges_gdf).to_undirected()

    geo_public_park_access_gdf['nearest_road_node'] = ox.distance.nearest_nodes(geo_graph, geo_public_park_access_gdf.geometry.centroid.x, geo_public_park_access_gdf.geometry.centroid.y)
    geo_buildings_gdf['nearest_road_node'] = ox.distance.nearest_nodes(geo_graph, geo_buildings_gdf.geometry.centroid.x, geo_buildings_gdf.geometry.centroid.y)

    geo_building_park_distance_df = get_closest_park(geo_graph, geo_buildings_gdf, geo_public_park_access_gdf)

    geo_building_park_distance_df.to_csv(geo_building_park_distance_path)

    end_time = time.time()
    logging.debug(f"Processing took {end_time - start_time:.2f} seconds")

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Description of your script.')
    parser.add_argument('--geo_level', type=str, required=True, default='LAD22CD', help='Name/Code of the desired geography')
    parser.add_argument('--geo_code', type=str, required=False, default='E07000008', help='Geographical variable name')
    parser.add_argument('--parallel', action='store_true', help='Run job in parallel')
    parser.add_argument('--n_workers', type=int, required=False, default=2, help='Number of workers')
    parser.add_argument('--log_level', type=str, required=False, default='WARNING', help='Logging level')

    args = parser.parse_args()

    geo_level = args.geo_level
    geo_code = args.geo_code
    parallel = args.parallel
    n_workers = args.n_workers
    log_level = args.log_level

    # IN paths
    imd_lsoa_bua_boundaries_path = VECTOR_OUT_DIR / "IMD" / "English_IMD_2019_BUA_filtered_boundaries.geojson"
    green_space_path = VECTOR_IN_DIR / "OS" / "Green_Spaces" / "opgrsp_gb.gpkg"
    roads_path = VECTOR_IN_DIR / "OS" / "Roads" / "oproad_gb.gpkg"
    buildings_path = VECTOR_IN_DIR / "EDINA" / "Buildings_6183" / "edition_17_0_new_format.gpkg"
    buildings_parquet_path = VECTOR_IN_DIR / "EDINA" / "Buildings_6183" / "Buildings_6183.parquet"

    log_path = Path("logs/T300_calculation.log")
    setup_logger(log_path=log_path, log_level=log_level)
    logging.info("Running started")
    logging.debug("Reading files")

    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path)
    
    green_space_access_gdf = gpd.read_file(green_space_path, layer='access_point')
    green_space_site_gdf = gpd.read_file(green_space_path, layer='greenspace_site')
    road_edges_gdf = gpd.read_file(roads_path, layer='road_link')
    road_nodes_gdf = gpd.read_file(roads_path, layer='road_node')

    buildings_columns = ['verisk_building_id', 'verisk_premise_id', 'premise_year', 'premise_use', 'premise_type',
                         'premise_floor_count', 'height', 'building_area', 'distance_building', 'distance_water', 
                         'map_use', 'map_simple_use', 'geometry']
    buildings_gdf = gpd.read_file(buildings_path, layer='edition_17_0_new_format', columns=buildings_columns)

    public_park_site_gdf = green_space_site_gdf.copy()[green_space_site_gdf['function'] == 'Public Park Or Garden']
    public_park_access_gdf = green_space_access_gdf.copy()[green_space_access_gdf['ref_to_greenspace_site'].isin(public_park_site_gdf.id)]

    if parallel:
        logging.debug("Running in parallel")

        with concurrent.futures.ThreadPoolExecutor(max_workers=n_workers) as executor:
            futures = [executor.submit(process_geo_code, geo_code, 
                                       geo_level, imd_lsoa_bua_gdf, 
                                       road_nodes_gdf, road_edges_gdf, 
                                       public_park_site_gdf, public_park_access_gdf, 
                                       buildings_gdf) for geo_code in imd_lsoa_bua_gdf[geo_level].unique()]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions Processed"):
                try:
                    future.result()                
                except Exception as e:
                    logging.error(f"Error processing: {e}")

    else:
        logging.debug("Running sequentially")

        for geo_code in tqdm(imd_lsoa_bua_gdf[geo_level].unique(), desc='Regions Processed'):   
            process_geo_code(geo_code, geo_level, imd_lsoa_bua_gdf, road_nodes_gdf, road_edges_gdf, public_park_site_gdf, public_park_access_gdf, buildings_gdf)
            