# Packages ----------------------------------------------------------------

source("R/utils/constants.R")
source("R/utils/paths.R")
load(here(T3_30_300_DIR, ".RData"))

library(dplyr)
library(tidyr)
library(readr)
library(forcats)
library(stringr)
library(ggplot2)
library(arrow)
library(geoarrow)
library(sf)
library(cowplot)
library(patchwork)
library(ggcorrplot)
library(corrplot)
library(ggpubr)
library(ggmagnify)
library(biscale)
library(BBmisc)
library(esquisse)
library(DescTools)
library(ggbump)
library(ggalluvial)
library(RColorBrewer)
library(kableExtra)
library(classInt)

# Plot Theme ---------------------------------------------------------------

plot_theme <- theme_bw(base_size = 12, base_family = "Helvetica") +
    theme(
        plot.title = element_text(size = 16, face = "bold"),
        axis.text = element_text(size = 9),
        axis.title = element_text(size = 10, face = "bold"),
        legend.title = element_text(size = 10, face = "bold"),
        legend.text = element_text(size = 9),
        panel.grid.minor = element_blank()
    )
# Box Plots ---------------------------------------------------------------

plot_boxplots_3_30_300 <- function(t3_30_300_lsoa_gdf, green_metric, plot_legend = TRUE, x_axis = TRUE, facet = TRUE) {

    t3_30_300_vars <- list("3" = list("plot_label" = "3 \nTree Count",
                                  "number" = 3, "variable" = "tree_count_25m",
                                  "breaks" = c(1, 3, 10, 50, 100, 200)),
                       "30" = list("plot_label" = "30 \nCanopy Cover (%)",
                                   "number" = 30, "variable" = "canopy_cover",
                                   "breaks" = c(1, 5, 10, 30, 60)),
                       "300" = list("plot_label" = "300 \nDistance to Park (m)",
                                    "number" = 300,
                                    "variable" = "park_distance_manhattan",
                                    "breaks" = c(50, 150, 300,
                                                 500, 1000, 2000,
                                                 5000, 10000, 25000)))

    res_plot <- t3_30_300_lsoa_gdf  |> 
        filter(!is.na(IMD_Decile))|> 
        filter(Urban_rural_flag == "Urban") |>
        mutate(RGN22NM = if_else(!is.na(IOL22NM), IOL22NM, RGN22NM)) |> 
        mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                                "Yorkshire and The Humber",
                                                "West Midlands", "East Midlands",
                                                "East of England", "South West",
                                                "South East", "Outer London",
                                                "Inner London"))) |> 
        ggplot() +
        aes(x = RGN22NM, y = !!sym(t3_30_300_vars[[green_metric]][["variable"]]), fill = IMD_Decile) +
        geom_boxplot(outlier.alpha = 0.3, outlier.size = 1, notch = TRUE) +
        geom_hline(aes(yintercept = t3_30_300_vars[[green_metric]][["number"]]),
                   linetype = "dashed") +
        scale_fill_brewer(palette = "RdYlBu", direction = 1) +
        scale_y_continuous(trans = "log", breaks = t3_30_300_vars[[green_metric]][["breaks"]]) +
        scale_x_discrete(labels = function(x) str_wrap(x, width = 8)) +
        labs(
            x = NULL,
            y = t3_30_300_vars[[green_metric]][["plot_label"]],
            fill = "IMD Decile"
        ) + 
        guides(fill = guide_legend(nrow = 1)) +
        plot_theme +
        theme(
            legend.position = ifelse(plot_legend, "top", "none"),
            axis.title.x = element_blank()
            )
    
    # if (facet) {
    #     res_plot <- res_plot + facet_wrap(~Urban_rural_flag, scales = "free_x")
    # }
    
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

t3_region_boxplots <- plot_boxplots_3_30_300(t3_30_300_lsoa_gdf, "3", plot_legend = TRUE, x_axis = FALSE)
t30_region_boxplots <- plot_boxplots_3_30_300(t3_30_300_lsoa_gdf, "30", plot_legend = FALSE, x_axis = FALSE)
t300_region_boxplots <- plot_boxplots_3_30_300(t3_30_300_lsoa_gdf, "300", plot_legend = FALSE, x_axis = TRUE)

t3_30_300_region_boxplots <- t3_region_boxplots / t30_region_boxplots / t300_region_boxplots

ggsave("images/t3_30_300_region_urban_boxplots.png", t3_30_300_region_boxplots, 
       width = 180, height = 180, units = "mm", dpi = 300)

# Correlation Matrix -------------------------------------------------------

corr_matrix <- cor(t3_30_300_standard_df |> 
                   select(where(is.numeric), -Pop_density, -tree_person_ratio, -IMDScore) |> 
                   drop_na(), method = "pearson")

corr_plot <- corrplot(corr_matrix, outline = TRUE,
         method = "color", col = brewer.pal(n = 10, name = "BrBG"),
         insig = "blank", type = "upper", diag = FALSE,
         tl.col = "black", tl.srt = 45) + 
         coord_flip()

corr_plot <- ggcorrplot(corr_matrix, type = "lower", lab = TRUE, legend.title = expression(rho),
     outline.col = "black", col = c("#bf812d", "#f5f5f5", "#35978f")) + 
     scale_y_discrete(limits=rev, position = "right") + 
     scale_x_discrete(position = "top") +
    #  coord_flip() +
     theme(panel.grid.major = element_blank(), 
     legend.position = "none",
     legend.title = element_text(size = 10, face = "bold"),
     legend.text = element_text(size = 7), 
     axis.text.x = element_text(hjust = 0),
     axis.text = element_text(size = 7, face = "bold"))

ggsave("images/t3_30_300_corr_plot.png", corr_plot, 
       width = 180, height = 180, units = "mm", dpi = 300)

# Scatter Plots -----------------------------------------------------------

format_number <- function(x) {
    case_when(
        x < 1000 ~ paste0(x),
        x == 1000 ~ "1K",
        x < 1000000 ~ paste0(as.integer(format(x / 1000L)), "K"),
        TRUE ~ as.character(x)
    )
}

