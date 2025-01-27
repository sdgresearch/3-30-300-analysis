
# Packages ----------------------------------------------------------------

library(tidyverse)
library(sf)
library(scales)
library(patchwork)
library(ggbump)
library(GGally)
library(ggbeeswarm)
library(ggstatsplot)
library(BBmisc)
library(corrplot)
library(factoextra)

source("scripts/constants.R")

# Paths -------------------------------------------------------------------

T3_30_300_DIR <-  here(VECTOR_OUT_DIR, "3-30-300")
t3_30_300_path <-  here(T3_30_300_DIR, "T3_30_300.geojson")

lsoa_to_bua_path <- here(TABULAR_IN_DIR, "ONS", "LSOA_(2021)_to_Built_Up_Area_to_Local_Authority_District_to_Region_(December_2022)_Lookup_in_England_and_Wales_v2.csv")
lad_to_bua_path <- here(VECTOR_IN_DIR, "ONS", "Local_Authority_Districts_December_2022_UK_BUC_V2_-1856850221694639751.geojson")

# Variables ---------------------------------------------------------------

t3_30_300_vars <- list('3' = list('plot_label' = '3 \nTree Count',
                                  'number' = 3, 'variable' = 'tree_count',
                                  'breaks' = c(1, 3, 10, 100, 500, 2000)),
                       '30' = list('plot_label' = '30 \nCanopy Cover (%)',
                                   'number' = 30, 'variable' = 'canopy_cover',
                                   'breaks' = c(1, 5, 10, 30, 60)),
                       '300' = list('plot_label' = '300 \nDistance to Park (m)',
                                    'number' = 300, 'variable' = 'park_distance',
                                    'breaks' = c(50, 150, 300 , 500, 1000, 2000, 
                                                 5000, 10000, 25000)))

plot_theme <- theme_bw(base_size = 12, base_family = "Helvetica") +
    theme(
        plot.title = element_text(size = 16, face = "bold"),
        axis.text = element_text(size = 7),
        axis.title = element_text(size = 8),
        panel.grid.minor = element_blank()
    )

# Processing --------------------------------------------------------------

t3_30_300_gdf <- read_sf(t3_30_300_path) |> 
    # filter(RGN22CD != 'E12000007') |> # London = E12000007
    select(-c("TotPop", "DepChi", "Pop16_59", "Pop60+", "WorkPop")) |> 
    mutate(park_distance = if_else(park_distance == -99, NA, park_distance),
           IMD_Decile = as_factor(IMD_Decile),
           RGN22NM = fct_relevel(RGN22NM, c('North West', 'North East',
                                            'Yorkshire and The Humber',
                                            'West Midlands', 'East Midlands',
                                            'East of England', 'South West',
                                            'South East', 'London', NA))) 

t3_30_300_long_df <- t3_30_300_gdf |> 
    st_drop_geometry() |> 
    pivot_longer(cols = NDVI:NDBI, names_to = 'spectral', values_to = 'spectral_value') |> 
    pivot_longer(cols = canopy_cover:park_distance, names_to = 't3_metric', values_to = 't3_value') #|>
    # pivot_longer(cols = Total:Pop_density, names_to = 'population', values_to = 'pop_value') |> 
    # pivot_longer(cols = contains('Score'), names_to = 'IMD_metric', values_to = 'IMD_score') |>
    # pivot_longer(cols = contains('Dec'), names_to = 'IMD_decile', values_to = 'IMD_decile_value') |>
    # pivot_longer(cols = contains('Rank'), names_to = 'IMD_rank', values_to = 'IMD_rank_value')

green_metric <- '3'
spectral_metric <- 'NDVI'
population_metric <- 'Total'
imd_metric <- 'IMDScore'

esquisse::esquisser()

# Box Plots ---------------------------------------------------------------

