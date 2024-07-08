
# Libraries ---------------------------------------------------------------

library(tidyverse)
library(readxl)
library(sf)
library(logger)
library(GWmodel)
library(lwgeom)
library(spgwr)
library(spdep)
library(spatialreg)
library(fmesher)
library(INLA)

log_threshold(DEBUG)

# Paths -------------------------------------------------------------------
log_info(paste("Creating path variables"))

DATA_DIR <- Sys.getenv("DATA_DIR")
INPUT_DIR <- paste0(DATA_DIR, "/input")
OUTPUT_DIR <- paste0(DATA_DIR, "/output")
VECTOR_INPUT_DIR <- paste0(INPUT_DIR, "/vector")
VECTOR_OUTPUT_DIR <- paste0(OUTPUT_DIR, "/vector")
TABULAR_INPUT_DIR <- paste0(INPUT_DIR, "/tabular")
TABULAR_OUTPUT_DIR <- paste0(OUTPUT_DIR, "/tabular")
SERIALISED_OUTPUT_DIR <- paste0(OUTPUT_DIR, "/serialised")

population_lsoa_path <- paste0(TABULAR_INPUT_DIR, "/population/2017_lsoa_population_total.csv")
population_ward_path <- paste0(TABULAR_INPUT_DIR, "/population/2017_ward_population_total.csv")
imd_distance_path <- paste0(VECTOR_OUTPUT_DIR, 
                            "/imd/imd_distance_aggregated_canopy_cover.geojson")
imd_england_path <- paste0(VECTOR_INPUT_DIR, 
                      "/imd/English IMD 2019/IMD_2019.shp")
diabetes_path <- paste0(TABULAR_INPUT_DIR, 
                        "/diabetes/Diabetes-Prevalence-Data(Wards).csv")
ons_codes_path <- paste0(TABULAR_INPUT_DIR, 
                         "/gbg_boundaries/LSOA11_WD19_LAD19_EW_LU_cbf3896924a74e58ac96b7ec66a34071_-277400741007527430.csv")
ons_geometries_path <- paste0(VECTOR_INPUT_DIR, 
                              "/gbg_boundaries/LAD_Dec_2019_Boundaries_UK_BFC_2022_2942927368901013076/Local_Authority_Districts__December_2019__Boundaries_UK_BFC.shp")
wards_geometries <- paste0(VECTOR_INPUT_DIR, 
                           "/gbg_boundaries/Wards_December_2019_FCB_GB_2022_-8436552284962077830/Wards_December_2019_FCB_GB.shp")

# Data Processing ---------------------------------------------------------

log_info(paste("Running Data Processing"))                           

imd_distance_df <- read_sf(imd_distance_path)
imd_england_sf <- read_sf(imd_england_path)

population_lsoa_df <- read_csv(population_lsoa_path)
population_ward_df <- read_csv(population_ward_path)

diabetes_df <- read_csv(diabetes_path) |> 
    mutate(`Estimated Diabetes Prevalence` = str_replace_all(`Estimated Diabetes Prevalence`, "[^0-9.]", "") |> 
               as.numeric(),
           `Patient Coverage` = str_replace_all(`Patient Coverage`, "[^0-9.]", "") |> 
               as.numeric()) |> 
    inner_join(population_ward_df, by = join_by(`ONS Code` == `Ward Code 1`)) |> 
    mutate(adult_pop = rowSums(across(`17`:`90+`)),
           diabetes_expected = adult_pop * 0.067, # 6.7% Prevalence in England
           diabetes_SIR = `Estimated QOF Diabetes Register (17+)` / diabetes_expected) |> 
    select(-`Ward Name 1`:-`90+`)

ons_codes_df <- read_sf(ons_codes_path)
ons_geometries <- read_sf(ons_geometries_path)
ons_codes_sf <- ons_geometries |> 
    left_join(ons_codes_df, by = join_by(lad19cd == LAD19CD))

wards_sf <- read_sf(wards_geometries)

