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
    """
    Filters various GeoDataFrames by performing spatial joins with a given geographic boundary.
    Parameters:
        road_nodes_gdf (gpd.GeoDataFrame): GeoDataFrame containing road nodes.
        road_edges_gdf (gpd.GeoDataFrame): GeoDataFrame containing road edges.
        public_park_site_gdf (gpd.GeoDataFrame): GeoDataFrame containing public park sites.
        public_park_access_gdf (gpd.GeoDataFrame): GeoDataFrame containing public park access points.
        buildings_gdf (gpd.GeoDataFrame): GeoDataFrame containing building information.
        geo_boundary_gdf (gpd.GeoDataFrame): GeoDataFrame containing the geographic boundary for filtering.
    Returns:
        dict: A dictionary containing filtered GeoDataFrames with the following keys:
            - 'nodes': Filtered road nodes GeoDataFrame.
            - 'edges': Filtered road edges GeoDataFrame.
            - 'public_park_sites': Filtered public park sites GeoDataFrame.
            - 'public_park_access': Filtered public park access points GeoDataFrame.
            - 'buildings': Filtered buildings GeoDataFrame.
    """
    
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
    """
    Calculate the closest park access point for each building in the given GeoDataFrame.
    Parameters:
        geo_graph (nx.MultiGraph): A graph representing the road network.
        geo_buildings_gdf (gpd.GeoDataFrame): A GeoDataFrame containing building information, including the nearest road node.
        geo_public_park_access_gdf (gpd.GeoDataFrame): A GeoDataFrame containing public park access points, including the nearest road node.
    Returns:
        pd.DataFrame: A DataFrame with columns 'verisk_premise_id', 'closest_park_access_id', and 'distance', representing the building ID, the closest park access point ID, and the distance to the closest park access point, respectively.
    """

    logging.debug(f"Getting closest park (n: {len(geo_public_park_access_gdf)}) to each building (n: {len(geo_buildings_gdf)})")

    park_access_nodes = geo_public_park_access_gdf['nearest_road_node'].unique()
    shortest_paths = {}
    for park_access_node in park_access_nodes:
        lengths = nx.single_source_dijkstra_path_length(geo_graph, park_access_node, weight='length')
        shortest_paths[park_access_node] = lengths

    # Create a list to store the distances
    distances = []

    # Iterate over each building
    for building in tqdm(geo_buildings_gdf.itertuples(), desc='Buildings processed'):
        building_node = building.nearest_road_node
        building_id = building.Index
        min_distance = float('inf')
        closest_park_access_id = None

        # Iterate over each park access point
        for park_access in geo_public_park_access_gdf.itertuples():
            park_access_node = park_access.nearest_road_node

            # Lookup the precomputed shortest path distance
            try:
                distance = shortest_paths[park_access_node][building_node]
                if distance < min_distance:
                    min_distance = distance
                    closest_park_access_id = park_access.id
            except KeyError:
                continue

        distances.append((building_id, closest_park_access_id, min_distance))

    # Convert the distances to a DataFrame
    distances_df = pd.DataFrame(distances, columns=['verisk_premise_id', 'closest_park_access_id', 'distance'])

    return distances_df

def process_geo_code(geo_code: str, geo_level: str, imd_lsoa_bua_gdf: gpd.GeoDataFrame, road_nodes_gdf: gpd.GeoDataFrame, 
                     road_edges_gdf: gpd.GeoDataFrame, public_park_site_gdf: gpd.GeoDataFrame,
                      public_park_access_gdf: gpd.GeoDataFrame, buildings_gdf: gpd.GeoDataFrame) -> None:
    """
    Processes geographical data for a given geo_code and geo_level, calculates the distance from buildings to the nearest park,
    and saves the results to a CSV file.
    Parameters:
        geo_code (str): The geographical code to process.
        geo_level (str): The geographical level (e.g., LSOA, BUA) to process.
        imd_lsoa_bua_gdf (gpd.GeoDataFrame): GeoDataFrame containing the geographical boundaries.
        road_nodes_gdf (gpd.GeoDataFrame): GeoDataFrame containing the road nodes.
        road_edges_gdf (gpd.GeoDataFrame): GeoDataFrame containing the road edges.
        public_park_site_gdf (gpd.GeoDataFrame): GeoDataFrame containing the public park sites.
        public_park_access_gdf (gpd.GeoDataFrame): GeoDataFrame containing the public park access points.
        buildings_gdf (gpd.GeoDataFrame): GeoDataFrame containing the buildings.
    Returns:
        None
    """
    
    start_time = time.time()
    
    T300_dir = VECTOR_OUT_DIR / "3-30-300" / "T300"
    T300_dir.mkdir(parents=True, exist_ok=True)
    geo_building_park_distance_path = T300_dir / f"T300_{geo_code}.csv"

    geo_boundary_gdf = imd_lsoa_bua_gdf[imd_lsoa_bua_gdf[geo_level] == geo_code].dissolve()[['geometry', geo_level]]

    geo_road_nodes_gdf, geo_road_edges_gdf, _, geo_public_park_access_gdf, geo_buildings_gdf = filter_features(road_nodes_gdf, road_edges_gdf, public_park_site_gdf, public_park_access_gdf, buildings_gdf, geo_boundary_gdf).values()

    logging.info(f"Generating graph for {geo_code}")

    geo_graph = ox.graph_from_gdfs(geo_road_nodes_gdf, geo_road_edges_gdf).to_undirected()

    geo_public_park_access_gdf['nearest_road_node'] = ox.distance.nearest_nodes(geo_graph, geo_public_park_access_gdf.geometry.centroid.x, geo_public_park_access_gdf.geometry.centroid.y)
    geo_buildings_gdf['nearest_road_node'] = ox.distance.nearest_nodes(geo_graph, geo_buildings_gdf.geometry.centroid.x, geo_buildings_gdf.geometry.centroid.y)

    geo_building_park_distance_df = get_closest_park(geo_graph, geo_buildings_gdf, geo_public_park_access_gdf)

    logging.info(f"Saving file for {geo_code} with {len(geo_building_park_distance_df)} records")

    geo_building_park_distance_df.to_csv(geo_building_park_distance_path, index=False)

    end_time = time.time()
    logging.info(f"Processing for {geo_code} took {end_time - start_time:.2f} seconds")

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
    logging.info("Calculating the 300 metric for all buildings")
    logging.debug("Reading files")

    imd_lsoa_bua_gdf = gpd.read_file(imd_lsoa_bua_boundaries_path).sort_values(by=geo_level)
    geo_level_codes = imd_lsoa_bua_gdf[geo_level].unique()

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
                                       buildings_gdf) for geo_code in geo_level_codes]
            
            for future in tqdm(concurrent.futures.as_completed(futures), total=len(futures), desc="Regions processed"):
                try:
                    future.result()                
                except Exception as e:
                    logging.error(f"Error processing: {e}")

    else:
        logging.debug("Running sequentially")

        for geo_code in tqdm(geo_level_codes, desc='Regions processed'):   
            process_geo_code(geo_code, geo_level, imd_lsoa_bua_gdf, road_nodes_gdf, road_edges_gdf, public_park_site_gdf, public_park_access_gdf, buildings_gdf)
            