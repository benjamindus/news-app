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
  [ "$bf" = "weekly_science.md" ] && continue
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

claude --model sonnet -p "Search for science news from the LAST 7 DAYS ONLY and update weekly_science.md with: 5 top fusion energy news, 5 top human genetics/gene science advancements, and 5 top AI advancements. IMPORTANT: Check publication dates - REJECT any story older than 7 days. Only include news published within the past week. Focus on most cited/discussed stories.

PREFERRED SOURCES — prioritize stories from these outlets:
Fusion Energy: Nature, Science, MIT Technology Review, Ars Technica, PhysicsWorld, New Scientist, ITER.org, Science Daily
Genetics/Gene Science: Nature, Nature Genetics, Science, STAT News, MIT Technology Review, New England Journal of Medicine, The Lancet, GenomeWeb
AI: MIT Technology Review, Ars Technica, The Verge, Wired, VentureBeat, IEEE Spectrum, arXiv blog, DeepMind blog, OpenAI blog

Format: H3 headline with NUMBER and date in italics (e.g. '### 1. Headline Title - *Feb 3*'). Number stories 1-5 within each section. Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Include Week of [date range] and use this EXACT timestamp: Research Generated: $CURRENT_TIME. List 10 sources at the end of each section.${DEDUP_INSTRUCTION}" --allowedTools "Edit,Write,WebSearch" --dangerously-skip-permissions

./venv/bin/python generate-audio.py weekly_science.md audio/weekly-science
# Build styled HTML
node build-html.js

# Push to GitHub
git checkout -- package-lock.json 2>/dev/null || true  # Reset any package changes
git add weekly_science.md briefing.html audio/weekly-science/*.mp3
git commit -m "Weekly science briefing update $(date +%Y-%m-%d)"
git stash --include-untracked || true
git pull --rebase origin main || git pull origin main
git stash pop 2>/dev/null || true
GIT_TERMINAL_PROMPT=0 git push

# Send push notification
node send-notification.cjs "Weekly Science Ready" "Your weekly science briefing has been updated."

echo "Weekly science briefing updated and pushed to GitHub"
