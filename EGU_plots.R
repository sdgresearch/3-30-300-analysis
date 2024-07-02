library(tidyverse)
library(sf)
imd_distance_path <- "/Users/ancazugo/Documents/PhD_Thesis/Tree_detection/data/output/vector/imd/imd_distance_aggregated_canopy_cover.geojson"
imd_distance_df <- sf::read_sf(imd_distance_path)

# histogram
ggplot(imd_distance_df) +
    geom_histogram(aes(log(`distance_pch mean`)), fill = 'darkgreen', color = 'black') +
    facet_wrap(~LA_decile, nrow = 1) +
    labs(x = 'Distance to closest tree (log(m))', y = 'IMD decile') +
    coord_flip() +
    theme_bw() + theme(axis.line.x = NULL)

ggplot(imd_distance_df) +
    geom_histogram(aes(log(`distance_ogs mean`)), fill = 'darkgreen', color = 'black') +
    facet_wrap(~LA_decile, nrow = 1) +
    labs(x = 'Distance to closest green space (log(m))', y = 'IMD decile') +
    coord_flip() +
    theme_bw()

ggplot(imd_distance_df) +
    geom_histogram(aes(canopy_cover), fill = 'darkgreen', color = 'black') +
    facet_wrap(~LA_decile, nrow = 1) +
    labs(x = 'Canopy cover (%)', y = 'IMD decile') +
    coord_flip() +
    theme_bw()

# scatter
ggplot(imd_distance_df) +
    geom_point(aes(SOA_pct, sqrt(`canopy_cover`))) +
    geom_smooth(aes(SOA_pct, sqrt(`canopy_cover`))) +
    theme_minimal()

ggplot(imd_distance_df) +
    geom_point(aes(SOA_pct, log(`distance_ogs mean`))) +
    geom_smooth(aes(SOA_pct, log(`distance_ogs mean`))) +
    theme_minimal()

ggplot(imd_distance_df) +
    geom_point(aes(SOA_pct, log(`distance_pch mean`))) +
    geom_smooth(aes(SOA_pct, log(`distance_pch mean`))) +
    theme_minimal()

# distribution
ggplot(imd_distance_df) +
    geom_hex(aes(log(`distance_ogs mean`), log(`distance_pch mean`))) +
    scale_fill_distiller(palette = 'Greens') +
    labs(title = '3 v 300', x = 'Distance to closest green space (log(m))',
             y = 'Distance to closest tree (log(m))', fill = 'Frequency') +
    theme_bw()

ggplot(imd_distance_df) +
    geom_hex(aes(log(`distance_ogs mean`), canopy_cover)) +
    scale_fill_distiller(palette = 'Greens') +
    labs(title = '300 v 30', x = 'Distance to closest green space (log(m))',
             y = 'Canopy cover (%)', fill = 'Frequency') +
    theme_minimal()

ggplot(imd_distance_df) +
    geom_hex(aes(log(`distance_pch mean`), canopy_cover)) +
    scale_fill_distiller(palette = 'Greens') +
    labs(title = '3 v 30', x = 'Distance to closest tree (log(m))',
             y = 'Canopy cover (%)', fill = 'Frequency') +
    theme_minimal()

# boxplot
ggplot(imd_distance_df) +
    geom_boxplot(aes(x = as.factor(SOA_decile), y = log(`distance_pch mean`)))

ggplot(imd_distance_df) +
    geom_boxplot(aes(x = as.factor(SOA_decile), y = log(`distance_ogs mean`)))
