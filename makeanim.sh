#!/usr/bin/env sh
# $1 should be a name template for the frames, eg frames/frame-%08d.ppm
# $2 should be the output filename
ffmpeg -i "$1" -c:v libvpx -crf 4 -b:v 100M -vf scale=320:-1 -sws_flags neighbor $2
