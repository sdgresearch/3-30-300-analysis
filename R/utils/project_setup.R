# Check and install the packages required by the R scripts in this repository.
# Run once before using R/chm_processing.R, R/data_processing.R,
# R/data_modelling.R or R/data_analysis.R.
required_packages <- c(
    # Data handling
    "arrow", "geoarrow", "dplyr", "tidyr", "readr", "forcats", "stringr",
    "purrr", "jsonlite", "here", "BBmisc", "DescTools",
    # Spatial
    "sf", "terra", "raster", "lidR", "spdep", "spatialreg", "classInt",
    # Plotting
    "ggplot2", "cowplot", "patchwork", "ggcorrplot", "corrplot", "ggpubr",
    "biscale", "ggbump", "ggalluvial", "RColorBrewer", "kableExtra",
    # Pipeline utilities
    "argparse", "logger", "future", "future.apply", "progress"
)
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
    install.packages(missing_packages)
}

# ggmagnify is only available from r-universe
if (!requireNamespace("ggmagnify", quietly = TRUE)) {
    install.packages("ggmagnify", repos = c("https://hughjonesd.r-universe.dev",
                                            "https://cloud.r-project.org"))
}
