#!/bin/bash

# bash script for converting raw lidar data (.las and/or .laz) using PDAL into a DEM, and subsequently using GDAL into a Hillshade and Contours
# Usage: basemap-batch.sh <lidar_DIRECTORY/*.laz> or <lidar_DIRECTORY/*.las>

# Assumes that this script, both the PDAL JSON files, both the color_xxxxxxxxx.txt, pullauta (and pullauta.ini) and the LiDAR files are in the same DIRECTORY

#Select Program to Use to Process
echo Select processing programs to run - options are PDAL, KARTTA, or BOTH.
read PROG
if [ $PROG = PDAL ] || [ $PROG = BOTH ]
then
	#Make PDAL Output Directory
	DIRECTORY=PDAL_Output
	mkdir $DIRECTORY
	#PDAL INPUT OPTIONS
	echo Select PDAL options - options are GROUND, VEG, or BOTH. 
	read PDALOPTS
	if [ $PDALOPTS = "GROUND" ] || [ $PDALOPTS = "BOTH" ]
	then
		PDALGROUND=YES
		echo Select basemap style - options are 5, 2-5, or 2.
		read STYLE
		echo Style set to $STYLE
	fi 
	if [ $PDALOPTS = "VEG" ] || [ $PDALOPTS = "BOTH" ]
	then
		PDALVEG=YES
	fi
	
fi

if [ $PROG = "KARTTA" ] || [ $PROG = "BOTH" ]
then
	KARTTA=YES
fi

#PDAL Ground Processing
if [ $PDALGROUND = "YES" ]
then
	SECONDS=0
	echo Starting PDAL Processing.  Generating DEM.
	pdal pipeline PDAL-LAS-to-DEM.json
	#GDAL Processing - Ground Points Only
	echo Done PDAL and DEM processing, starting GDAL - Generating hillshade.
	gdaldem hillshade DEM.tif $DIRECTORY/hillshade.tiff
	echo Done processing hillshade, generating intermediate-slope map.
	gdaldem slope -p -b 1 DEM.tif slope.tiff
	echo Done processing intermediate-slope map, generating slopeshade.
	gdaldem color-relief slope.tiff color_slope.txt $DIRECTORY/slopeshade.tiff
	rm slope.tiff
	echo Done processing GDAL Layers.  Processing Contours.

	#Generating Contours
	if [ $STYLE = "5" ]
	then
		gdal_contour -b 1 -a elev -i 1 DEM.tif 1m_contours_int.shp
		echo 1m Contours Generated.  Formatting to 25m Index Contour, 5m Contour, and 1m Formline
		ogr2ogr -where 'elev %1 = 0 AND elev %5 != 0' $DIRECTORY/1m_contours.shp 1m_contours_int.shp
		ogr2ogr -where 'elev %5 = 0 AND elev %25 != 0' $DIRECTORY/5m_contours.shp 1m_contours_int.shp
		ogr2ogr -where 'elev %25 = 0' $DIRECTORY/25m_contours.shp 1m_contours_int.shp
		rm 1m_contours_int.*
	fi

	if [ $STYLE = "2" ]
	then
		gdal_contour -b 1 -a elev -i 0.5 DEM.tif 0-5m_contours_int.shp
		echo 1m Contours Generated.  Formatting to 10m Index Contour, 2m Contour, and 0.5m Formline
		ogr2ogr -where "elev %2 != 0" $DIRECTORY/0-5m_contours.shp 0-5m_contours_int.shp
		ogr2ogr -where 'elev %2 = 0 AND elev %10 != 0' $DIRECTORY/2m_contours.shp 0-5m_contours_int.shp
		ogr2ogr -where 'elev %10 = 0' $DIRECTORY/10m_contours.shp 0-5m_contours_int.shp
		rm 0-5m_contours_int.*
	fi
	if [ $STYLE = "2-5" ]
	then
		gdal_contour -b 1 -a elev -i 0.5 DEM.tif 0-5m_contours_int.shp
		echo 1m Contours Generated.  Formatting to 10m Index Contour, 2m Contour, and 0.5m Formline
		ogr2ogr -where "elev - 2.5 * CAST((elev / 2.5) as Integer) != 0" $DIRECTORY/0-5m_contours.shp 0-5m_contours_int.shp
		ogr2ogr -where "elev - 2.5 * CAST((elev / 2.5) as Integer) = 0 AND 12.5 * CAST((elev / 12.5) as Integer) != 0" $DIRECTORY/2-5m_contours.shp 0-5m_contours_int.shp
		ogr2ogr -where 'elev - 12.5 * CAST((elev / 12.5) as Integer) = 0' $DIRECTORY/12-5m_contours.shp 0-5m_contours_int.shp
		rm 0-5m_contours_int.*
	fi

	cp DEM.tif $DIRECTORY/
	rm DEM.tif
	PDALGND_TIME=$SECONDS
	echo Contours Formatted.  Done ground-based basemaps.  
	echo PDAL Ground took "$(($PDALGND_TIME / 60)) minutes and $(($PDALGND_TIME % 60)) seconds."
fi

#CANOPY HEIGHT MODEL PDAL VEG
if [ $PDALVEG = "YES" ]
then	
	SECONDS=0
	echo Started PDAL Processing.  Calculating Height Above Ground
	pdal pipeline PDAL-LAS-to-Veg-Height.json
	wait
	echo Finished HAG Calculations.  GDAL processing Canopy Height Model Started
	gdaldem color-relief Veg-Height.tif color_veg-height.txt $DIRECTORY/Canopy-Height.tif
	rm Veg-Height.tif
	PDALVEG_TIME=$SECONDS
	echo PDAL Veg took "$(($PDALVEG_TIME / 60)) minutes and $(($PDALVEG_TIME % 60)) seconds."
	echo Canopy Height Model Done --- 0m = Yellow - 1m = Red 2m = Green - 20m = Blue - 50m = Black
fi

#KARTTAPULLAUTIN Processing

if [ $KARTTA = "YES" ]
then
	SECONDS=0
	lasmerge -i *.laz -o all_merged.laz
	perl pullauta all_merged.laz
	KP_TIME=$SECONDS
	echo Rusty Karttapullautin took "$(($KP_TIME / 60)) minutes and $(($KP_TIME % 60)) seconds."
fi


echo All done.
