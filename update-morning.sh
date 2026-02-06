#!/bin/bash

# Detect environment and set paths accordingly
if [ -d "/home/briefing/morning-briefing" ]; then
    # VPS environment
    BRIEFING_DIR="/home/briefing/morning-briefing"
    export PATH="/usr/local/bin:/usr/bin:$PATH"
else
    # Local Mac environment
    BRIEFING_DIR="/Users/borisdus/code/morning-briefing"
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fi

cd "$BRIEFING_DIR"

CURRENT_TIME=$(TZ='America/Los_Angeles' date '+%B %d, %Y, %I:%M %p PST')

# --- Cross-briefing deduplication ---
ALL_BRIEFINGS=(
  "morning_briefing.md"
  "daily_briefing.md"
  "weekly_news.md"
  "weekly_science.md"
  "weekly_finance.md"
)

DEDUP_HEADLINES=""
for bf in "${ALL_BRIEFINGS[@]}"; do
  [ "$bf" = "morning_briefing.md" ] && continue
  [ -f "$bf" ] || continue
  HEADLINES=$(grep '^### ' "$bf" | grep -vi '^### sources')
  if [ -n "$HEADLINES" ]; then
    DEDUP_HEADLINES="$DEDUP_HEADLINES
$HEADLINES"
  fi
done

DEDUP_INSTRUCTION=""
if [ -n "$DEDUP_HEADLINES" ]; then
  DEDUP_INSTRUCTION=" IMPORTANT DEDUPLICATION: The following stories have ALREADY been covered in other briefings. Do NOT cover these stories again, even if the headline is worded differently. Match by TOPIC, not exact title. Find COMPLETELY DIFFERENT stories instead:
$DEDUP_HEADLINES"
fi

claude -p "Search for today's news and update morning_briefing.md with: 10 top geopolitical stories and 10 top financial stories.

PREFERRED SOURCES — prioritize stories from these outlets:
Geopolitical: Reuters, Associated Press, BBC News, The Guardian, Al Jazeera, Foreign Policy, The Economist, NPR, Politico, The New York Times, Washington Post, Nikkei Asia, The Diplomat, South China Morning Post, Stratfor, CSIS, France 24, Deutsche Welle
Financial: Bloomberg, Financial Times, Wall Street Journal, CNBC, MarketWatch, The Economist, Reuters Business, Nikkei Asia, South China Morning Post

Format: H3 headline with ONLY the date in italics (e.g. 'Feb 3' - use the ACTUAL publication date). Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Use this EXACT timestamp in header: Research Generated: $CURRENT_TIME. List 10 sources at the end of each section.${DEDUP_INSTRUCTION}" --allowedTools "Edit,Write,WebSearch"

# Generate audio with Kokoro TTS
source venv/bin/activate
python3 generate-audio.py morning_briefing.md audio/morning
deactivate

# Build styled HTML
node build-html.js

# Push to GitHub
git add morning_briefing.md briefing.html audio/morning/*.mp3
git commit -m "Morning briefing update $(date +%Y-%m-%d)"
GIT_TERMINAL_PROMPT=0 git push || gh repo sync

echo "Morning briefing updated and pushed to GitHub"
