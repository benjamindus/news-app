/**
 * Daily News Researcher
 *
 * This script is designed to be run via Claude Code to generate a daily news briefing.
 *
 * Usage:
 *   npm run research
 *
 * This invokes Claude Code with a prompt to search for news and generate the briefing.
 * It uses your Claude Max subscription limits (no API key needed).
 */

export const RESEARCH_PROMPT = `
Search for today's news and create a daily briefing in daily_briefing.md with these categories:

## Category 1: Geopolitical News (5 items)
Search for the top 5 geopolitical news stories covering:
- US politics and government
- Ukraine conflict developments
- Major global events

## Category 2: Financial News (5 items)
Search for the top 5 financial/economic news stories covering:
- Stock market movements
- Economic policy and Fed decisions
- Major business developments

For each news item, include:
1. A clear headline
2. A 2-3 sentence summary
3. Source links

Format as a well-structured markdown file with today's date.
`;

console.log("To run the daily researcher, use one of these methods:");
console.log("");
console.log("1. Interactive: Run 'claude' and ask it to search for news");
console.log("2. Direct: Run 'npm run research' which pipes the prompt to Claude");
console.log("");
console.log("The prompt to use:");
console.log("─".repeat(60));
console.log(RESEARCH_PROMPT);