plot_boxplots_3_30_300 <- function(green_metric, plot_legend = T, x_axis = T) {
    
    res_plot <- t3_30_300_gdf |> 
        filter(!is.na(RGN22NM)) |> 
        ggplot() +
        aes(x = RGN22NM, y = !!sym(t3_30_300_vars[[green_metric]][['variable']]), fill = IMD_Decile) +
        geom_boxplot() +
        geom_hline(aes(yintercept = t3_30_300_vars[[green_metric]][['number']]),
                   linetype = 'dashed') +
        scale_fill_brewer(palette = "RdYlBu", direction = 1) +
        scale_y_continuous(trans = "log", breaks = t3_30_300_vars[[green_metric]][['breaks']]) +
        scale_x_discrete(labels = function(x) str_wrap(x, width = 8)) +
        labs(
            x = NULL,
            y = t3_30_300_vars[[green_metric]][['plot_label']],
            fill = "IMD Decile"
        ) + 
        guides(fill = guide_legend(nrow = 1)) +
        plot_theme +
        theme(
            legend.position = ifelse(plot_legend, "bottom", 'none')
            )
    
    if (!x_axis) {
        res_plot <- res_plot +
            theme(
                axis.title.x = element_blank(),
                axis.text.x = element_blank(),
                axis.ticks.x = element_blank()
            )
    } else {
        res_plot <- res_plot +
            theme(
                axis.title.x = element_text(size = 8),
                axis.text.x = element_text(size = 7, hjust = 0.5, vjust = 0.5),
                axis.ticks.x = element_line(linewidth = 0.5)
            )
    }
        return(res_plot)
}

t3_region_boxplots <- plot_boxplots_3_30_300('3', plot_legend = F, x_axis = F)
t30_region_boxplots <- plot_boxplots_3_30_300('30', plot_legend = F, x_axis = F)
t300_region_boxplots <- plot_boxplots_3_30_300('300', plot_legend = T, x_axis = T)

t3_30_300_region_boxplots <- t3_region_boxplots / t30_region_boxplots / t300_region_boxplots

ggsave("images/t3_30_300_region_boxplots.png", t3_30_300_region_boxplots, 
       width = 180, height = 170, units = 'mm', dpi = 300)

# Rank Map ----------------------------------------------------------------

lsoa_to_bua_df <- read_csv(lsoa_to_bua_path)
lad_to_bua_gdf <- read_sf(lad_to_bua_path)

rgn22_gdf <- lad_to_bua_gdf |> 
    left_join(lsoa_to_bua_df |> 
                  select(LAD22CD, RGN22CD, RGN22NM), by = c('LAD22CD' = 'LAD22CD')) |>
    select(RGN22CD, RGN22NM, geometry) |> 
    group_by(RGN22CD, RGN22NM) |> 
    summarise() |> 
    mutate(RGN22NM = if_else(RGN22NM == 'Wales', NA, RGN22NM)) |>
    mutate(RGN22NM = fct_relevel(RGN22NM, c('North West', 'North East',
                                            'Yorkshire and The Humber',
                                            'West Midlands', 'East Midlands',
                                            'East of England', 'South West',
                                            'South East', 'London', NA))) |> 
    filter(!is.na(RGN22NM))

t3_30_300_rank_gdf <- t3_30_300_gdf |> 
    st_drop_geometry() |> 
    select(RGN22CD, ends_with('Score'), park_distance, water_distance,
           tree_count, canopy_cover, NDVI, NDBI, NDWI, area, Total) |> 
    filter(!is.na(RGN22CD), RGN22CD != 'W92000004') |> 
    group_by(RGN22CD) |> 
    summarise(across(ends_with('Score'), mean, .names = '{.col}'),
              across(area:Total, sum, .names = '{.col}'),
              across(park_distance:NDWI, ~ mean(.x, na.rm = TRUE), .names = '{.col}')) |>
    mutate(across(IMDScore:water_distance, function(x) {rank(-x)}, .names = '{.col}_rank')) |> 
    mutate(across(tree_count:NDWI, function(x) {rank(x)}, .names = '{.col}_rank')) |> 
    mutate(IMD = as.character(IMDScore_rank)) |> 
    select(RGN22CD, IMD, ends_with('rank'))