plot_scatter_3_30_300 <- function(t3_30_300_lsoa_gdf, x_var, y_var, color_var, 
                                  x_axis_scale, y_axis_scale,
                                  x_breaks, y_breaks, x_label, y_label, 
                                  x_threshold, y_threshold, 
                                  x_axis = TRUE, y_axis = TRUE, 
                                  x_text_position = "bottom", y_text_position = "left",
                                  alpha_val = .5, size_val =.5, legend_position = "none") {

    res_plot <- t3_30_300_lsoa_gdf |> 
        filter(Urban_rural_flag == "Urban") |>
        ggplot() +
        geom_point(aes(x = !!sym(x_var), y = !!sym(y_var), color = !!sym(color_var)),
                   alpha = .5, size = size_val) +
        scale_x_continuous(transform = x_axis_scale, breaks = x_breaks,
                           labels = format_number, position = x_text_position) +
        scale_y_continuous(transform = y_axis_scale, breaks = y_breaks,
                           labels = format_number, position = y_text_position) +
        scale_color_brewer(palette = "RdYlBu") +
        labs(x = x_label, y = y_label,
             color = "IMD Decile") +
        plot_theme + theme(legend.position = legend_position)
    
    if (x_threshold) {
        res_plot <- res_plot +
            geom_vline(aes(xintercept = x_threshold), linetype = "dashed")
    }
    
    if (y_threshold) {
        res_plot <- res_plot +
            geom_hline(aes(yintercept = y_threshold), linetype = "dashed")
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

scatter_vars <- c("tree_count_25m", "canopy_cover", "park_distance_manhattan", 
                  "water_distance", "NDVI", "NDWI", "NDBI")
scatter_labels <- list("tree_count_25m" = "3", "canopy_cover" = "30 (%)",
                       "park_distance_manhattan" = "300 (m)", "water_distance" = "Water Distance (m)",
                       "NDVI" = "NDVI", "NDWI" = "NDWI", "NDBI" = "NDBI")
scatter_breaks <- list("tree_count_25m" = c(1, 3, 5, 10, 100, 2000), 
                       "canopy_cover" = c(1, 5, 30), 
                       "park_distance_manhattan" = c(50, 300, 2000, 5000, 20000), 
                       "water_distance" = c(20, 100, 500, 2000, 5000),
                       "NDVI" = seq(-.5, 1, .25),
                       "NDWI" = seq(-.75, .5, .25),
                       "NDBI" = seq(-.5, .25, .25))
scatter_thresholds <- c("tree_count_25m" = 3, "canopy_cover" = 30, "park_distance_manhattan" = 300)

x_var <- "tree_count_25m"
y_var <- "canopy_cover"
color_var <- "IMD_Decile"
x_breaks <- scatter_breaks[[x_var]]
x_label <- scatter_labels[[x_var]]
y_breaks <- scatter_breaks[[y_var]]
y_label <- scatter_labels[[y_var]]
x_axis_scale <- "log"
x_threshold <- scatter_thresholds[[x_var]]
y_axis_scale <- "log"
y_threshold <- scatter_thresholds[[y_var]]
x_axis <- FALSE
y_axis <- TRUE
x_text_position <- "bottom"
y_text_position <- "left"
alpha_val <- .5
size_val <- .5
first_plot <- plot_scatter_3_30_300(t3_30_300_lsoa_gdf, x_var, y_var, color_var,
                                    x_axis_scale, y_axis_scale, x_breaks, y_breaks,
                                    x_label, y_label,
                                    x_threshold, y_threshold,
                                    x_axis, y_axis,
                                    x_text_position, y_text_position,
                                    alpha_val, size_val)

scatter_plots <- first_plot
plot_list <- list()
plot_list[[1]] <- first_plot
for (i in seq_along(scatter_vars)) {
    for (j in seq_along(scatter_vars)) {
        
        x_var <- scatter_vars[i]
        y_var <- scatter_vars[j]
        
        x_breaks <- scatter_breaks[[x_var]]
        x_label <- scatter_labels[[x_var]]
        y_breaks <- scatter_breaks[[y_var]]
        y_label <- scatter_labels[[y_var]]

        if (x_var %in% c("tree_count_25m", "canopy_cover", "park_distance_manhattan")) {
            x_axis_scale <- "log"
            # x_threshold = TRUE
            x_threshold <- scatter_thresholds[[x_var]]
        } else if (x_var == "water_distance") {
            x_axis_scale <- "log"
            x_threshold <- FALSE
            # y_threshold_val <- NULL
        } else {
            x_axis_scale <- "identity"
            x_threshold <- FALSE
            # y_threshold_val <- NULL
        }
        
        if (y_var %in% c("tree_count_25m", "canopy_cover", "park_distance_manhattan")) {
            y_axis_scale <- "log"
            # y_threshold = TRUE
            y_threshold <- scatter_thresholds[[y_var]]
        } else if (y_var == "water_distance") {
            y_axis_scale <- "log"
            y_threshold <- FALSE
            # y_threshold_val <- NULL
        } else {
            y_axis_scale <- "identity"
            y_threshold <- FALSE
            # y_threshold_val <- NULL
        }
        
        if (j == length(scatter_vars)) {
            x_axis <- TRUE
        } else {
            x_axis <- FALSE
        }
        
        if (i == 1) {
            y_axis <- TRUE
        } else {
            y_axis <- FALSE
        }
        
        if ((i == 1 && j == 2) || i == j) {
            next
        }
        if (i == length(scatter_vars)) {
            next
        }
        
        if (i > j) {
            temp_plot <- plot_spacer()
        }
        else {
            temp_plot <- plot_scatter_3_30_300(t3_30_300_lsoa_gdf, x_var, y_var, color_var,
                                               x_axis_scale, y_axis_scale, x_breaks, y_breaks,
                                               x_label, y_label,
                                               x_threshold, y_threshold, 
                                               x_axis, y_axis,
                                               x_text_position, y_text_position,
                                               alpha_val, size_val)
            
        }       
        scatter_plots <- scatter_plots + temp_plot
        # plot_list[[length(plot_list) + 1]] <- temp_plot
    }
}

legend_plot <- get_legend(
    plot_scatter_3_30_300(t3_30_300_lsoa_gdf |> filter(!is.na(IMD_Decile)), 
                          x_var, y_var, color_var,
                          x_axis_scale, y_axis_scale, x_breaks, y_breaks,
                          x_label, y_label,
                          x_threshold, y_threshold,
                          x_axis, y_axis,
                          x_text_position, y_text_position,
                          alpha_val, size_val, legend_position = "bottom") + 
    guides(color = guide_legend(nrow = 1, override.aes = list(size = 5)))) |> 
    as_ggplot() + theme_void()

t3_30_300_scatter_plots <- scatter_plots + 
        plot_layout(ncol = length(scatter_vars) - 1, nrow = length(scatter_vars) - 1, byrow = FALSE) & 
        theme(plot.margin = unit(c(1, .5, 1, .5), "mm")) 

t3_30_300_scatter_plots_legend <- plot_grid(t3_30_300_scatter_plots, legend_plot, 
                                            ncol = 1, rel_heights = c(1, .1),
                                            align = "v", axis = "l")

ggsave("images/t3_30_300_scatter_urban_plots.png", t3_30_300_scatter_plots_legend, 
       width = 180, height = 180, units = "mm", dpi = 300)

# 3-30-300 LSOA Maps -------------------------------------------------------

t3_lsoa_map <- t3_30_300_lsoa_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        # filter(RGN22NM == "London") |> 
        ggplot() + 
        geom_sf(aes(fill = tree_count_25m, colour = tree_count_25m)) +
        scale_fill_distiller(palette = "Greens", direction = 1) +
        scale_colour_distiller(palette = "Greens", direction = 1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = "Visible\nTrees", fill = NULL) + 
        guides(colour = "none") +
        theme_void() +
        theme(legend.position = "bottom") + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99)

t30_lsoa_map <- t3_30_300_lsoa_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        # filter(RGN22NM == "London") |> 
        ggplot() + 
        geom_sf(aes(fill = canopy_cover, colour = canopy_cover)) +
        scale_fill_distiller(palette = "Greens", direction = 1) +
        scale_colour_distiller(palette = "Greens", direction = 1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = 'Canopy\nCover') + 
        guides(colour = "none") +
        theme_void() +
        theme(legend.position = c(.15, .5)) + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .001, alpha = .99)

