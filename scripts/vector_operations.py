import pandas as pd
import geopandas as gpd
from shapely.ops import unary_union, nearest_points

def union_of_layers(vector_layers_paths, output_path):

    # Load the first layer to initialize
    gdf_combined = gpd.read_file(vector_layers_paths[0])

    # Loop through the remaining vector layer paths and union them with the first
    for path in vector_layers_paths[1:]:
        # Load the current layer
        gdf_current = gpd.read_file(path)
        
        # Ensure CRS matches the combined one to avoid mixing geometries from different projections
        if gdf_current.crs != gdf_combined.crs:
            gdf_current = gdf_current.to_crs(gdf_combined.crs)
        
        # Perform the union of geometries
        gdf_combined = gpd.GeoDataFrame(geometry=[unary_union([gdf_combined.geometry.unary_union, gdf_current.geometry.unary_union])], crs=gdf_combined.crs)

    # At this point, gdf_combined contains a single feature representing the union of all input layers
    # You can save this to a new file
    gdf_combined.to_file(output_path, driver='GeoJSON')


def dissolve_adjacent(input_vector, columns=['abshmin', 'absh2', 'abshmax', 'relh2', 'relhmax']):

    # Dissolve all features into a single MultiPolygon (this keeps disjoint features separate)
    # and explode back into separate features
    dissolved = input_vector.dissolve().explode().reset_index(drop=True).drop(columns=columns).drop(columns=['os_topo_toid', 'os_topo_version', 'bha_processdate', 'bha_conf'])

    # Create a spatial join between the original intersection GeoDataFrame and the dissolved one
    # to find which original polygons correspond to which dissolved ones
    joined = gpd.sjoin(input_vector, dissolved, how='left', op='within')

    # Calculate mean, min, and max values for each group of original polygons
    # that are now part of the same dissolved polygon
    aggregated = joined.groupby(joined.index_right)[columns].agg(['mean', 'min', 'max'])

    # Flatten MultiIndex columns resulting from aggregation
    aggregated.columns = ['_'.join(col).strip() for col in aggregated.columns.values]

    # Merge the aggregated values back with the dissolved GeoDataFrame
    dissolved_with_aggregates = dissolved.join(aggregated, how='left')

    return dissolved_with_aggregates

# Define a function that returns the closest point and distance for a given geometry
def find_closest_point_and_distance(reference_layer, compare_layer):

    single_polygon = compare_layer[compare_layer['height'] != 255].dissolve()
    geom = single_polygon.geometry.iloc[0]
    reference_point, closest_point = nearest_points(reference_layer, geom)
    distance = reference_layer.distance(closest_point)
    return pd.Series([distance], index=['distance_pch'])

