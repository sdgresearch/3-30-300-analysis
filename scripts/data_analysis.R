
# Packages ----------------------------------------------------------------

library(tidyverse)
library(sf)
library(patchwork)
library(ggbump)
library(BBmisc)
library(esquisse)

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
        axis.text = element_text(size = 9),
        axis.title = element_text(size = 10, face = 'bold'),
        legend.title = element_text(size = 10, face = 'bold'),
        legend.text = element_text(size = 9),
        panel.grid.minor = element_blank()
    )

# Processing --------------------------------------------------------------

lsoa_2021_df <- lad_to_bua_gdf |>
    full_join(lsoa_to_bua_df, by = c('LAD22CD', 'LAD22NM')) |> 
    select(LSOA21CD, LSOA21NM, LAD22CD, LAD22NM, BUA22CD, BUA22NM, RGN22CD, RGN22NM, geometry) |> 
    filter(RGN22CD != 'W92000004') |> 
    st_drop_geometry()

t3_30_300_gdf <- read_sf(t3_30_300_path) |> 
    # filter(RGN22CD != 'E12000007') |> # London = E12000007
    select(-c("TotPop", "DepChi", "Pop16_59", "Pop60+", "WorkPop", LSOA21NM:RGN22NM)) |> 
    left_join(lsoa_2021_df, by = 'LSOA21CD') |> 
    mutate(
           park_distance = if_else(park_distance == -99, NA, park_distance),
           IMD_Decile = as_factor(IMD_Decile),
           across(ends_with('Dec'), as_factor, .names = "{.col}"),
           RGN22NM = fct_relevel(RGN22NM, c('North West', 'North East',
                                            'Yorkshire and The Humber',
                                            'West Midlands', 'East Midlands',
                                            'East of England', 'South West',
                                            'South East', 'London', NA))) |> 
    distinct(LSOA11CD, .keep_all = T)

t3_30_300_gdf |> write_sf(here(T3_30_300_DIR, "T3_30_300_cleaned.geojson"))

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

# Run for interactive plotting
# esquisser()

# Box Plots ---------------------------------------------------------------

plot_boxplots_3_30_300 <- function(green_metric, plot_legend = T, x_axis = T) {
    
    res_plot <- t3_30_300_gdf |> 
        filter(!is.na(RGN22NM)) |> 
        ggplot() +
        aes(x = RGN22NM, y = !!sym(t3_30_300_vars[[green_metric]][['variable']]), fill = IMD_Decile) +
        geom_boxplot(outlier.alpha = 0.3, outlier.size = 1, notch = T) +
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
            legend.position = ifelse(plot_legend, "top", 'none'),
            axis.title.x = element_blank()
            )
    
    if (!x_axis) {
        res_plot <- res_plot +
            theme(
                axis.text.x = element_blank(),
                axis.ticks.x = element_blank()
            )
    } else {
        res_plot <- res_plot +
            theme(
                axis.text.x = element_text(size = 9, hjust = 0.5, vjust = 0.5),
                axis.ticks.x = element_line(linewidth = 0.5)
            )
    }
        return(res_plot)
}

t3_region_boxplots <- plot_boxplots_3_30_300('3', plot_legend = T, x_axis = F)
t30_region_boxplots <- plot_boxplots_3_30_300('30', plot_legend = F, x_axis = F)
t300_region_boxplots <- plot_boxplots_3_30_300('300', plot_legend = F, x_axis = T)

