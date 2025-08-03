# Check and install required packages
required_packages <- c("apache.sedona", "biscale", "gridGeometry", "ggview", "ggmagnify")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
    # Install packages with appropriate repositories
    for (pkg in missing_packages) {
        if (pkg == "ggmagnify") {
            install.packages(pkg, repos = c("https://hughjonesd.r-universe.dev", 
                                          "https://cloud.r-project.org"))
        } else {
            install.packages(pkg)
        }
    }
}