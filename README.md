# (Urban) Tree Detection

## Requirements

- Poetry (Python package manager)
- *.env*
  - **DATA_FOLDER**: Path to data folders

## Data

- **PCH:** UK Canopy Height using Planet imagery
  - Raster (tif, vrt)
  - 5-m resolution
  - Tiled
- **BHF:** GB Building Height and Footprint
  - Vector (gpkg)
  - Per GB Grid tile
- **BUA:** UK Built up areas
  - Vector (gpkg)
  - All of the UK
- **PGS:** GB Public green spaces
  - Vector (shp)
  - All of the UK
- **GBG:** GB Grid system (5 km)
  - Vector (shp)
  - All of GB

## Step-by-Step Process

1. Dissolve **BUA** into one feature (1 x *.gpkg*)
2. Mask each tile from **PCH** with **BUA dissolved**
3. Filter **PCH mask** with values between 3 and 70 (n x *.tif*)
4. Create *.vrt* from **PCH mask filtered**
5. Dissolve adjacent polygons from **BHF** (n x *.gpkg*)
   - Spatial join of **BHF** with itself to get statistics
6. Crop each tile from **PCH filtered** using extent of **GB grid** tiles (n x *.tif*)
   - Cross-reference extent with **BHF dissolved**
7. Vectorise **PCH filtered tiled** (n x *.gpkg*)
8. Calculate nearest point in **PCH filtered tiled** to each feature in **BHF dissolved**
