#!/bin/bash
# Determine which briefing to run based on current time

# Detect environment and set paths accordingly
if [ -d "/home/briefing/morning-briefing" ]; then
    # VPS environment
    BRIEFING_DIR="/home/briefing/morning-briefing"
else
    # Local Mac environment
    BRIEFING_DIR="/Users/borisdus/code/morning-briefing"
fi

cd "$BRIEFING_DIR"

# Auto-pull latest changes from GitHub (for VPS auto-sync)
git pull --quiet origin main 2>/dev/null || true

# Use PST timezone for schedule checks (VPS is in UTC)
HOUR=$(TZ='America/Los_Angeles' date +%H)
WEEKDAY=$(TZ='America/Los_Angeles' date +%u)  # 1=Monday, 7=Sunday

# Morning briefing: 6:00 AM Mon-Sat (not Sunday)
if [ "$HOUR" = "06" ] && [ "$WEEKDAY" != "7" ]; then
    echo "Running morning briefing..."
    ./update-morning.sh
    exit 0
fi

# Daily briefing: 4:00 PM every day
if [ "$HOUR" = "16" ]; then
    echo "Running daily briefing..."
    ./update-daily.sh
    exit 0
fi

# Weekly news: Sunday 7:00 AM
if [ "$HOUR" = "07" ] && [ "$(TZ='America/Los_Angeles' date +%M)" -lt "30" ] && [ "$WEEKDAY" = "7" ]; then
    echo "Running weekly news briefing..."
    ./update-weekly-news.sh
    exit 0
fi

# Weekly science: Sunday 7:30 AM
if [ "$HOUR" = "07" ] && [ "$(TZ='America/Los_Angeles' date +%M)" -ge "30" ] && [ "$WEEKDAY" = "7" ]; then
    echo "Running weekly science briefing..."
    ./update-weekly-science.sh
    exit 0
fi

# Weekly finance: Sunday 8:00 AM
if [ "$HOUR" = "08" ] && [ "$WEEKDAY" = "7" ]; then
    echo "Running weekly finance briefing..."
    ./update-weekly-finance.sh
    exit 0
fi

echo "No scheduled briefing for this time slot"
