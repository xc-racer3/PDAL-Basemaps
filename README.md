# PDAL-Basemaps
PDAL Based LiDAR processing scripts for Orienteering Basemaps

bash script for converting raw lidar data (.las and/or .laz) using PDAL and GDAL into a DEM, Hillshade, Slopeshade, Contours, Intensity raster, and Vegetation Height.  Also built in Rusty-Pullaut calling as an option.
Usage: basemap-batch.sh <lidar_DIRECTORY/*.laz> or <lidar_DIRECTORY/*.las

Note:  Assumes that this script, all the PDAL JSON files, all three of the color_xxxxxxxxx.txt, pullauta (and pullauta.ini) and the LiDAR files are in the same DIRECTORY

If you want other layers or have improvements that you want, please add an issue or pull request and I will see what I can do.