t3_30_300_rank_long_gdf <- t3_30_300_rank_gdf |> 
    pivot_longer(ends_with('rank'), names_to = 'Metric', values_to = 'Rank') |> 
    mutate(Metric = fct_relevel(Metric, c('tree_count_rank', 'canopy_cover_rank', 
                                          'park_distance_rank', 'water_distance_rank',
                                          'NDVI_rank', 'NDWI_rank', 'NDBI_rank',
                                          'IMDScore_rank', 'IncScore_rank', 'EmpScore_rank',
                                          'EduScore_rank', 'HDDScore_rank', 'CriScore_rank',
                                          'BHSScore_rank', 'EnvScore_rank', 'area_rank',
                                          'Total_rank')))

x_start <- 2
x_span <- 2
metric_names <- c('3', '30', '300', 'Water \nDistance', 'NDVI', 'NDWI', 'NDBI', 'IMD')
text_labels_df <- tibble(metric_names, y = 56.3,
                         x = seq(x_start, x_start + x_span * (nrow(text_labels_df) - 1), x_span))

t3_30_300_rank_rgn_gdf <- t3_30_300_rank_gdf |> 
    left_join(st_geometry(rgn22_gdf) |> 
                  st_point_on_surface() |> 
                  st_coordinates() |>
                  as_tibble() |> bind_cols(rgn22_gdf |> select(RGN22CD, RGN22NM)), by = 'RGN22CD') |> 
    mutate_at(vars(ends_with('rank')), ~ normalize(., range = c(st_bbox(rgn22_gdf)$ymin, st_bbox(rgn22_gdf)$ymax),
                                                   method = 'range'))

t3_30_300_spectral_rank_map <- t3_30_300_rank_rgn_gdf |> 
    ggplot() +
    geom_sf(data = rgn22_gdf, fill = 'transparent') +
    geom_point(aes(x = X, y = Y, color = IMD)) +
    
    geom_sigmoid(linetype = 'dotted', aes(x = X, y = Y, xend = x_start + x_span * 0, yend = tree_count_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 0, y = tree_count_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 0, y = tree_count_rank, xend = x_start + x_span * 1, yend = canopy_cover_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 1, y = canopy_cover_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 1, y = canopy_cover_rank, xend = x_start + x_span * 2, yend = park_distance_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 2, y = park_distance_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 2, y = park_distance_rank, xend = x_start + x_span * 3, yend = water_distance_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 3, y = water_distance_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 3, y = water_distance_rank, xend = x_start + x_span * 4, yend = NDVI_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 4, y = NDVI_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 4, y = NDVI_rank, xend = x_start + x_span * 5, yend = NDWI_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 5, y = NDWI_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 5, y = NDWI_rank, xend = x_start + x_span * 6, yend = NDBI_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 6, y = NDBI_rank, color = IMD)) +
    
    geom_sigmoid(aes(x = x_start + x_span * 6, y = NDBI_rank, xend = x_start + x_span * 7, yend = IMDScore_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 7, y = IMDScore_rank, color = IMD)) +
    
    geom_text(aes(x = x_start + x_span * 7 + .5, y = IMDScore_rank, 
                  label = str_wrap(RGN22NM, width = 15)), size = 2, hjust = 0) +
    
    geom_text(data = text_labels_df, aes(x = x, y = y, label = metric_names), size = 2) +
    scale_x_continuous(limits = c(-5.5, 18)) +
    scale_color_brewer(palette = "RdYlBu") +
    guides(color = guide_legend(nrow = 1)) +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = 'transparent'),
          legend.position = "none",
          legend.title = element_text(size = 20),
          legend.text = element_text(size = 15))