t300_lsoa_map <- t3_30_300_lsoa_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        # filter(RGN22NM == "London") |> 
        ggplot() + 
        geom_sf(aes(fill = park_distance_manhattan, colour = park_distance_manhattan)) +
        scale_fill_distiller(palette = "Greens", direction = -1) +
        scale_colour_distiller(palette = "Greens", direction = -1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = "Distance\nto Park", fill = NULL) + 
        guides(colour = "none") +
        theme_void() +
        theme(legend.position = "bottom") + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                     shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99)

t3_30_300_lad_map <- t3_lsoa_map | t30_lsoa_map | t300_lsoa_map

ggsave("images/t3_30_300_lsoa_map.png", t3_30_300_lad_map, 
       width = 180, height = 90, units = "mm", dpi = 300)

# Gini Biscale plots -------------------------------------------------------

water_distance_gini_map <- t3_30_300_lad_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        ggplot() + 
        geom_sf(aes(fill = distance_water_gini, colour = distance_water_gini)) +
        scale_fill_distiller(palette = "BrBG", direction = -1) +
        scale_colour_distiller(palette = "BrBG", direction = -1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = 'Water\ndistance\nGini') + 
        guides(colour = "none") +
        theme_void() +
        theme(legend.position = c(.15, .5)) + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99)

ggsave("images/water_distance_gini_lad_map.png", water_distance_gini_map, 
       width = 180, height = 210, units = "mm", dpi = 300)


t30_breaks <- classIntervals(t3_30_300_lsoa_gdf$canopy_cover,
    n = 9, style = "fisher")$brks |> 
    round(3)

t30_breaks[1] <- min(t3_30_300_lsoa_gdf$canopy_cover, na.rm = TRUE)  # Replace first break with actual minimum
t30_breaks[length(t30_breaks)] <- max(t3_30_300_lsoa_gdf$canopy_cover, na.rm = TRUE)

# Step 2: Categorize data into Jenks bins
t3_30_300_lsoa_gdf <- t3_30_300_lsoa_gdf |> 
  mutate(canopy_cover_jenks = cut(canopy_cover, 
    breaks = t30_breaks, include.lowest = TRUE, right = TRUE, 
    labels = sprintf("%.1f", tail(t30_breaks, -1))))

canopy_cover_hist <- t3_30_300_lsoa_gdf |> 
    filter(!is.na(canopy_cover_jenks)) |> 
    ggplot() +
    geom_bar(aes(x = canopy_cover_jenks, fill = canopy_cover_jenks)) +
    # scale_x_discrete(limits = rev(levels(t3_30_300_lsoa_gdf$tree_person_ratio_jenks))) +
    # scale_y_sqrt(breaks = c(1, 10, 25, 50, 100)) +
    scale_y_sqrt(breaks = c(100, 1000, 2000, 5000, 8000), labels = function(x) paste0(x / 1000, "k")) +
    scale_fill_manual(values = colorRampPalette(brewer.pal(9, "YlGn"))(9), 
        guide = "none") + 
    coord_flip() + 
    labs(x = NULL, y = NULL, title = "Canopy Cover") +
    theme_minimal() +
    theme(panel.grid.minor = element_blank(), 
        panel.grid.major.y = element_blank(), 
        axis.text = element_text(size = 10),
        plot.title = element_text(size = 13))

# Step 3: Plot with discrete colors
canopy_cover_map <- t3_30_300_lsoa_gdf |> 
    st_transform(crs = WGS84_CRS) |> 
    ggplot() +
    aes(fill = canopy_cover_jenks) + 
    geom_sf(color = NA) +
    scale_fill_manual(values = colorRampPalette(brewer.pal(9, "YlGn"))(9), drop = FALSE) +
    scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
    scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE, keywidth = unit(0.5, "cm"), 
        color = "none")) +
    geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), 
        expand = .35, shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99) +
    theme_void() + 
    theme(legend.position = "none")

canopy_cover_plot <- ggdraw() + 
    draw_plot(canopy_cover_map) +
    draw_plot(canopy_cover_hist, x = 0.15, y = 0, hjust = 0.5, scale = 0.3)

ggsave('images/canopy_cover_lsoa_map.png', canopy_cover_plot,  device = "png",
       width = 180, height = 210, units = "mm", dpi = 300)

biclass_df <- bi_class(t3_30_300_lsoa_gdf, x = tree_count_slope_gini,
                       y = distance_manhattan_gini, style = "fisher",  dim = 4) |> 
                select(RGN22NM, bi_class, tree_count_slope_gini, distance_manhattan_gini)

biclass_gini_map <- biclass_df |> 
    st_transform(crs = WGS84_CRS) |> 
    ggplot() +
    aes(fill = bi_class) +
    geom_sf(lwd = 0) +
    bi_scale_fill(pal = "GrPink2", dim = 4) +
    scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
    scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
    theme_void() +
    theme(legend.position = "none") +
    geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99)

biclass_gini_legend <- bi_legend(pal = "GrPink2", dim = 4, size = 7) + 
            labs(x = "Park Distance Gini\n(More unequal) →", 
                 y = "Tree Count Gini\n(More unequal) →") +
            theme(plot.background = element_blank(), 
                axis.title = element_text(size = 16))

gini_biplot_map <- ggdraw() +
    draw_plot(biclass_gini_map, 0, 0, 1, 1) +
    draw_plot(biclass_gini_legend, .05, .15, 0.2, 0.6)

ggsave('images/gini_biplot_lsoa_map.png', gini_biplot_map,  device = "png",
       width = 180, height = 210, units = "mm", dpi = 300)

t3_30_300_gini_map <- ggdraw() + 
    draw_plot(plot_grid(canopy_cover_plot, biclass_gini_map, labels = c("A", "B"), label_size = 20), 0, 0, 1, 1) +
    draw_plot(biclass_gini_legend, .45, .15, 0.2, 0.6)

ggsave("images/t3_30_300_gini_lsoa_map.png", t3_30_300_gini_map, 
       width = 360, height = 210, units = "mm", dpi = 300)

# 3-30-300 rules ----------------------------------------------------------

t3_30_300_pop_summary <- t3_30_300_lsoa_gdf |> 
    filter(Urban_rural_flag == "Urban") |>
    mutate(RGN22NM = if_else(!is.na(IOL22NM), IOL22NM, RGN22NM)) |> 
    mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                            "Yorkshire and The Humber",
                                            "West Midlands", "East Midlands",
                                            "East of England", "South West",
                                            "South East", "Outer London",
                                            "Inner London"))) |> 
    st_drop_geometry() |> 
    mutate(meets_3_trees = tree_count_25m >= 3,
           meets_30_canopy = canopy_cover >= 30,
           meets_300_distance = park_distance_manhattan <= 300,
           meets_3_30 = meets_3_trees & meets_30_canopy,
           meets_30_300 = meets_30_canopy & meets_300_distance,
           meets_3_300 = meets_3_trees & meets_300_distance,
           meets_3_30_300 = meets_3_trees & meets_30_canopy & meets_300_distance) |> 
    select(RGN22CD, RGN22NM, total_pop, meets_3_trees, meets_30_canopy, meets_300_distance, meets_3_30, meets_30_300, meets_3_300, meets_3_30_300) |> 
    group_by(RGN22NM, meets_3_trees, meets_30_canopy, meets_300_distance) |> 
    summarise(total_pop = sum(total_pop, na.rm = TRUE),
              .groups = "drop") |> 
    pivot_longer(cols = c(meets_3_trees, meets_30_canopy, meets_300_distance), names_to = "rule", values_to = "meets") |> 
    na.omit() |> 
    mutate(rule = str_extract(rule, "300|30|3"), meets = if_else(meets, "Yes", "No"))

