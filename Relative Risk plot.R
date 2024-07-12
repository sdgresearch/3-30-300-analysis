library(leaflet)

map <- model_df
map$RR <- hypothesis_inla_model$summary.fitted.values[, "mean"]
map$LL <- hypothesis_inla_model$summary.fitted.values[, "0.025quant"]
map$UL <- hypothesis_inla_model$summary.fitted.values[, "0.975quant"]

pal <- colorNumeric(palette = "YlOrRd", domain = map$RR)

labels <- sprintf("<strong> %s </strong> <br/>
  Observed: %s <br/> Expected: %s <br/>
  3-Visibility: %s <br/> 30-Availability: %s <br/>
  300-Accessibility: %s <br/> SIR: %s <br/> RR: %s (%s, %s)",
                  map$lsoa, map$diabetes_qof, round(map$diabetes_expected, 2),
                  round(map$d_pch, 2), round(map$canopy_cover, 2), round(map$d_ogs, 2), round(map$diabetes_SIR, 2),
                  round(map$RR, 2),
                  round(map$LL, 2), round(map$UL, 2)
) %>% lapply(htmltools::HTML)

lRR <- leaflet(map) %>%
    addTiles() %>%
    addPolygons(
        color = "grey", weight = 1, fillColor = ~ pal(RR),
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
        pal = pal, values = ~RR, opacity = 0.5, title = "RR",
        position = "bottomright"
    )
lRR

# Critically analysing the 3/30/300 for health
# hotspot analysis  econometrics (geoda)
# real state prices 
# Focus on outliers
# cold spot vs hot spots (Check Luton)