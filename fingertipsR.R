library(fingertipsR)

profs <- profiles()
profid <- 26
inds <- indicators(ProfileID = profid)
print(inds[grepl("Healthy", inds$IndicatorName), c("IndicatorID", "IndicatorName")])

indid <- 41001
df <- fingertips_data(IndicatorID = indid, AreaTypeID = 302)

