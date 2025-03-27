
# Packages ----------------------------------------------------------------

library(logger)
library(argparse)
library(future)
library(future.apply)
library(progress)
library(jsonlite)
library(readr)
library(dplyr)
library(stringr)
library(terra)
library(sf)
library(lidR)

source("scripts/constants.R")

# Paths -------------------------------------------------------------------

vom_dir <- here(RASTER_IN_DIR, "Defra", "VOM")
vom_lad_dir <- here(vom_dir, "LADs")
trees_dir <- here(VECTOR_OUT_DIR, "3-30-300", "VOM_Trees")
chm_lad_tiles_path <- here(vom_lad_dir, "LAD_CHM_tiles_paths.json")
chm_lad_tiles_lst <- jsonlite::read_json(chm_lad_tiles_path, simplifyVector = T)
chm_tif_paths <- sort(unique(unlist(chm_lad_tiles_lst)))

extract_trees <- function(chm_spat_rast) {

    kernel <- matrix(1, 5, 5)
    chm_smoothed <- focal(chm_spat_rast, w = kernel, fun = median, na.rm = T)
    current_crs <- terra::crs(chm_smoothed)

    chm_smoothed_rast <- raster::raster(chm_smoothed)
    terra::crs(chm_smoothed_rast) <- current_crs

    f <- function(z) {
        z[z < 3] <- 3  # Ignore very low vegetation
        
        # Wider Gaussian function to prevent over-segmentation
        mu <- 18  # Focus on taller trees
        sigma <- 7  # Wider spread to avoid excessive detections
        size <- round(6 + 18 * exp(-((z - mu)^2) / (2 * sigma^2)))  
        
        # Larger window constraints to prevent too many detections
        min_size <- 7  # Minimum window size increased
        max_size <- 0.7 * quantile(z, 0.95, na.rm = TRUE)  # 70% of tallest trees
        
        size[size < min_size] <- min_size
        size[size > max_size] <- max_size
        
        return(size)
    }

    log_warn('Locating Trees')
    ttops_chm_smoothed <- locate_trees(chm_smoothed, lmf(f))
    if (nrow(ttops_chm_smoothed) == 0) {
        ttops_chm_smoothed <- locate_trees(chm_spat_rast, lmf(f))
    }
    ttops_chm_smoothed_spat_vect <- vect(ttops_chm_smoothed)
    names(ttops_chm_smoothed_spat_vect)[2] <- 'height'

    log_warn('Segmenting Trees')
    algo <- dalponte2016(chm_smoothed_rast, ttops_chm_smoothed)
    crowns <- algo()
    crowns_spat_rast <- as(crowns, 'SpatRaster')

    crowns_vect <- as.polygons(crowns_spat_rast)
    names(crowns_vect) <- 'treeID'

    log_warn('Saving Crowns')
    crowns_vect <- merge(crowns_vect, ttops_chm_smoothed_spat_vect, by = 'treeID')
    crowns_vect$area <- expanse(crowns_vect, unit = "m")
    
    return(crowns_vect)
}

process_vom_tile <- function(chm_path) {
    library(logger)
    log_appender(appender_file("logs/VOM_Trees_calculation.log"))
    log_formatter(formatter_glue)
    log_layout(layout_glue_generator("{time} - {level} - {msg}"))
    log_threshold(log_level)
    tryCatch({   
        # Extract the parent folder (2023)
        year <- str_match(chm_path, ".*/(\\d{4})/.*")[,2]

        # Extract the specific part of the filename (two uppercase letters followed by four numbers)
        tile_name <- str_match(chm_path, "VOM_([A-Z]{2}\\d{4})_")[,2]
        
        log_warn(paste("Processing tile", tile_name, "from", year))

        crowns_path <- here(trees_dir, paste0("VOM_trees_", tile_name, "_", year, ".gpkg"))

        if (!file.exists(crowns_path)) {
            chm_spat_rast <- rast(chm_path)
            crowns_vect <- extract_trees(chm_spat_rast)

            writeVector(crowns_vect, crowns_path, overwrite = T)
        }
    },
    error = function(e) {
        log_error("Error processing: ", e$message)

        return(NULL)
    }
    # warning = function(w) {
    #     message("Warning when reading file: ", chm_path)
    #     message("Warning message: ", w$message)
    #     return(NULL)
    # }
    )
}

# Create a parser object
parser <- ArgumentParser(description = "This script segments trees from CHM tiles")

# Add arguments
parser$add_argument("--parallel", type = "logical", default=F, help = "Run job in parallel")
parser$add_argument("--n_workers", type = "integer", default = 2, help = "Number of workers")
parser$add_argument('--log_level', type = "character", default = 'WARN', help = "Logging level")

# Parse the arguments
args <- parser$parse_args()

parallel <- args$parallel
n_workers <- args$n_workers
log_level <- args$log_level

# Set the log format
# log_appender(appender_console)
log_appender(appender_file("logs/VOM_Trees_calculation.log"))
log_formatter(formatter_glue)
log_layout(layout_glue_generator("{time} - {level} - {msg}"))
log_threshold(log_level)

if (parallel) {
    
    log_warn("Running in parallel")

    # cl <- makeCluster(n_workers)
    # clusterExport(cl, varlist = c("process_vom_tile", "extract_trees", "rast", "here", "str_match",
    #                               "log_warn", "log_warn", "writeVector", "trees_dir", "chm_lad_tiles_lst",
    #                               "chm_tif_paths"))
    # pboptions(type = "timer")
    # pblapply(chm_tif_paths, process_vom_tile, cl = cl)
    # stopCluster(cl)
    plan(multisession, workers = n_workers)
    future.apply::future_lapply(chm_tif_paths, process_vom_tile)

} else {

    pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = length(chm_tif_paths))
    log_warn("Running sequentially")

    for (chm_path in chm_tif_paths) {
        
        process_vom_tile(chm_path)
        pb$tick()
    }
}
