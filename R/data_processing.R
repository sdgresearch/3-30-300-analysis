# Packages ----------------------------------------------------------------

source("R/utils/constants.R")
source("R/utils/paths.R")

library(dplyr)
library(tidyr)
library(readr)
library(forcats)
library(arrow)
library(geoarrow)
library(sf)
library(DescTools)

# Data --------------------------------------------------------------------

# t3_30_300_spectral_df <- read_parquet(t3_30_300_spectral_parquet)
output_areas_boundaries_gdf <- open_dataset(output_areas_boundaries_parquet) |>
    st_as_sf()
os_tile_boundaries_gdf <- open_dataset(os_tile_boundaries_parquet) |> 
    st_as_sf()
output_areas_buildings_df <- read_parquet(output_areas_buildings_parquet)
lsoa_urban_df <- read_csv(lsoa_urban_path)
lad_london_df <- read_csv(lad_london_path)
tree_vector_paths_df <- read_parquet(tree_vector_paths_parquet)
imd_lsoa_df <- read_parquet(imd_lsoa_parquet)
spectral_df <- read_parquet(spectral_parquet) |> 
    mutate(across(starts_with("ND"), as.numeric))
std_population_estimates_df <- read_parquet(std_population_estimates_parquet)
tree_count_df <- read_parquet(tree_count_parquet) |> 
    mutate(tree_count = as.integer(tree_count))
t3_300_df <- read_parquet(t3_300_parquet) |> 
    mutate(verisk_premise_id = as.integer(verisk_premise_id),
           across(starts_with("tree_count"), as.numeric),
           across(contains("distance"), as.numeric))
t30_df <- read_parquet(t30_parquet) |> 
    mutate(across(canopy_cover:total_pixels, as.numeric))

# Processing --------------------------------------------------------------

population_df <- std_population_estimates_df |>  
    left_join(imd_lsoa_df |> select(LSOA11CD, LSOA21CD), by = "LSOA11CD") |> 
    left_join(output_areas_boundaries_gdf |> 
                st_drop_geometry() |> 
                select(LSOA21CD, MSOA21CD, LAD22CD, RGN22CD) |> 
                distinct(), by = "LSOA21CD") |> 
    distinct(LSOA21CD, .keep_all = TRUE)

t3_300_buildings_df <- t3_300_df |>
    left_join(output_areas_buildings_df, by = "verisk_premise_id") |>
    select(-closest_park_access_id, -closest_park_site_id) |> 
    distinct(verisk_premise_id, .keep_all = TRUE)

group_by_geo_level <- function(geo_level = "LSOA21CD", dTolerance = 500) { 

    geo_level_gdf <- output_areas_boundaries_gdf |> 
        group_by(!!sym(geo_level)) |> 
        summarise(geometry = st_union(geometry), area = sum(area), .groups = "drop") |> 
        filter(!is.na(!!sym(geo_level))) |> 
        st_simplify(dTolerance = dTolerance, preserveTopology = FALSE)

    population_geo_level_df <- population_df |> 
        group_by(!!sym(geo_level)) |> 
        summarise(total_pop = sum(total_pop, na.rm = TRUE),
                #   across(ends_with("ratio"), ~round(sum(.x * total_pop) / sum(total_pop), 2), .names = "{.col}_person_ratio"), # TODO: Calculate ratio per geo_level
                  .groups = "drop") |> 
        drop_na(!!sym(geo_level))

    t3_300_buildings_gini_geo_level_df <- t3_300_buildings_df |> 
        filter(map_use == "Residential") |>
        group_by(!!sym(geo_level)) |>
        summarise(across(starts_with("tree_count"), ~Gini(.x, na.rm = TRUE, unbiased = TRUE), .names = "{.col}_gini"),
                  across(starts_with("tree_count"), ~round(mean(.x, na.rm = TRUE), 2), .names = "{.col}"),
                  across(starts_with("distance"), ~1 - Gini(.x, na.rm = TRUE, unbiased = TRUE), .names = "{.col}_gini"),
                  across(starts_with("distance"), ~round(mean(.x, na.rm = TRUE), 2), .names = "{.col}"),
                  building_count = n(), .groups = "drop")

    t30_geo_level_df <- t30_df |> 
        group_by(!!sym(geo_level)) |> 
        summarise(canopy_cover = round(sum(canopy_cover * total_pixels) / sum(total_pixels), 2), .groups = "drop")
    
    tree_count_geo_level_df <- tree_count_df |> 
        left_join(output_areas_boundaries_gdf |> st_drop_geometry(), by = "OA21CD") |> 
        group_by(!!sym(geo_level)) |> 
        summarise(total_trees = sum(tree_count, na.rm = TRUE), .groups = "drop")

    t3_30_300_geo_level_gdf <- geo_level_gdf |> 
        left_join(population_geo_level_df, by = geo_level) |> 
        left_join(tree_count_geo_level_df, by = geo_level) |> 
        left_join(t3_300_buildings_gini_geo_level_df, by = geo_level) |> 
        left_join(t30_geo_level_df, by = geo_level) |> 
        mutate(pop_density = total_pop / area,
               tree_person_ratio = total_trees / total_pop,
               tree_area_ratio = total_trees / area)
    
    return(t3_30_300_geo_level_gdf)
}

