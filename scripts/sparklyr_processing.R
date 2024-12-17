
library(sparklyr)
library(dplyr)

source("scripts/constants.R")
sc <- spark_connect(master <- "local")

project_crs <- 'EPSG:27700'

T3_30_300_DIR <- here(VECTOR_OUT_DIR, "3-30-300")
T3_dir <- here(T3_30_300_DIR, "T3")
T30_dir <- here(T3_30_300_DIR, "T30")
T300_dir <- here(T3_30_300_DIR, "T300")
t3_30_300_path <- here(T3_30_300_DIR, "T3_30_300.geojson")
imd_lsoa_bua_boundaries_path <- here(VECTOR_OUT_DIR, "IMD", "English_IMD_2019_BUA_filtered_boundaries.geojson")
imd_england_path <- here(VECTOR_IN_DIR, "IMD", "English IMD 2019", "IMD_2019.shp")
buildings_path <- here(VECTOR_IN_DIR, "EDINA", "Buildings_6183", "Buildings_6183.parquet")

t3_sdf <- spark_read_csv(sc, name = "t3", path = T3_dir, header = T, infer_schema = T)
t30_sdf <- spark_read_csv(sc, name = "t30", path = T30_dir, header = T, infer_schema = T)
t300_sdf <- spark_read_csv(sc, name = "t300", path = T300_dir, header = T, infer_schema = T)

