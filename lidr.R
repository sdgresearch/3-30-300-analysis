library(raster)
library(terra)
library(lidR)
library(tidyterra)
library(sf)
library(tidyverse)

# One File Processing -----------------------------------------------------

img_rgbni_path <- "/Users/ancazugo/Library/CloudStorage/GoogleDrive-acz25@cam.ac.uk/My Drive/PhD Thesis/data/imagery/PlanetScope/composite.tif"
img_rgbni_path <- "/Users/ancazugo/Downloads/WV2_2018_32630.tif"
 
# NDVI --------------------------------------------------------------------
 
img_rgbni <- rast(img_rgbni_path) %>% 
  project("epsg:27700")

# img_ndvi <- (img_rgbni[[4]] - img_rgbni[[3]]) / (img_rgbni[[4]] + img_rgbni[[3]]) #planet
img_ndvi <- (img_rgbni[[4]] - img_rgbni[[1]]) / (img_rgbni[[4]] + img_rgbni[[1]]) #WV2

# Point Cloud -------------------------------------------------------------

las_file <- "/Users/ancazugo/Downloads/Download_Cambridge_LiDAR_2523456/england-laz-2017_5536972/tl/tl4456_p_11045_20170311_20170405.laz"
las <- readLAS(las_file) #%>% 
  # st_transform(st_crs(32630))
las@data$ndvi <- extract(img_ndvi, cbind(las@data$X, las@data$Y))
las_filt <- filter_poi(las, (Classification %in% c(4,5) & NumberOfReturns > 1) & ndvi > 0.4)
las_filt <- clip_rectangle(las_filt, 545250, 256750, 545500, 257250)
# 545250, 256750, 545500, 257250 #CRS: 27700

chm_filt <- rasterize_canopy(las_filt, res = 0.5, 
                             pitfree(thresholds = seq(0,30,2), subcircle = 0, max_edge = c(0,5)))
plot(chm_filt, col = height.colors(50))

f <- function(x) {
  y <- 2.6 * (-(exp(-0.08 * (x - 2)) - 1)) + 10
  y[x < 2] <- 10
  y[x > 20] <- 15
  return(y)
}
f <- function(x) {x * 0.1 + 10}

ttops_filt <- locate_trees(las_filt, lmf(f))
plot(sf::st_geometry(ttops_filt), add = TRUE, pch = 3)

algo <- dalponte2016(chm_filt, ttops_filt,th_tree = 3, max_cr = 25)
las_ttops_filt <- segment_trees(las_filt, algo) # segment point cloud

crowns <- crown_metrics(las_ttops_filt, func = .stdtreemetrics, geom = "convex") %>% 
  dplyr::filter(npoints > 100)
plot(crowns["convhull_area"], main = "Crown area (convex hull)")
st_write(crowns, "/Users/ancazugo/Downloads/crowns.geojson", delete_layer = T)

ggplot() +
  geom_spatraster(data=crop(img_rgbni, ext(545250, 545500, 256750, 257250))) +
  geom_sf(data = crowns["convhull_area"], fill = NA, color = "red") +
  theme_minimal() +
  labs(title = "Raster with SF Layer Overlay")

# Multiple-file Processing ------------------------------------------------

sentinel2_ndvi_path <- "/Users/ancazugo/Downloads/NDVI_Sentinel2.tif"
point_cloud_dir <- "/Users/ancazugo/Downloads/Download_Cambridge_LiDAR_2523456/england-laz-2017_5536972/tl/"
dtm_path <- ""

img_ndvi <- rast(sentinel2_ndvi_path) %>% 
  project("epsg:27700")

point_cloud_files <- list.files(point_cloud_dir, full.names = T)

point_cloud_files <- point_cloud_files[str_detect(x, '[1-9].laz')]

ctg <- readLAScatalog(point_cloud_files)
las_check(ctg, deep = T)

# Define a custom function to extract raster values and add them to LAS points
filter_vegetation_point_cloud <- function(chunk, ndvi_img) {
  # Convert LAS points to a data frame
  las <- readLAS(chunk)
  if (lidR::is.empty(las)) return(NULL)
  las@data$ndvi <- raster::extract(ndvi_img, cbind(las@data$X, las@data$Y))
  las_filt <- filter_poi(las, (Classification %in% c(4,5) & NumberOfReturns > 1) & ndvi > 0.4)
  las_filt <- filter_poi(las_filt, buffer == 0)
  
  return(las_filt)
}

opt_output_files(ctg) <-  paste0(tempdir(), "/{*}_norm")
ctg_norm <- normalize_height(ctg, tin())

opt_output_files(ctg_norm) <-  paste0(tempdir(), "/{*}_filt")
options <- list(automerge = TRUE)
ctg_norm_filt <- catalog_apply(ctg_norm, filter_vegetation_point_cloud, img_ndvi, .options = options)

ctg_filt_unique <- ctg_norm_filt %>% filter_duplicates()

chm_filt <- rasterize_canopy(ctg_filt_unique, res = 0.5, 
                             pitfree(thresholds = seq(0,30,2), subcircle = 0, max_edge = c(0,5)))

rasterize_canopy_catalog <- function(chunk) {
  
  # Convert LAS points to a data frame
  las <- readLAS(chunk)
  if (lidR::is.empty(las)) return(NULL)
  
  chm <- rasterize_canopy(chunk, res = 0.5, 
                               pitfree(thresholds = seq(0,30,2), subcircle = 0, max_edge = c(0,5)))
  
  return(chm)
}

opt_output_files(ctg_filt_unique) <-  paste0(tempdir(), "/{*}_chm")

chm_filt <- catalog_apply(ctg_filt_unique, rasterize_canopy_catalog, .options = options)

locate_trees_catalog <- function(chunk, func) {
  
  ttops_filt <- locate_trees(chunk, lmf(func))
  
  return(ttops_filt)
}

opt_output_files(ctg_filt_unique) <-  paste0(tempdir(), "/{*}_ttop2")
chm_filt <- catalog_apply(ctg_filt_unique, locate_trees_catalog, f, .options = options)

ttops_filt <- locate_trees(ctg_filt_unique, lmf(f), uniqueness = "bitmerge")

read_ttops <- function(ttops_files) {
  ttops_list <- lapply(ttops_files, st_read)
  ttops_combined <- do.call(rbind, ttops_list)
  return(ttops_combined)
}

# Combine the tree tops into a single LAS object
ttops_combined <- read_ttops(ttops_filt)
ttops_combined_unique <- ttops_combined %>% distinct(treeID, .keep_all = T)

opt_output_files(ctg_filt_unique) <- paste0(tempdir(), "/{*}_tree")

algo <- dalponte2016(chm_filt, ttops_combined_unique, th_tree = 3, max_cr = 25)
las_ttops_filt <- segment_trees(ctg_filt_unique, algo) # segment point cloud

crowns <- crown_metrics(las_ttops_filt, func = .stdtreemetrics, geom = "convex")
  
crowns_total <- read_ttops(crowns) %>% 
  dplyr::filter(npoints > 100)
plot(crowns_total["convhull_area"], main = "Crown area (convex hull)")
st_write(crowns_total, "/Users/ancazugo/Downloads/crowns.geojson", delete_layer = T)