diabetes_lsoa_df <- diabetes_df |> 
    left_join(ons_codes_df, by = join_by(`ONS Code` == WD19CD)) |> 
    group_by(LSOA11CD) |> 
    summarize(across(`Estimated Diabetes Prevalence`:diabetes_SIR, mean, na.rm = TRUE))

diabetes_imd_green_sf <- imd_distance_df |> 
    select(LSOA, `distance_pch mean`:canopy_cover) |> 
    inner_join(imd_england_sf |> 
                   st_drop_geometry(), by = join_by(LSOA == lsoa11cd)) |> 
    inner_join(diabetes_lsoa_df, by = join_by(LSOA == LSOA11CD))

normalize <- function(x) (x - min(x)) / (max(x) - min(x))

model_df <- diabetes_imd_green_sf |> 
    drop_na() |> 
    mutate(lsoa = LSOA, 
           d_pch_bin = if_else(`distance_pch mean` > median(`distance_pch mean`), "High", "Low"),
           d_pch = normalize(log(`distance_pch mean` + 1)),
           d_ogs_bin = if_else(`distance_ogs mean` > median(`distance_ogs mean`), "High", "Low"),
           d_ogs = normalize(log(`distance_ogs mean` + 1)),
           canopy_cover_bin = if_else(canopy_cover > median(canopy_cover), "High", "Low"),
           canopy_cover = normalize(sqrt(canopy_cover)),
           diabetes_prev_bin = if_else(`Estimated Diabetes Prevalence` > 6.7, 1, 0), 
           diabetes_prev = normalize(`Estimated Diabetes Prevalence`),
           diabetes_qof = `Estimated QOF Diabetes Register (17+)`) |> 
    select(lsoa, IMD_Rank, IMD_Decile, d_pch, d_ogs, canopy_cover,
           diabetes_prev, diabetes_qof, diabetes_expected, diabetes_SIR, 
           ends_with('Score')) |> 
    drop_na() |> 
    st_make_valid()

# EDA - Diabetes ----------------------------------------------------------

model_df |>
    ggplot(aes(x = as.factor(IMD_Decile), y = diabetes_prev, fill = as.factor(IMD_Decile))) +
    geom_violin() +
    geom_smooth() +
    scale_fill_brewer(palette = 'RdYlBu') +
    theme_minimal()

