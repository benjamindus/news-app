#!/bin/bash

# Change to repo root (works both locally and in CI)
cd "$(dirname "$0")"

# Ensure PATH includes homebrew and common bin locations
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Run Claude to update the briefing
CURRENT_TIME=$(TZ='America/Los_Angeles' date '+%B %d, %Y, %I:%M %p PST')

# --- Cross-project deduplication via GitHub raw URLs ---
DEDUP_REPOS=(
  "benjamindus/daily-news:daily_briefing.md"
  "benjamindus/daily-news-inworld:morning_briefing.md"
  "benjamindus/weekly-news:weekly_briefing.md"
  "benjamindus/weekly-finance:weekly_briefing.md"
  "benjamindus/weekly-science:weekly_briefing.md"
)

DEDUP_HEADLINES=""
for entry in "${DEDUP_REPOS[@]}"; do
  repo="${entry%%:*}"
  file="${entry##*:}"
  HEADLINES=$(curl -sf "https://raw.githubusercontent.com/$repo/main/$file" | grep '^### ' | grep -vi '^### sources')
  if [ -n "$HEADLINES" ]; then
    DEDUP_HEADLINES="$DEDUP_HEADLINES
$HEADLINES"
  fi
done

DEDUP_INSTRUCTION=""
if [ -n "$DEDUP_HEADLINES" ]; then
  DEDUP_INSTRUCTION=" IMPORTANT DEDUPLICATION: The following stories have ALREADY been covered in other briefings. Do NOT cover these stories again, even if the headline is worded differently. Match by TOPIC, not exact title — e.g. 'Trump Tariffs on China' and 'US Imposes Fresh China Tariffs' are the SAME story. Skip ANY story about the same underlying event, policy, company, or development. Find COMPLETELY DIFFERENT stories instead:
$DEDUP_HEADLINES"
fi
# --- End deduplication ---

claude -p "Search for today's news and update morning_briefing.md with: 10 top geopolitical stories and 10 top financial stories.

PREFERRED SOURCES — prioritize stories from these outlets:
Geopolitical: Reuters, Associated Press, BBC News, The Guardian, Al Jazeera, Foreign Policy, The Economist, NPR, Politico, The New York Times, Washington Post, Nikkei Asia, The Diplomat, South China Morning Post, Stratfor, CSIS, France 24, Deutsche Welle
Financial: Bloomberg, Financial Times, Wall Street Journal, CNBC, MarketWatch, The Economist, Reuters Business, Nikkei Asia, South China Morning Post

Format: H3 headline with ONLY the date in italics (e.g. 'Feb 3' - use the ACTUAL publication date from the article URL or metadata, do NOT guess times, do NOT make up dates). Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Use this EXACT timestamp in header: Research Generated: $CURRENT_TIME. List 10 sources at the end of each section.${DEDUP_INSTRUCTION}" --allowedTools "Edit,Write,WebSearch"

# Generate audio with Kokoro TTS
python3 generate-audio.py

# Build styled HTML
node build-html.js
