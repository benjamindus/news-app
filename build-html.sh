#!/bin/bash

cd /Users/borisdus/daily-researcher

# Convert markdown to HTML
BODY=$(npx marked -i daily_briefing.md)

# Read template and replace placeholder
awk -v content="$BODY" '{gsub(/\{\{CONTENT\}\}/, content); print}' template.html > daily_briefing.html

echo "Built daily_briefing.html with mobile-friendly styling"
