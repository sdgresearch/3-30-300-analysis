devtools::install_github("TESS-Laboratory/chmloader")

library(chmloader)

cambridge_sf <- sf::st_point(c(0.13292455497178973, 52.1993302991873)) |>
    sf::st_sfc(crs = 4326) |>
    sf::st_buffer(10000)

cam_chm <- download_chm(
    cambridge_sf,
    filename = tempfile(fileext = ".tif")
)
terra::plot(cam_chm, col = hcl.colors(256, "viridis"))

f <- function(x) {
    y <- 2.6 * (-(exp(-0.08*(x-2)) - 1)) + 15
    y[x < 2] <- 15
    y[x > 20] <- 25
    return(y)
}

tiles <- makeTiles(cam_chm, c(1024, 1024))

out <- sapply(tiles[401:500], \(tile) {
    x <- rast(tile)
    taos <- lidR::locate_trees(x, lmf(f))
    vect(taos)
})

out <- vect(out) |> 
    st_as_sf()
out

algo <- dalponte2016(tiles, out) #corregir porque no se
crowns <- algo()


sf::write_sf(out, "/Users/ancazugo/Downloads/meta_crowns.geojson", delete_layer = T)

ttops_cam <- locate_trees(cam_chm, lmf(3))
