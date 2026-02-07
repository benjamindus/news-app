## Morning Briefing System - Infrastructure Context

**Project**: `/Users/borisdus/code/news-app` (local) / `/home/briefing/news-app` (VPS)
**Repo**: https://github.com/benjamindus/news-app

### Architecture
The system runs on a Hetzner VPS (CPX 11, $5.59/mo) at `5.161.109.207`. Cron jobs trigger briefings on schedule, Claude CLI generates news content, Kokoro TTS creates audio, and results are pushed to GitHub.

### VPS Access
```bash
ssh briefing@5.161.109.207
```

### Key Files
- `run-scheduled.sh` - Entry point, auto-pulls from GitHub, routes to correct briefing based on time
- `update-morning.sh` - Morning briefing (6 AM Mon-Sat PST)
- `update-daily.sh` - Daily briefing (4 PM daily PST)
- `update-weekly-news.sh` - Weekly news (Sun 7 AM PST)
- `update-weekly-science.sh` - Weekly science (Sun 7:30 AM PST)
- `update-weekly-finance.sh` - Weekly finance (Sun 8 AM PST)
- `generate-audio.py` - Kokoro TTS audio generation
- `build-html.js` - Combines all briefings into briefing.html with audio players

### Output Files
- `morning_briefing.md`, `daily_briefing.md`, `weekly_news.md`, `weekly_science.md`, `weekly_finance.md`
- `briefing.html` - Combined HTML with all briefings and embedded audio players
- `audio/*/story-XX.mp3` - Generated audio files per story

### Scripts auto-detect environment
- VPS: `/home/briefing/news-app`
- Mac: `/Users/borisdus/code/news-app`

### Briefing Content Format
Each briefing markdown follows this structure:
```markdown
# Briefing Title
Research Generated: [timestamp]

## Section (e.g., "Top Geopolitical Stories")

### Story Headline *Feb 6*
> 1-2 sentence summary in blockquote

3 detailed paragraphs about the story...

### Sources
1. [Source Name](url)
...
```

### Deduplication System
Each update script checks other briefing files for existing headlines (`### ` lines) and instructs Claude to avoid covering the same topics. This prevents story overlap between morning/daily/weekly briefings.

### Audio Generation (`generate-audio.py`)
- Parses markdown, extracts stories by H3 headers
- Skips "Sources" sections
- Cleans text (removes markdown, converts $ to "dollars")
- Uses Kokoro TTS with voice "af_heart" at 1.0x speed
- Outputs MP3 files at 64kbps

### HTML Build (`build-html.js`)
- Combines all briefing markdown files into one HTML
- Injects `<audio>` players after each H3 story header
- Uses `template-audio.html` as the base template
- Outputs `briefing.html`

### VPS Setup Details
- User: `briefing`
- Python venv at `~/news-app/venv` with: kokoro-onnx, pydub, soundfile
- TTS models in project root: `kokoro-v1.0.onnx` (311MB), `voices-v1.0.bin` (27MB) - both in .gitignore
- Claude CLI uses `--dangerously-skip-permissions` and `--allowedTools "Edit,Write,WebSearch"` for automated runs
- ANTHROPIC_API_KEY stored in `~/.bashrc`
- GitHub token embedded in git remote URL for push access

### Cron Schedule (as briefing user, times in UTC)
```
0 14 * * 1-6  # Morning 6AM PST (Mon-Sat)
0 0 * * *     # Daily 4PM PST
0 15 * * 0    # Weekly news Sun 7AM PST
30 15 * * 0   # Weekly science Sun 7:30AM PST
0 16 * * 0    # Weekly finance Sun 8AM PST
```

### Logs & Debugging
```bash
# View cron output
tail -f /home/briefing/news-app/logs/cron.log

# Test a briefing manually
cd ~/news-app && ./update-morning.sh

# Check cron is running
crontab -l
```

### Workflow
1. Cron triggers `run-scheduled.sh` at scheduled time
2. Script runs `git pull` to get latest code changes
3. Routes to appropriate `update-*.sh` based on time/day
4. Claude CLI searches web and writes/updates markdown file
5. `generate-audio.py` creates MP3s for each story
6. `build-html.js` rebuilds combined HTML
7. Git commits and pushes to GitHub

### Common Issues
- **"Not logged in"**: Claude CLI needs `--dangerously-skip-permissions` flag
- **Audio not generating**: Check Kokoro models exist (kokoro-v1.0.onnx, voices-v1.0.bin)
- **Git push fails**: GitHub token may have expired, regenerate at github.com/settings/tokens
- **Wrong briefing runs**: Check system time with `date` and ensure cron times are in UTC

### Credentials (stored on VPS, not in repo)
- Anthropic API key: `~/.bashrc` on VPS
- GitHub token: embedded in git remote URL on VPS
- SSH key: `~/.ssh/id_ed25519` on local Mac
