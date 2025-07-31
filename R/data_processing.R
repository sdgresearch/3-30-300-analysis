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

t3_30_300_spectral_df <- read_parquet(t3_30_300_spectral_parquet)
output_areas_boundaries_gdf <- open_dataset(output_areas_boundaries_parquet) |>
    st_as_sf()
os_tile_boundaries_gdf <- open_dataset(os_tile_boundaries_parquet) |> 
    st_as_sf()
output_areas_buildings_df <- read_parquet(output_areas_buildings_parquet)
lsoa_urban_df <- read_csv(lsoa_urban_path)
lad_london_df <- read_csv(lad_london_path)
tree_vector_paths_df <- read_parquet(tree_vector_paths_parquet)
imd_lsoa_df <- read_parquet(imd_lsoa_parquet)
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
                  across(starts_with("distance"), ~1 - Gini(.x, na.rm = TRUE, unbiased = TRUE), .names = "{.col}_gini"),
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
    full_join(t3_30_300_spectral_df |> select(-canopy_cover, -total_trees), by = "LSOA21CD") |> 
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
    arrange(RGN22CD, LAD22CD, MSOA21CD, LSOA21CD)

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
