# Packages ----------------------------------------------------------------

source("R/utils/constants.R")
source("R/utils/paths.R")
load(here(T3_30_300_DIR, ".RData"))

library(dplyr)
library(tidyr)
library(forcats)
library(sf)
library(tidymodels)
library(ranger)
library(vip)
library(corrplot)
library(FactoMineR)
library(factoextra)
library(DescTools)
library(spdep)
library(spatialreg)

# Data Preparation -------------------------------------------------------

# z_score_normalize <- function(x) {
#     (x - mean(x)) / sd(x)
# }

# t3_30_300_lsoa_standard_df <- t3_30_300_lsoa_standard_df |> 
#     mutate(across(is.numeric, z_score_normalize))

t3_30_300_lsoa_srm_gdf <- t3_30_300_lsoa_gdf |> 
    select(LSOA11CD, Region = RGN22NM, Urban = Urban_rural_flag, tree_count_slope_gini, 
           canopy_cover, park_distance_manhattan, distance_manhattan_gini, water_distance, 
           distance_water_gini, tree_person_ratio, tree_area_ratio, NDVI, NDWI, NDBI, IMDScore, pop_density) |> 
    drop_na()

# Spatial Regression Models -----------------------------------------------

nb_lsoa <- poly2nb(t3_30_300_lsoa_srm_gdf, queen = TRUE, row.names = t3_30_300_lsoa_srm_gdf$LSOA11CD)
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
moran.test(t3_30_300_lsoa_srm_gdf_subset$distance_manhattan_gini, lw_lsoa_subset)
moran.test(t3_30_300_lsoa_srm_gdf_subset$distance_water_gini, lw_lsoa_subset)

vars_lst <- c("tree_count_slope_gini", "distance_water_gini", "distance_manhattan_gini")

sem_models <- list()
slm_models <- list()

for (var in vars_lst) { 
    print(var)
    formula <- paste(var, "~ IMDScore + Urban + Region + IMDScore*Urban + IMDScore*Region + pop_density + NDVI + NDWI + NDBI")
    sem_model <- errorsarlm(as.formula(formula),
                            data = t3_30_300_lsoa_srm_gdf_subset,
                            listw = lw_lsoa_subset)
    slm_model <- lagsarlm(as.formula(formula),
                          data = t3_30_300_lsoa_srm_gdf_subset,
                          listw = lw_lsoa_subset)
    sem_models[[var]] <- sem_model
    slm_models[[var]] <- slm_model
    print(paste("--------------------------------"))
}
saveRDS(sem_models, here(T3_30_300_DIR, "models", "sem_models.rds"))
saveRDS(slm_models, here(T3_30_300_DIR, "models", "slm_models.rds"))

sem_models <- readRDS(here(T3_30_300_DIR, "models", "sem_models.rds"))
slm_models <- readRDS(here(T3_30_300_DIR, "models", "slm_models.rds"))

# PCA ---------------------------------------------------------------------

t3_30_300_pca <- t3_30_300_lsoa_gdf |>
    select() |>
    prcomp(center = T, scale. = T)

explained_variance <- t3_30_300_pca$sdev^2 / sum(t3_30_300_pca$sdev^2)

# Select top k PCs that explain 90% variance
k <- which(cumsum(explained_variance) >= 0.70)[1]

# Extract loadings for the top k PCs
loadings <- abs(t3_30_300_pca$rotation[, 1:k])

# Weight by explained variance
weighted_loadings <- sweep(loadings, 2, explained_variance[1:k], "*")

# Sum across selected PCs
final_weights <- rowSums(weighted_loadings)

# Normalize weights to sum to 1
final_weights <- final_weights / sum(final_weights)

# Print final weights
final_weights


t3_30_300_pca |>
    fviz_pca_var()


# FAMD --------------------------------------------------------------------

t3_30_300_famd <- t3_30_300_standard_df |>
    # mutate(EnvDec = as.numeric(EnvDec)) |>
    select(-c(LSOA21CD, LAD22CD, RGN22CD, Pop_density, EnvDec)) |>
    FAMD(graph = F)

fviz_screeplot(t3_30_300_famd)
fviz_contrib(t3_30_300_famd, "var", axes = 1)
fviz_famd_var(t3_30_300_famd, repel = T)
fviz_mfa_ind(t3_30_300_famd, habillage = 'Urban_rural_flag', label = 'none')

t3_30_300_standard_df |> 
    cbind(t3_30_300_famd$ind$coord) |> 
    ggplot(aes(Dim.1, Dim.2, color = EnvDec, shape = Urban_rural_flag)) +
    geom_point(alpha=.5) +
    scale_color_brewer(palette = 'RdYlBu') +
    facet_wrap(~Urban_rural_flag)


# Get explained variance for each dimension
explained_variance <- t3_30_300_famd$eig[, 2] / sum(t3_30_300_famd$eig[, 2])  # Normalize variance explained

