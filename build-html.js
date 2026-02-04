import { readFileSync, writeFileSync, existsSync } from 'fs';
import { execSync } from 'child_process';

// Convert markdown to HTML using marked
let htmlBody = execSync('npx marked -i morning_briefing.md', { encoding: 'utf-8' });

// Check if audio files exist
const hasAudio = existsSync('audio/story-01.mp3');

if (hasAudio) {
    // Inject audio players after each H3 (news story header)
    let storyNum = 0;
    htmlBody = htmlBody.replace(/<h3>([^<]+)<\/h3>/g, (match, title) => {
        // Skip "Sources" headers
        if (title.toLowerCase().includes('sources')) {
            return match;
        }
        storyNum++;
        const audioFile = `audio/story-${String(storyNum).padStart(2, '0')}.mp3`;
        return `<h3>${title}</h3>\n<audio class="story-audio" controls src="${audioFile}"></audio>`;
    });

    // Use audio template
    const template = readFileSync('template-audio.html', 'utf-8');
    const output = template.replace('{{CONTENT}}', htmlBody);
    writeFileSync('morning_briefing.html', output);
    console.log('Built morning_briefing.html with Kokoro TTS audio');
} else {
    // Fallback to regular template (Web Speech API)
    const template = readFileSync('template.html', 'utf-8');
    const output = template.replace('{{CONTENT}}', htmlBody);
    writeFileSync('morning_briefing.html', output);
    console.log('Built morning_briefing.html with Web Speech API (no audio files found)');
}
