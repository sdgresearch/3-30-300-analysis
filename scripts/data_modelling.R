# Packages ----------------------------------------------------------------

library(tidyverse)
library(forcats)
library(sf)
library(tidymodels)
library(ranger)
library(vip)
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
    # select(EnvDec, `3`, `30`, `300`, water, NDVI, NDWI, NDBI, Pop_density) |> 
select(ends_with('Score'), Pop_density, `3`, `30`, `300`, water, NDVI, NDWI, NDBI,
#        # area, ends_with('ratio')
       ) |>
# select(-IMDScore) |>
    drop_na()
t3_30_300_pca <- t3_30_300_standard_df |>
    prcomp(scale. = T)

t3_30_300_pca |>
    fviz_pca_var()

t3_30_300_cor <- t3_30_300_standard_df |>
    cor(method = 'pearson')

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
    select(LSOA11CD, LSOA11NM, LAD22CD, LAD22NM, pass_3, pass_30, pass_300,
           tree_count, canopy_cover, park_distance) |>
    mutate(pass_3_30 = if_else(pass_3 == 1 & pass_30 == 1, 1, 0),
           pass_3_300 = if_else(pass_3 == 1 & pass_300 == 1, 1, 0),
           pass_30_300 = if_else(pass_30 == 1 & pass_300 == 1, 1, 0),
           pass_all = if_else(pass_3 + pass_30 + pass_300 == 1, 1, 0)) |> 
    distinct(LSOA11CD, .keep_all = T) |> 
    arrange(desc(pass_all), desc(canopy_cover), park_distance, desc(tree_count))

t3_30_300_pass_agg_df <- t3_30_300_pass_df |>
    drop_na() |> 
    group_by(LAD22CD, LAD22NM) |>
    summarise(across(tree_count:pass_all, ~ 100 * round(mean(.x, na.rm = T), 3))) |> 
    arrange(desc(pass_all), desc(pass_30_300), desc(canopy_cover), park_distance) #|> 
mutate(Ranking = 1:nrow(.))