# View cumulative explained variance
cumsum(explained_variance)

# Extract contributions of variables to each dimension
var_contrib <- as.data.frame(t3_30_300_famd$var$contrib)

# Select top k dimensions explaining 90% variance
k <- which(cumsum(explained_variance) >= 0.60)[1]

# Extract only the top k dimensions
selected_contributions <- var_contrib[, 1:k]

# Multiply contributions by explained variance of each dimension
weighted_contributions <- sweep(selected_contributions, 2, explained_variance[1:k], "*")

# Sum across selected dimensions
final_weights <- rowSums(weighted_contributions)

# Normalize weights to sum to 1
final_weights <- final_weights / sum(final_weights)

# Print final weights
final_weights

# Convert categorical variables to numeric dummy variables
df <- t3_30_300_standard_df |>
    # mutate(EnvDec = as.numeric(EnvDec)) |>
    select(-c(LSOA21CD, LAD22CD, RGN22CD, Pop_density, EnvDec))
df_encoded <- model.matrix(~.-1, data = df)

# Compute the final index
df$Urban_Green_Index <- as.matrix(df_encoded)[,1:9] %*% final_weights

min_value <- min(df$Urban_Green_Index)

df_gini <- df |> 
    cbind(t3_30_300_standard_df |> 
              select(LSOA21CD, LAD22CD, RGN22CD, EnvDec)) |> 
    mutate(Urban_Green_Index = Urban_Green_Index - min_value)

df_gini_lad <- df_gini |> 
    group_by(LAD22CD) |> 
    summarise(Urban_Green_Index = Gini(Urban_Green_Index, unbiased = T))

lad_gdf <- t3_30_300_gdf |> 
    group_by(LAD22CD) |> 
    summarise(geometry = st_union(geometry))

# 0 is perfect equality and 1 is inequality

lad_gdf |> 
    left_join(df_gini_lad, by = 'LAD22CD') |> 
    ggplot(aes(fill = Urban_Green_Index)) +
    geom_sf() +
    scale_fill_distiller(palette = 'RdYlBu') +
    labs(fill = 'Green Gini Coefficient') +
    theme_minimal() +
    theme(legend.position = 'bottom')

# Correlation -------------------------------------------------------------

t3_30_300_cor <- t3_30_300_standard_df |>
    select(-c(LSOA21CD, RGN22CD, Pop_density, EnvDec, Urban_rural_flag)) |>
    cor(method = 'pearson')
p.mat <- cor_pmat(t3_30_300_cor, n = nrow(t3_30_300_standard_df) |> 
                      select(-c(LSOA21CD, RGN22CD, Pop_density, EnvDec, Urban_rural_flag)))

corrplot(t3_30_300_cor, method = 'circle', type = 'upper', 
           tl.col = 'black', p.mat = p.mat, sig.level = 0.05)

t3_30_300_cor_df <- as.data.frame(t3_30_300_cor) |> 
    mutate(IMD_var = colnames(t3_30_300_cor)) |>
    filter(str_detect(IMD_var, 'Score|density')) |> 
    select(IMD_var, `3`:NDBI) |> 
    pivot_longer(cols = `3`:NDBI, names_to = 'Env_var', values_to = 'value') |> 
    mutate(IMD_var = case_when(IMD_var == 'Pop_density' ~ 'Population \nDensity',
                               IMD_var == 'IMDScore' ~ 'IMD \n(overall)',
                               IMD_var == 'IncScore' ~ 'Income',
                               IMD_var == 'EmpScore' ~ 'Employment',
                               IMD_var == 'EduScore' ~ 'Education',
                               IMD_var == 'HDDScore' ~ 'Health',
                               IMD_var == 'CriScore' ~ 'Crime',
                               IMD_var == 'BHSScore' ~ 'Housing',
                               IMD_var == 'EnvScore' ~ 'Environment'),
           Env_var = case_when(Env_var == '3' ~ '3',
                               Env_var == '30' ~ '30',
                               Env_var == '300' ~ '300',
                               Env_var == 'water' ~ 'Water \nDistance',
                               Env_var == 'NDVI' ~ 'NDVI',
                               Env_var == 'NDWI' ~ 'NDWI',
                               Env_var == 'NDBI' ~ 'NDBI')) |> 
    mutate(IMD_var = fct_relevel(IMD_var, c('Population \nDensity', 'IMD \n(overall)',
                                            'Income', 'Employment', 'Education',
                                            'Health', 'Crime', 'Housing', 'Environment')),
           Env_var = fct_relevel(Env_var, rev(c('3', '30', '300', 'Water \nDistance',
                                                'NDVI', 'NDWI', 'NDBI'))))

