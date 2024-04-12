# Attach the 'ForestTools' and 'terra' libraries
library(ForestTools)
library(raster)
library(sf)

DATA_FOLDER <- Sys.getenv('DATA_FOLDER')
imagery_folder <- paste0(DATA_FOLDER, "/imagery")
mask_folder <- paste0(DATA_FOLDER, "/geopackages")
pch_dir <- paste0(imagery_folder, "/UK_planet_height")
pch_diss_dir <- paste0(imagery_folder, "/UK_planet_height_dissolved")
pch_vrt_path <- paste0(pch_dir, "/UK_planet_height.vrt")
pch_diss_vrt_path <- paste0(pch_diss_dir, "/UK_planet_height_dissolved.vrt")

gbg_path <- paste0(mask_folder, "/GB_grids/5km_grid_region.shp")

pch_paths <- sort(list.files(path = pch_diss_dir, pattern = "\\.tif$",
                        recursive = T, full.names = T))
pch_vrt <- raster(pch_paths[78])
gbg_sf <- st_read(gbg_path)

pch_vrt <- raster(pch_diss_vrt_path)
# Reproject the raster or vector
# example_raster <- projectRaster(example_raster, crs = st_crs(gbg_sf)$proj4string)
gbg_sf <- st_transform(gbg_sf, crs = projection(pch_vrt))

# Get the bounding box of the polygon(s)
bboxPolygon <- st_bbox(gbg_sf[9619,])

# Convert to an extent object recognized by the raster package
extentPolygon <- as(extent(bboxPolygon[c("xmin", "xmax", "ymin", "ymax")]), "Extent")
croppedRaster <- crop(pch_vrt, extentPolygon)

croppedRaster2 <- crop(croppedRaster, c(-.5, -.49, 52.11, 52.12))

# Remove plot margins (optional)
par(mar = rep(0.5, 4))
# Plot CHM (extra optional arguments remove labels and tick marks from the plot)
plot(croppedRaster2)

# Function for defining dynamic window size
lin <- function(x){x * 0.05 + 0.6}

# Detect treetops
ttops <- vwf(croppedRaster2, winFun = lin, minHeight = 3)

# Create crown map
crowns_ras <- mcws(treetops = ttops, CHM = chm, minHeight = 3)

# Plot crowns
plot(crowns_ras, col = sample(rainbow(50), nrow(unique(chm)), replace = T), 
     legend = F, xlab = "", ylab = "", xaxt='n', yaxt = 'n')