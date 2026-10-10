#!/usr/bin/env python3
"""Validate staged lesson text and export plain-text, engine-neutral TTS inputs.

This never edits runtime resources, audio, timings, or saved learner progress.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Content/course-baseline.json'
RUNTIME = ROOT / 'Sources/CheckmateCore/Resources/course.json'
CONTENT = ROOT / 'Content/course-scripts.en-GB.json'


def sha(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def speech_text(text):
    numbers = dict(zip('12345678', ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight']))
    text = re.sub(r'\b([KQRBN])([a-h])([1-8])\b', lambda m: f'capital {m[1]}, {m[2].upper()} {numbers[m[3]]}', text)
    text = re.sub(r'\b([a-h])([1-8])\b', lambda m: f'{m[1].upper()} {numbers[m[2]]}', text)
    return re.sub(r'\b([a-h])-file\b', lambda m: f'letter {m[1].upper()} file', text)


def without(mapping, fields):
    return {key: value for key, value in mapping.items() if key not in fields}


def validate(content, source):
    assert content['schemaVersion'] == 2
    assert content['publicationState'] in ('awaiting_recordings', 'published')
    assert content['locale'] == 'en-GB'
    assert content['sourceResourceSHA256'] == hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'Immutable baseline changed; review action/answer parity before rebasing the scripts.'
    assert 'voices' not in content, 'Editorial source must not carry generated narration metadata.'
    assert [l['id'] for l in content['lessons']] == [l['id'] for l in source['lessons']]
    retired = set(content.get('retiredExerciseIDs', []))
    assert retired == set(source['exercises']), 'Every embedded quiz must be retired.'
    assert not content['exercises'], 'Lessons are continuous narration; exercises belong in Quick puzzles.'
    ids = set()
    for new, old in zip(content['lessons'], source['lessons']):
        assert without(new, ['beats', 'teaches']) == without(old, ['beats', 'teaches'])
        assert new['teaches'] and all(isinstance(t, str) and t.strip() for t in new['teaches'])
        retained = [(i, b) for i, b in enumerate(old['beats']) if f"{new['id']}:{i}" not in retired]
        assert len(new['beats']) == len(retained)
        for beat, (i, original) in zip(new['beats'], retained):
            key = f"{new['id']}:{i}"
            assert beat['id'] == key and key not in ids
            ids.add(key)
            assert isinstance(beat['say'], str) and beat['say'].strip()
            assert isinstance(beat['speak'], str) and beat['speak'].strip()
            assert not re.search(r'pause the video|bye bye|hello(?: again)?, chess friends|when you are bigger|every green dot|it changes colour', beat['say'], re.I), key
            assert without(beat, ['id', 'say', 'speak', 'quiz']) == without(original, ['say', 'speak', 'quiz']), f'Board action changed: {key}'
            assert 'quiz' not in beat
    for key, exercise in content['exercises'].items():
        assert without(exercise, ['prompt']) == without(source['exercises'][key], ['prompt']), f'Answer changed: {key}'
    assert [p['id'] for p in content['puzzles']] == [p['id'] for p in source['puzzles']]
    for puzzle, original in zip(content['puzzles'], source['puzzles']):
        assert without(puzzle, ['exercise', 'context', 'explanation']) == without(original, ['exercise', 'context', 'explanation']), f'Puzzle position changed: {puzzle["id"]}'
        assert without(puzzle['exercise'], ['prompt']) == without(original['exercise'], ['prompt'])
        assert puzzle['explanation'].strip()
        assert not re.search(r'^(Naming |Finding a piece|Asks |Yes/no |Rule question:|Spotting |Which pawn .*not a move)', puzzle['explanation'])
        if puzzle['id'].startswith('course:'):
            key = puzzle['id'].removeprefix('course:')
            assert key in retired
    return ids


def outputs(content):
    lines = ['# Checkmate lesson scripts — British English', '',
             ('Published native course text with Cedar narration.' if content['publicationState'] == 'published' else 'Rewritten text for recording. Status: awaiting recordings. This is not the currently bundled narration.'), '',
             'Lessons play continuously without embedded quizzes. Segment IDs retain their original recording identifiers; standalone puzzles remain separate.', '']
    narration = []
    for number, lesson in enumerate(content['lessons'], 1):
        lines += [f"## {number}. {lesson['title']}", '', '### Takeaways', '']
        lines += ['- ' + item for item in lesson['teaches']]
        lines += ['', '### Narration', '']
        for i, beat in enumerate(lesson['beats']):
            lines += [f"**{beat['id']}**", '', beat['say'], '']
            if beat['speak'] != beat['say']:
                lines += ['Recording text: ' + beat['speak'], '']
            narration.append({'id': beat['id'], 'lessonId': lesson['id'], 'beatIndex': int(beat['id'].rsplit(':', 1)[1]),
                              'locale': content['locale'], 'displayText': beat['say'], 'text': beat['speak'],
                              'sha256': sha(beat['speak']), 'outputStem': f"voice-v2/{lesson['id']}/{int(beat['id'].rsplit(':', 1)[1]):02d}"})
    lines += ['## Standalone puzzle feedback', '']
    feedback = []
    for puzzle in content['puzzles']:
        lines += [f"### {puzzle['id']}", '', 'Question: ' + puzzle['exercise']['prompt'], '']
        if puzzle['context']:
            lines += ['Context: ' + puzzle['context'], '']
        lines += ['Answer explanation: ' + puzzle['explanation'], '']
        # Optional feedback audio is separate from sequential lesson clips.
        text = speech_text(puzzle['explanation'])
        feedback.append({'id': puzzle['id'] + ':feedback', 'locale': content['locale'],
                         'displayText': puzzle['explanation'], 'text': text, 'sha256': sha(text), 'delivery': 'optional_feedback'})
    def jsonl(records):
        return ''.join(json.dumps(record, ensure_ascii=False) + '\n' for record in records)
    return {'lesson-scripts.en-GB.md': '\n'.join(lines),
            'lesson-narration.en-GB.jsonl': jsonl(narration),
            'puzzle-feedback.en-GB.jsonl': jsonl(feedback)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate parity and require current exports without writing files.')
    args = parser.parse_args()
    content = json.loads(CONTENT.read_text())
    source = json.loads(SOURCE.read_text())
    ids = validate(content, source)
    for name, text in outputs(content).items():
        path = ROOT / 'Content' / name
        if args.check:
            assert path.exists() and path.read_text() == text, f'Stale export: {path}'
        else:
            path.write_text(text)
    stats = {'lessons': len(content['lessons']), 'segments': len(ids),
             'exercises': len(content['exercises']), 'puzzles': len(content['puzzles']),
             'rewrittenSegments': sum(n['say'] != ol['beats'][int(n['id'].rsplit(':', 1)[1])]['say'] for nl, ol in zip(content['lessons'], source['lessons']) for n in nl['beats']),
             'originalWords': sum(len(b['say'].split()) for l in source['lessons'] for b in l['beats']),
             'rewrittenWords': sum(len(b['say'].split()) for l in content['lessons'] for b in l['beats']),
             'retainedActionsAndStandaloneAnswersUnchanged': True,
             'retiredLessonQuestions': len(content['retiredExerciseIDs']),
             'runtimeResourceUnchanged': RUNTIME.read_bytes() == SOURCE.read_bytes(),
             'publicationState': content['publicationState']}
    print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    main()
