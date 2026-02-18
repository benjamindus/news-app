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

# Timeout command (works on both Linux and macOS with coreutils)
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout 1200"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout 1200"
else
    TIMEOUT_CMD=""
fi

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
  [ "$bf" = "weekly_news.md" ] && continue
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

$TIMEOUT_CMD claude --model sonnet -p "Search for this week's biggest news and update weekly_news.md with: 15 top geopolitical stories and 15 top financial stories from the past 7 days. EXCLUDE all sports news.

PREFERRED SOURCES — prioritize stories from these outlets:
Geopolitical: Reuters, Associated Press, BBC News, The Guardian, Al Jazeera, Foreign Policy, The Economist, NPR, Politico, The New York Times, Washington Post, Nikkei Asia, The Diplomat, South China Morning Post, Stratfor, CSIS, France 24, Deutsche Welle
Financial: Bloomberg, Financial Times, Wall Street Journal, CNBC, MarketWatch, The Economist, Reuters Business, Nikkei Asia, South China Morning Post

Format: H3 headline with ONLY the date in italics (e.g. 'Feb 3' - use the ACTUAL publication date). Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Include Week of [date range] and use this EXACT timestamp: Research Generated: $CURRENT_TIME. List 15 sources at the end of each section.${DEDUP_INSTRUCTION}" --allowedTools "Edit,Write,WebSearch" --dangerously-skip-permissions

./venv/bin/python generate-audio.py weekly_news.md audio/weekly-news
# Build styled HTML
node build-html.js

# Push to GitHub
git checkout -- package-lock.json 2>/dev/null || true
git add weekly_news.md briefing.html audio/weekly-news/*.mp3
git commit -m "Weekly news briefing update $(date +%Y-%m-%d)"
# Pull with rebase; if it fails due to other uncommitted files, stash them and retry
if ! git pull --rebase origin main; then
    git stash --include-untracked 2>/dev/null || true
    git pull --rebase origin main || git pull origin main
    git stash pop 2>/dev/null || true
fi
GIT_TERMINAL_PROMPT=0 git push

# Send push notification
node send-notification.cjs "Weekly News Ready" "Your weekly news briefing has been updated."

echo "Weekly news briefing updated and pushed to GitHub"
