# Packages ----------------------------------------------------------------

library(tidyverse)
library(forcats)
library(sf)
library(tidymodels)
library(ranger)
library(corrplot)
library(factoextra)

source("scripts/constants.R")

# Paths -------------------------------------------------------------------

T3_30_300_DIR <-  here(VECTOR_OUT_DIR, "3-30-300")
t3_30_300_path <-  here(T3_30_300_DIR, "T3_30_300.geojson")

# Variables ---------------------------------------------------------------

t3_30_300_standard_df <- read_sf(t3_30_300_path) |> 
    st_drop_geometry() |> 
    mutate(park_distance = if_else(park_distance == -99, NA, park_distance),
           EnvDec = as_factor(EnvDec),
           `3` = log(tree_count + 1),
           `30` = log(canopy_cover + 1),
           `300` = log(park_distance + 1),
           water = log(water_distance + 1),
           across(ends_with('Score'), scale, .names = "{.col}"),
           Pop_density = round(Pop_density * 1000, 2)) |> 
    distinct(LSOA11CD, .keep_all = T) |>
    select(EnvDec, `3`, `30`, `300`, water, NDVI, NDWI, NDBI, Pop_density) |> 
# select(ends_with('Score'), `3`, `30`, `300`, water, NDVI, NDWI, NDBI, Pop_density,
#        # area, ends_with('ratio')
#        ) |>
# select(-IMDScore) |>
    drop_na()
# t3_30_300_pca <- t3_30_300_standard_df |>
#     prcomp(scale. = T)

# t3_30_300_pca |> 
#     fviz_pca_var()

# t3_30_300_cor <- t3_30_300_standard_df |>
#     cor(method = 'spearman') 

# t3_30_300_cor |> 
#     corrplot(method = "circle", type = "upper",# order = "hclust",
#              tl.col = "black", tl.srt = 45)

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

# End timing the script
end_time <- Sys.time()
execution_time <- end_time - start_time
print(paste("Execution time:", execution_time))