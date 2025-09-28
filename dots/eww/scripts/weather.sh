#!/usr/bin/env bash

# Weather script for eww - matches qtile CustomWeather widget
# Usage:
#   weather.sh              -> fetch current weather data
#   weather.sh refresh      -> force refresh weather data

CONFIG_DIR="$HOME/.config/eww"
CITY_FILE="$CONFIG_DIR/weather_city"
CACHE_FILE="/tmp/eww_weather_cache"
CACHE_DURATION=600  # 10 minutes in seconds

get_weather_icon() {
    case "$1" in
        "01d") echo " " ;;    # clear sky day
        "01n") echo " " ;;    # clear sky night
        "02d") echo " " ;;    # few clouds day
        "02n") echo " " ;;    # few clouds night
        "03d") echo " " ;;    # scattered clouds day
        "03n") echo " " ;;    # scattered clouds night
        "04d") echo " " ;;    # broken clouds day
        "04n") echo " " ;;    # broken clouds night
        "09d") echo " " ;;    # shower rain day
        "09n") echo " " ;;    # shower rain night
        "10d") echo " " ;;    # rain day
        "10n") echo " " ;;    # rain night
        "11d") echo " " ;;    # thunderstorm day
        "11n") echo " " ;;    # thunderstorm night
        "13d") echo "󰒷" ;;     # snow day
        "13n") echo "󰒷" ;;     # snow night
        "50d") echo " " ;;    # mist day
        "50n") echo " " ;;    # mist night
        *) echo "" ;;         # unknown/error
    esac
}

get_api_key() {
    echo "7834197c2338888258f8cb94ae14ef49"  # this is a publicly available key, I don't care leaking it
}

get_city() {
    if [ -f "$CITY_FILE" ]; then
        cat "$CITY_FILE"
    else
        echo "Toronto"  # Default city
    fi
}

is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local cache_time
    cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    local current_time
    current_time=$(date +%s)

    [ $((current_time - cache_time)) -lt $CACHE_DURATION ]
}

fetch_weather() {
    local api_key city
    api_key=$(get_api_key)
    city=$(get_city)

    if [ -z "$api_key" ]; then
        echo '{"icon": "", "temp": "--", "feels_like": "--", "humidity": "--", "wind": "--", "condition": "No API key", "error": true}'
        return 1
    fi

    local url="https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${api_key}&units=metric"
    local response

    if ! response=$(curl -s "$url" 2>/dev/null) || [ -z "$response" ]; then
        echo '{"icon": "", "temp": "--", "feels_like": "--", "humidity": "--", "wind": "--", "condition": "Network error", "error": true}'
        return 1
    fi

    # Check if API returned error
    local error_code
    error_code=$(echo "$response" | jq -r '.cod // empty' 2>/dev/null)

    if [ "$error_code" != "200" ] && [ -n "$error_code" ]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.message // "API error"' 2>/dev/null)
        echo "{\"icon\": \"\", \"temp\": \"--\", \"feels_like\": \"--\", \"humidity\": \"--\", \"wind\": \"--\", \"condition\": \"$error_msg\", \"error\": true}"
        return 1
    fi

    # Parse weather data
    local temp feels_like humidity wind_speed icon_code condition icon

    temp=$(echo "$response" | jq -r '.main.temp // 0' 2>/dev/null | cut -d. -f1)
    feels_like=$(echo "$response" | jq -r '.main.feels_like // 0' 2>/dev/null | cut -d. -f1)
    humidity=$(echo "$response" | jq -r '.main.humidity // 0' 2>/dev/null)
    wind_speed=$(echo "$response" | jq -r '.wind.speed // 0' 2>/dev/null | cut -d. -f1)
    icon_code=$(echo "$response" | jq -r '.weather[0].icon // "Unknown"' 2>/dev/null)
    condition=$(echo "$response" | jq -r '.weather[0].description // "Unknown"' 2>/dev/null)

    # Convert wind speed from m/s to km/h
    wind_speed=$(echo "$wind_speed" | awk '{printf "%.0f", $1 * 3.6}')

    icon=$(get_weather_icon "$icon_code")

    local weather_json
    weather_json=$(cat <<EOF
{
  "icon": "$icon",
  "temp": "$temp",
  "feels_like": "$feels_like",
  "humidity": "$humidity",
  "wind": "$wind_speed",
  "condition": "$condition",
  "error": false
}
EOF
)

    echo "$weather_json"

    # Cache the result
    echo "$weather_json" > "$CACHE_FILE"
}

# Show configuration help

case "${1:-}" in
    "refresh")
        # Force refresh - remove cache and fetch new data
        rm -f "$CACHE_FILE"
        fetch_weather
        ;;
    "")
        # Check cache first, fetch if needed
        if is_cache_valid; then
            cat "$CACHE_FILE"
        else
            fetch_weather
        fi
        ;;
    *)
        echo "Usage: $0 [refresh|config]" >&2
        echo "  No args: get weather data (cached)" >&2
        echo "  refresh: force refresh weather data" >&2
        echo "  config:  show configuration help" >&2
        exit 1
        ;;
esac
