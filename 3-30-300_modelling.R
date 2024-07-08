
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

imd_distance_path <- paste0(VECTOR_OUTPUT_DIR, 
                            "/imd/imd_distance_aggregated_canopy_cover.geojson")
diabetes_path <- paste0(TABULAR_INPUT_DIR, 
                        "/diabetes/Diabetes-Prevalence-Data(Wards).csv")
ons_codes_path <- paste0(TABULAR_INPUT_DIR, 
                         "/gbg_boundaries/LSOA11_WD19_LAD19_EW_LU_cbf3896924a74e58ac96b7ec66a34071_-277400741007527430.csv")
ons_geometries_path <- paste0(VECTOR_INPUT_DIR, 
                              "/gbg_boundaries/LAD_Dec_2019_Boundaries_UK_BFC_2022_2942927368901013076/Local_Authority_Districts__December_2019__Boundaries_UK_BFC.shp")
wards_geometries <- paste0(VECTOR_INPUT_DIR, 
                           "/gbg_boundaries/Wards_December_2019_FCB_GB_2022_-8436552284962077830/Wards_December_2019_FCB_GB.shp")

population_lsoa_path <- paste0(TABULAR_INPUT_DIR, "/population/2017_lsoa_population_total.csv")
population_ward_path <- paste0(TABULAR_INPUT_DIR, "/population/2017_ward_population_total.csv")

# Data Processing ---------------------------------------------------------

log_info(paste("Running Data Processing"))                           
imd_distance_df <- read_sf(imd_distance_path)

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
    inner_join(diabetes_lsoa_df, join_by(LSOA == LSOA11CD))

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
    select(lsoa, d_pch, d_ogs, canopy_cover, LA_decile, LA_pct, SOA_decile,
           SOA_pct, diabetes_prev, diabetes_qof, diabetes_expected, diabetes_SIR, 
           ends_with('_bin')) |> 
    drop_na() |> 
    st_make_valid()


# EDA - Diabetes ----------------------------------------------------------

# model_df |> 
#     ggplot(aes(x = canopy_cover, y = diabetes_prev, colour = as.factor(LA_decile))) +
#     geom_point(alpha = .5) +
#     geom_smooth() +
#     scale_color_brewer(palette = 'RdYlBu') +
#     theme_minimal()

# model_df |> 
#     ggplot(aes(x = d_pch, y = diabetes_prev, colour = as.factor(LA_decile))) +
#     geom_point(alpha = .5) +
#     geom_smooth() +
#     scale_color_brewer(palette = 'RdYlBu') +
#     theme_minimal()

# model_df |> 
#     ggplot(aes(x = d_ogs, y = diabetes_prev, colour = as.factor(LA_decile))) +
#     geom_point(alpha = .5) +
#     geom_smooth() +
#     scale_color_brewer(palette = 'RdYlBu') +
#     theme_minimal()

# model_df |> 
#     ggplot(aes(x = as.factor(LA_decile), y = diabetes_prev, fill = as.factor(LA_decile))) +
#     geom_boxplot() +
#     geom_smooth() +
#     scale_fill_brewer(palette = 'RdYlBu') +
#     theme_minimal()

# SDG Presentation --------------------------------------------------------

# Create a spatial weights matrix using Queen contiguity
coords <- st_coordinates(model_df)
nb <- poly2nb(model_df)
lw <- nb2listw(nb, style = "W", zero.policy = T)

# Define the formula
formula <- diabetes_prev ~ d_pch + d_ogs + canopy_cover + LA_pct

log_info(paste("Running OLS Model"))
# OLS Regression
ols_model <- lm(formula, data = model_df)
summary(ols_model)
write_rds(ols_model, paste0(SERIALISED_OUTPUT_DIR, "/ols_model.rds"))

# Check for spatial autocorrelation in residuals
moran.test(residuals(ols_model), lw)

