## Morning Briefing System - Infrastructure Context

**Project**: `/Users/borisdus/code/morning-briefing` (local) / `/home/briefing/morning-briefing` (VPS)
**Repo**: https://github.com/benjamindus/morning-briefing

### Architecture
The system runs on a Hetzner VPS (CPX 11, $5.59/mo) at `5.161.109.207`. Cron jobs trigger briefings on schedule, Claude CLI generates news content, Kokoro TTS creates audio, and results are pushed to GitHub.

### VPS Access
```bash
ssh briefing@5.161.109.207
```

### Key Files
- `run-scheduled.sh` - Entry point, auto-pulls from GitHub, routes to correct briefing based on time
- `update-morning.sh` - Morning briefing (6 AM Mon-Sat PST)
- `update-daily.sh` - Daily briefing (6 PM daily PST)
- `update-weekly-news.sh` - Weekly news (Sun 7 AM PST)
- `update-weekly-science.sh` - Weekly science (Sun 7:30 AM PST)
- `update-weekly-finance.sh` - Weekly finance (Sun 8 AM PST)
- `generate-audio.py` - Kokoro TTS audio generation
- `build-html.js` - Generates briefing.html

### Scripts auto-detect environment
- VPS: `/home/briefing/morning-briefing`
- Mac: `/Users/borisdus/code/morning-briefing`

### VPS Setup
- User: `briefing`
- Python venv with: kokoro-onnx, pydub, soundfile
- TTS models: kokoro-v1.0.onnx, voices-v1.0.bin (in .gitignore)
- Claude CLI uses `--dangerously-skip-permissions` for automated runs
- ANTHROPIC_API_KEY in ~/.bashrc
- GitHub token embedded in git remote URL

### Cron (as briefing user)
```
0 14 * * 1-6  # Morning 6AM PST
0 2 * * *     # Daily 6PM PST
0 15 * * 0    # Weekly news Sun 7AM PST
30 15 * * 0   # Weekly science Sun 7:30AM PST
0 16 * * 0    # Weekly finance Sun 8AM PST
```

### Logs
```bash
tail -f /home/briefing/morning-briefing/logs/cron.log
```
