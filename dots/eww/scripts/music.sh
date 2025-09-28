#!/usr/bin/env bash

# Music player script for eww - matches qtile MusicPlayer widget
# Usage:
#   music.sh              -> get current track info
#   music.sh play-pause   -> toggle play/pause
#   music.sh next         -> next track
#   music.sh prev         -> previous track

# Configuration
PLAYER="chromium"  # Default to chromium (YouTube Music)
MAX_LENGTH=60      # Maximum character length for song title

# Try to find the correct chromium instance
get_chromium_player() {
    local chromium_players
    chromium_players=$(playerctl --list-all 2>/dev/null | grep "^chromium" | head -1)
    
    if [ -n "$chromium_players" ]; then
        echo "$chromium_players"
    else
        echo "chromium"
    fi
}

# Get track information
get_track_info() {
    local player
    player=$(get_chromium_player)
    
    # Check if player is available and playing
    if ! playerctl --player="$player" status >/dev/null 2>&1; then
        echo '{"icon": "󰝚", "artist": "", "title": "", "text": "", "playing": false, "available": false}'
        return 0
    fi
    
    local status artist title text playing
    
    # Get playback status
    status=$(playerctl --player="$player" status 2>/dev/null || echo "Stopped")
    
    # Determine if playing
    if [ "$status" = "Playing" ]; then
        playing="true"
    else
        playing="false"
    fi
    
    # Get metadata
    artist=$(playerctl --player="$player" metadata artist 2>/dev/null || echo "")
    title=$(playerctl --player="$player" metadata title 2>/dev/null || echo "")
    
    # Handle empty metadata
    if [ -z "$artist" ] && [ -z "$title" ]; then
        text=""
    elif [ -z "$artist" ]; then
        # Truncate title if too long
        if [ ${#title} -gt $MAX_LENGTH ]; then
            title="${title:0:$((MAX_LENGTH-3))}..."
        fi
        text="$title"
    elif [ -z "$title" ]; then
        text="$artist"
    else
        # Combine artist and title
        local combined="$artist · $title"
        # Truncate if too long
        if [ ${#combined} -gt $MAX_LENGTH ]; then
            combined="${combined:0:$((MAX_LENGTH-3))}..."
        fi
        text="$combined"
    fi
    
    # HTML escape the text (basic escaping)
    text=$(echo "$text" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Output JSON
    cat <<EOF
{
  "icon": "󰝚",
  "artist": "$artist",
  "title": "$title", 
  "text": "$text",
  "playing": $playing,
  "available": true
}
EOF
}

# Control playback
control_playback() {
    local action="$1"
    local player
    player=$(get_chromium_player)
    
    case "$action" in
        "play-pause")
            playerctl --player="$player" play-pause 2>/dev/null
            ;;
        "next")
            playerctl --player="$player" next 2>/dev/null
            ;;
        "prev"|"previous")
            playerctl --player="$player" previous 2>/dev/null
            ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
    
    # Return updated track info after action
    sleep 0.2  # Brief delay for state to update
    get_track_info
}

case "${1:-}" in
    "play-pause"|"next"|"prev"|"previous")
        control_playback "$1"
        ;;
    "")
        get_track_info
        ;;
    *)
        echo "Usage: $0 [play-pause|next|prev]" >&2
        echo "  No args: get current track info" >&2
        echo "  play-pause: toggle play/pause" >&2
        echo "  next: next track" >&2
        echo "  prev: previous track" >&2
        exit 1
        ;;
esac