population_summary_plot <- t3_30_300_pop_summary |> 
    ggplot() +
    aes(x = rule, y = total_pop, fill = meets) +
    geom_bar(stat = "identity", position = "fill") +
    # scale_y_continuous(labels = function(x) paste0(x / 1e6, " M"), breaks = seq(1e6, 8e6, 1e6)) +
    scale_fill_brewer(palette = "Set2", direction = -1) +
    labs(y = "Population (%)", x = NULL, fill = "Meets Rule") +
    facet_wrap(~RGN22NM, nrow = 1, strip.position = "top", labeller = label_wrap_gen(width=10)) +
    theme_minimal() + 
    theme(legend.position = "bottom", 
          axis.ticks.x = element_blank(),
          panel.grid.major.x = element_blank())

ggsave("images/population_summary_urban_prc_plot.png", population_summary_plot, 
       width = 180, height = 90, units = "mm", dpi = 300)

# Tree Counts --------------------------------------------------------

# Step 1: Compute Jenks breaks (same as before)
tree_person_breaks <- classIntervals(t3_30_300_lad_gdf$tree_person_ratio,
    n = 9, style = "fisher")$brks |> 
    round(3)

tree_person_breaks[1] <- min(t3_30_300_lad_gdf$tree_person_ratio, na.rm = TRUE)  # Replace first break with actual minimum
tree_person_breaks[length(tree_person_breaks)] <- max(t3_30_300_lad_gdf$tree_person_ratio, na.rm = TRUE)

# Step 2: Categorize data into Jenks bins
t3_30_300_lad_gdf <- t3_30_300_lad_gdf |> 
  mutate(tree_person_ratio_jenks = cut(tree_person_ratio, 
    breaks = tree_person_breaks, include.lowest = TRUE, right = TRUE, 
    labels = sprintf("%.1f", tail(tree_person_breaks, -1))))

trees_pop_hist <- t3_30_300_lad_gdf |> 
    filter(!is.na(tree_person_ratio_jenks)) |> 
    ggplot() +
    geom_bar(aes(x = tree_person_ratio_jenks, fill = tree_person_ratio_jenks)) +
    # scale_x_discrete(limits = rev(levels(t3_30_300_lad_gdf$tree_person_ratio_jenks))) +
    scale_y_sqrt(breaks = c(1, 10, 25, 50, 100)) +
    scale_fill_manual(values = colorRampPalette(brewer.pal(9, "YlGn"))(9), 
        guide = "none") + 
    coord_flip() + 
    labs(x = NULL, y = NULL, title = "Trees per Person") +
    theme_minimal() +
    theme(panel.grid.minor = element_blank(), 
        panel.grid.major.y = element_blank(), 
        axis.text = element_text(size = 10),
        plot.title = element_text(size = 13))

# Step 3: Plot with discrete colors
trees_pop_map <- t3_30_300_lad_gdf |> 
    st_transform(crs = WGS84_CRS) |> 
    ggplot() +
    aes(fill = tree_person_ratio_jenks) + 
    geom_sf(color = NA) +
    scale_fill_manual(values = colorRampPalette(brewer.pal(9, "YlGn"))(9),
        name = "Trees per person (Jenks breaks)", drop = FALSE) +
    scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
    scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE, keywidth = unit(0.5, "cm"), 
        color = "none")) +
    geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), 
        expand = .35, shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99) +
    theme_void() + 
    theme(legend.position = "none")

tree_pop_plot <- ggdraw() + 
    draw_plot(trees_pop_map) +
    draw_plot(trees_pop_hist, x = 0.15, y = 0, hjust = 0.5, scale = 0.3)

ggsave("images/tree_pop_plot.png", tree_pop_plot, width = 180, height = 210, units = "mm", dpi = 300)

# Step 1: Compute Jenks breaks (same as before)
tree_area_breaks <- classIntervals(t3_30_300_lad_gdf$tree_area_ratio, 
    n = 9, style = "fisher")$brks |> 
    round(3)

tree_area_breaks[1] <- min(t3_30_300_lad_gdf$tree_area_ratio, na.rm = TRUE)  # Replace first break with actual minimum
tree_area_breaks[length(tree_area_breaks)] <- max(t3_30_300_lad_gdf$tree_area_ratio, na.rm = TRUE)

# Step 2: Categorize data into Jenks bins
t3_30_300_lad_gdf <- t3_30_300_lad_gdf |> 
    mutate(tree_area_ratio_jenks = cut(tree_area_ratio, 
        breaks = tree_area_breaks, include.lowest = TRUE, right = TRUE, 
        labels = sprintf("%.1f", tail(tree_area_breaks, -1))))

trees_area_hist <- t3_30_300_lad_gdf |> 
    filter(!is.na(tree_area_ratio_jenks)) |> 
    ggplot() +
    geom_bar(aes(x = tree_area_ratio_jenks, fill = tree_area_ratio_jenks)) +
    # scale_x_discrete(limits = rev(levels(t3_30_300_lad_gdf$tree_person_ratio_jenks))) +
    scale_y_sqrt(breaks = c(10, 25, 50, 75)) +
    scale_fill_manual(values = colorRampPalette(brewer.pal(9, "OrRd"))(9),
        guide = "none") + 
    coord_flip() + 
    labs(x = NULL, y = NULL, title = bquote(Trees ~ per ~ km^2)) +
    theme_minimal() +
    theme(panel.grid.minor = element_blank(), 
        panel.grid.major.y = element_blank(), 
        axis.text = element_text(size = 10),
        plot.title = element_text(size = 13))

# Step 3: Plot with discrete colors
trees_area_map <- t3_30_300_lad_gdf |> 
    st_transform(crs = WGS84_CRS) |> 
    ggplot() +
    aes(fill = tree_area_ratio_jenks) +
    geom_sf(color = NA) +
    scale_fill_manual(values = colorRampPalette(brewer.pal(9, "OrRd"))(9),
        name = "Trees per km^2 (Jenks breaks)",drop = FALSE) +
    scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
    scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE, keywidth = unit(0.5, "cm"), 
        color = "none")) +
    geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), 
        expand = .35, shadow = TRUE, shape = 'outline', linewidth = .001, alpha = 0.99) +
    theme_void() + 
    theme(legend.position = "none")

tree_area_plot <- ggdraw() + 
    draw_plot(trees_area_map) +
    draw_plot(trees_area_hist, x = 0.15, y = 0, hjust = 0.5, scale = 0.3)

ggsave("images/tree_area_plot.png", tree_area_plot, width = 180, height = 210, units = "mm", dpi = 300)

total_trees_std_map <- ggdraw() + 
    draw_plot(plot_grid(tree_pop_plot, tree_area_plot, labels = c("A", "B"), label_size = 20), 0, 0, 1, 1)

