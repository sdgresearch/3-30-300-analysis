
# Libraries ---------------------------------------------------------------

library(jsonlite)
library(dplyr)
library(stringr)
library(readr)
library(terra)

library(sf)
library(lidR)

source("scripts/constants.R")

# Variables ---------------------------------------------------------------

geo_code <- 'E09000013'

# Data Paths --------------------------------------------------------------

# imd_lsoa_bua_boundaries_path <- here(VECTOR_OUT_DIR, "IMD", "English_IMD_2019_BUA_filtered_boundaries.geojson")
vom_dir <- here(RASTER_INPUT_DIR, "Defra", "VOM")
vom_lad_dir <- here(vom_dir, "LADs")
T3_dir <- here(VECTOR_OUTPUT_DIR, "3-30-300", "T3")
chm_lad_tiles_path <- here(vom_lad_dir, "LAD_CHM_tiles_paths.json")
chm_lad_tiles_lst <- jsonlite::read_json(chm_lad_tiles_path, simplifyVector = T)
crowns_path <- here(T3_dir, paste0("T3_", geo_code, ".geojson"))

chm_tif_paths <- chm_lad_tiles_lst[[geo_code]]

valid_rasters <- list()

for (path in chm_tif_paths) {
    r <- rast(path)
    if (!is.null(r)) {
        valid_rasters[[length(valid_rasters) + 1]] <- r
    }
}

chm_spat_rast <- merge(sprc(valid_rasters))

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

print('Locating Trees')
ttops_chm_smoothed <- locate_trees(chm_smoothed, lmf(f))
ttops_chm_smoothed_spat_vect <- vect(ttops_chm_smoothed)
names(ttops_chm_smoothed_spat_vect)[2] <- 'height'
write_rds(ttops_chm_smoothed, "temp/ttops_chm_smoothed.rds")
write_rds(chm_smoothed, "temp/chm_smoothed.rds")

print('Segmenting Trees')
algo <- dalponte2016(chm_smoothed_rast, ttops_chm_smoothed)
crowns <- algo()
crowns_spat_rast <- as(crowns, 'SpatRaster')

crowns_vect <- as.polygons(crowns_spat_rast)
names(crowns_vect) <- 'treeID'

print('Saving Crowns')
crowns_vect <- merge(crowns_vect, ttops_chm_smoothed_spat_vect, by = 'treeID')
crowns_vect$area <- expanse(crowns_vect, unit = "m")
writeVector(crowns_vect, crowns_path, overwrite = T)
