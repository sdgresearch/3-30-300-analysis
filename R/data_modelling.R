# Packages ----------------------------------------------------------------

source("R/utils/constants.R")
source("R/utils/paths.R")
load(here(T3_30_300_DIR, ".RData"))

library(dplyr)
library(tidyr)
library(sf)
library(spdep)
library(spatialreg)

# Data Preparation -------------------------------------------------------

t3_30_300_lsoa_srm_gdf <- t3_30_300_lsoa_gdf |>
    select(LSOA21CD, Region = RGN22NM, Urban = Urban_rural_flag, tree_count_slope_gini,
           tree_count_10m_gini, tree_count_25m_gini, tree_count_50m_gini, tree_count_75m_gini, tree_count_100m_gini,
           canopy_cover_100m_gini, canopy_cover_200m_gini, canopy_cover_300m_gini, distance_manhattan_gini,
           tree_person_ratio, tree_area_ratio, NDVI, NDBI, IMDScore, pop_density) |>
    drop_na()

# Spatial Regression Models -----------------------------------------------

nb_lsoa <- poly2nb(t3_30_300_lsoa_srm_gdf, queen = TRUE, row.names = t3_30_300_lsoa_srm_gdf$LSOA21CD)
lw_lsoa <- nb2listw(nb_lsoa, style = "W", zero.policy = TRUE)

neighbour_counts <- card(nb_lsoa)

# 2. Create a new data frame that excludes the "islands"
# Keep only the rows where the neighbour count is greater than 0
t3_30_300_lsoa_srm_gdf_subset <- t3_30_300_lsoa_srm_gdf[neighbour_counts > 0, ]

# 3. Re-create the spatial weights matrix using ONLY the subsetted data
# This step is crucial to ensure the data and weights matrix align perfectly
nb_lsoa_subset <- poly2nb(t3_30_300_lsoa_srm_gdf_subset, queen = TRUE,
                          row.names = t3_30_300_lsoa_srm_gdf_subset$LSOA11CD)

lw_lsoa_subset <- nb2listw(nb_lsoa_subset, style = "W", zero.policy = FALSE)

moran.test(t3_30_300_lsoa_srm_gdf_subset$tree_count_slope_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$tree_count_10m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$tree_count_25m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$tree_count_50m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$tree_count_75m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$tree_count_100m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$canopy_cover_100m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$canopy_cover_200m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$canopy_cover_300m_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$distance_manhattan_gini, lw_lsoa_subset)

vars_lst <- c("tree_count_slope_gini", "tree_count_10m_gini", "tree_count_25m_gini", "tree_count_50m_gini", "tree_count_75m_gini", "tree_count_100m_gini",
              "canopy_cover_100m_gini", "canopy_cover_200m_gini", "canopy_cover_300m_gini", "distance_manhattan_gini")

ols_models <- list()
ols_int_models <- list()
sem_models <- list()
slm_models <- list()

# OLS for models

for (var in vars_lst) {
    message("Fitting OLS model for ", var)
    formula <- paste(var, "~ IMDScore + Region + Urban + pop_density + NDVI + NDBI")
    ols_model <- lm(as.formula(formula), data = t3_30_300_lsoa_srm_gdf_subset)
    ols_models[[var]] <- ols_model
}

for (var in vars_lst) {
    message("Fitting OLS interaction model for ", var)
    formula <- paste(var, "~ IMDScore + Region + Urban + IMDScore*Region +  IMDScore*Urban + pop_density + NDVI + NDBI")
    ols_model <- lm(as.formula(formula), data = t3_30_300_lsoa_srm_gdf_subset)
    ols_int_models[[var]] <- ols_model
}

saveRDS(ols_models, here(T3_30_300_DIR, "models_new", "ols_models.rds"))
saveRDS(ols_int_models, here(T3_30_300_DIR, "models_new", "ols_int_models.rds"))

# Spatial models

for (var in vars_lst) {
    message("Fitting SEM and SLM models for ", var)
    formula <- paste(var, "~ IMDScore + Urban + Region + IMDScore*Urban + IMDScore*Region + pop_density + NDVI + NDBI")
    sem_model <- errorsarlm(as.formula(formula),
                            data = t3_30_300_lsoa_srm_gdf_subset,
                            listw = lw_lsoa_subset,
                            method = "Matrix")
    slm_model <- lagsarlm(as.formula(formula),
                          data = t3_30_300_lsoa_srm_gdf_subset,
                          listw = lw_lsoa_subset,
                          method = "Matrix")
    sem_models[[var]] <- sem_model
    slm_models[[var]] <- slm_model
}

saveRDS(sem_models, here(T3_30_300_DIR, "models_new", "sem_models.rds"))
saveRDS(slm_models, here(T3_30_300_DIR, "models_new", "slm_models.rds"))
