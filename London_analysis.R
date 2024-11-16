library(terra)
library(ggtext)
source('constants.R')

spectral_indexes_path <- here(RASTER_OUTPUT_DIR, "spectral_indexes",
                              "NDBI_NDVI_NDWI_London.tif")

london_imd_guppd_path <- here(VECTOR_OUTPUT_DIR, "imd", "London_GUPPD_LSOA_IMD.shp")

spectral_indexes_rast <- rast(spectral_indexes_path)

london_imd_guppd_vect <- vect(london_imd_guppd_path)

spectral_indexes_rast <- project(spectral_indexes_rast, crs(london_imd_guppd_vect))

zonal_stats <- extract(spectral_indexes_rast, london_imd_guppd_vect,
                       fun = "mean", na.rm = T)

zonal_df <- cbind(london_imd_guppd_vect, zonal_stats)

model_spectral_df <- model_df |> 
    filter(lsoa %in% zonal_df$lsoa11cd) |> 
    left_join(as_tibble(zonal_df) |> 
                  select(lsoa11cd, NDVI, NDWI, NDBI), by = join_by(lsoa == lsoa11cd)) |> 
    rename('T3' = d_pch, 'T30' = canopy_cover, 'T300' = d_ogs)
    
# AI4ER Symposium ---------------------------------------------------------

# Create a spatial weights matrix using Queen contiguity
coords <- st_coordinates(model_spectral_df)
nb <- poly2nb(model_spectral_df, row.names = model_spectral_df$lsoa)
lw <- nb2listw(nb, style = "W", zero.policy = T)


matrix_path <- here(SERIALISED_OUTPUT_DIR, "n_matrix_london.rds")

nb2INLA(matrix_path, nb)
g <- inla.read.graph(filename = matrix_path)

model_spectral_df$idareau <- 1:nrow(model_spectral_df)
model_spectral_df$idareav <- 1:nrow(model_spectral_df)

model_variables <- list("T3_30_300" = c("T3", "T30", "T300"), 
                        "IMDScore" = "IMDScore", 
                        "IMDs" = c("IncScore", "EmpScore", "EduScore", "HDDScore", "CriScore", "BHSScore", "EnvScore"),
                        "Spectral" = c("NDVI", "NDWI", "NDBI"),
                        "IncScore" = "IncScore", "EmpScore" = "EmpScore", 
                        "EduScore" = "EduScore", "HDDScore" = "HDDScore", 
                        "CriScore" = "CriScore", "BHSScore" = "BHSScore", 
                        "EnvScore" = "EnvScore", "T3" = "T3", "T30" = "T30", "T300" = "T300",
                        "NDVI" = "NDVI", "NDWI" = "NDWI", "NDBI" = "NDBI")

define_formulas <- function(y_variable, x_variables_groups) {
    
    formulas <- list()
    
    formulas[['Null']] <- as.formula(paste(y_variable, "~ 1"))
    
    for (group in names(x_variables_groups)) {
        
        variables <- x_variables_groups[[group]]
        
        temp_formula <- as.formula(paste(y_variable, "~", paste(variables, collapse = ' + ')))
        formulas[[group]] <- temp_formula
        
        for (variable in variables) {
            
            temp_formula <- as.formula(paste(y_variable, "~", variable))
            formulas[[variable]] <- temp_formula
        }
    }
    
    combination <- combn(x_variables_groups, m = 2, simplify = F)
    
    for (element in combination) {
        
        comb_name <- paste(sort(names(element), decreasing = T), collapse = '_')
        
        temp_formula <- as.formula(paste(y_variable, "~", paste(element[[1]], collapse = ' + '),
                                         ' + ', paste(element[[2]], collapse = ' + ')))
        formulas[[comb_name]] <- temp_formula
    }
    
    return(formulas)
}

(formulas <- define_formulas('diabetes_prev', model_variables))

for(name in names(formulas)) {
    
    if ((str_count(name, 'Score') == 2 || str_count(name, 'IMD') == 2) || 
        (str_detect(name, 'IMDScore.+Score|Score.+IMDScore')) || 
        (str_count(name, 'Score') == 2 || str_count(name, 'ND.I') == 2) ||
        (str_detect(name, 'ND.I') && str_detect(name, 'T3')) || 
        (str_count(name, 'T3') > 1)) {
        print(name)
        formulas2[name] <- NULL
    }
}

