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

pal <- colorNumeric(palette = "YlOrRd", domain = map$RR)

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
    addTiles() %>%
    addPolygons(
        color = "grey", weight = 1, fillColor = ~ pal(RR_eh),
        fillOpacity = 0.5,
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
    addLegend(
        pal = pal, values = ~RR_eh, opacity = 0.5, title = "RR",
        position = "bottomright"
    )
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


# Critically analysing the 3/30/300 for health
# hotspot analysis  econometrics (geoda)
# real state prices 
# Focus on outliers
# cold spot vs hot spots (Check Luton)