ggsave("images/total_trees_std_lad_map.png", total_trees_std_map, 
       width = 360, height = 210, units = "mm", dpi = 300)

# Coverage plot -----------------------------------------------------------

coverage_map_plot <- ggplot() +
    # Layer 1: All available data tiles (Orange)
    geom_sf(data = os_tile_boundaries_gdf |>
                mutate(TILE_NAME_5KM_int = toupper(TILE_NAME_5KM_int)) |>
                filter(TILE_NAME_5KM_int %in% tree_vector_paths_df$TILE_NAME) |>
                st_union(),
            aes(fill = 'Data Available (Rural & Suburban)'), # Map fill to a label
            colour = '#d95f02',
            alpha = 0.5) +
    # Layer 2: Urban areas (Green)
    geom_sf(data = t3_30_300_lsoa_gdf |>
                filter(Urban_rural_flag == "Urban"),
            aes(fill = 'Urban'), # Map fill to a different label
            colour = '#1b9e77') +
    # Layer 3: England outline
    geom_sf(data = t3_30_300_rgn_gdf,
            fill = "transparent",
            color = "black",
            linewidth = .3, linetype = 'dotted') +
    geom_sf_text(data = t3_30_300_rgn_gdf, size = 3,
                    aes(label = str_wrap(RGN22NM, width = 8), geometry = geometry)) +
    # Manually set the colors and title for the legend
    scale_fill_manual(
        name = "Data Coverage", # This is the legend title
        values = c(
            'Data Available (Rural & Suburban)' = '#d95f02',
            'Urban' = '#1b9e77'
        )
    ) +
    theme_void() +
    # Optional: Customize legend position
    theme(legend.position = "bottom",
          legend.title = element_text(size = 10, face = "bold"),
          legend.text = element_text(size = 9))

ggsave("images/coverage_map_plot.png", coverage_map_plot, 
       width = 180, height = 180, units = "mm", dpi = 300)

# Tables ------------------------------------------------------------------

t3_30_300_lad_summary <- lad_gdf |> 
    left_join(t3_30_300_lsoa_gdf |>
    st_drop_geometry() |>
    filter(Urban_rural_flag == "Urban") |>
    group_by(RGN22CD, RGN22NM, LAD22CD, LAD22NM) |>
    summarise(
        total_areas = n(),
        meets_3_trees = sum(tree_count_25m >= 3, na.rm = TRUE),
        meets_30_canopy = sum(canopy_cover >= 30, na.rm = TRUE), 
        meets_300_distance = sum(park_distance_manhattan <= 300, na.rm = TRUE),
        meets_3_30 = sum(tree_count_25m >= 3 & canopy_cover >= 30, na.rm = TRUE),
        meets_30_300 = sum(canopy_cover >= 30 & park_distance_manhattan <= 300, na.rm = TRUE),
        meets_3_300 = sum(tree_count_25m >= 3 & park_distance_manhattan <= 300, na.rm = TRUE),
        meets_3_30_300 = sum(tree_count_25m >= 3 & canopy_cover >= 30 & park_distance_manhattan <= 300, na.rm = TRUE),
        pct_3_trees = round(meets_3_trees / total_areas * 100, 1),
        pct_30_canopy = round(meets_30_canopy / total_areas * 100, 1),
        pct_300_distance = round(meets_300_distance / total_areas * 100, 1),
        pct_3_30 = round(meets_3_30 / total_areas * 100, 1),
        pct_30_300 = round(meets_30_300 / total_areas * 100, 1),
        pct_3_300 = round(meets_3_300 / total_areas * 100, 1),
        pct_3_30_300 = round(meets_3_30_300 / total_areas * 100, 1),
        .groups = "drop"
    ), by = c("LAD22CD", "LAD22NM", "RGN22CD", "RGN22NM")) |>
    mutate(RGN22NM = fct_relevel(RGN22NM, c("North West", "North East",
                                            "Yorkshire and The Humber",
                                            "West Midlands", "East Midlands",
                                            "East of England", "South West",
                                            "South East", "London"))) |> 
    arrange(RGN22NM)

t3_30_300_rgn_summary <- t3_30_300_lad_summary |> 
    st_drop_geometry() |>
    group_by(RGN22NM) |>
    summarise(total_areas = sum(total_areas, na.rm = TRUE),
              meets_3_trees = sum(meets_3_trees, na.rm = TRUE),
              meets_30_canopy = sum(meets_30_canopy, na.rm = TRUE),
              meets_300_distance = sum(meets_300_distance, na.rm = TRUE),
              meets_3_30_300 = sum(meets_3_30_300, na.rm = TRUE),
              meets_3_30 = sum(meets_3_30, na.rm = TRUE),
              meets_30_300 = sum(meets_30_300, na.rm = TRUE),
              meets_3_300 = sum(meets_3_300, na.rm = TRUE),
              .groups = "drop") |> 
    mutate(pct_3_trees = round(meets_3_trees / total_areas * 100, 1),
           pct_30_canopy = round(meets_30_canopy / total_areas * 100, 1),
           pct_300_distance = round(meets_300_distance / total_areas * 100, 1),
           pct_3_30 = round(meets_3_30 / total_areas * 100, 1),
           pct_30_300 = round(meets_30_300 / total_areas * 100, 1),
           pct_3_300 = round(meets_3_300 / total_areas * 100, 1),
           pct_3_30_300 = round(meets_3_30_300 / total_areas * 100, 1)) |> 
           select(RGN22NM, total_areas, pct_3_trees, pct_30_canopy, pct_300_distance, pct_3_30_300)

t3_30_300_england_summary <- t3_30_300_lad_summary |> 
    st_drop_geometry() |>
    summarise(total_areas = sum(total_areas, na.rm = TRUE),
              meets_3_trees = sum(meets_3_trees, na.rm = TRUE),
              meets_30_canopy = sum(meets_30_canopy, na.rm = TRUE),
              meets_300_distance = sum(meets_300_distance, na.rm = TRUE),
              meets_3_30_300 = sum(meets_3_30_300, na.rm = TRUE),
              meets_3_30 = sum(meets_3_30, na.rm = TRUE),
              meets_30_300 = sum(meets_30_300, na.rm = TRUE),
              meets_3_300 = sum(meets_3_300, na.rm = TRUE)) |> 
    mutate(RGN22NM = "England", 
           pct_3_trees = round(meets_3_trees / total_areas * 100, 1),
           pct_30_canopy = round(meets_30_canopy / total_areas * 100, 1),
           pct_300_distance = round(meets_300_distance / total_areas * 100, 1),
           pct_3_30 = round(meets_3_30 / total_areas * 100, 1),
           pct_30_300 = round(meets_30_300 / total_areas * 100, 1),
           pct_3_300 = round(meets_3_300 / total_areas * 100, 1),
           pct_3_30_300 = round(meets_3_30_300 / total_areas * 100, 1)) |>
    select(RGN22NM, total_areas, pct_3_trees, pct_30_canopy, pct_300_distance, pct_3_30_300)


t3_30_300_rgn_summary |> 
    bind_rows(t3_30_300_england_summary) |> 
    kable(format = "latex", booktabs = TRUE)

# Rank Map ----------------------------------------------------------------

