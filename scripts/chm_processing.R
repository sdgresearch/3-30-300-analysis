
# Libraries ---------------------------------------------------------------

library(logger)
library(argparse)
library(parallel)
library(pbapply)
library(progress)
library(jsonlite)
library(readr)
library(dplyr)
library(stringr)
library(terra)
library(sf)
library(lidR)

source("scripts/constants.R")

# Data Paths --------------------------------------------------------------

vom_dir <- here(RASTER_INPUT_DIR, "Defra", "VOM")
vom_lad_dir <- here(vom_dir, "LADs")
trees_dir <- here(VECTOR_OUTPUT_DIR, "3-30-300", "VOM_Trees")
chm_lad_tiles_path <- here(vom_lad_dir, "LAD_CHM_tiles_paths.json")
chm_lad_tiles_lst <- jsonlite::read_json(chm_lad_tiles_path, simplifyVector = T)
chm_tif_paths <- sort(unique(unlist(chm_lad_tiles_lst)))

# geo_code <- 'E09000013'
# crowns_path <- here(T3_dir, paste0("T3_", geo_code, ".geojson"))
# chm_tif_paths <- chm_lad_tiles_lst[[geo_code]]
# valid_rasters <- list()
# for (path in chm_tif_paths) {
#     r <- rast(path)
#     if (!is.null(r)) {
#         valid_rasters[[length(valid_rasters) + 1]] <- r
#     }
# }
# chm_spat_rast <- merge(sprc(valid_rasters))

extract_trees <- function(chm_spat_rast) {

    kernel <- matrix(1,3,3)
    chm_smoothed <- focal(chm_spat_rast, w = kernel, fun = median, na.rm = T)
    current_crs <- terra::crs(chm_smoothed)

    chm_smoothed_rast <- raster::raster(chm_smoothed)
    terra::crs(chm_smoothed_rast) <- current_crs

    f <- function(x) {
        y <- 2.6 * (-(exp(-0.08 * (x - 2)) - 1)) + 3
        y[x < 2] <- 3
        y[x > 20] <- 5
        return(y)
    }

    log_debug('Locating Trees')
    ttops_chm_smoothed <- locate_trees(chm_smoothed, lmf(f))
    ttops_chm_smoothed_spat_vect <- vect(ttops_chm_smoothed)
    names(ttops_chm_smoothed_spat_vect)[2] <- 'height'
    # write_rds(ttops_chm_smoothed, "temp/ttops_chm_smoothed.rds")
    # write_rds(chm_smoothed, "temp/chm_smoothed.rds")

    log_debug('Segmenting Trees')
    algo <- dalponte2016(chm_smoothed_rast, ttops_chm_smoothed)
    crowns <- algo()
    crowns_spat_rast <- as(crowns, 'SpatRaster')

    crowns_vect <- as.polygons(crowns_spat_rast)
    names(crowns_vect) <- 'treeID'

    log_debug('Saving Crowns')
    crowns_vect <- merge(crowns_vect, ttops_chm_smoothed_spat_vect, by = 'treeID')
    crowns_vect$area <- expanse(crowns_vect, unit = "m")
    
    return(crowns_vect)
}

process_vom_tile <- function(chm_path) {
    
    # Extract the parent folder (2023)
    year <- str_match(chm_path, ".*/(\\d{4})/.*")[,2]

    # Extract the specific part of the filename (two uppercase letters followed by four numbers)
    tile_name <- str_match(chm_path, "VOM_([A-Z]{2}\\d{4})_")[,2]
    
    log_info(paste("Processing tile", tile_name, "from", year))

    crowns_path <- here(trees_dir, paste0("VOM_trees_", tile_name, "_", year, ".geojson"))
    chm_spat_rast <- rast(chm_path)
    crowns_vect <- extract_trees(chm_spat_rast)

    writeVector(crowns_vect, crowns_path, overwrite = T)
}

log_threshold(DEBUG)

# Create a parser object
parser <- ArgumentParser(description = "Example script with argparse")

# Add arguments
parser$add_argument("--parallel", type = "logical", default=F, help = "Run job in parallel")
parser$add_argument("--n_workers", type = "integer", default = 2, help = "Number of workers")

# Parse the arguments
args <- parser$parse_args()

parallel <- args$parallel
n_workers <- args$n_workers

if (parallel) {
    
    log_debug("Running in parallel")

    cl <- makeCluster(n_workers)
    clusterExport(cl, varlist = c("process_vom_tile", "chm_tif_paths", "trees_dir",
                                  "extract_trees", "rast", "here", "str_match",
                                  "log_info", "log_debug", "writeVector"))
    pboptions(type = "timer")
    pblapply(cl, chm_tif_paths, process_vom_tile)
    stopCluster(cl)

} else {
    # print('************************')
    pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = length(chm_tif_paths))
    log_debug("Running sequentially")

    for (chm_path in chm_tif_paths) {
        
        process_vom_tile(chm_path)
        pb$tick()
    }
}