run_gwr <- function(formula, dataframe, ...) {
    
    bandwidth <- bw.gwr(formula, data = dataframe, adapt = F, parallel.method = 'cluster')
    gwr <- gwr.basic(formula,
                     data = dataframe,
                     bw = bandwidth,
                     kernel = "gaussian")
    
    return(gwr)
}

for (model in names(formulas)) {
    
    gwr_name <- paste0(model, '_gwr')
    print('GWR')
    temp_gwr <- run_gwr(formulas[[model]], model_spectral_df|>
                            as_Spatial(IDs = 'lsoa'))
    
    assign(gwr_name, temp_gwr, envir = .GlobalEnv)
    write_rds(gwr_name, here(SERIALISED_OUTPUT_DIR, paste0("london_", gwr_name, ".rds")))
    
    inla_name <- paste0(model, '_inla')
    inla_formula <- update(formulas[[model]], diabetes_qof ~ . + f(idareau, model = 'besag',
                                                                   graph = g, scale.model = T) +
                               f(idareav, model = 'iid'))
    
    print('INLA')
    temp_inla <- inla(inla_formula,
                      family = "gaussian", data = model_spectral_df, E = diabetes_expected,
                      control.predictor = list(compute = T),
                      control.compute = list(return.marginals.predictor = T, dic = T, waic = T, cpo = T))
    
    assign(inla_name, temp_inla, envir = .GlobalEnv)
    write_rds(inla_name, here(SERIALISED_OUTPUT_DIR, paste0("london_", inla_name, ".rds")))
}

gwr_models <- setNames(lapply(paste0(names(formulas), '_gwr'), get), paste0(names(formulas), '_gwr'))

inla_models <- setNames(lapply(paste0(names(formulas), '_inla'), get), paste0(names(formulas), '_inla'))

library(purrr)

gwr_models_df <- map_df(gwr_models2, function(x) {

    AIC <- x$GW.diagnostic$AIC
    BIC <- x$GW.diagnostic$BIC
    R2 <- x$GW.diagnostic$gw.R2
    
    return(tibble(AIC, BIC, R2))
    })
gwr_models_df$model_formula <- names(gwr_models)

inla_models_df <- map_df(inla_models, function(x) {
    
    DIC <- x$dic$dic
    WAIC <- x$waic$waic
    mlik <- x$mlik[2]
    
    return(tibble(DIC, WAIC, mlik))
})

inla_models_df$model_formula <- names(inla_models)

tidy_dataframe <- function(dataframe, model_name) {
    
    clean_df <- dataframe |> 
        filter(!(str_detect(model_formula, 'IMDs') & str_detect(model_formula,'Score'))) |> 
        mutate(model_formula = str_replace(model_formula, paste0('_', model_name), '') |> 
                   str_replace('T3_30_300', 'T330300')) |> 
        # separate(model_formula, c('A', 'B')) |>
        mutate(Green_var = case_when(str_detect(model_formula, 'T330300') ~ '3-30-300',
                                     str_detect(model_formula, 'T300') ~ 'T300',
                                     str_detect(model_formula, 'T30') ~ 'T30',
                                     str_detect(model_formula, 'T3') ~ 'T3',
                                     str_detect(model_formula, 'Spectral') ~ 'Spectral',
                                     str_detect(model_formula, 'NDVI') ~ 'NDVI',
                                     str_detect(model_formula, 'NDBI') ~ 'NDBI',
                                     str_detect(model_formula, 'NDWI') ~ 'NDWI') |> 
                   factor(levels = c('3-30-300', 'T3', 'T30', 'T300', 
                                     'Spectral', 'NDVI', 'NDBI', 'NDWI')),
               IMD_var = case_when(str_detect(model_formula, 'IMDs') ~ 'IMDs',
                                   str_detect(model_formula, 'IMDScore') ~ 'IMDScore',
                                   str_detect(model_formula, 'Inc|Emp|Edu|HDD|BHS|Cri|Env') ~ str_extract(model_formula, '(.{3})Score'))) |> 
        mutate(IMD_var = case_when(IMD_var == 'IncScore' ~ 'Income',
                                   IMD_var == 'EmpScore' ~ 'Employment',
                                   IMD_var == 'EduScore' ~ 'Health',
                                   IMD_var == 'HDDScore' ~ 'Education',
                                   IMD_var == 'BHSScore' ~ 'Housing',
                                   IMD_var == 'CriScore' ~ 'Crime',
                                   IMD_var == 'EnvScore' ~ 'Environment',
                                   IMD_var == 'IMDScore' ~ 'IMDScore',
                                   IMD_var == 'IMDs' ~ 'IMDs') |> 
                   factor(levels = c('IMDs', 'IMDScore', 'Income', 
                                     'Employment', 'Health', 'Education',
                                     'Housing', 'Crime', 'Environment'))) |> 
        mutate(Green_cat = case_when(Green_var %in% c('3-30-300', 'T3', 'T30', 'T300') ~ '3-30-300',
                                     Green_var %in% c('Spectral', 'NDVI', 'NDBI', 'NDWI') ~ 'Spectral'),
               IMD_cat = case_when(IMD_var == 'IMDScore' ~ 'IMD Score',
                                   IMD_var == 'IMDs' ~ 'IMD Total',
                                   .default = 'IMD Component'))
    
    return(clean_df)
}

