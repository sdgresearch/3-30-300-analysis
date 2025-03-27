library(leaflet)

map <- model_df
map$RR_b <- base_inla_model$summary.fitted.values[, "mean"]
map$LL_b <- base_inla_model$summary.fitted.values[, "0.025quant"]
map$UL_b <- base_inla_model$summary.fitted.values[, "0.975quant"]
map$RR_eb <- expanded_base_inla_model$summary.fitted.values[, "mean"]
map$LL_eb <- expanded_base_inla_model$summary.fitted.values[, "0.025quant"]
map$UL_eb <- expanded_base_inla_model$summary.fitted.values[, "0.975quant"]
map$RR_h <- hypothesis_inla_model$summary.fitted.values[, "mean"]
map$LL_h <- hypothesis_inla_model$summary.fitted.values[, "0.025quant"]
map$UL_h <- hypothesis_inla_model$summary.fitted.values[, "0.975quant"]
map$RR_eh <- expanded_hypothesis_inla_model$summary.fitted.values[, "mean"]
map$LL_eh <- expanded_hypothesis_inla_model$summary.fitted.values[, "0.025quant"]
map$UL_eh <- expanded_hypothesis_inla_model$summary.fitted.values[, "0.975quant"]

pal_RR <- colorNumeric(palette = "YlOrRd", domain = map$RR_eh)
pal_IMD <- colorNumeric(palette = "RdYlBu", domain = map$IMD_Decile)
pal_canopy <- colorNumeric(palette = "Greens", domain = map$canopy_cover)
pal_NDVI <- colorNumeric(palette = "PRGn", domain = map$NDVI)

labels <- sprintf("<strong> %s </strong> <br/>
                  Observed: %s <br/> Expected: %s <br/>
                  3-Visibility: %s <br/> 30-Availability: %s <br/>
                  300-Accessibility: %s <br/> IncScore: %s <br/> EmpScore: %s <br/>
                  EduScore: %s <br/> HDDScore: %s <br/> CriScore: %s <br/>
                  BHSScore: %s <br/> EnvScore: %s <br/> SIR: %s <br/> 
                  RR_b: %s (%s, %s) <br/>
                  RR_eb: %s (%s, %s) <br/>
                  RR_h: %s (%s, %s) <br/>
                  RR_eh: %s (%s, %s) <br/>",
                  map$lsoa, map$diabetes_qof, round(map$diabetes_expected, 2),
                  round(map$d_pch, 2), round(map$canopy_cover, 2), round(map$d_ogs, 2), 
                  round(map$IncScore, 2), round(map$EmpScore, 2), round(map$EduScore, 2), 
                  round(map$HDDScore, 2), round(map$CriScore, 2), round(map$BHSScore, 2), 
                  round(map$EnvScore, 2), round(map$diabetes_SIR, 2),
                  round(map$RR_b, 2), round(map$LL_b, 2), round(map$UL_b, 2),
                  round(map$RR_eb, 2), round(map$LL_eb, 2), round(map$UL_eb, 2),
                  round(map$RR_h, 2), round(map$LL_h, 2), round(map$UL_h, 2),
                  round(map$RR_eh, 2), round(map$LL_eh, 2), round(map$UL_eh, 2)
) %>% lapply(htmltools::HTML)

