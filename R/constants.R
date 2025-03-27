
library(here)

DATA_DIR <- Sys.getenv("DATA_DIR")
INPUT_DIR <- here(DATA_DIR, "input")
OUTPUT_DIR <- here(DATA_DIR, "output")
VECTOR_IN_DIR <- here(INPUT_DIR, "vector")
VECTOR_OUT_DIR <- here(OUTPUT_DIR, "vector")
RASTER_IN_DIR <- here(INPUT_DIR, "raster")
RASTER_OUT_DIR <- here(OUTPUT_DIR, "raster")
TABULAR_IN_DIR <- here(INPUT_DIR, "tabular")
TABULAR_OUT_DIR <- here(OUTPUT_DIR, "tabular")
SERIALISED_OUT_DIR <- here(OUTPUT_DIR, "serialised")