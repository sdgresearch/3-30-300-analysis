
# Libraries ---------------------------------------------------------------

library(tidyverse)
library(patchwork)

# EDA - Diabetes ----------------------------------------------------------

diabetes_imd_violin_plot <- model_df |>
    ggplot(aes(x = as.factor(IMD_Decile), y = diabetes_prev, fill = as.factor(IMD_Decile))) +
    geom_violin() +
    geom_smooth() +
    scale_fill_brewer(palette = 'RdYlBu') +
    labs(y = 'Diabetes Prevalence (%)', x = 'IMD Decile', fill = NULL) +
    theme_bw() + theme(legend.position = "none")

diabetes_pch_scatter_plot <- model_df |>
    ggplot(aes(x = d_pch, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    labs(y = 'Diabetes Prevalence (%)', x = 'Distance to closest tree', color = 'IMD decile') +
    theme_bw() + theme(legend.position = "none")

diabetes_canopy_scatter_plot <- model_df |>
    ggplot(aes(x = canopy_cover, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    labs(y = 'Diabetes Prevalence (%)', x = 'Canopy Cover', color = 'IMD decile') +
    theme_bw() + theme(legend.position = "none")

diabetes_ogs_scatter_plot <- model_df |>
    ggplot(aes(x = d_ogs, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point(alpha = .5) +
    geom_smooth() +
    scale_color_brewer(palette = 'RdYlBu') +
    labs(y = 'Diabetes Prevalence (%)', x = 'Distance to closest green space', color = 'IMD decile') +
    theme_bw() + theme(legend.position = "none")

diabetes_pch_scatter_plot <- model_df |> 
    ggplot(aes(x = IMDScore, y = diabetes_prev, colour = as.factor(IMD_Decile))) +
    geom_point() +
    scale_color_brewer(palette = 'RdYlBu') +
    geom_smooth() +
    theme_minimal()

diabetes_pch_scatter_plot <- model_df |> 
    ggplot(aes(x = EnvScore, y = d_ogs, colour = as.factor(IMD_Decile))) +
    geom_point() +
    scale_color_brewer(palette = 'RdYlBu') +
    geom_smooth() +
    theme_minimal()

imd_3_boxplot <- ggplot(imd_distance_df) +
    # geom_histogram(aes(log(`distance_pch mean`)), fill = 'darkgreen', color = 'black') +
    # facet_wrap(~LA_decile, nrow = 1) +
    # coord_flip() +
    geom_boxplot(aes(x = as.factor(SOA_decile), y = log(`distance_pch mean`), fill = as.factor(SOA_decile))) +
    scale_fill_brewer(palette = 'RdYlBu') +
    labs(y = 'Distance to closest tree', x = 'IMD decile') +
    theme_bw() + theme(axis.line.x = NULL, legend.position = "none")

imd_30_boxplot <- ggplot(imd_distance_df) +
    # geom_histogram(aes(log(canopy_cover)), fill = 'darkgreen', color = 'black') +
    # facet_wrap(~LA_decile, nrow = 1) +
    # coord_flip() +
    geom_boxplot(aes(x = as.factor(SOA_decile), y = log(`canopy_cover`), fill = as.factor(SOA_decile))) +
    scale_fill_brewer(palette = 'RdYlBu') +
    labs(y = 'Canopy cover', x = 'IMD decile') +
    theme_bw() + theme(axis.line.x = NULL, legend.position = "none")

imd_300_boxplot <- ggplot(imd_distance_df) +
    # geom_histogram(aes(log(`distance_ogs mean`)), fill = 'darkgreen', color = 'black') +
    # facet_wrap(~LA_decile, nrow = 1) +
    # coord_flip() +
    geom_boxplot(aes(x = as.factor(SOA_decile), y = log(`distance_ogs mean`), fill = as.factor(SOA_decile))) +
    scale_fill_brewer(palette = 'RdYlBu') +
    labs(y = 'Distance to closest green space', x = 'IMD decile') +
    theme_bw() + theme(axis.line.x = NULL, legend.position = "none")

# distribution
three_thirty_hexplot <- ggplot(imd_distance_df) +
    geom_hex(aes(log(`distance_pch mean`), log(canopy_cover))) +
    scale_fill_distiller(palette = 'Greens') +
    labs(x = 'Distance to closest tree',
         y = 'Canopy cover', fill = 'Frequency') +
    theme_bw() + theme(aspect.ratio=1)

three_three_hundred_hexplot <- ggplot(imd_distance_df) +
    geom_hex(aes(log(`distance_ogs mean`), log(`distance_pch mean`))) +
    scale_fill_distiller(palette = 'Greens') +
    labs(x = 'Distance to closest green space',
         y = 'Distance to closest tree', fill = 'Frequency') +
    theme_bw() + theme(aspect.ratio=1)

three_hundred_thirty_hexplot <- ggplot(imd_distance_df) +
    geom_hex(aes(log(`distance_ogs mean`), log(canopy_cover))) +
    scale_fill_distiller(palette = 'Greens') +
    labs(x = 'Distance to closest green space',
         y = 'Canopy cover', fill = 'Frequency') +
    theme_bw() + theme(aspect.ratio=1)



diabetes_imd_violin_plot / (diabetes_pch_scatter_plot | diabetes_canopy_scatter_plot | diabetes_ogs_scatter_plot) +
    plot_annotation(tag_levels = 'A')

imd_3_boxplot / imd_30_boxplot / imd_300_boxplot +
    plot_annotation(tag_levels = 'A')

three_thirty_hexplot + three_three_hundred_hexplot + three_hundred_thirty_hexplot + 
    plot_annotation(tag_levels = 'A')