lRR <- leaflet(map) %>%
    # addTiles() %>% 
    addProviderTiles("CartoDB.Positron") %>%
    addPolygons(
        color = "grey", weight = 2, fillColor = ~ pal_RR(RR_eh),
        fillOpacity = 0.7, group = 'Relative Risk',
        highlightOptions = highlightOptions(weight = 4),
        label = labels,
        labelOptions = labelOptions(
            style =
                list(
                    "font-weight" = "normal",
                    padding = "3px 8px"
                ),
            textsize = "15px", direction = "auto"
        )
    ) %>%
    addPolygons(
        color = "grey", weight = 2, fillColor = ~ pal_IMD(IMD_Decile),
        fillOpacity = 0.7, group = 'IMD',
        highlightOptions = highlightOptions(weight = 4),
        label = labels,
        labelOptions = labelOptions(
            style =
                list(
                    "font-weight" = "normal",
                    padding = "3px 8px"
                ),
            textsize = "15px", direction = "auto"
        )
    ) %>%
    addPolygons(
        color = "grey", weight = 2, fillColor = ~ pal_canopy(canopy_cover),
        fillOpacity = 0.7, group = 'Canopy Cover',
        highlightOptions = highlightOptions(weight = 4),
        label = labels,
        labelOptions = labelOptions(
            style =
                list(
                    "font-weight" = "normal",
                    padding = "3px 8px"
                ),
            textsize = "15px", direction = "auto"
        )
    ) %>%
    addPolygons(
        color = "grey", weight = 2, fillColor = ~ pal_NDVI(NDVI),
        fillOpacity = 0.7, group = 'NDVI',
        highlightOptions = highlightOptions(weight = 4),
        label = labels,
        labelOptions = labelOptions(
            style =
                list(
                    "font-weight" = "normal",
                    padding = "3px 8px"
                ),
            textsize = "15px", direction = "auto"
        )
    ) %>%
    addLayersControl(
        baseGroups = c(
            "Positron (minimal)"),
        overlayGroups = c("Relative Risk", "IMD", "Canopy Cover", 'NDVI'),
        options = layersControlOptions(collapsed = T)
    ) #|> 
    # addLegend(
    #     pal = pal, values = ~RR_eh, opacity = 0.5, title = "RR",
    #     position = "bottomright"
    # )
lRR

map <- tibble(.rows = 1)
map$lsoa <- 1
map$RR_b <- mean(base_inla_model$summary.fitted.values[, "mean"])
map$LL_b <- mean(base_inla_model$summary.fitted.values[, "0.025quant"])
map$UL_b <- mean(base_inla_model$summary.fitted.values[, "0.975quant"])
map$RR_eb <- mean(expanded_base_inla_model$summary.fitted.values[, "mean"])
map$LL_eb <- mean(expanded_base_inla_model$summary.fitted.values[, "0.025quant"])
map$UL_eb <- mean(expanded_base_inla_model$summary.fitted.values[, "0.975quant"])
map$RR_h <- mean(hypothesis_inla_model$summary.fitted.values[, "mean"])
map$LL_h <- mean(hypothesis_inla_model$summary.fitted.values[, "0.025quant"])
map$UL_h <- mean(hypothesis_inla_model$summary.fitted.values[, "0.975quant"])
map$RR_eh <- mean(expanded_hypothesis_inla_model$summary.fitted.values[, "mean"])
map$LL_eh <- mean(expanded_hypothesis_inla_model$summary.fitted.values[, "0.025quant"])
map$UL_eh <- mean(expanded_hypothesis_inla_model$summary.fitted.values[, "0.975quant"])

map |> select(lsoa, ends_with(c('_b', '_eb', '_h', '_eh'))) |> 
    pivot_longer(RR_b:UL_eh, names_to = 'Risk_dist', values_to = 'Risk_value') |> 
    mutate(Hypothesis = case_when(Risk_dist |> str_detect('_b') ~ 'Base',
                                  Risk_dist |> str_detect('_eb') ~ 'Expanded Base',
                                  Risk_dist |> str_detect('_h') ~ 'Hypothesis',
                                  Risk_dist |> str_detect('_eh') ~ 'Expanded Hypothesis'),
           Risk_dist = str_replace(Risk_dist, '_[a-z]*', '')) |> 
ggplot() +
    geom_point(aes(x = Risk_value, y = Hypothesis)) +
    theme_bw()


library(sf)
library(ggplot2)
library(RColorBrewer)

# Assuming your spatial data is stored in a variable called 'spatial_data'
# and it has a column named 'IMD_Decile'

# Create the color palette
color_palette <- colorRampPalette(brewer.pal(11, "RdYlBu"))(10)

# Create the map
choropleth_map <- ggplot(data = model_spectral_df) +
    geom_sf(aes(fill = IMD_Decile), color = 'darkgray', size = 0.05) +
    scale_fill_gradientn(colors = color_palette, 
                         name = "IMD Decile",
                         breaks = 1:10,
                         labels = 1:10,
                         limits = c(1, 10)) +
    theme_minimal() +
    theme(legend.position = "bottom",
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank())

choropleth_map


# Critically analysing the 3/30/300 for health
# hotspot analysis  econometrics (geoda)
# real state prices 
# Focus on outliers
# cold spot vs hot spots (Check Luton)