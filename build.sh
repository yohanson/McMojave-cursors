#!/bin/bash

set -e

function get_inkscape_opts() {
    if inkscape -V | grep -qF 'Inkscape 0'; then
        echo '-z -e'
    else
        echo '-o'
    fi
}

function get_frame() {
    svg=$1
    basename ${svg%.*}
}

function get_cursor() {
    frame=$1
    if [[ "$frame" =~ -[0-9]+$ ]]; then
        echo ${frame%-*}
    else
        echo $frame
    fi
}

function create {
    BUILD="$(dirname "$SRC")/build"
    CONFIGS="$BUILD/config"
    DIST="$(dirname "$SRC")/dist"
	OUTPUT="$DIST/cursors"
	ALIASES="$SRC/cursorList"
    HOTPOINTS="$SRC/hotpoints"
    inkscape_opts=$(get_inkscape_opts)

    mkdir -p "$CONFIGS"
    mkdir -p "$OUTPUT"

	cd "$SRC"

    original_size=32
    scales=(1 1.25 1.5 2)
    svgs=$(ls -1 $1/*.svg)
    total_images=$(echo "$svgs" | wc -l)

    rm -f $BUILD/config/*.cursor
    for scale in ${scales[@]}; do
        mkdir -p "$BUILD/$scale"
    done

    image_number=0
    for svg in $svgs; do
        let 'image_number+=1'
        echo -en "\\rRendering PNGs $image_number/$total_images... "
    
        frame=$(get_frame $svg)
        cursor=$(get_cursor $frame)
        dst="$frame.png"
        hotpoints_line=$(grep "^$cursor " "$HOTPOINTS")
        hotx=$(echo "$hotpoints_line" | awk '{print $2}')
        hoty=$(echo "$hotpoints_line" | awk '{print $3}')
        delay_ms=$(echo "$hotpoints_line" | awk '{print $4}')

        for scale in ${scales[@]}; do
            scale_name=$(echo "x$scale" | tr '.' '_')

            size_px=$(echo "$original_size * $scale" | bc -l | sed -r 's/\.0+$//g')
            inkscape $inkscape_opts "$BUILD/$scale_name/$dst" -w $size_px -h $size_px "$SRC/$svg" > /dev/null

            hotx_scaled=$(echo "$hotx * $scale" | bc -l | sed 's/\..*$//g')
            hoty_scaled=$(echo "$hoty * $scale" | bc -l | sed 's/\..*$//g')
            config_line="$size_px $hotx_scaled $hoty_scaled $BUILD/$scale_name/$dst"
            if [ "$delay_ms" ]; then
                config_line+=" $delay_ms"
            fi
            echo "$config_line" >> "$BUILD/config/$cursor.cursor"
        done
    done
    echo "DONE"

    echo -n "Generating cursor theme... "
    for svg in $svgs; do
        cursor=$(get_cursor $(get_frame $svg))
        xcursorgen "$BUILD/config/$cursor.cursor" "$OUTPUT/$cursor"
    done
    echo "DONE"

	cd "$OUTPUT"	

	#generate aliases
	echo -n "Generating shortcuts... "
	while read ALIAS; do
		FROM="${ALIAS#* }"
		TO="${ALIAS% *}"

		if [ -e $TO ]; then
			continue
		fi
		ln -sr "$FROM" "$TO"
	done < "$ALIASES"
	echo "DONE"

	cd "$PWD"

	echo -n "Generating Theme Index... "
	INDEX="$OUTPUT/../index.theme"
	if [ ! -e "$OUTPUT/../$INDEX" ]; then
		touch "$INDEX"
		echo -e "[Icon Theme]\nName=$THEME\n" > "$INDEX"
	fi
	echo "DONE"
}

# generate pixmaps from svg source
SRC=$PWD/src
THEME="McMojave Cursors"

create svg

