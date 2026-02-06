#!/bin/bash
# Determine which briefing to run based on current time

cd /Users/borisdus/code/morning-briefing

HOUR=$(date +%H)
WEEKDAY=$(date +%u)  # 1=Monday, 7=Sunday

# Morning briefing: 6:00 AM Mon-Sat (not Sunday)
if [ "$HOUR" = "06" ] && [ "$WEEKDAY" != "7" ]; then
    echo "Running morning briefing..."
    ./update-morning.sh
    exit 0
fi

# Daily briefing: 6:00 PM every day
if [ "$HOUR" = "18" ]; then
    echo "Running daily briefing..."
    ./update-daily.sh
    exit 0
fi

# Weekly news: Sunday 8:00 AM
if [ "$HOUR" = "08" ] && [ "$WEEKDAY" = "7" ]; then
    echo "Running weekly news briefing..."
    ./update-weekly-news.sh
    exit 0
fi

# Weekly science: Sunday 9:00 AM
if [ "$HOUR" = "09" ] && [ "$WEEKDAY" = "7" ]; then
    echo "Running weekly science briefing..."
    ./update-weekly-science.sh
    exit 0
fi

# Weekly finance: Sunday 10:00 AM
if [ "$HOUR" = "10" ] && [ "$WEEKDAY" = "7" ]; then
    echo "Running weekly finance briefing..."
    ./update-weekly-finance.sh
    exit 0
fi

echo "No scheduled briefing for this time slot"
