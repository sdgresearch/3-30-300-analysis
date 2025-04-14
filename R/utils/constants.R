
library(here)

DATA_DIR <- Sys.getenv("DATA_DIR")
INPUT_DIR <- here(DATA_DIR, "input")
OUTPUT_DIR <- here(DATA_DIR, "output")
JAVA_HOME <- here(dirname(DATA_DIR), ".jdk", Sys.getenv("JDK_HOME"))

PROJECT_CRS <- "EPSG:27700"  # OSGB 1936 / British National Grid