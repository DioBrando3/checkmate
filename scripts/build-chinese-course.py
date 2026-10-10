#!/usr/bin/env python3
"""Build the Chinese course from reviewed scripts and local macOS speech.

No network API or microphone is used. Existing clips are reused only when their
text and voice configuration match. Original course IDs, diagrams and answers
are preserved; playback timing is derived from the new recordings.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/CheckmateCore/Resources'
VOICE = 'Tingting (中文（中国大陆）)'
RATE = '190'

def read_scripts():
    lessons = {}
    current = None
    for line in (ROOT / 'Content/zh-Hans/lessons.txt').read_text().splitlines():
        if line.startswith('# '):
            key, title = line[2:].split('|', 1)
            current = {'title': title, 'beats': {}}
            assert key not in lessons, key
            lessons[key] = current
        elif line.strip():
            index, text = line.split(' ', 1)
            assert index not in current['beats'], index
            current['beats'][index] = text
    return lessons

def record(item):
    key, text = item
    digest = hashlib.sha256((VOICE + RATE + text).encode()).hexdigest()[:16]
    relative = f'course/zh-Hans/{key.replace(":", "/")}-{digest}.m4a'
    target = RES / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        with tempfile.TemporaryDirectory(prefix='checkmate-speech-') as temporary:
            script = Path(temporary) / 'script.txt'
            script.write_text(text)
            aiff = Path(temporary) / 'speech.aiff'
            encoded = Path(temporary) / 'speech.m4a'
            subprocess.run(['/usr/bin/say', '-v', VOICE, '-r', RATE, '-f', str(script), '-o', str(aiff)], check=True, capture_output=True)
            subprocess.run(['/usr/bin/afconvert', '-f', 'm4af', '-d', 'aac', '-b', '64000', str(aiff), str(encoded)], check=True, capture_output=True)
            os.replace(encoded, target)
    info = subprocess.check_output(['/usr/bin/afinfo', str(target)], text=True)
    seconds = float(re.search(r'estimated duration:\s*([\d.]+)', info)[1])
    assert seconds > 0, key
    return key, {'file': relative, 'seconds': seconds, 'duration': seconds + 0.5}

def main():
    course = json.loads((RES / 'course.json').read_text())
    translations = read_scripts()
    items = []
    for lesson in course['lessons']:
        tr = translations[lesson['id']]
        assert {b['id'].split(':')[-1] for b in lesson['beats']} == set(tr['beats']), lesson['id']
        items.extend((b['id'], tr['beats'][b['id'].split(':')[-1]]) for b in lesson['beats'])
    voices = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for i, (key, voice) in enumerate(pool.map(record, items), 1):
            voices[key] = voice
            if i % 40 == 0: print(f'Recorded {i}/{len(items)}', flush=True)
    (ROOT / 'Content/zh-Hans/voice-manifest.json').write_text(json.dumps(voices, ensure_ascii=False, indent=2) + '\n')
    print(f'Chinese recordings complete: {len(voices)}', flush=True)
    guide_path = RES / 'piece-guide.zh-Hans.json'
    entries = json.loads(guide_path.read_text())
    for entry in entries:
        _, voice = record(('guide:' + entry['id'], '\n'.join([entry['title'] + '。', entry['summary']] + entry['rules'])))
        entry['audio'] = voice['file']
    guide_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
    print(f'Chinese rule recordings complete: {len(entries)}', flush=True)

if __name__ == '__main__':
    main()