t3_30_300_corrplot <- ggplot(t3_30_300_cor_df, aes(x = IMD_var, y = Env_var, fill = value)) +
    geom_tile(linewidth = .2, width = .95, height = .95, linejoin = 'round', color = 'black') +
    geom_text(aes(label = round(value, 2)), size = 3, color = 'black') +
    scale_fill_distiller(type = "div", palette = "PuOr") +
    scale_x_discrete(position = 'top') +
    # coord_fixed() +
    labs(x = NULL, y = NULL, fill = 'Spearman \nCorrelation') +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = 'transparent'),
          panel.grid = element_blank(),
          axis.text.y = element_text(size = 9, face = 'bold', hjust = 1),
          axis.text.x = element_text(size = 9, face = 'bold', vjust = .5),
          axis.ticks = element_blank(),
          legend.position = "bottom",
          legend.key.width = unit(1, "cm"),
          legend.key.height = unit(.5, "cm"),
          legend.title = element_text(size = 10, face = 'bold'),
          legend.text = element_text(size = 9))

t3_30_300_corrplot

ggsave("images/t3_30_300_corrplot.png", t3_30_300_corrplot, 
       width = 180, height = 90, units = 'mm', dpi = 300)

t3_30_300_cor |>
    corrplot(method = "circle", type = "upper",# order = "hclust",
             tl.col = "black", tl.srt = 45)

# Split the data into training and testing sets
set.seed(123)  # for reproducibility
data_split <- initial_split(t3_30_300_standard_df, prop = .8, strata = EnvDec)
train_data <- training(data_split)
test_data  <- testing(data_split)

# Start timing the script
start_time <- Sys.time()

rf_recipe <- recipe(EnvDec ~ ., data = train_data) %>%
    step_dummy(all_nominal(), -all_outcomes()) %>%
    step_zv(all_predictors())

rf_model_tune <- rand_forest(
    mtry = tune(),
    trees = tune(),
    min_n = tune()
) %>%
    set_engine("ranger", importance = "impurity") %>%
    set_mode("classification")

rf_workflow_tune <- workflow() %>%
    add_model(rf_model_tune) %>%
    add_recipe(rf_recipe)

rf_grid <- grid_regular(
    mtry(range = c(2, 8)),
    trees(range = c(100, 500)),
    min_n(range = c(5, 20)),
    levels = 5
)
print('Running model')
rf_tune_results <- rf_workflow_tune %>%
    tune_grid(
        resamples = vfold_cv(train_data, v = 5),
        grid = rf_grid
    )

best_rf <- rf_tune_results %>%
    select_best(metric = "roc_auc")

final_rf <- finalize_workflow(rf_workflow_tune, best_rf)

final_rf_fit <- final_rf %>%
    fit(train_data)

saveRDS(final_rf_fit, "final_rf_fit.rds")

final_rf_fit <- readRDS("final_rf_fit.rds")

final_rf_fit |> 
    extract_fit_parsnip() |> 
    vip() + 
    theme_minimal() +
    theme(axis.text.y = element_text(size = 9, face = 'bold', hjust = 1),
          axis.text.x = element_text(size = 9, vjust = .5),
          axis.title = element_text(size = 10, face = 'bold'),
          legend.title = element_text(size = 10))

# End timing the script
end_time <- Sys.time()
execution_time <- end_time - start_time
print(paste("Execution time:", execution_time))

# Aggregate and Pass DataFrame --------------------------------------------

t3_30_300_pass_df <- read_sf(t3_30_300_path) |> 
    st_drop_geometry() |> 
    mutate(pass_3 = if_else(tree_count > 3, 1, 0),
           pass_30 = if_else(canopy_cover > 30, 1, 0),
           pass_300 = if_else(park_distance < 300, 1, 0)) |> 
    select(LSOA21CD, LSOA11NM, LAD22CD, LAD22NM, pass_3, pass_30, pass_300,
           tree_count, canopy_cover, park_distance) |>
    mutate(pass_3_30 = if_else(pass_3 == 1 & pass_30 == 1, 1, 0),
           pass_3_300 = if_else(pass_3 == 1 & pass_300 == 1, 1, 0),
           pass_30_300 = if_else(pass_30 == 1 & pass_300 == 1, 1, 0),
           pass_all = if_else(pass_3 + pass_30 + pass_300 == 1, 1, 0)) |> 
    distinct(LSOA21CD, .keep_all = T) |> 
    arrange(desc(pass_all), desc(canopy_cover), park_distance, desc(tree_count))

t3_30_300_pass_agg_df <- t3_30_300_pass_df |>
    drop_na() |> 
    group_by(LAD22CD, LAD22NM) |>
    summarise(across(tree_count:pass_all, ~ 100 * round(mean(.x, na.rm = T), 3))) |> 
    arrange(desc(pass_all), desc(pass_30_300), desc(canopy_cover), park_distance) #|> 
mutate(Ranking = 1:nrow(.))