(t3_30_300_region_boxplots <- t3_region_boxplots / t30_region_boxplots / t300_region_boxplots)

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
           tree_count, canopy_cover, NDVI, NDWI, NDBI, area, Total) |> 
    filter(!is.na(RGN22CD), RGN22CD != 'W92000004') |> 
    group_by(RGN22CD) |> 
    summarise(across(ends_with('Score'), mean, .names = '{.col}'),
              across(area:Total, sum, .names = '{.col}'),
              across(park_distance:NDBI, ~ mean(.x, na.rm = TRUE), .names = '{.col}')) |>
    mutate(across(IMDScore:water_distance, function(x) {rank(-x)}, .names = '{.col}_rank'),
           across(tree_count:NDWI, function(x) {rank(x)}, .names = '{.col}_rank'),
           NDBI_rank = rank(-NDBI),
           IMD = as_factor(IMDScore_rank)) |> 
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
metric_names <- c('3', '30', '300', 'Water \nDistance', 'NDVI', 'NDWI', 'NDBI', 'Env \nDeprivation')
text_labels_df <- tibble(metric_names, y = 56.3,
                         x = seq(x_start, x_start + x_span * (length(metric_names) - 1), x_span))

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
    
    geom_sigmoid(aes(x = x_start + x_span * 6, y = NDBI_rank, xend = x_start + x_span * 7, yend = EnvScore_rank, group = RGN22CD, color = IMD)) +
    geom_point(aes(x = x_start + x_span * 7, y = EnvScore_rank, color = IMD)) +
    
    geom_text(aes(x = x_start + x_span * 7 + .5, y = EnvScore_rank, 
                  label = str_wrap(RGN22NM, width = 15)), size = 3, hjust = 0) +
    
    geom_text(data = text_labels_df, aes(x = x, y = y, label = metric_names), size = 3) +
    scale_x_continuous(limits = c(-5.5, 19)) +
    scale_color_brewer(palette = "PiYG") +
    labs(color = 'IMD Ranking') +
    guides(color = guide_legend(nrow = 1)) +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = 'transparent'),
          legend.position = "bottom",
          legend.title = element_text(size = 10, face = 'bold'),
          legend.text = element_text(size = 9))

t3_30_300_spectral_rank_map

ggsave("images/t3_30_300_spectral_rank_map.png", t3_30_300_spectral_rank_map, 
       width = 180, height = 90, units = 'mm', dpi = 300)


# t3_30_300_rank_long_gdf |> 
#     filter(Metric %in% c('tree_count_rank', 'canopy_cover_rank',
#                          'park_distance_rank', 'water_distance_rank', 
#                          'NDVI_rank', 'NDBI_rank', 'NDWI_rank', 'IMDScore_rank')) |> 
#     left_join(t3_30_300_gdf |> 
#                   st_drop_geometry() |> 
#                   select(RGN22CD, RGN22NM), by = 'RGN22CD') |> 
#     ggplot(aes(x = Metric, y = Rank, group = RGN22CD, colour = IMD)) + 
#     geom_point(size = 3) +
#     geom_bump(size = 2, smooth = 8) +
#     # geom_text(aes(label = RGN22NM)) +
#     # scale_y_reverse() +
#     scale_y_continuous(breaks = 1:10) +
#     scale_color_brewer(palette = 'RdYlBu') +
#     labs(x = 'Metric', y = 'Rank') +
#     plot_theme

# Low Score -> High Ranking -> Low Deprivation
# High Score -> Low Ranking -> High Deprivation


# 3-30-300 LAD Maps -------------------------------------------------------

lad22_gdf <- lad_to_bua_gdf |> 
    left_join(lsoa_to_bua_df |> 
                  select(LAD22CD, RGN22CD, RGN22NM), by = c('LAD22CD' = 'LAD22CD')) |>
    select(LAD22CD, LAD22NM, geometry) |> 
    group_by(LAD22CD, LAD22NM) |> 
    summarise()

t3_30_300_lad_gdf <- lad22_gdf |> 
    right_join(t3_30_300_gdf |> 
                   st_drop_geometry() |> 
                   filter(!is.na(RGN22CD), RGN22CD != 'W92000004') |> 
                   select(LAD22CD, ends_with('Score'), park_distance, water_distance,
                          tree_count, canopy_cover, NDVI, NDWI, NDBI, area, Total) |> 
                   group_by(LAD22CD) |> 
                   summarise(across(ends_with('Score'), mean, .names = '{.col}'),
                             across(area:Total, sum, .names = '{.col}'),
                             across(park_distance:NDBI, ~ mean(.x, na.rm = TRUE), .names = '{.col}')), 
               by = 'LAD22CD')

(t3_lad22_map <- ggplot(t3_30_300_lad_gdf) + 
        geom_sf(aes(fill = tree_count)) +
        scale_fill_distiller(palette = "Greens", direction = 1) +
        labs(title = '3 Visible Trees', fill = NULL) + 
        theme_void() +
        theme(legend.position = 'bottom'))

(t30_lad22_map <- ggplot(t3_30_300_lad_gdf) + 
        geom_sf(aes(fill = canopy_cover)) +
        scale_fill_distiller(palette = "Greens", direction = 1) +
        labs(title = '30% Canopy Cover', fill = NULL) + 
        theme_void() +
        theme(legend.position = 'bottom'))