t3_30_300_rank_gdf <- t3_30_300_lsoa_gdf |> 
    st_drop_geometry() |> 
    select(RGN22CD, ends_with("Score"), starts_with("park_distance"), 
           water_distance,
           starts_with("tree_count"), canopy_cover, NDVI, NDWI, NDBI, area, total_pop) |> 
    group_by(RGN22CD) |> 
    summarise(across(ends_with("Score"), mean, .names = "{.col}"),
              across(area:total_pop, sum, .names = "{.col}"),
              across(park_distance_manhattan:NDBI, ~ mean(.x, na.rm = TRUE), .names = "{.col}")) |>
    mutate(across(IMDScore:water_distance, function(x) {rank(-x)}, .names = "{.col}_rank"),
           across(tree_count_25m:NDWI, function(x) {rank(x)}, .names = "{.col}_rank"),
           NDBI_rank = rank(-NDBI),
           IMD = as_factor(IMDScore_rank)) |> 
    select(RGN22CD, IMD, ends_with("rank"))

t3_30_300_rank_long_gdf <- t3_30_300_rank_gdf |> 
    pivot_longer(ends_with("rank"), names_to = "Metric", values_to = "Rank") |> 
    mutate(Metric = fct_relevel(Metric, c("tree_count_25m_rank", "canopy_cover_rank", 
                                          "park_distance_rank", "water_distance_rank",
                                          "NDVI_rank", "NDWI_rank", "NDBI_rank",
                                          "IMDScore_rank", "IncScore_rank", "EmpScore_rank",
                                          "EduScore_rank", "HDDScore_rank", "CriScore_rank",
                                          "BHSScore_rank", "EnvScore_rank", "area_rank",
                                          "Total_rank")))

t3_30_300_rank_rgn_gdf <- t3_30_300_rank_gdf |> 
    left_join(st_geometry(t3_30_300_rgn_gdf) |> 
                  st_point_on_surface() |> 
                  st_coordinates() |>
                  as_tibble() |> bind_cols(t3_30_300_rgn_gdf |> select(RGN22CD, RGN22NM)) |> st_as_sf(), by = "RGN22CD") |> 
    mutate_at(vars(ends_with("rank")), ~ normalize(., range = c(st_bbox(t3_30_300_rgn_gdf)$ymin, st_bbox(t3_30_300_rgn_gdf)$ymax),
                                                   method = "range"))

t3_30_300_rank_rgn_gdf <- t3_30_300_rgn_gdf |> 
    select(RGN22CD, RGN22NM) |> 
    bind_cols(st_geometry(t3_30_300_rgn_gdf) |> 
                  st_point_on_surface() |> 
                  st_coordinates() |>
                  as_tibble()) |> 
    right_join(t3_30_300_rank_gdf, by = "RGN22CD") |> 
    mutate_at(vars(ends_with("rank")), ~ normalize(., range = c(st_bbox(t3_30_300_rgn_gdf)$ymin, st_bbox(t3_30_300_rgn_gdf)$ymax),
                                                   method = "range"))

x_start <- 700000
x_span <- 100000
metric_names <- c("3", "30", "300", "Water \nDistance", "NDVI", "NDWI", "NDBI", "Env \nDeprivation")
text_labels_df <- tibble(metric_names, y = max(t3_30_300_rank_rgn_gdf$tree_count_25m_rank + 50000),
                         x = seq(x_start, x_start + x_span * (length(metric_names) - 1), x_span))
group_var <- "RGN22CD"
colour_var <- "IMD"

t3_30_300_spectral_rank_map <- t3_30_300_rank_rgn_gdf |> 
    ggplot() +
    geom_sf(data = t3_30_300_rgn_gdf, fill = "transparent") +
    geom_point(aes(x = X, y = Y, color = !!sym(colour_var))) +
    geom_sigmoid(linetype = "dotted", aes(x = X, y = Y, xend = x_start + x_span * 0, yend = tree_count_25m_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 0, y = tree_count_25m_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 0, y = tree_count_25m_rank, xend = x_start + x_span * 1, yend = canopy_cover_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 1, y = canopy_cover_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 1, y = canopy_cover_rank, xend = x_start + x_span * 2, yend = park_distance_manhattan_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 2, y = park_distance_manhattan_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 2, y = park_distance_manhattan_rank, xend = x_start + x_span * 3, yend = water_distance_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 3, y = water_distance_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 3, y = water_distance_rank, xend = x_start + x_span * 4, yend = NDVI_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 4, y = NDVI_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 4, y = NDVI_rank, xend = x_start + x_span * 5, yend = NDWI_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 5, y = NDWI_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 5, y = NDWI_rank, xend = x_start + x_span * 6, yend = NDBI_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 6, y = NDBI_rank, color = !!sym(colour_var))) +
    
    geom_sigmoid(aes(x = x_start + x_span * 6, y = NDBI_rank, xend = x_start + x_span * 7, yend = EnvScore_rank, group = !!sym(group_var), color = !!sym(colour_var))) +
    geom_point(aes(x = x_start + x_span * 7, y = EnvScore_rank, color = !!sym(colour_var))) +
    
    geom_text(aes(x = x_start + x_span * 7 + 15000, y = EnvScore_rank, 
                  label = str_wrap(RGN22NM, width = 15)), size = 2, hjust = 0) +
    geom_text(data = text_labels_df, aes(x = x, y = y, label = metric_names), size = 2) +
    scale_x_continuous(limits = c(150000, 1500000)) +
    scale_color_brewer(palette = "PiYG") +
    labs(color = paste(colour_var, "Ranking")) +
    guides(color = guide_legend(nrow = 1)) +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = "transparent"),
          legend.position = "bottom",
          legend.title = element_text(size = 8, face = "bold"),
          legend.text = element_text(size = 7))

t3_30_300_spectral_rank_map

ggsave("images/t3_30_300_spectral_rank_map.png", t3_30_300_spectral_rank_map, 
       width = 180, height = 90, units = "mm", dpi = 300)

# t3_30_300_rank_long_gdf |> 
#     filter(Metric %in% c("tree_count_rank", "canopy_cover_rank",
#                          "park_distance_rank", "water_distance_rank", 
#                          "NDVI_rank", "NDBI_rank", "NDWI_rank", "IMDScore_rank")) |> 
#     left_join(t3_30_300_lsoa_gdf |> 
#                   st_drop_geometry() |> 
#                   select(RGN22CD, RGN22NM), by = "RGN22CD") |> 
#     ggplot(aes(x = Metric, y = Rank, group = RGN22CD, colour = IMD)) + 
#     geom_point(size = 3) +
#     geom_bump(size = 2, smooth = 8) +
#     # geom_text(aes(label = RGN22NM)) +
#     # scale_y_reverse() +
#     scale_y_continuous(breaks = 1:10) +
#     scale_color_brewer(palette = "RdYlBu") +
#     labs(x = "Metric", y = "Rank") +
#     plot_theme

# Low Score -> High Ranking -> Low Deprivation
# High Score -> Low Ranking -> High Deprivation

# Spectral Plots ----------------------------------------------------------

