
# Libraries ---------------------------------------------------------------

library(tidyverse)
library(readxl)
library(sf)

# Paths -------------------------------------------------------------------

imd_distance_path <- "/Users/ancazugo/Documents/PhD_Thesis/Tree_detection/data/output/vector/imd/imd_distance_aggregated_canopy_cover.geojson"
diabetes_path <- "/Users/ancazugo/Downloads/Diabetes-Prevalence-Data(Wards).csv"
ons_codes_path <- "/Users/ancazugo/Downloads/LSOA11_WD19_LAD19_EW_LU_cbf3896924a74e58ac96b7ec66a34071_-277400741007527430.csv"
ons_geometries_path <- "/Users/ancazugo/Downloads/LAD_Dec_2019_Boundaries_UK_BFC_2022_2942927368901013076/Local_Authority_Districts__December_2019__Boundaries_UK_BFC.shp"
wards_geometries <- "/Users/ancazugo/Downloads/Wards_December_2019_FCB_GB_2022_-8436552284962077830/Wards_December_2019_FCB_GB.shp"

imd_distance_df <- sf::read_sf(imd_distance_path)

diabetes_df <- read_csv(diabetes_path) |> 
    mutate(`Estimated Diabetes Prevalence` = str_replace_all(`Estimated Diabetes Prevalence`, "[^0-9.]", "") |> 
               as.numeric(),
           `Patient Coverage` = str_replace_all(`Patient Coverage`, "[^0-9.]", "") |> 
               as.numeric())

ons_codes_df <- read_sf(ons_codes_path)
ons_geometries <- read_sf(ons_geometries_path)
ons_codes_sf <- ons_geometries |> 
    left_join(ons_codes_df, by = join_by(lad19cd == LAD19CD))

wards_sf <- read_sf(wards_geometries)

x <- diabetes_df |> 
    left_join(ons_codes_df, by = join_by(`ONS Code` == WD19CD)) |> 
    group_by(LSOA11CD) |> 
    summarize(across(`Estimated Diabetes Prevalence`:`Patient Coverage`, mean, na.rm = TRUE))

y <- imd_distance_df |> 
    # st_drop_geometry() |> 
    # as_tibble() |> 
    left_join(ons_codes_sf, by = join_by(LSOA == LSOA11CD)) |> 
    group_by(LSOA) |> 
    summarize(across(SOA_pct:canopy_cover, mean, na.rm = TRUE),
              geometry = st_union(geometry))

# z <- x |> 
#     left_join(y, by = join_by(LSOA11CD == LSOA)) |> 
#     st_as_sf()

z <- imd_distance_df |> 
    inner_join(x, join_by(LSOA == LSOA11CD))

st_write(z, '/Users/ancazugo/Downloads/diabetes_3-30-300.shp')

normalize <- function(x) (x - min(x)) / (max(x) - min(x))

z_standard <- z |> 
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
           SOA_pct, diabetes_prev, diabetes_qof, ends_with('_bin')) |> 
    drop_na() |> 
    st_make_valid()

# EDA - Diabetes ----------------------------------------------------------

z_standard |> 
    ggplot(aes(x = canopy_cover, y = diabetes_prev, colour = as.factor(LA_decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    theme_minimal()

z_standard |> 
    ggplot(aes(x = d_pch, y = diabetes_prev, colour = as.factor(LA_decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    theme_minimal()

z_standard |> 
    ggplot(aes(x = d_ogs, y = diabetes_prev, colour = as.factor(LA_decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    theme_minimal()

z_standard |> 
    ggplot(aes(x = as.factor(LA_decile), y = diabetes_prev, fill = as.factor(LA_decile))) +
    geom_boxplot() +
    geom_smooth() +
    scale_fill_brewer(palette = 'RdYlBu') +
    theme_minimal()

# Odds Ratio (RR) ---------------------------------------------------------

# Create a contingency table (diabetes v. canopy_cover)
table <- table(z_standard$diabetes_prev_bin, z_standard$canopy_cover_bin)

# Calculate probabilities
p_high <- table[2, "High"] / sum(table[, "High"])
p_low <- table[2, "Low"] / sum(table[, "Low"])

# Calculate relative risk
relative_risk <- p_high / p_low
relative_risk

# Logistic regression model
logistic_model <- glm(diabetes_prev_bin ~ d_pch + d_ogs + canopy_cover_bin, data = z_standard, family = binomial)

# Summary of the model
summary(logistic_model)

# Extract odds ratios
odds_ratios <- exp(coef(logistic_model))
odds_ratios

# Create a contingency table (diabetes v. LA decil)
table <- table(z_standard$diabetes_prev_bin, z_standard$LA_decile)

# Calculate probabilities
p_high <- table[2, "High"] / sum(table[, "High"])
p_low <- table[2, "Low"] / sum(table[, "Low"])

# Calculate relative risk
relative_risk <- p_high / p_low
relative_risk

# Logistic regression model
logistic_model <- glm(diabetes_prev_bin ~ d_pch + d_ogs + canopy_cover + LA_decile, data = z_standard, family = binomial)

# Summary of the model
summary(logistic_model)

# SDG Presentation --------------------------------------------------------

library(GWmodel)
library(lwgeom)
library(spgwr)
library(spdep)
library(spatialreg)

# Create a spatial weights matrix using Queen contiguity
coords <- st_coordinates(z_standard)
nb <- poly2nb(z_standard)
lw <- nb2listw(nb, style="W", zero.policy = T)

# Define the formula
formula <- diabetes_prev ~ d_pch + d_ogs + canopy_cover + LA_pct

# OLS Regression
ols_model <- lm(formula, data = z_standard)
summary(ols_model)

# Spatial Lag Model (SLM)
slm_model <- lagsarlm(formula, data = z_standard, listw = lw, zero.policy = T)
summary(slm_model)

# Spatial Error Model (SEM)
sem_model <- errorsarlm(formula, data = z_standard, listw = lw, zero.policy = T)
summary(sem_model)

# Define the bandwidth for GWR
gwr_bandwidth <- gwr.sel(formula, data = z_standard, coords = coords, adapt = T)

# GWR Model
gwr_model <- gwr(formula, data = z_standard, coords = coords, adapt = gwr_bandwidth, hatmatrix=T)

summary(gwr_model)

# Check for spatial autocorrelation in residuals
moran.test(residuals(ols_model), lw)

# Check for validity
validity <- st_is_valid(z)
invalid_geometries <- z[!validity, ]

# Print invalid geometries if any
print(invalid_geometries)


# Convert multipolygon to points (centroids)
sf_points <- st_centroid(sf_data)

# Convert sf object to SpatialPointsDataFrame
sp_points <- as(sf_points, "Spatial")

# Select the optimal bandwidth
bandwidth <- bw.gwr(formula, data = sp_points)

# Select the optimal bandwidth
bandwidth <- gwr.sel(formula, data = sp_points)

# Perform GWR
gwr_model <- gwr(formula, data = sp_points, bandwidth = bandwidth)
