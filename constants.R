
library(here)

DATA_DIR <- Sys.getenv("DATA_DIR")
INPUT_DIR <- here(DATA_DIR, "input")
OUTPUT_DIR <- here(DATA_DIR, "output")
VECTOR_INPUT_DIR <- here(INPUT_DIR, "vector")
VECTOR_OUTPUT_DIR <- here(OUTPUT_DIR, "vector")
RASTER_INPUT_DIR <- here(INPUT_DIR, "raster")
RASTER_OUTPUT_DIR <- here(OUTPUT_DIR, "raster")
TABULAR_INPUT_DIR <- here(INPUT_DIR, "tabular")
TABULAR_OUTPUT_DIR <- here(OUTPUT_DIR, "tabular")
SERIALISED_OUTPUT_DIR <- here(OUTPUT_DIR, "serialised")