ndvi_map_plot <- t3_30_300_lad_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        # filter(RGN22NM == "London") |> 
        ggplot() + 
        geom_sf(aes(fill = NDVI), linewidth = 0.01, colour = "black", alpha = 0.9) +
        scale_fill_distiller(palette = "RdYlGn", direction = 1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = 'NDVI') + 
        theme_void() +
        theme(legend.position = c(.15, .5)) + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .1, colour = "black", alpha = 0.5)

ggsave('images/ndvi_lad_map.png', ndvi_map_plot,  device = "png", width = 180, height = 210, units = "mm", dpi = 300)

ndwi_map_plot <- t3_30_300_lad_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        # filter(RGN22NM == "London") |> 
        ggplot() + 
        geom_sf(aes(fill = NDWI), linewidth = 0.01, colour = "black", alpha = 0.9) +
        scale_fill_distiller(palette = "RdBu", direction = 1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = 'NDWI') + 
        theme_void() +
        theme(legend.position = c(.15, .5)) + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .1, colour = "black", alpha = 0.5)

ggsave('images/ndwi_lad_map.png', ndwi_map_plot,  device = "png", width = 180, height = 210, units = "mm", dpi = 300)

ndbi_map_plot <- t3_30_300_lad_gdf |> 
        st_transform(crs = WGS84_CRS) |> 
        # filter(RGN22NM == "London") |> 
        ggplot() + 
        geom_sf(aes(fill = NDBI), linewidth = 0.01, colour = "black", alpha = 0.9) +
        scale_fill_distiller(palette = "BrBG", direction = -1) +
        scale_x_continuous(limits = c(-6.5, 4), expand = c(0, 0)) +
        scale_y_continuous(limits = c(49.5, 56.5), expand = c(0, 0)) +
        labs(fill = 'NDBI') + 
        theme_void() +
        theme(legend.position = c(.15, .5)) + 
        geom_magnify(aes(from = RGN22NM == "London"), to = c(-.2, 3, 54.5, 56), expand = .35,
                 shadow = TRUE, shape = 'outline', linewidth = .1, colour = "black", alpha = 0.5)

ggsave('images/ndbi_lad_map.png', ndbi_map_plot,  device = "png", width = 180, height = 210, units = "mm", dpi = 300)

# TES Comparison ----------------------------------------------------------

tes_gdf <- read_sf(here(INPUT_DIR, "TES", "england_tes.shp"))

t3_30_300_tes_df <- t3_30_300_lsoa_gdf |> 
    filter(Urban_rural_flag == "Urban") |> 
    select(LSOA11CD, RGN22NM, canopy_cover, tree_count_slope_gini, distance_manhattan_gini, EnvDec) |> 
    st_drop_geometry() |> 
    left_join(tes_gdf |> 
        st_drop_geometry() |> 
        select(bge_code, tes, treecanopy), by = c("LSOA11CD" = "bge_code")) |>
        na.omit()

t3_30_300_tes_normal_df <- t3_30_300_tes_df |>
    mutate(across(c(canopy_cover, tree_count_slope_gini, distance_manhattan_gini, tes),
                 ~ normalize(.x, method = "range", range = c(0, 1)))) |> 
    pivot_longer(cols = c(canopy_cover, tree_count_slope_gini, distance_manhattan_gini, tes),
                names_to = "variable", values_to = "value") |> 
    mutate(variable = factor(variable, levels = c("canopy_cover", "tree_count_slope_gini", "distance_manhattan_gini", "tes"),
                             labels = c("Canopy\nCover", "Tree Count\nGini", "Park Distance\nGini", "TES")))

t3_30_300_tes_bump_plot <- t3_30_300_tes_normal_df |>
    ggplot(aes(x = variable, y = value, group = LSOA11CD)) +
    geom_bump(aes(color = EnvDec), alpha = 0.3, size = 0.5) +
    geom_point(aes(color = EnvDec), alpha = 0.3, size = .2) +
    scale_color_brewer(palette = "RdYlBu", direction = 1) +
    scale_x_discrete(labels = c("Canopy\nCover", "Tree Count\nGini", "Park Distance\nGini", "TES")) +
    labs(x = NULL, y = "Normalized Value", color = "Environment IMD") +
    guides(color = guide_legend(nrow = 1)) +
    theme_minimal() +
    theme(legend.position = "bottom",
          panel.grid.minor = element_blank(),
          axis.text.x = element_text(size = 8))

ggsave("images/t3_30_300_tes_bump_plot.png", t3_30_300_tes_bump_plot,
       width = 180, height = 90, units = "mm", dpi = 300)

t3_30_300_tes_sankey_df <- t3_30_300_tes_df |> 
# mutate(across(c(canopy_cover, tree_count_slope_gini, distance_manhattan_gini, tes),
    #     ~ cut(.x, breaks = quantile(.x, probs = seq(0, 1, 0.2), na.rm = TRUE),
    #     include.lowest = TRUE, labels = c("Q1", "Q2", "Q3", "Q4", "Q5")), .names = "{.col}_cat")) |> 
    mutate(
    tes_cat = factor(cut(tes, 
                         breaks = quantile(tes, probs = seq(0, 1, 0.2), na.rm = TRUE),
                         include.lowest = TRUE,
                         labels = c("Very\nLow", "Low", "Medium", "High", "Very\nHigh")),
                     levels = c("Very\nLow", "Low", "Medium", "High", "Very\nHigh")),
    canopy_cover_cat = factor(cut(canopy_cover, 
                         breaks = quantile(canopy_cover, probs = seq(0, 1, 0.2), na.rm = TRUE),
                         include.lowest = TRUE,
                         labels = c("Very\nLow", "Low", "Medium", "High", "Very\nHigh")),
                     levels = c("Very\nLow", "Low", "Medium", "High", "Very\nHigh")),
    tree_count_slope_gini_cat = factor(cut(tree_count_slope_gini,
                         breaks = quantile(tree_count_slope_gini, probs = seq(0, 1, 0.2), na.rm = TRUE),
                         include.lowest = TRUE,
                         labels = c("High\nEquality", "Equal", "Medium", "Unequal", "High\nInequality")),
                     levels = c("High\nEquality", "Equal", "Medium", "Unequal", "High\nInequality")),
    distance_manhattan_gini_cat = factor(cut(distance_manhattan_gini,
                         breaks = quantile(distance_manhattan_gini, probs = seq(0, 1, 0.2), na.rm = TRUE),
                         include.lowest = TRUE,
                         labels = c("High\nEquality", "Equal", "Medium", "Unequal", "High\nInequality")),
                     levels = c("High\nEquality", "Equal", "Medium", "Unequal", "High\nInequality"))
    ) |>
    group_by(RGN22NM, EnvDec, tes_cat, canopy_cover_cat, tree_count_slope_gini_cat, distance_manhattan_gini_cat) |> 
    summarise(n = n(), .groups = "drop")

tes_sankey_plot <- t3_30_300_tes_sankey_df |> 
    ggplot() +
    aes(y = n, axis1 = EnvDec, axis2 = tree_count_slope_gini_cat, axis3 = canopy_cover_cat,
        axis4 = distance_manhattan_gini_cat, axis5 = tes_cat) +
    geom_alluvium(aes(fill = EnvDec)) +
    geom_stratum() +
    geom_text(stat = "stratum", aes(label = after_stat(stratum)), size = 3) +
    scale_x_discrete(limits = c("Environment\nIMD", "Tree Count\nGini", "Canopy Cover", "Park Distance\nGini", "TES")) +
    scale_fill_brewer(palette = "RdYlBu", direction = 1) +
    labs(fill = "Environment IMD", y = NULL) +
    guides(fill = guide_legend(nrow = 1)) +
    theme_minimal() +
        theme_minimal() +
        theme(legend.position = "bottom",
            axis.text.y = element_blank(),
            axis.ticks = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank())

