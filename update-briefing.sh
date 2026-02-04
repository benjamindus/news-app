#!/bin/bash

cd /Users/borisdus/code/morning-briefing

# Ensure PATH includes homebrew and common bin locations
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Run Claude to update the briefing
CURRENT_TIME=$(TZ='America/Los_Angeles' date '+%B %d, %Y, %I:%M %p PST')
claude -p "Search for today's news and update morning_briefing.md with: 10 top geopolitical stories and 10 top financial stories. Format: H3 headline with ONLY the date in italics (e.g. 'Feb 3' - use the ACTUAL publication date from the article URL or metadata, do NOT guess times, do NOT make up dates). Then a blockquote (>) with a 1-2 sentence summary, then 3 detailed paragraphs per story. Use this EXACT timestamp in header: Research Generated: $CURRENT_TIME. List 10 sources at the end of each section." --allowedTools "Edit,Write,WebSearch"

# Generate audio with Kokoro TTS (using shared venv from daily-news)
source /Users/borisdus/code/daily-news/venv/bin/activate
python3 generate-audio.py
deactivate

# Build styled HTML
node build-html.js

# Push to GitHub
git add morning_briefing.md morning_briefing.html audio/*.mp3
git commit -m "Morning briefing update $(date +%Y-%m-%d)"
GIT_TERMINAL_PROMPT=0 git push || gh repo sync

echo "Morning briefing updated and pushed to GitHub"