log_info(paste("Running Bandwith"))
# Define the bandwidth for GWR
model_df_bw <- model_df |>
    select(lsoa, diabetes_prev, d_pch, d_ogs, canopy_cover, LA_pct, geometry) |>
    as_Spatial(IDs = 'lsoa')

# gwr_bandwidth <- gwr.sel(formula, data = model_df_bw, coords = coords, adapt = T)    
gwr_bandwidth <- bw.gwr(diabetes_prev ~ d_pch + d_ogs + canopy_cover + LA_pct, data = model_df_bw, adapt = T, parallel.method = 'cluster')

write_rds(gwr_bandwidth, paste0(SERIALISED_OUTPUT_DIR, "/gwr_bandwith.rds"))

log_info(paste("Running GWR Model"))
# GWR Model
gwr_model <- gwr(diabetes_prev ~ d_pch + d_ogs + canopy_cover + LA_pct,
                 data = model_df_bw, coords = coords, adapt = gwr_bandwidth, hatmatrix = T)
summary(gwr_model)
write_rds(gwr_model, paste0(SERIALISED_OUTPUT_DIR, "/gwr_model.rds"))

log_info(paste("Running SLM Model"))
# Spatial Lag Model (SLM)
slm_model <- lagsarlm(formula, data = model_df, listw = lw, zero.policy = T)
summary(slm_model)
write_rds(slm_model, paste0(SERIALISED_OUTPUT_DIR, "/slm_model.rds"))

log_info(paste("Running SEM Model"))
# Spatial Error Model (SEM)
sem_model <- errorsarlm(formula, data = model_df, listw = lw, zero.policy = T)
summary(sem_model)
write_rds(sem_model, paste0(SERIALISED_OUTPUT_DIR, "/sem_model.rds"))


# Relative Risk Analysis --------------------------------------------------

nb2INLA(paste0(SERIALISED_OUTPUT_DIR, "/n_matrix.rds"), nb)
g <- inla.read.graph(filename = paste0(SERIALISED_OUTPUT_DIR, "/n_matrix.rds"))

model_df$idareau <- 1:nrow(model_df)
model_df$idareav <- 1:nrow(model_df)

formula <- diabetes_qof ~ canopy_cover * as.factor(SOA_decile) +
    f(idareau, model = "besag", graph = g, scale.model = TRUE) +
    f(idareav, model = "iid")

res <- inla(formula,
            family = "poisson", data = model_df, E = diabetes_expected,
            control.predictor = list(compute = TRUE),
            control.compute = list(return.marginals.predictor = TRUE)
)

summary(res)

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

# Odds Ratio (RR) ---------------------------------------------------------

# # Create a contingency table (diabetes v. canopy_cover)
# table <- table(model_df$diabetes_prev_bin, model_df$canopy_cover_bin)
# 
# # Calculate probabilities
# p_high <- table[2, "High"] / sum(table[, "High"])
# p_low <- table[2, "Low"] / sum(table[, "Low"])
# 
# # Calculate relative risk
# relative_risk <- p_high / p_low
# relative_risk
# 
# # Logistic regression model
# logistic_model <- glm(diabetes_prev_bin ~ d_pch + d_ogs + canopy_cover_bin, data = model_df, family = binomial)
# 
# # Summary of the model
# summary(logistic_model)
# 
# # Extract odds ratios
# odds_ratios <- exp(coef(logistic_model))
# odds_ratios
# 
# # Create a contingency table (diabetes v. LA decil)
# table <- table(model_df$diabetes_prev_bin, model_df$LA_decile)
# 
# # Calculate probabilities
# p_high <- table[2, "High"] / sum(table[, "High"])
# p_low <- table[2, "Low"] / sum(table[, "Low"])
# 
# # Calculate relative risk
# relative_risk <- p_high / p_low
# relative_risk
# 
# # Logistic regression model
# logistic_model <- glm(diabetes_prev_bin ~ d_pch + d_ogs + canopy_cover + LA_decile, data = model_df, family = binomial)
# 
# # Summary of the model
# summary(logistic_model)
