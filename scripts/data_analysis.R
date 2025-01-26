
# Packages ----------------------------------------------------------------

library(tidyverse)
library(sf)
library(scales)
library(patchwork)
library(ggbump)
library(GGally)
library(ggbeeswarm)
library(ggstatsplot)
library(corrplot)
library(factoextra)

source("scripts/constants.R")


# Paths -------------------------------------------------------------------

T3_30_300_DIR <-  here(VECTOR_OUT_DIR, "3-30-300")
t3_30_300_path <-  here(T3_30_300_DIR, "T3_30_300.geojson")


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

# Rank Map ----------------------------------------------------------------

t3_30_300_rank_gdf <- t3_30_300_gdf |> 
    st_drop_geometry() |> 
    select(RGN22CD, ends_with('Score'), Total:Pop_density, tree_count, canopy_cover, park_distance,
           water_distance, NDVI, NDBI, NDWI) |> 
    filter(!is.na(RGN22CD), RGN22CD != 'W92000004') |> 
    group_by(RGN22CD) |> 
    summarise(across(ends_with('Score'), mean, .names = '{.col}'),
              across(Total:Pop_density, sum, .names = '{.col}'),
              across(canopy_cover:water_distance, ~ mean(.x, na.rm = TRUE), .names = '{.col}')) |> 
    mutate(across(IMDScore:park_distance, function(x) {rank(-x)}, .names = '{.col}_rank')) |> 
    mutate(across(tree_count_rank:canopy_cover_rank, function(x) {n() + 1 - x}, .names = '{.col}')) |>
    mutate(IMD = as.character(IMDScore_rank)) |> 
    select(RGN22CD, IMD, ends_with('rank')) |> 
    pivot_longer(ends_with('rank'), names_to = 'Metric', values_to = 'Rank')
    # select(ends_with('Score'), ends_with('ratio'), area, TotPop_density,  starts_with('3'))
    # mutate(across(I))

t3_30_300_rank_gdf |> 
    filter(Metric %in% c('IMDScore_rank', 'tree_count_rank',
                         'canopy_cover_rank', 'park_distance_rank')) |> 
    mutate(Metric = factor(Metric, 
                           levels = c('IMDScore_rank', 'tree_count_rank',
                                      'canopy_cover_rank', 'park_distance_rank'),
                           ordered = T)) |> 
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

pacman::p_load(BBmisc, tidyverse, hablar, ggbump, sf, rnaturalearth, feather, janitor, lubridate)
options(stringsAsFactors = F)
set_wd_to_script_path()

gdpr_violations <- readr::read_tsv('https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2020/2020-04-21/gdpr_violations.tsv')

df <- gdpr_violations %>% 
    group_by(name) %>% 
    summarise(price = sum_(price)) %>% 
    ungroup()

sdf <- rnaturalearthdata::countries50 %>% 
    st_as_sf() %>% 
    st_crop(xmin = -24, xmax = 31, ymin = 33, ymax = 73) %>% 
    filter(admin %in% df$name) %>% 
    left_join(df, by = c("admin" = "name")) %>% 
    mutate(price_cap  = price / pop_est,
           admin = case_when(admin == "United Kingdom" ~ "UK",
                             admin == "Czech Republic" ~ "Czech",
                             T ~ admin))

ranking <- st_geometry(sdf) %>% 
    st_point_on_surface() %>% 
    st_coordinates() %>% 
    as_tibble() %>% 
    bind_cols(tibble(fine_cap = normalize(rank(sdf$price_cap), range = c(40.12161, 66.12161), method = "range"),
                     country = sdf$admin,
                     xend = 60,
                     x_axis_start = xend + 10,
                     fine_cap_x = normalize(sdf$price_cap, range = c(first(x_axis_start), 100), method = "range"),
                     val_txt = paste0(format(sdf$price_cap, digits = 1, nsmall = 2)),
                     val_txt2 = if_else(country == "Austria", paste0(val_txt, "€ per capita"), val_txt)
                     )
              )

sdf <- sdf %>% 
    bind_cols(ranking %>% select(fine_cap))

ggplot() + 
    geom_sf(data = sdf, size = .3, fill = "transparent", color = "gray17") +
    # Sigmoid from country to start of barchart
    geom_sigmoid(data = ranking, 
                 aes(x = X, y = Y, xend = x_axis_start - .2, yend = fine_cap, group = country, color = fine_cap), 
                 alpha = .6, smooth = 10, size = 1) + 
    # Line from xstart to value
    geom_segment(data = ranking, 
                 aes(x = x_axis_start, y = fine_cap, xend = fine_cap_x, yend = fine_cap, color = fine_cap), alpha = .6, size = 1, 
                 lineend = "round") + 
    # Y axis - black line
    geom_segment(data = ranking, 
                 aes(x = x_axis_start, y = 40, xend = x_axis_start, yend = 67), alpha = .6, size = 1.3, color = "black") +
    # dot on centroid of country in map
    geom_point(data = ranking, 
               aes(x = X, y = Y, color = fine_cap), size = 2) +
    # Country text
    geom_text(data = ranking, aes(x = x_axis_start-.5, y = fine_cap, label = country, color = fine_cap), hjust = 1, size = 2.5, nudge_y = .5) +
    # Value text
    geom_text(data = ranking, aes(x = fine_cap_x, y = fine_cap, label = val_txt2, color = fine_cap), hjust = 0, size = 2, nudge_x = .4) +
    coord_sf(clip = "off") +
    scale_fill_viridis_c() +
    scale_color_viridis_c() +
    theme_void() +
    labs(title = "GDPR fines per capita",
         subtitle = str_wrap("The General Data Protection Regulation (EU) 2016/679 (GDPR) is a regulation in EU law on data protection and privacy in the European Union (EU) and the European Economic Area (EEA).", 100),
         caption = "Source: TidyTuesday & Wikipedia") +
    theme(plot.margin = margin(.5, 1, .5, .5, "cm"),
          legend.position = "none",
          plot.background = element_rect(fill = "black"),
          plot.caption = element_text(color = "gray40"),
          plot.title = element_text(color = "gray40", size = 16, family = "Helvetica", face = "bold"),
          plot.subtitle = element_text(color = "gray40", size = 8))

