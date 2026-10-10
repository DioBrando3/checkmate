#!/usr/bin/env python3
"""Assemble localized resources without changing chess diagrams or answer keys."""
import copy
import json
from pathlib import Path
import re
import runpy
ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/CheckmateCore/Resources'
translations = runpy.run_path(str(ROOT / 'scripts/build-chinese-course.py'))['read_scripts']()
original = json.loads((RES / 'course.json').read_text())
course = copy.deepcopy(original)
voices = json.loads((ROOT / 'Content/zh-Hans/voice-manifest.json').read_text())
catalog = dict(line.split('\t', 1) for line in (ROOT / 'Content/zh-Hans/interface.tsv').read_text().splitlines() if line.strip())
catalog.update({l['title']: translations[l['id']]['title'] for l in original['lessons']})
catalog['Checkmate'] = '将死'

def localize(value):
    if value in catalog: return catalog[value]
    return value

puzzles = dict((parts[0], parts[1:]) for line in (ROOT / 'Content/zh-Hans/puzzles.txt').read_text().splitlines() if (parts := line.split('|', 2)))
assert len(puzzles) == len(course['puzzles'])
for index, lesson in enumerate(course['lessons']):
    tr = translations[lesson['id']]
    lesson['title'] = tr['title']
    for step, beat in enumerate(lesson['beats']):
        text = tr['beats'][beat['id'].split(':')[-1]]
        beat['say'] = beat['speak'] = text
        if beat.get('big'): beat['big'] = localize(beat['big'])
        voice = copy.deepcopy(voices[beat['id']])
        moves = len(beat.get('moves', []))
        movement_end = 0.25 + max(0, moves - 1) * 0.95 + (0.7 if moves else 0) + 0.75
        voice['duration'] = max(voice['seconds'] + 0.5, movement_end + 0.5, len(beat.get('count', [])) * 0.2 + 0.5)
        course['voices'][index][step] = voice
        course['stepTitles'][index][step] = re.split('[。！？：；，]', text)[0][:22]
        for frame in course['frames'][index][step].values():
            if isinstance(frame, dict) and frame.get('big'): frame['big'] = localize(frame['big'])
    lesson['teaches'] = [lesson['beats'][-1]['say']]

choices = {'File': '纵线', 'Rank': '横线', 'Diagonal': '斜线'}
for puzzle in course['puzzles']:
    prompt, explanation = puzzles[puzzle['id']]
    if puzzle['id'].startswith('course:'):
        lesson_id = puzzle['id'].split(':')[1]
        puzzle['title'] = translations[lesson_id]['title'] + ' · ' + puzzle['title'].split(' · ')[-1]
        puzzle['context'] = ''
    else:
        puzzle['title'] = {'rook': '吃掉无保护的车', 'fork': '一马双攻', 'mate': '底线将杀', 'queen': '王后配合'}[puzzle['id']]
        puzzle['context'] = {'rook': '黑车没有保护，先检查吃子后能否安全。', 'fork': '寻找同时攻击两个目标的日字形落点。', 'mate': '黑兵堵住王的出口，寻找沿底线的将军。', 'queen': '白王能保护位于将杀格的后。'}[puzzle['id']]
    puzzle['topic'] = localize(puzzle['topic'])
    # The difficulty picker stores these identifiers; its label is localized in UI.
    puzzle['explanation'] = explanation
    exercise = puzzle['exercise']
    exercise['prompt'] = prompt
    if 'choices' in exercise: exercise['choices'] = [choices.get(x, localize(x)) for x in exercise['choices']]
    if 'answer' in exercise: exercise['answer'] = choices.get(exercise['answer'], localize(exercise['answer']))
    exercise_id = puzzle['id'].removeprefix('course:')
    if exercise_id in course['exercises']: course['exercises'][exercise_id] = copy.deepcopy(exercise)

# All standalone exercise strings must come from the reviewed puzzle translations.
for key, e in course['exercises'].items():
    assert re.search('[\u4e00-\u9fff]', e['prompt']), ('untranslated exercise', key)
course['narration'] = {'language': 'zh-Hans', 'provider': 'macOS local speech', 'voice': 'Tingting', 'rate': 190, 'segments': len(voices)}
(RES / 'course.zh-Hans.json').write_text(json.dumps(course, ensure_ascii=False, separators=(',', ':')) + '\n')
(RES / 'localization-zh-Hans.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
missing = sorted({b.get('big') for l in course['lessons'] for b in l['beats'] if b.get('big') and re.search('[a-zA-Z]{3}', b['big'])})
print('Published', len(course['lessons']), 'lessons,', len(voices), 'recordings,', len(puzzles), 'puzzles;', len(catalog), 'UI translations')
print('Untranslated title cards:', missing)