(t300_lad22_map <- ggplot(t3_30_300_lad_gdf) + 
        geom_sf(aes(fill = park_distance)) +
        scale_fill_distiller(palette = "Greens", direction = -1) +
        labs(title = '300 m from Public Park', fill = NULL) + 
        theme_void() +
        theme(legend.position = 'bottom'))


t3_30_300_lad22_map <- t3_lad22_map | t30_lad22_map | t300_lad22_map

ggsave("images/t3_30_300_lad22_map.png", t3_30_300_lad22_map, 
       width = 180, height = 90, units = 'mm', dpi = 300)

# Scatter Plots -----------------------------------------------------------

format_number <- function(x) {
    case_when(
        x < 1000 ~ paste0(x),
        x == 1000 ~ "1K",
        x < 1000000 ~ paste0(as.integer(format(x / 1000L)), "K"),
        TRUE ~ as.character(x)
    )
}

plot_scatter_3_30_300 <- function(x_var, y_var, color_var, 
                                  x_axis_scale, y_axis_scale,
                                  x_breaks, y_breaks, x_label, y_label, 
                                  x_threshold, y_threshold, 
                                  x_axis = T, y_axis = T, 
                                  x_text_position = 'bottom', y_text_position = 'left',
                                  alpha_val = .5, size_val =.5) {

    res_plot <- t3_30_300_gdf |> 
        ggplot() +
        geom_point(aes(x = !!sym(x_var), y = !!sym(y_var), color = !!sym(color_var)),
                   alpha = .5, size = size_val) +
        # geom_smooth(aes(x = !!sym(x_var), y = !!sym(y_var), !!sym(color_var)),
        #             method = 'lm', se = F, size = .5) +
        scale_x_continuous(transform = x_axis_scale, breaks = x_breaks,
                           labels = format_number, position = x_text_position) +
        scale_y_continuous(transform = y_axis_scale, breaks = y_breaks,
                           labels = format_number, position = y_text_position) +
        scale_color_brewer(palette = 'RdYlBu') +
        labs(x = x_label, y = y_label,
             color = 'IMD Decile') +
        plot_theme + theme(legend.position = 'none')
    
    if (x_threshold) {
        res_plot <- res_plot +
            geom_vline(aes(xintercept = x_threshold), linetype = 'dashed')
    }
    
    if (y_threshold) {
        res_plot <- res_plot +
            geom_hline(aes(yintercept = y_threshold), linetype = 'dashed')
    }
    
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
                axis.text.x = element_text(size = 7),
                axis.ticks.x = element_line(linewidth = 0.5)
            )
    }
    
    if (!y_axis) {
        res_plot <- res_plot +
            theme(
                axis.title.y = element_blank(),
                axis.text.y = element_blank(),
                axis.ticks.y = element_blank()
            )
    } else {
        res_plot <- res_plot +
            theme(
                axis.text.y = element_text(size = 7),
                axis.ticks.y = element_line(linewidth = 0.5)
            )
    }
    
    return(res_plot)
}

scatter_vars <- c('tree_count', 'canopy_cover', 'park_distance', 
                  'water_distance', 'NDVI', 'NDWI', 'NDBI')
scatter_labels <- list('tree_count' = '3', 'canopy_cover' = '30 (%)',
                       'park_distance' = '300 (m)', 'water_distance' = 'Water Distance (m)',
                       'NDVI' = 'NDVI', 'NDWI' = 'NDWI', 'NDBI' = 'NDBI')
scatter_breaks <- list('tree_count' = c(1, 3, 100, 2000), 
                       'canopy_cover' = c(1, 5, 30), 
                       'park_distance' = c(50, 300, 2000, 5000, 20000), 
                       'water_distance' = c(20, 100, 500, 2000, 5000),
                       'NDVI' = seq(-.5, 1, .25),
                       'NDWI' = seq(-.75, .5, .25),
                       'NDBI' = seq(-.5, .25, .25))
scatter_thresholds <- c('tree_count' = 3, 'canopy_cover' = 30, 'park_distance' = 300)

