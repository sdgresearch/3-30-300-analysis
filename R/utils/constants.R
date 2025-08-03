
library(here)

HOME_DIR <- Sys.getenv("HOME_DIR")
DATA_DIR <- Sys.getenv("DATA_DIR")
INPUT_DIR <- here(DATA_DIR, "input")
OUTPUT_DIR <- here(DATA_DIR, "output")
JAVA_HOME <- here(dirname(DATA_DIR), ".jdk", Sys.getenv("JDK_HOME"))
Sys.setenv("JAVA_HOME"=JAVA_HOME)
Sys.setenv("PROJ_LIB"=paste0(Sys.getenv("CONDA_PREFIX"), "/envs/r-env/share/proj"))
PROJECT_CRS <- "EPSG:27700"  # OSGB 1936 / British National Grid
WGS84_CRS <- "EPSG:4326"
WEB_MERCATOR_CRS <- "EPSG:3857"
