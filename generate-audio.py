#!/usr/bin/env python3
"""Generate audio files from briefing markdown using Kokoro TTS."""

import os
import re
import sys
import soundfile as sf
from kokoro_onnx import Kokoro
from pydub import AudioSegment

def format_number_for_tts(match):
    """Convert numbers like 48,000 to '48 thousand' for natural TTS reading."""
    num_str = match.group().replace(',', '')
    try:
        num = float(num_str)
        if num >= 1_000_000_000:
            formatted = num / 1_000_000_000
            if formatted == int(formatted):
                return f"{int(formatted)} billion"
            return f"{formatted:.1f} billion".replace('.0 ', ' ')
        elif num >= 1_000_000:
            formatted = num / 1_000_000
            if formatted == int(formatted):
                return f"{int(formatted)} million"
            return f"{formatted:.1f} million".replace('.0 ', ' ')
        elif num >= 1_000:
            formatted = num / 1_000
            if formatted == int(formatted):
                return f"{int(formatted)} thousand"
            return f"{formatted:.1f} thousand".replace('.0 ', ' ')
        else:
            return num_str
    except:
        return match.group()

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
        full_text = re.sub(r'\$[\d,.]+[BMK]?', lambda m: m.group().replace('$', ' dollars '), full_text)
        # Fix abbreviations like U.S. -> US, U.K. -> UK so TTS reads them naturally
        full_text = re.sub(r'\b([A-Z])\.([A-Z])\.([A-Z])\.([A-Z])\.?', r'\1\2\3\4', full_text)  # 4-letter abbrevs
        full_text = re.sub(r'\b([A-Z])\.([A-Z])\.([A-Z])\.?', r'\1\2\3', full_text)  # 3-letter abbrevs like U.A.E.
        full_text = re.sub(r'\b([A-Z])\.([A-Z])\.?', r'\1\2', full_text)  # 2-letter abbrevs like U.S., U.K.
        # Convert large numbers to readable format: 48,000 -> "48 thousand"
        full_text = re.sub(r'\b\d{1,3}(?:,\d{3})+\b', format_number_for_tts, full_text)
        full_text = full_text.replace('&amp;', 'and')
        full_text = full_text.replace('  ', ' ')

        if len(full_text) > 50:  # Only include substantial content
            story_num += 1
            stories.append({
                'num': story_num,
                'title': title[:50],
                'text': full_text
            })

    return stories

def generate_audio(stories, output_dir):
    """Generate audio files using Kokoro."""
    os.makedirs(output_dir, exist_ok=True)

    print("Loading Kokoro model...")
    kokoro = Kokoro("kokoro-v1.0.onnx", "voices-v1.0.bin")

    for story in stories:
        wav_file = f"{output_dir}/story-{story['num']:02d}.wav"
        mp3_file = f"{output_dir}/story-{story['num']:02d}.mp3"
        print(f"Generating {mp3_file}: {story['title']}...")

        try:
            # Generate audio
            samples, sample_rate = kokoro.create(
                story['text'],
                voice="af_heart",
                speed=1.0,
                lang="en-us"
            )

            # Save as WAV temporarily
            sf.write(wav_file, samples, sample_rate)

            # Convert to MP3
            audio = AudioSegment.from_wav(wav_file)
            audio.export(mp3_file, format="mp3", bitrate="64k")
            os.remove(wav_file)  # Remove WAV file
            print(f"  Saved {mp3_file}")
        except Exception as e:
            print(f"  Error: {e}")

    print(f"\nGenerated {len(stories)} audio files in {output_dir}")

if __name__ == '__main__':
    # Default values
    input_file = 'morning_briefing.md'
    output_dir = 'audio/morning'

    # Parse command line arguments
    if len(sys.argv) >= 2:
        input_file = sys.argv[1]
    if len(sys.argv) >= 3:
        output_dir = sys.argv[2]

    print(f"Parsing {input_file}...")
    stories = parse_markdown(input_file)
    print(f"Found {len(stories)} stories")

    if stories:
        generate_audio(stories, output_dir)
    else:
        print("No stories found!")
