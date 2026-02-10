#!/bin/bash

# Detect environment and set paths accordingly
if [ -d "/home/briefing/news-app" ]; then
    # VPS environment
    BRIEFING_DIR="/home/briefing/news-app"
    export PATH="/usr/local/bin:/usr/bin:$PATH"
else
    # Local Mac environment
    BRIEFING_DIR="/Users/borisdus/code/news-app"
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fi

cd "$BRIEFING_DIR"

CURRENT_TIME=$(TZ='America/Los_Angeles' date '+%B %d, %Y, %I:%M %p PST')
TODAY=$(date '+%Y-%m-%d')
HISTORY_DIR="$BRIEFING_DIR/headline_history"
HISTORY_FILE="$HISTORY_DIR/morning_daily_history.txt"

# Ensure history directory exists
mkdir -p "$HISTORY_DIR"

# --- Clean up headlines older than 7 days ---
if [ -f "$HISTORY_FILE" ]; then
  CUTOFF_DATE=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d')
  # Keep only lines with dates >= cutoff
  awk -F'|' -v cutoff="$CUTOFF_DATE" '$1 >= cutoff' "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
  mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
fi

# --- Load week-long headline history for morning/daily cross-check ---
HISTORY_HEADLINES=""
if [ -f "$HISTORY_FILE" ]; then
  # Extract just the headlines (after the date|type| prefix)
  HISTORY_HEADLINES=$(cut -d'|' -f3- "$HISTORY_FILE" | grep -v '^$')
fi

# --- Cross-briefing deduplication (weekly briefings) ---
WEEKLY_BRIEFINGS=(
  "weekly_news.md"
  "weekly_science.md"
  "weekly_finance.md"
)

WEEKLY_HEADLINES=""
for bf in "${WEEKLY_BRIEFINGS[@]}"; do
  [ -f "$bf" ] || continue
  HEADLINES=$(grep '^### ' "$bf" | grep -vi '^### sources')
  if [ -n "$HEADLINES" ]; then
    WEEKLY_HEADLINES="$WEEKLY_HEADLINES
$HEADLINES"
  fi
done

# Combine history and weekly headlines
DEDUP_HEADLINES="$HISTORY_HEADLINES
$WEEKLY_HEADLINES"

DEDUP_INSTRUCTION=""
if [ -n "$(echo "$DEDUP_HEADLINES" | grep -v '^$')" ]; then
  DEDUP_INSTRUCTION=" IMPORTANT DEDUPLICATION: The following stories have ALREADY been covered in the past 7 days of morning/daily briefings or in weekly briefings. Do NOT cover these stories again, even if the headline is worded differently. Match by TOPIC, not exact title. Find COMPLETELY DIFFERENT stories instead:
$DEDUP_HEADLINES"
fi

claude --model sonnet -p "Search for news from the LAST 24 HOURS ONLY and update daily_briefing.md with: 10 top geopolitical stories and 10 top financial stories. IMPORTANT: Check publication dates - REJECT any story older than 24 hours. Only include breaking news and stories published today. EXCLUDE all sports news.

PREFERRED SOURCES — prioritize stories from these outlets:
Geopolitical: Reuters, Associated Press, BBC News, The Guardian, Al Jazeera, Foreign Policy, The Economist, NPR, Politico, The New York Times, Washington Post, Nikkei Asia, The Diplomat, South China Morning Post, Stratfor, CSIS, France 24, Deutsche Welle
Financial: Bloomberg, Financial Times, Wall Street Journal, CNBC, MarketWatch, The Economist, Reuters Business, Nikkei Asia, South China Morning Post

Format: H3 headline with ONLY the date in italics (e.g. 'Feb 3' - use the ACTUAL publication date). Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Use this EXACT timestamp in header: Research Generated: $CURRENT_TIME. List 10 sources at the end of each section.${DEDUP_INSTRUCTION}" --allowedTools "Edit,Write,WebSearch" --dangerously-skip-permissions

# --- Save new headlines to history ---
if [ -f "daily_briefing.md" ]; then
  NEW_HEADLINES=$(grep '^### ' daily_briefing.md | grep -vi '^### sources')
  if [ -n "$NEW_HEADLINES" ]; then
    echo "$NEW_HEADLINES" | while read -r headline; do
      echo "${TODAY}|daily|${headline}" >> "$HISTORY_FILE"
    done
  fi
fi

# Generate audio with Kokoro TTS
./venv/bin/python generate-audio.py daily_briefing.md audio/daily

# Build styled HTML
node build-html.js

# Push to GitHub
git add daily_briefing.md briefing.html audio/daily/*.mp3
git commit -m "Daily briefing update $(date +%Y-%m-%d)"
GIT_TERMINAL_PROMPT=0 git push || gh repo sync

# Send push notification
node send-notification.cjs "Daily Briefing Ready" "Your daily news briefing has been updated with fresh stories."

echo "Daily briefing updated and pushed to GitHub"