ggsave("images/t3_30_300_spectral_rank_map.png", t3_30_300_spectral_rank_map, 
       width = 180, height = 90, units = 'mm', dpi = 300)


t3_30_300_rank_long_gdf |> 
    filter(Metric %in% c('tree_count_rank', 'canopy_cover_rank',
                         'park_distance_rank', 'water_distance_rank', 
                         'NDVI_rank', 'NDBI_rank', 'NDWI_rank', 'IMDScore_rank')) |> 
    left_join(t3_30_300_gdf |> 
                  st_drop_geometry() |> 
                  select(RGN22CD, RGN22NM), by = 'RGN22CD') |> 
    ggplot(aes(x = Metric, y = Rank, group = RGN22CD, colour = IMD)) + 
    geom_point(size = 3) +
    geom_bump(size = 2, smooth = 8) +
    # geom_text(aes(label = RGN22NM)) +
    # scale_y_reverse() +
    scale_y_continuous(breaks = 1:10) +
    scale_color_brewer(palette = 'RdYlBu') +
    labs(x = 'Metric', y = 'Rank') +
    plot_theme


# Low Scors -> High Ranking -> Low Deprivation
# High Score -> Low Ranking -> High Deprivation

# Scatter Plots -----------------------------------------------------------

t3_30_300_gdf |> 
    ggplot() +
    geom_point(aes(x = !!sym(spectral_metric), 
               y = !!sym(t3_30_300_vars[[green_metric]][['variable']]),
               color = IMD_Decile), alpha = .5) +
    geom_hline(aes(yintercept = t3_30_300_vars[[green_metric]][['number']]),
               linetype = 'dashed') +
    scale_y_continuous(transform = 'log',
                       breaks = trans_breaks("log", function(x) exp(x)),
                       labels = trans_format("log", function(x) format(exp(x),
                                                                       digits = 1, 
                                                                       scientific = F))) +
    scale_color_brewer(palette = 'RdYlBu') +
    labs(y = t3_30_300_vars[[green_metric]][['plot_label']], x = 'NDVI',
         color = 'IMD Decile') +
    plot_theme

plot_scatter <- function(gdf, x_var, y_var, colour_var, intercept, alpha, legend = T) {
    
    x_var <- !!sym(x_var)
    y_var <- !!sym(y_var)
    colour_var <- !!sym(colour_var)
    
    scatter_plot <- ggplot() +
        geom_point(aes(x = x_var,
                       y = y_var,
                       colour = factor(colour_var)), alpha = alpha) +
        geom_vline(aes(xintercept = intercept)) +
        scale_x_continuous(transform = 'log',
                           breaks = trans_breaks("log", function(x) exp(x)),
                           labels = trans_format("log", function(x) format(exp(x),
                                                                           digits = 1, 
                                                                           scientific = F))) +
        scale_color_brewer(palette = 'RdYlBu') +
        labs(x = t3_30_300_vars[[green_metric]][['plot_label']], y = 'IMD Score',
             colour = 'IMD Decile') +
        plot_theme
    
    return(scatter_plot)
}

t3_30_300_standard_df <- t3_30_300_gdf |> 
    st_drop_geometry() |> 
    mutate(park_distance = if_else(park_distance == -99, NA, park_distance)) |> 
    mutate(`3` = log(tree_count + 1),
           `30` = log(canopy_cover + 1),
           `300` = log(park_distance + 1)) |> 
    select(ends_with('Score'), ends_with('ratio'), area, TotPop_density,  starts_with('3')) |> 
    select(-IMDScore) |> 
    drop_na() 

t3_30_300_pca <- t3_30_300_standard_df |>
    prcomp(scale. = T)
    
t3_30_300_cor <- t3_30_300_standard_df |>
    cor(method = 'spearman') 

t3_30_300_pca |> 
    fviz_pca_var()

t3_30_300_cor |> 
    corrplot(method = "circle", type = "upper",# order = "hclust",
             tl.col = "black", tl.srt = 45)

