#!/bin/sh

running=$(pidof spotify)
if [ "$running" != "" ]; then
    artist=$(playerctl --player spotify metadata artist)
    song=$(playerctl --player spotify metadata title | cut -c 1-60)
    echo "$artist · $song"
fi