t3_30_300_lsoa_gdf <- group_by_geo_level("LSOA21CD", 10) |> 
    left_join(output_areas_boundaries_gdf |> 
        st_drop_geometry() |> 
        select(LSOA21CD, LSOA21NM, MSOA21CD, MSOA21NM, LAD22CD, LAD22NM, RGN22CD, RGN22NM) |> 
        distinct(), by = "LSOA21CD") |> 
    # full_join(t3_30_300_spectral_df |> select(-canopy_cover, -total_trees, -NDVI, -NDWI, -NDBI), by = "LSOA21CD") |> 
    full_join(spectral_df, by = "LSOA21CD") |> 
    full_join(imd_lsoa_df, by = "LSOA21CD") |> 
    mutate(IMD_Decile = as_factor(IMD_Decile),
           across(ends_with("Dec"), as_factor, .names = "{.col}")) |> 
    left_join(lad_london_df |> select(LAD22CD, IOL22CD, IOL22NM), by = "LAD22CD") |>
    left_join(lsoa_urban_df |> 
                select(LSOA21CD, Urban_rural_flag), by = "LSOA21CD") |>
    mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                            "Yorkshire and The Humber",
                                            "West Midlands", "East Midlands",
                                            "East of England", "South West",
                                            "South East", "London"))) |>
    arrange(RGN22CD, LAD22CD, MSOA21CD, LSOA21CD) |> 
    distinct(LSOA21CD, .keep_all = TRUE)

write_parquet(t3_30_300_lsoa_gdf |> st_transform(crs = WGS84_CRS) |> mutate(RGN22NM = as.character(RGN22NM)), here(app_files_dir, "Aggregated", "t3_30_300_lsoa_4326.parquet"))
write_csv(t3_30_300_lsoa_gdf |> st_drop_geometry() |> mutate(RGN22NM = as.character(RGN22NM)), here(app_files_dir, "Aggregated", "t3_30_300_lsoa_4326.csv"))
# Clean field names for shapefile compatibility (max 10 chars, alphanumeric + underscore only)
clean_shapefile_names <- function(names) {
    # First make valid names
    valid_names <- make.names(names, unique = TRUE)
    
    # Create a mapping to preserve meaning while ensuring uniqueness
    name_mapping <- c(
        # Tree count fields
        "tree_count_10m" = "tree_10m",
        "tree_count_25m" = "tree_25m", 
        "tree_count_50m" = "tree_50m",
        "tree_count_75m" = "tree_75m",
        "tree_count_100m" = "tree_100m",
        "tree_count_slope" = "tree_slope",
        "tree_count_10m_gini" = "tree10_gini",
        "tree_count_25m_gini" = "tree25_gini",
        "tree_count_50m_gini" = "tree50_gini",
        "tree_count_75m_gini" = "tree75_gini",
        "tree_count_100m_gini" = "tree100_gini",
        "tree_count_slope_gini" = "treesl_gini",
        
        # Distance fields
        "distance_manhattan" = "dist_manh",
        "distance_euclidean" = "dist_eucl",
        "distance_water" = "dist_water",
        "distance_manhattan_gini" = "distm_gini",
        "distance_euclidean_gini" = "diste_gini",
        "distance_water_gini" = "distw_gini",
        
        # Basic fields
        "total_trees" = "tot_trees",
        "total_pop" = "tot_pop",
        "canopy_cover" = "canopy_cov",
        "pop_density" = "pop_dens",
        "tree_person_ratio" = "tree_per",
        "tree_area_ratio" = "tree_area",
        "building_count" = "bldg_count",
        
        # IMD and related fields
        "IMD_Decile" = "IMD_Dec",
        "IMD_Rank" = "IMD_Rank",
        "IMDScore" = "IMDScore",
        "IncScore" = "IncScore",
        "IncRank" = "IncRank",
        "IncDec" = "IncDec",
        "EmpScore" = "EmpScore",
        "EmpRank" = "EmpRank",
        "EmpDec" = "EmpDec",
        "EduScore" = "EduScore",
        "EduRank" = "EduRank",
        "EduDec" = "EduDec",
        "HDDScore" = "HDDScore",
        "HDDRank" = "HDDRank",
        "HDDDec" = "HDDDec",
        "CriScore" = "CriScore",
        "CriRank" = "CriRank",
        "CriDec" = "CriDec",
        "BHSScore" = "BHSScore",
        "BHSRank" = "BHSRank",
        "BHSDec" = "BHSDec",
        "EnvScore" = "EnvScore",
        "EnvRank" = "EnvRank",
        "EnvDec" = "EnvDec",
        
        # Geographic identifiers
        "LSOA21CD" = "LSOA21CD",
        "LSOA21NM" = "LSOA21NM",
        "MSOA21CD" = "MSOA21CD",
        "MSOA21NM" = "MSOA21NM",
        "LAD22CD" = "LAD22CD",
        "LAD22NM" = "LAD22NM",
        "RGN22CD" = "RGN22CD",
        "RGN22NM" = "RGN22NM",
        "IOL22CD" = "IOL22CD",
        "IOL22NM" = "IOL22NM",
        "LSOA11CD" = "LSOA11CD",
        
        # Other fields
        "area" = "area",
        "geometry" = "geometry",
        "NDBI" = "NDBI",
        "NDVI" = "NDVI",
        "NDWI" = "NDWI",
        "Urban_rural_flag" = "Urban_flag"
    )
    
    # Apply the mapping
    cleaned_names <- valid_names
    for (i in seq_along(valid_names)) {
        if (valid_names[i] %in% names(name_mapping)) {
            cleaned_names[i] <- name_mapping[valid_names[i]]
        } else {
            # For any remaining names, truncate to 10 chars
            cleaned_names[i] <- substr(valid_names[i], 1, 10)
        }
    }
    
    # Ensure uniqueness by adding numbers if needed
    final_names <- make.unique(cleaned_names, sep = "_")
    
    return(final_names)
}