model_df |>
    ggplot(aes(x = d_pch, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    theme_minimal()

model_df |>
    ggplot(aes(x = canopy_cover, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    theme_minimal()

model_df |>
    ggplot(aes(x = d_ogs, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    theme_minimal()

model_df |> 
    ggplot(aes(x = IMDScore, y = diabetes_prev)) +
    geom_point() +
    geom_smooth() +
    theme_minimal()

# SDG Presentation --------------------------------------------------------

# Create a spatial weights matrix using Queen contiguity
coords <- st_coordinates(model_df)
nb <- poly2nb(model_df, row.names = model_df$lsoa)
lw <- nb2listw(nb, style = "W", zero.policy = T)

# Base formula
base_formula <- diabetes_prev ~ IMDScore

# Expanded Base Formula
expanded_base_formula <- diabetes_prev ~ IncScore + EmpScore + EduScore + HDDScore + CriScore + 
    BHSScore + EnvScore + IDCScore + IDOScore + CYPScore + 
    ASScore + GBScore +  WBScore +  IndScore + OutScore

# (Green) Hypothesis Formulas
# 3: Visibility
# 30: Availability
# 300: Accessibility
hypothesis_base_formula <- diabetes_prev ~ IMDScore + d_pch + d_ogs + canopy_cover

expanded_hypothesis_formula <- diabetes_prev ~ IMDScore + d_pch + d_ogs + canopy_cover +
    IncScore + EmpScore + EduScore + HDDScore + CriScore + 
    BHSScore + EnvScore + IDCScore + IDOScore + CYPScore + 
    ASScore + GBScore +  WBScore +  IndScore + OutScore

# OLS Regression
log_info(paste("Running OLS Model"))

base_ols_model <- lm(base_formula, data = model_df)
expanded_base_ols_model <- lm(expanded_base_formula, data = model_df)
hypothesis_ols_model <- lm(hypothesis_base_formula, data = model_df)
expanded_hypothesis_ols_model <- lm(expanded_hypothesis_formula, data = model_df)

summary(base_ols_model)
summary(expanded_base_ols_model)
summary(hypothesis_ols_model)
summary(expanded_hypothesis_ols_model)

write_rds(base_ols_model, paste0(SERIALISED_OUTPUT_DIR, "/base_ols_model.rds"))
write_rds(expanded_base_ols_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_base_ols_model.rds"))
write_rds(hypothesis_ols_model, paste0(SERIALISED_OUTPUT_DIR, "/hypothesis_ols_model.rds"))
write_rds(expanded_hypothesis_ols_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_hypothesis_ols_model.rds"))

# Check for spatial autocorrelation in residuals
moran.test(residuals(hypothesis_ols_model), lw)

# Define the bandwidth for GWR
log_info(paste("Running Bandwith"))

model_df_bw <- model_df |>
    select(lsoa, diabetes_prev, d_pch, d_ogs, canopy_cover, LA_pct, geometry) |>
    as_Spatial(IDs = 'lsoa')

# gwr_bandwidth <- gwr.sel(formula, data = model_df_bw, coords = coords, adapt = T)    
gwr_bandwidth <- bw.gwr(diabetes_prev ~ d_pch + d_ogs + canopy_cover + LA_pct, data = model_df_bw, adapt = T, parallel.method = 'cluster')

write_rds(gwr_bandwidth, paste0(SERIALISED_OUTPUT_DIR, "/gwr_bandwith.rds"))

# GWR Model
log_info(paste("Running GWR Model"))

gwr_model <- gwr(hypothesis_base_formula,
                 data = model_df_bw, coords = coords, adapt = gwr_bandwidth, hatmatrix = T)
summary(gwr_model)
write_rds(gwr_model, paste0(SERIALISED_OUTPUT_DIR, "/gwr_model.rds"))

# Spatial Lag Model (SLM)
log_info(paste("Running SLM Model"))

base_slm_model <- lagsarlm(base_formula, data = model_df, listw = lw, zero.policy = T)
expanded_base_slm_model <- lagsarlm(expanded_base_formula, data = model_df, listw = lw, zero.policy = T)
hypothesis_slm_model <- lagsarlm(hypothesis_base_formula, data = model_df, listw = lw, zero.policy = T)
expanded_hypothesis_slm_model <- lagsarlm(expanded_hypothesis_formula, data = model_df, listw = lw, zero.policy = T)

summary(base_slm_model)
summary(expanded_base_slm_model)
summary(hypothesis_slm_model)
summary(expanded_hypothesis_slm_model)

write_rds(base_slm_model, paste0(SERIALISED_OUTPUT_DIR, "/base_slm_model.rds"))
write_rds(expanded_base_slm_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_base_slm_model.rds"))
write_rds(hypothesis_slm_model, paste0(SERIALISED_OUTPUT_DIR, "/hypothesis_slm_model.rds"))
write_rds(expanded_hypothesis_slm_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_hypothesis_slm_model.rds"))

# Spatial Error Model (SEM)
log_info(paste("Running SEM Model"))

base_sem_model <- errorsarlm(base_formula, data = model_df, listw = lw, zero.policy = T)
expanded_base_sem_model <- errorsarlm(expanded_base_formula, data = model_df, listw = lw, zero.policy = T)
hypothesis_sem_model <- errorsarlm(hypothesis_base_formula, data = model_df, listw = lw, zero.policy = T)
expanded_hypothesis_sem_model <- errorsarlm(expanded_hypothesis_formula, data = model_df, listw = lw, zero.policy = T)

summary(base_sem_model)
summary(expanded_base_sem_model)
summary(hypothesis_sem_model)
summary(expanded_hypothesis_sem_model)

write_rds(base_sem_model, paste0(SERIALISED_OUTPUT_DIR, "/base_sem_model.rds"))
write_rds(expanded_base_sem_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_base_sem_model.rds"))
write_rds(hypothesis_sem_model, paste0(SERIALISED_OUTPUT_DIR, "/hypothesis_sem_model.rds"))
write_rds(expanded_hypothesis_sem_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_hypothesis_sem_model.rds"))

# Relative Risk Analysis --------------------------------------------------

nb2INLA(paste0(SERIALISED_OUTPUT_DIR, "/n_matrix.rds"), nb)
g <- inla.read.graph(filename = paste0(SERIALISED_OUTPUT_DIR, "/n_matrix.rds"))

model_df$idareau <- 1:nrow(model_df)
model_df$idareav <- 1:nrow(model_df)

# Base formula
qof_base_formula <- diabetes_qof ~ IMDScore +
    f(idareau, model = "besag", graph = g, scale.model = TRUE) +
    f(idareav, model = "iid")

# Expanded Base Formula
qof_expanded_base_formula <- diabetes_qof ~ IncScore + EmpScore + EduScore + HDDScore + CriScore + 
    BHSScore + EnvScore + IDCScore + IDOScore + CYPScore + 
    ASScore + GBScore +  WBScore +  IndScore + OutScore +
    f(idareau, model = "besag", graph = g, scale.model = TRUE) +
    f(idareav, model = "iid")

# (Green) Hypothesis Formulas
# 3: Visibility
# 30: Availability
# 300: Accessibility
qof_hypothesis_base_formula <- diabetes_qof ~ IMDScore + d_pch + d_ogs + canopy_cover +
    f(idareau, model = "besag", graph = g, scale.model = TRUE) +
    f(idareav, model = "iid")

qof_expanded_hypothesis_formula <- diabetes_qof ~ IMDScore + d_pch + d_ogs + canopy_cover +
    IncScore + EmpScore + EduScore + HDDScore + CriScore + 
    BHSScore + EnvScore + IDCScore + IDOScore + CYPScore + 
    ASScore + GBScore +  WBScore +  IndScore + OutScore +
    f(idareau, model = "besag", graph = g, scale.model = TRUE) +
    f(idareav, model = "iid")

qof_formula <- diabetes_qof ~ canopy_cover + IMDScore

base_inla_model <- inla(qof_base_formula,
            family = "poisson", data = model_df, E = diabetes_expected,
            control.predictor = list(compute = TRUE),
            control.compute = list(return.marginals.predictor = TRUE))
expanded_base_inla_model <- inla(qof_expanded_base_formula,
                   family = "poisson", data = model_df, E = diabetes_expected,
                   control.predictor = list(compute = TRUE),
                   control.compute = list(return.marginals.predictor = TRUE))
hypothesis_inla_model <- inla(qof_hypothesis_base_formula,
                   family = "poisson", data = model_df, E = diabetes_expected,
                   control.predictor = list(compute = TRUE),
                   control.compute = list(return.marginals.predictor = TRUE))
expanded_hypothesis_inla_model <- inla(qof_expanded_hypothesis_formula,
                   family = "poisson", data = model_df, E = diabetes_expected,
                   control.predictor = list(compute = TRUE),
                   control.compute = list(return.marginals.predictor = TRUE))

summary(base_inla_model)
summary(expanded_base_inla_model)
summary(hypothesis_inla_model)
summary(expanded_hypothesis_inla_model)

write_rds(base_inla_model, paste0(SERIALISED_OUTPUT_DIR, "/base_inla_model.rds"))
write_rds(expanded_base_inla_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_base_inla_model.rds"))
write_rds(hypothesis_inla_model, paste0(SERIALISED_OUTPUT_DIR, "/hypothesis_inla_model.rds"))
write_rds(expanded_hypothesis_inla_model, paste0(SERIALISED_OUTPUT_DIR, "/expanded_hypothesis_inla_model.rds"))

# # Check for validity
# validity <- st_is_valid(model_df)
# invalid_geometries <- model_df[!validity, ]
# 
# # Convert multipolygon to points (centroids)
# sf_points <- st_centroid(sf_data)
# 
# # Convert sf object to SpatialPointsDataFrame
# sp_points <- as(sf_points, "Spatial")

# # Select the optimal bandwidth
# bandwidth <- bw.gwr(formula, data = sp_points)
# 
# # Select the optimal bandwidth
# bandwidth <- gwr.sel(formula, data = sp_points)
