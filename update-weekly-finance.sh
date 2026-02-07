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
  [ "$bf" = "weekly_finance.md" ] && continue
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

claude --model sonnet -p "Search for last week's biggest finance news and update weekly_finance.md with: 5 top inflation and finance metrics news, and 5 top crypto market developments. Focus on most cited/discussed stories.

PREFERRED SOURCES — prioritize stories from these outlets:
Inflation/Finance Metrics: Bloomberg, Financial Times, FT Alphaville, Wall Street Journal, Reuters Business, The Economist, Federal Reserve releases, Bureau of Labor Statistics, CNBC, MarketWatch, Barron's, Nikkei, Institutional Investor, The Information, Seeking Alpha, Morningstar
Crypto: CoinDesk, The Block, Decrypt, CoinTelegraph, Bloomberg Crypto, Reuters, DL News, Blockworks

Format: H3 headline with ONLY the date in italics (e.g. 'Feb 3' - use the ACTUAL publication date). Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Include Week of [date range] and use this EXACT timestamp: Research Generated: $CURRENT_TIME. List 10 sources at the end of each section.${DEDUP_INSTRUCTION}" --allowedTools "Edit,Write,WebSearch" --dangerously-skip-permissions

# Generate audio with Kokoro TTS
source venv/bin/activate
python3 generate-audio.py weekly_finance.md audio/weekly-finance
deactivate

# Build styled HTML
node build-html.js

# Push to GitHub
git add weekly_finance.md briefing.html audio/weekly-finance/*.mp3
git commit -m "Weekly finance briefing update $(date +%Y-%m-%d)"
GIT_TERMINAL_PROMPT=0 git push || gh repo sync

echo "Weekly finance briefing updated and pushed to GitHub"