gwr_models_clean_df <- tidy_dataframe(gwr_models_df, 'gwr')
inla_models_clean_df <- tidy_dataframe(inla_models_df, 'inla')

gwr_models_clean_df |> 
    mutate(AIC_rank = rank(AIC),
           BIC_rank = rank(BIC),
           R2_rank = rank(-R2)) |> 
    filter(IMD_cat == 'IMD Component') |> 
    ggplot(aes(x = Green_var, y = IMD_var)) + 
    geom_tile(aes(fill = R2, width = .9, height = .9), colour = '#262626') +
    geom_text(aes(label = R2_rank), size = 7) +
    scale_fill_distiller(palette = 'Greens', direction = 1, 
                         limits = range(gwr_models_clean_df$R2)) +
    coord_equal() +
    labs(x = NULL, y = NULL, fill = 'R<sup>2</sup>') +
    theme_minimal() +
    theme(
        panel.grid = element_blank(),
        legend.title = element_markdown(),
        legend.position = 'none',
        axis.text = element_markdown(size = 20, face = 'bold')
    )

gwr_models_clean_df |> 
    mutate(AIC_rank = rank(AIC),
           BIC_rank = rank(BIC),
           R2_rank = rank(-R2)) |> 
    filter(IMD_cat != 'IMD Component') |> 
    ggplot(aes(x = Green_var, y = IMD_var)) + 
    geom_tile(aes(fill = R2, width = .9, height = .9), colour = '#262626') +
    # geom_text(aes(label = R2_rank), size = 7) +
    scale_fill_distiller(palette = 'Greens', direction = 1, 
                         limits = range(gwr_models_clean_df$R2)) +
    coord_equal() +
    labs(x = NULL, y = NULL, fill = 'R<sup>2</sup>') +
    theme_minimal() +
    theme(
        panel.grid = element_blank(),
        legend.title = element_markdown(size = 20, face = 'bold'),
        
        # legend.text = element_text(size = 10),
        legend.text = element_text(size = 15),   # Increase legend text size
        legend.key.size = unit(1.5, 'cm'),       # Increase legend key size
        legend.key.height = unit(2, 'cm'), 
        axis.text = element_markdown(size = 20, face = 'bold')
    )


inla_models_clean_df |> 
    mutate(DIC_rank = rank(DIC),
           WAIC_rank = rank(WAIC),
           mlik_rank = rank(-mlik)) |> 
    filter(IMD_cat == 'IMD Component') |> 
    ggplot(aes(x = Green_var, y = IMD_var)) + 
    geom_tile(aes(fill = mlik, width = .9, height = .9), colour = '#262626') +
    geom_text(aes(label = DIC_rank), size = 7) +
    scale_fill_distiller(palette = 'Oranges', direction = -1, 
                         limits = range(inla_models_clean_df$mlik)) +
    coord_equal() +
    labs(x = NULL, y = NULL, fill = 'R<sup>2</sup>') +
    theme_minimal() +
    theme(
        panel.grid = element_blank(),
        legend.title = element_markdown(),
        legend.position = 'none',
        axis.text = element_markdown(size = 20, face = 'bold')
    )

