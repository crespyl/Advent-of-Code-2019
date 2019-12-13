#!/usr/bin/env sh
ffmpeg -r 120 -i "frames/frame-%08d.ppm" -c:v libvpx -b:v 100M -vf scale=320:-1 -sws_flags neighbor -r 120 output.webm