t3_30_300_tes_df |> 
    ggplot() +
    aes(x = tree_count_slope_gini, y = tes, colour = EnvDec) +
    geom_point(alpha = 0.5)

ggsave("images/tes_sankey_plot.png", tes_sankey_plot,
       width = 250, height = 150, units = "mm", dpi = 300)

temp_plot <- t3_30_300_tes_df |> 
    ggplot() +
    aes(x = canopy_cover, y = treecanopy, colour = RGN22NM) +
    geom_point(alpha = 0.5)

ggsave("images/temp_plot.png", temp_plot, 
       width = 180, height = 90, units = "mm", dpi = 300)

# Forest Research Comparison -----------------------------------------------

# Read all GDB files from Forest Research TOW folder and count features
tree_count_region_df <- tree_count_df |> 
    left_join(output_areas_boundaries_gdf |> st_drop_geometry(), by = "OA21CD") |> 
    group_by(RGN22NM) |> 
    summarise(total_trees = sum(tree_count, na.rm = TRUE),
              .groups = "drop")

nfi_gsf <- read_sf(here("/maps/acz25/phd-thesis-data/input/Forest_Research/NFI/National_Forest_Inventory_England_2023.shp"))

fr_gdb_files <- list.files(here("/maps/acz25/phd-thesis-data/input/Forest_Research/TOW"), 
                          pattern = "\\.gdb$", 
                          full.names = TRUE)

fr_data_list <- list()
fr_feature_counts <- data.frame(gdb_file = character(),
                              layer = character(), 
                              feature_count = numeric(),
                              area_sum = numeric())

for (gdb_file in fr_gdb_files) {
    # Get layers in GDB
    layers <- st_layers(gdb_file)$name
    
    # Read each layer and count features
    for (layer in layers) {
        layer_data <- st_read(gdb_file, layer = layer)
        fr_data_list[[basename(gdb_file)]][[layer]] <- layer_data
        
        # Add count to feature_counts dataframe
        fr_feature_counts <- rbind(fr_feature_counts,
                                 data.frame(gdb_file = basename(gdb_file),
                                          layer = layer,
                                          feature_count = nrow(layer_data),
                                          area_sum = sum(layer_data$TOW_Area_M, na.rm = TRUE)))
    }
}

# Display feature counts
print("Feature counts in each GDB layer:")
print(fr_feature_counts)

# Other plots -------------------------------------------------------------

t3_30_300_lsoa_gdf |> 
    ggplot(aes(x = distance_manhattan_gini, y = tree_count_25m_gini, colour = EnvDec)) + 
    geom_point(alpha = .5) + 
    scale_colour_brewer(palette = "RdYlBu", direction = 1) + 
    facet_wrap(~RGN22NM) + plot_theme

manhattan_distance_gini_map <- t3_30_300_lad_gdf |> 
    ggplot() +
    aes(fill = distance_manhattan_gini) +
    geom_sf(color = alpha("grey", 0.2)) +
    scale_fill_distiller(palette = "PiYG", direction = -1) +
    labs(fill = "Manhattan Distance Gini") +
    plot_theme

ggsave("images/manhattan_distance_gini_map.png", manhattan_distance_gini_map, 
       width = 180, height = 90, units = "mm", dpi = 300)

(euclidean_distance_gini_map <- t3_30_300_lad_gdf |> 
    ggplot() +
    aes(fill = distance_euclidean_gini) +
    geom_sf(color = alpha("grey", 0.2)) +
    scale_fill_distiller(palette = "PiYG", direction = -1) +
    labs(fill = "Euclidean Distance Gini") +
    plot_theme)

ggsave("images/euclidean_distance_gini_map.png", euclidean_distance_gini_map, 
       width = 180, height = 90, units = "mm", dpi = 300)

total_trees_gini_map <- t3_30_300_lad_gdf |> 
    ggplot() +
    aes(fill = total_trees_gini) +
    geom_sf(color = alpha("grey", 0.2)) +
    scale_fill_distiller(palette = "PiYG", direction = -1) +
    labs(fill = "Total Trees Gini") +
    plot_theme

ggsave("images/total_trees_gini_map.png", total_trees_gini_map, 
       width = 180, height = 90, units = "mm", dpi = 300)

tree_slope_gini_map <- t3_30_300_lad_gdf |> 
    ggplot() +
    aes(fill = tree_count_slope_gini) +
    geom_sf(color = alpha("grey", 0.2)) +
    scale_fill_distiller(palette = "PiYG", direction = -1) +
    labs(fill = "Slope Gini") +
    plot_theme

ggsave("images/tree_slope_gini_map.png", tree_slope_gini_map, 
       width = 180, height = 90, units = "mm", dpi = 300)
 
(env_imd_map <- t3_30_300_lsoa_gdf |> 
    filter(RGN22NM == "London") |> 
    ggplot() +
    aes(fill = EnvDec) +
    geom_sf(color = alpha("grey", 0.2)) +
    scale_fill_brewer(palette = "RdYlBu") +
    # scale_fill_distiller(palette = "RdYlBu") +
    labs(fill = "Env IMD") +
    plot_theme)

ggsave("images/env_imd_map.png", env_imd_map, 
       width = 180, height = 90, units = "mm", dpi = 300)

# Scatter Plot: water_distance vs distance_manhattan
t3_300_buildings_df |> 
    filter(!is.na(distance_water), !is.na(distance_manhattan)) |> 
    filter(map_use == "Residential") |> 
    ggplot(aes(x = distance_water, y = tree_count_25m, colour = RGN22CD)) +
    geom_point(alpha = 0.5, size = 0.5) +
    scale_x_continuous(trans = "log") +
    # scale_y_continuous(trans = "log") +
    labs(
        x = "Water Distance (m)",
        y = "Tree Count at 25 m"
    ) +
    theme_minimal()

t3_300_buildings_df |>
    filter(!is.na(tree_count_50m)) |>
    filter(map_use == "Residential") |> 
    ggplot() + 
    geom_histogram(aes(tree_count_50m)) +
    scale_x_continuous(trans = "log")

t3_30_300_lsoa_gdf |> 
    filter(RGN22NM == "London") |> 
    ggplot() +
    aes(fill = park_distance_ratio) +
    geom_sf() +
    scale_fill_distiller(palette = "PRGn", direction = 1) +
    theme_minimal()

t3_30_300_lsoa_gdf |> 
    filter(Urban_rural_flag == "Urban") |> 
    ggplot() +
    aes(x = distance_water_gini, y = NDVI, colour = EnvDec) +
    geom_point(alpha = 0.5) +
    # scale_x_continuous(trans = "log") +
    # scale_y_continuous(trans = "log") +
    scale_colour_brewer(palette = "RdYlBu", direction = 1) +
    facet_wrap(~RGN22NM) +
    theme_minimal()    