inla_models_clean_df |> 
    mutate(DIC_rank = rank(DIC),
           WAIC_rank = rank(WAIC),
           mlik_rank = rank(-mlik)) |> 
    filter(IMD_cat != 'IMD Component') |> 
    ggplot(aes(x = Green_var, y = IMD_var)) + 
    geom_tile(aes(fill = mlik, width = .9, height = .9), colour = '#262626') +
    geom_text(aes(label = DIC_rank), size = 7) +
    scale_fill_distiller(palette = 'Oranges', direction = -1, 
                         limits = range(inla_models_clean_df$mlik)) +
    coord_equal() +
    labs(x = NULL, y = NULL, fill = 'DIC') +
    theme_minimal() +
    theme(
        panel.grid = element_blank(),
        legend.title = element_markdown(size = 20, face = 'bold'),
        
        # legend.text = element_text(size = 10),
        legend.text = element_text(size = 15),   # Increase legend text size
        legend.key.size = unit(1.5, 'cm'),       # Increase legend key size
        legend.key.height = unit(2, 'cm'), 
        axis.text = element_markdown(size = 20, face = 'bold')
    )

library(ggbump)

model_bump_df <- model_spectral_df |> 
    st_drop_geometry() |> 
    group_by(IMD_Decile) |> 
    summarise(across(c(T3:diabetes_prev, NDVI:NDBI), ~ mean(.x, na.rm = T))) |> 
    mutate(T3_Rank = rank(-T3, ties.method = 'first'),
           T300_Rank = rank(-T300, ties.method = 'first'),
           T30_Rank = rank(T30, ties.method = 'first'),
           diabetes_prev_Rank = rank(-diabetes_prev, ties.method = 'first'),
           NDVI_Rank = rank(NDVI, ties.method = 'first'),
           NDBI_Rank = rank(-NDBI, ties.method = 'first'),
           NDWI_Rank = rank(NDWI, ties.method = 'first')
           # IMD_Rank = rank(-IMDScore, ties.method = 'first')
    ) |> 
    select(IMD_Decile, ends_with('Rank'), T3, T300, T30, diabetes_prev) |> 
    rename(`3` = 'T3_Rank', `30` = 'T30_Rank', `300` = 'T300', 
           NDVI = 'NDVI_Rank', NDBI = 'NDBI_Rank', NDWI = 'NDWI_Rank',
           Diabetes = diabetes_prev_Rank, IMD = IMD_Decile) |> 
    mutate(IMD_Decile = IMD,
           IMD_fact = as.character(IMD_Decile)) |> 
    pivot_longer(cols = IMD:NDWI, names_to = 'Metric', values_to = 'Rank') |> 
    mutate(Metric = factor(Metric, 
                           levels = c("IMD", "3", "30", "300", "NDVI",
                                      "NDBI", "NDWI", "Diabetes"),
                           ordered = T))

ggplot(model_bump_df, aes(x = Metric, y = Rank, color = factor(IMD_Decile), group = IMD_fact)) + 
    geom_point(size = 3) +
    geom_bump(size = 2, smooth = 8) +
    # scale_y_reverse() +
    scale_y_continuous(breaks = 1:10) +
    scale_color_brewer(palette = 'RdYlBu') +
    labs(x = 'Metric', y = 'Rank') +
    theme_minimal() +
    theme(
        # panel.background = element_rect(fill = '#000000'),
        # plot.background = element_rect(fill = '#000000'),
        plot.margin = unit(c(1, 1, 0.5, 1), "cm"),
        panel.grid = element_blank(),
        axis.ticks = element_blank(),
        
        # axis.text.y = element_text(color = 'white', size = 20, hjust = 0.5),
        # axis.text.y.right = element_text(color = 'white', size = 20, hjust = 0.5),
        axis.text.y = element_blank(),
        axis.text.x = element_text(color = 'black', size = 15),
        plot.title = element_text(face = 'bold', colour = 'black', size = 20),
        plot.subtitle = element_text(colour = 'black', size = 15),
        plot.caption = element_text(colour = 'black', size = 10),
        plot.caption.position = "plot",
        legend.background = element_rect(fill = '#000000'),
        legend.text = element_text(face = 'bold', color = 'black', size = 15),
        legend.position = 'bottom',
        legend.key = element_rect(fill = '#000000'),
        legend.spacing.x = unit(.5, "cm"),
        legend.key.size = unit(2, "cm")
    ) +
    theme(legend.position = "none")
