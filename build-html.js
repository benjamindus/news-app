import { readFileSync, writeFileSync, existsSync } from 'fs';
import { execSync } from 'child_process';

// Briefing configurations
const briefings = [
    { id: 'morning', name: 'Morning News', mdFile: 'morning_briefing.md', audioDir: 'audio/morning' },
    { id: 'daily', name: 'Daily News', mdFile: 'daily_briefing.md', audioDir: 'audio/daily' },
    { id: 'weekly-news', name: 'Weekly News', mdFile: 'weekly_news.md', audioDir: 'audio/weekly-news' },
    { id: 'weekly-science', name: 'Weekly Science', mdFile: 'weekly_science.md', audioDir: 'audio/weekly-science' },
    { id: 'weekly-finance', name: 'Weekly Finance', mdFile: 'weekly_finance.md', audioDir: 'audio/weekly-finance' },
];

let allContent = '';

briefings.forEach(briefing => {
    const mdPath = briefing.mdFile;

    if (!existsSync(mdPath)) {
        // Create placeholder section for missing briefings
        allContent += `<div class="briefing-section" id="section-${briefing.id}">
    <div class="no-content">
        <h2>${briefing.name}</h2>
        <p>No content available yet. Run the ${briefing.name} research to generate content.</p>
    </div>
</div>\n\n`;
        return;
    }

    // Convert markdown to HTML
    let htmlBody = execSync(`npx marked -i ${mdPath}`, { encoding: 'utf-8' });

    // Check if audio files exist for this briefing
    const audioDir = briefing.audioDir;
    const hasAudio = existsSync(`${audioDir}/story-01.mp3`);

    if (hasAudio) {
        // Inject audio players after each H3 (news story header)
        let storyNum = 0;
        htmlBody = htmlBody.replace(/<h3>([^<]+)<\/h3>/g, (match, title) => {
            // Skip "Sources" headers
            if (title.toLowerCase().includes('sources')) {
                return match;
            }
            storyNum++;
            const audioFile = `${audioDir}/story-${String(storyNum).padStart(2, '0')}.mp3`;
            if (existsSync(audioFile)) {
                return `<h3>${title}</h3>\n<audio class="story-audio" controls src="${audioFile}"></audio>`;
            }
            return match;
        });
    }

    // Wrap in section div
    allContent += `<div class="briefing-section" id="section-${briefing.id}">\n${htmlBody}\n</div>\n\n`;
});

// Check if any briefing has audio
const hasAnyAudio = briefings.some(b => existsSync(`${b.audioDir}/story-01.mp3`));

// Use appropriate template
const templateFile = hasAnyAudio ? 'template-audio.html' : 'template.html';
const template = readFileSync(templateFile, 'utf-8');
const output = template.replace('{{CONTENT}}', allContent);
writeFileSync('briefing.html', output);

console.log(`Built briefing.html with ${briefings.filter(b => existsSync(b.mdFile)).length} briefings`);
if (hasAnyAudio) {
    console.log('Audio players enabled');
}
