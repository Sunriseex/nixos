#!/bin/sh


API_KEY="your_api_key_here"
CITY="Moscow"
URL="https://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$API_KEY&units=metric&lang=ru"


WEATHER_JSON=$(curl -s "$URL")


TEMP=$(echo "$WEATHER_JSON" | jq '.main.temp' | cut -d. -f1)
WEATHER_DESC=$(echo "$WEATHER_JSON" | jq -r '.weather[0].description')
ICON_CODE=$(echo "$WEATHER_JSON" | jq -r '.weather[0].icon')


get_icon() {
    case $1 in
        "01d") echo "☀️";;
        "01n") echo "🌙";;
        "02d") echo "⛅";;
        "02n") echo "⛅";;
        "03d"|"03n") echo "☁️";;
        "04d"|"04n") echo "☁️";;
        "09d"|"09n") echo "🌧️";;
        "10d"|"10n") echo "🌦️";;
        "11d"|"11n") echo "⛈️";;
        "13d"|"13n") echo "❄️";;
        "50d"|"50n") echo "🌫️";;
        *) echo "🌡️";;
    esac
}

ICON=$(get_icon "$ICON_CODE")

echo "$ICON $TEMP°C"