t3_30_300_lsoa_gdf_clean <- t3_30_300_lsoa_gdf |> 
    st_transform(crs = WGS84_CRS) |>
    rename_with(~clean_shapefile_names(.), .cols = everything())

t3_30_300_lsoa_gdf_clean |> 
    st_write(here(app_files_dir, "Aggregated", "t3_30_300_lsoa_4326.shp"))

t3_30_300_msoa_gdf <- group_by_geo_level("MSOA21CD", 100) |> 
    left_join(output_areas_boundaries_gdf |> 
        st_drop_geometry() |> 
        select(MSOA21CD, MSOA21NM, LAD22CD, LAD22NM, RGN22CD, RGN22NM) |> 
        distinct(), by = "MSOA21CD") |> 
    left_join(lad_london_df |> select(LAD22CD, IOL22CD, IOL22NM), by = "LAD22CD") |>
    mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                            "Yorkshire and The Humber",
                                            "West Midlands", "East Midlands",
                                            "East of England", "South West",
                                            "South East", "London"))) |>
    arrange(RGN22CD, LAD22CD, MSOA21CD)

t3_30_300_lad_gdf <- group_by_geo_level("LAD22CD", 100) |> 
    left_join(output_areas_boundaries_gdf |> 
        st_drop_geometry() |> 
        select(LAD22CD, LAD22NM, RGN22CD, RGN22NM) |> 
        distinct(), by = "LAD22CD") |> 
    left_join(lad_london_df |> select(LAD22CD, IOL22CD, IOL22NM), by = "LAD22CD") |>
    mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                            "Yorkshire and The Humber",
                                            "West Midlands", "East Midlands",
                                            "East of England", "South West",
                                            "South East", "London"))) |>
    arrange(RGN22CD, LAD22CD)
                  
t3_30_300_rgn_gdf <- group_by_geo_level("RGN22CD", 100) |> 
    left_join(output_areas_boundaries_gdf |> 
        st_drop_geometry() |> 
        select(RGN22CD, RGN22NM) |> 
        distinct(), by = "RGN22CD") |>
    mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                            "Yorkshire and The Humber",
                                            "West Midlands", "East Midlands",
                                            "East of England", "South West",
                                            "South East", "London"))) |>
    arrange(RGN22CD)

t3_30_300_lsoa_standard_df <- t3_30_300_lsoa_gdf |> 
    st_drop_geometry() |> 
    mutate(`3` = log(tree_count_25m + 1),
           `30 (%)` = log(canopy_cover + 1),
           `300 (m)` = -log(park_distance_manhattan + 1),
           `Water Distance (m)` = -log(water_distance + 1),
           tree_person_ratio = log(tree_person_ratio + 1),
           across(ends_with('Score'), scale, .names = "{.col}")) |> 
    select(`3`, `30 (%)`, `300 (m)`, `Water Distance (m)`,
           tree_person_ratio, NDVI, NDWI, NDBI, IMDScore,
           LSOA21CD, LAD22CD, RGN22CD, pop_density, Urban_rural_flag, EnvDec) |> 
    drop_na()

save.image(here(T3_30_300_DIR, ".RData"))

# library(sparklyr)
# library(apache.sedona)
# sc <- spark_connect(master = "local")
