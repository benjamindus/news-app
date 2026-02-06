#!/usr/bin/env python3
"""Generate audio files from morning_briefing.md using Kokoro TTS."""

import os
import re
import soundfile as sf
from kokoro_onnx import Kokoro
from pydub import AudioSegment

# Create audio directory
os.makedirs('audio', exist_ok=True)

def spoken_number(num):
    """Convert a number to a spoken form like '1.5 million'."""
    if num >= 1_000_000_000_000:
        val = num / 1_000_000_000_000
        return f"{round(val, 2):g} trillion"
    elif num >= 1_000_000_000:
        val = num / 1_000_000_000
        return f"{round(val, 2):g} billion"
    elif num >= 1_000_000:
        val = num / 1_000_000
        return f"{round(val, 2):g} million"
    elif num >= 1000:
        val = num / 1000
        if val == int(val):
            return f"{int(val)} thousand"
        return f"{round(val, 1):g} thousand"
    else:
        return f"{num:g}"

def normalize_numbers(text):
    """Convert numbers to TTS-friendly spoken forms."""
    # Dollar amounts with B/M/K/T suffix: $1.5B → 1.5 billion dollars
    def money_suffix(m):
        num = m.group(1)
        suffix = m.group(2).upper()
        words = {'B': 'billion', 'M': 'million', 'K': 'thousand', 'T': 'trillion'}
        return f"{num} {words.get(suffix, '')} dollars"
    text = re.sub(r'\$([\d]+(?:\.\d+)?)\s*([BMKTbmkt])\b', money_suffix, text)

    # Plain dollar amounts with commas/digits: $16,000 → 16 thousand dollars
    def money_plain(m):
        num_str = m.group(1).replace(',', '')
        try:
            return spoken_number(float(num_str)) + ' dollars'
        except ValueError:
            return m.group(0)
    text = re.sub(r'\$([\d,]+(?:\.\d+)?)', money_plain, text)

    # Percentages: 3.5% → 3.5 percent
    text = re.sub(r'([\d]+(?:\.\d+)?)\s*%', r'\1 percent', text)

    # Large numbers with commas: 16,000 → 16 thousand
    def commas_number(m):
        num_str = m.group(0).replace(',', '')
        try:
            return spoken_number(float(num_str))
        except ValueError:
            return m.group(0)
    text = re.sub(r'\b\d{1,3}(?:,\d{3})+(?:\.\d+)?\b', commas_number, text)

    # Standalone large numbers without commas (5+ digits): 16000 → 16 thousand
    def big_number(m):
        try:
            return spoken_number(float(m.group(0)))
        except ValueError:
            return m.group(0)
    text = re.sub(r'\b\d{5,}\b', big_number, text)

    return text

def parse_markdown(filepath):
    """Parse markdown and extract news stories."""
    with open(filepath, 'r') as f:
        content = f.read()

    stories = []
    # Split by H3 headers (### )
    sections = re.split(r'\n###\s+', content)

    story_num = 0
    for section in sections[1:]:  # Skip content before first H3
        lines = section.strip().split('\n')
        if not lines:
            continue

        # Get title (first line)
        title = lines[0].strip()

        # Skip "Sources" section
        if title.lower().startswith('sources'):
            continue

        # Remove italics markers and clean title
        title = re.sub(r'\*([^*]+)\*', r'\1', title)
        title = re.sub(r'_([^_]+)_', r'\1', title)

        # Get blockquote and paragraphs
        text_parts = [title]
        for line in lines[1:]:
            line = line.strip()
            # Stop when we hit Sources section
            if 'sources:' in line.lower() or line.startswith('**Sources'):
                break
            if line.startswith('>'):
                # Blockquote - remove > and add
                text_parts.append(line[1:].strip())
            elif line and not line.startswith('[') and not line.startswith('http') and not line.startswith('1.') and not line.startswith('2.'):
                # Regular paragraph (skip links and numbered lists)
                text_parts.append(line)

        full_text = '. '.join(text_parts)
        # Clean up text for TTS
        full_text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', full_text)  # Remove markdown links
        full_text = re.sub(r'\*\*([^*]+)\*\*', r'\1', full_text)  # Remove bold **text**
        full_text = re.sub(r'\*([^*]+)\*', r'\1', full_text)  # Remove italics *text*
        full_text = re.sub(r'_([^_]+)_', r'\1', full_text)  # Remove italics _text_
        full_text = re.sub(r'\*+', '', full_text)  # Remove any remaining asterisks
        full_text = full_text.replace('&amp;', 'and')
        full_text = normalize_numbers(full_text)
        full_text = full_text.replace('  ', ' ')

        if len(full_text) > 50:  # Only include substantial content
            story_num += 1
            stories.append({
                'num': story_num,
                'title': title[:50],
                'text': full_text
            })

    return stories

def generate_audio(stories):
    """Generate audio files using Kokoro."""
    print("Loading Kokoro model...")
    kokoro = Kokoro("kokoro-v1.0.onnx", "voices-v1.0.bin")

    for story in stories:
        filename = f"audio/story-{story['num']:02d}.wav"
        print(f"Generating {filename}: {story['title']}...")

        try:
            # Generate audio
            samples, sample_rate = kokoro.create(
                story['text'],
                voice="af_heart",
                speed=1.0,
                lang="en-us"
            )

            # Save as WAV temporarily
            wav_file = filename.replace('.mp3', '.wav')
            sf.write(wav_file, samples, sample_rate)

            # Convert to MP3
            mp3_file = f"audio/story-{story['num']:02d}.mp3"
            audio = AudioSegment.from_wav(wav_file)
            audio.export(mp3_file, format="mp3", bitrate="64k")
            os.remove(wav_file)  # Remove WAV file
            print(f"  Saved {mp3_file}")
        except Exception as e:
            print(f"  Error: {e}")

    print(f"\nGenerated {len(stories)} audio files")

if __name__ == '__main__':
    print("Parsing morning_briefing.md...")
    stories = parse_markdown('morning_briefing.md')
    print(f"Found {len(stories)} stories")

    if stories:
        generate_audio(stories)
    else:
        print("No stories found!")