x_var = 'tree_count'
y_var = 'canopy_cover'
color_var = 'IMD_Decile'
x_breaks = scatter_breaks[[x_var]]
x_label = scatter_labels[[x_var]]
y_breaks = scatter_breaks[[y_var]]
y_label = scatter_labels[[y_var]]
x_axis_scale = 'log'
x_threshold = scatter_thresholds[[x_var]]
y_axis_scale = 'log'
y_threshold = scatter_thresholds[[y_var]]
x_axis = F
y_axis = T
x_text_position = 'bottom'
y_text_position = 'left'
alpha_val = .5
size_val =.5
first_plot <- plot_scatter_3_30_300(x_var, y_var, color_var,
                                    x_axis_scale, y_axis_scale, x_breaks, y_breaks,
                                    x_label, y_label,
                                    x_threshold, y_threshold, 
                                    x_axis, y_axis,
                                    x_text_position, y_text_position,
                                    alpha_val, size_val)
(scatter_plots <- first_plot)

for (i in seq_along(scatter_vars)) {
    for (j in seq_along(scatter_vars)) {
        
        x_var = scatter_vars[i]
        y_var = scatter_vars[j]
            
        x_breaks = scatter_breaks[[x_var]]
        x_label = scatter_labels[[x_var]]
        y_breaks = scatter_breaks[[y_var]]
        y_label = scatter_labels[[y_var]]
        
        if (x_var %in% c('tree_count', 'canopy_cover', 'park_distance')) {
            x_axis_scale = 'log'
            # x_threshold = T
            x_threshold <- scatter_thresholds[[x_var]]
        } else if (x_var == 'water_distance') {
            x_axis_scale = 'log'
            x_threshold = F
            # y_threshold_val <- NULL
        } else {
            x_axis_scale = 'identity'
            x_threshold = F
            # y_threshold_val <- NULL
        }
        
        if (y_var %in% c('tree_count', 'canopy_cover', 'park_distance')) {
            y_axis_scale = 'log'
            # y_threshold = T
            y_threshold <- scatter_thresholds[[y_var]]
        } else if (y_var == 'water_distance') {
            y_axis_scale = 'log'
            y_threshold = F
            # y_threshold_val <- NULL
        } else {
            y_axis_scale = 'identity'
            y_threshold = F
            # y_threshold_val <- NULL
        }
        
        if (j == length(scatter_vars)) {
            x_axis = T
        } else {
            x_axis = F
        }
        
        if (i == 1) {
            y_axis = T
        } else {
            y_axis = F
        }
        
        # if (i + 1 == j) {
        #     x_text_position = 'top'
        #     y_text_position = 'right'
        #     x_axis = T
        #     x_label = NULL
        #     y_axis = T
        #     y_label = NULL
        # } else {
        #     x_text_position = 'bottom'
        #     y_text_position = 'left'
        # }
        

        if ((i == 1 && j == 2) || i == j) {
            next
        }
        if (i == length(scatter_vars)) {
            next
        }
        
        if (i > j) {
            temp_plot <- plot_spacer()
            
            # if (i %in% 5:6 && j == 2) {
            #     legend_df <- tibble(EnvDec = as_factor(1:10), 
            #                         x = 1:10,
            #                         y = 1,
            #                         brewer_color = brewer.pal(10, 'RdYlBu'))
            #     
            #     if (i == 5) {
            #         legend_clip_df <- legend_df |> filter(x %in% 1:5)
            #     } else if (i == 6) {
            #         legend_clip_df <- legend_df |> filter(x %in% 6:10)
            #     }
            #     temp_plot <- legend_clip_df |> 
            #         ggplot(aes(x = x, y = y, colour = EnvDec, colour = brewer_color)) + 
            #         geom_point(size = 2, alpha = alpha_val) + 
            #         geom_text(aes(label = EnvDec, y = y + .3), colour = 'black') +
            #         scale_colour_identity() + 
            #         theme_void() + theme(legend.position = 'none')
            # }
        }
        else {
            temp_plot <- plot_scatter_3_30_300(x_var, y_var, color_var,
                                               x_axis_scale, y_axis_scale, x_breaks, y_breaks,
                                               x_label, y_label,
                                               x_threshold, y_threshold, 
                                               x_axis, y_axis,
                                               x_text_position, y_text_position,
                                               alpha_val, size_val)
        }
        scatter_plots <- scatter_plots + temp_plot
    }
}

(t3_30_300_scatter_plots <- scatter_plots + 
    plot_layout(ncol = length(scatter_vars) - 1, nrow = length(scatter_vars) - 1, byrow = F) & 
    theme(plot.margin = unit(c(1, .5, 1, .5), "mm")))

ggsave("images/t3_30_300_scatter_plots.png", t3_30_300_scatter_plots, 
       width = 180, height = 180, units = 'mm', dpi = 300)
