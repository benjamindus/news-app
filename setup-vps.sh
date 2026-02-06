#!/bin/bash
# One-time VPS setup script for morning-briefing system
# Run as: sudo ./setup-vps.sh

set -e

echo "=== Morning Briefing VPS Setup ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./setup-vps.sh)"
    exit 1
fi

echo ""
echo "Step 1: Installing system packages..."
apt update
apt install -y python3-pip python3-venv nodejs npm ffmpeg git curl

echo ""
echo "Step 2: Creating briefing user..."
if id "briefing" &>/dev/null; then
    echo "User 'briefing' already exists"
else
    adduser --disabled-password --gecos "" briefing
    usermod -aG sudo briefing
fi

echo ""
echo "Step 3: Installing Claude CLI..."
npm install -g @anthropic-ai/claude-code

echo ""
echo "Step 4: Setting up project directory..."
su - briefing << 'USERSCRIPT'
set -e

cd ~

if [ ! -d "morning-briefing" ]; then
    echo "Cloning repository..."
    git clone https://github.com/benjamindus/morning-briefing.git
fi

cd morning-briefing

echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "Downloading Kokoro TTS models..."
if [ ! -f "kokoro-v1.0.onnx" ]; then
    wget -q https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/kokoro-v1.0.onnx
fi
if [ ! -f "voices-v1.0.bin" ]; then
    wget -q https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/voices-v1.0.bin
fi

echo "Creating logs directory..."
mkdir -p logs

deactivate
USERSCRIPT

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Set up Anthropic API key:"
echo "   su - briefing"
echo "   echo 'export ANTHROPIC_API_KEY=\"your-key-here\"' >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "2. Set up cron jobs:"
echo "   crontab -e"
echo ""
echo "   Add these lines (times in UTC, adjust for your timezone):"
echo "   # Morning briefing: 6:00 AM Mon-Sat PST (14:00 UTC)"
echo "   0 14 * * 1-6 cd /home/briefing/morning-briefing && ./run-scheduled.sh >> logs/cron.log 2>&1"
echo ""
echo "   # Weekly news: Sunday 7:00 AM PST (15:00 UTC)"
echo "   0 15 * * 0 cd /home/briefing/morning-briefing && ./run-scheduled.sh >> logs/cron.log 2>&1"
echo ""
echo "   # Weekly science: Sunday 7:30 AM PST (15:30 UTC)"
echo "   30 15 * * 0 cd /home/briefing/morning-briefing && ./run-scheduled.sh >> logs/cron.log 2>&1"
echo ""
echo "   # Weekly finance: Sunday 8:00 AM PST (16:00 UTC)"
echo "   0 16 * * 0 cd /home/briefing/morning-briefing && ./run-scheduled.sh >> logs/cron.log 2>&1"
echo ""
echo "   # Daily briefing: 6:00 PM PST (02:00 UTC next day)"
echo "   0 2 * * * cd /home/briefing/morning-briefing && ./run-scheduled.sh >> logs/cron.log 2>&1"
echo ""
echo "3. Test manually:"
echo "   su - briefing"
echo "   cd morning-briefing"
echo "   ./run-scheduled.sh"
