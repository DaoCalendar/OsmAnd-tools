# Script used to create a big sqlite file for hillshading
#   DEM data should be in data/
#   mainly depends on gdal, imagemagick, python-gdal, python-PIL, numpy

# It is strongly advised to split this bash script into smaller ones
# and run them with nohup !
# consider running this world-wide will last a few weeks
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#  VARIABLES: START_STAGE, END_STAGE, PROCESS, COLOR_SCHEME
# LZW, JPEG
FINAL_COMPRESS="${FINAL_COMPRESS:-LZW}"
INTER_COMPRESS="${INTER_COMPRESS:-LZW}"

if [ -z "$START_STAGE" ]; then
	START_STAGE=1
fi
if [ -z "$END_STAGE" ]; then
	END_STAGE=10
fi
# PROCESS: composite, hillshade, slopes
if [ -z "$PROCESS" ]; then
	PROCESS=composite
fi
mkdir -p hillshade
mkdir -p slopes
mkdir -p composite
if [ "$START_STAGE" -le 1 ] && [ "$END_STAGE" -ge 1 ]; then
	echo "1. Create hillshade and slope tiles (can last hours or 1-2 days) $(date)"
	for F in data/*.tif
	do
		echo "$F hillshade"
		name=$(basename $F)
		if [ ! -f slopes/s_$name ]; then
			if [ -f slopes.tif ]; then rm slopes.tif; fi
			gdaldem hillshade -z 2 -s 111120 -compute_edges $F hillshade/hs_$name
			gdaldem slope -compute_edges -s 111120 $F slopes.tif
			gdaldem color-relief slopes.tif $DIR/color_slope.txt slopes/s_$name	
			rm slopes.tif || true
		fi
	done
fi

if [ "$START_STAGE" -le 2 ] && [ "$END_STAGE" -ge 2 ] && [ "$PROCESS" = "composite" ] ; then
	echo "2. Merge hillshade and slopes tiles with imagemagick (can last hours or 1-2 days) $(date)"
	for F in data/*.tif
	do
		if [ -f composed.tif ]; then rm composed.tif; fi
		echo "$F composed"
		name=$(basename $F)
		composite -quiet -compose Multiply hillshade/hs_$name slopes/s_$name composed.tif
		convert -level 28%x70% composed.tif composite/c_$name
		$DIR/gdalcopyproj.py hillshade/hs_$name composite/c_$name
		rm composed.tif || true
	done
fi

if [ "$START_STAGE" -le 3 ] && [ "$END_STAGE" -ge 3 ]; then
	echo "3. Built a single virtual file vrt, options ensure to keep ocean white $(date)"
	gdalbuildvrt -hidenodata -vrtnodata "255" virtualtiff.vrt $PROCESS/*.tif
fi
 
if [ "$START_STAGE" -le 4 ] && [ "$END_STAGE" -ge 4 ]; then
	echo "4. Merge all tile in a single giant tiff (can last hours or 1-2 days) $(date)"
	gdal_translate -of GTiff -co "COMPRESS=$INTER_COMPRESS" -co "BIGTIFF=YES" -co "TILED=YES" virtualtiff.vrt WGS84-all.tif
fi

if [ "$START_STAGE" -le 5 ] && [ "$END_STAGE" -ge 5 ]; then
	echo "5. Make a small tiff to check before going further $(date)"
	rm WGS84-all-small.tif || true
	gdalwarp -of GTiff -ts 4000 0 WGS84-all.tif WGS84-all-small.tif
fi

if [ "$START_STAGE" -le 6 ] && [ "$END_STAGE" -ge 6 ]; then
	echo "6. [DISABLED NOW] Then re-project to Mercator (can last hours or 1-2 days) $(date)"
	rm  all-3857.tif || true
	# gdalwarp -of GTiff -co "JPEG_QUALITY=90" -co "BIGTIFF=YES" -co "TILED=YES" -co "COMPRESS=JPEG" \
	#	-t_srs "+init=epsg:3857 +over" \
	#	-r cubic -order 3 -multi WGS84-all.tif all-3857.tif
fi

if [ "$START_STAGE" -le 7 ] && [ "$END_STAGE" -ge 7 ]; then
	echo "7. [DISABLED NOW] Make a small tiff to check before going further $(date)"
	rm all-small-3857.tif || true
	# gdalwarp -of GTiff -co "COMPRESS=JPEG" -ts 4000 0 all-3857.tif all-small-3857.tif
fi

if [ "$START_STAGE" -le 8 ] && [ "$END_STAGE" -ge 8 ]; then
	echo "8. Add alpha or color to planet"
	if [ "$PROCESS" = "composite" ] || [ "$PROCESS" = "hillshade" ]; then
		COLOR_SCHEME="${COLOR_SCHEME:-hillshade_alpha}"
	elif [ "$PROCESS" = "slopes" ]; then
		COLOR_SCHEME="${COLOR_SCHEME:-slopes_main}"
	fi
	rm WGS84-all-alpha.tif || true
	if [ "$PROCESS" = "composite" ] || [ "$PROCESS" = "hillshade" ]; then
		gdaldem color-relief -alpha WGS84-all.tif $DIR/$COLOR_SCHEME.txt WGS84-all-color.tif -co "COMPRESS=$INTER_COMPRESS" -co "BIGTIFF=YES" -co "TILED=YES"
		gdal_translate -b 1 -b 4 -colorinterp_1 gray WGS84-all-color.tif WGS84-all-alpha.tif -co "COMPRESS=$FINAL_COMPRESS" -co "BIGTIFF=YES" -co "TILED=YES"
		rm WGS84-all-color.tif || true
	else
		gdaldem color-relief -alpha WGS84-all.tif $DIR/$COLOR_SCHEME.txt WGS84-all-alpha.tif -co "COMPRESS=$FINAL_COMPRESS" -co "BIGTIFF=YES" -co "TILED=YES"
	fi
fi
if [ "$START_STAGE" -le 9 ] && [ "$END_STAGE" -ge 9 ]; then
	echo "9. Split planet to tiles"
	rm -rf tiles/ || true
	# -e option to continue
	gdal2tiles.py --processes 3 -z 4-11 WGS84-all-alpha.tif tiles/
	rm WGS84-all-alpha.tif || true
	
fi

# Create country-wide sqlites compatible with Osmand (minutes or hour each, 5-6days complete country list)
# ./extractSqlite.py -i $WORKSPACE/tools/OsmAndMapCreator/src/net/osmand/map/countries.xml -s $JENKINS_HOME/data/all-3857.tif.sqlitedb -o $JENKINS_HOME/hillshade_sqlite/
