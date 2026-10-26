#!/usr/bin/env python3
"""Extract timestamped, unmodified reference frames with a local FFmpeg binary."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
    args = parser.parse_args()
    if not args.ffmpeg:
        parser.error('Pass --ffmpeg /path/to/ffmpeg or put ffmpeg on PATH.')
    root = Path(__file__).resolve().parent
    source = root / 'game-play.mp4'
    output = root / 'evidence'
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='idle-reference-') as temp:
        result = subprocess.run([
            args.ffmpeg, '-hide_banner', '-i', str(source), '-map', '0:v:0',
            '-vf', r'select=not(mod(n\,5)),showinfo', '-fps_mode', 'vfr',
            str(Path(temp) / 'frame-%03d.png'),
        ], capture_output=True, text=True, check=True)
        pts = [float(value) for value in re.findall(
            r'\bn:\s*\d+\s+pts:\s*\d+\s+pts_time:([\d.]+)', result.stderr)]
        frames = sorted(Path(temp).glob('frame-*.png'))
        if len(frames) != len(pts) or not frames:
            raise RuntimeError('Frame count and decoded timestamps do not match.')
        # Keep four compact sheets; their last cell is empty if fewer than 40 samples.
        subprocess.run([
            args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
            '-framerate', '6', '-i', str(Path(temp) / 'frame-%03d.png'),
            '-vf', 'tile=2x5', '-fps_mode', 'vfr',
            str(output / 'gameplay-sequence-%02d.png'),
        ], check=True)
        manifest = {
            'source': 'game-play.mp4',
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'method': 'Decode video; select every fifth source frame; tile row-major 2x5. No AI generation.',
            'audio_reviewed': False,
            'samples': [{'index': i, 'source_frame_index': (i - 1) * 5,
                         'pts_seconds': value,
                         'sheet': f'gameplay-sequence-{(i - 1) // 10 + 1:02d}.png',
                         'row': (i - 1) % 10 // 2 + 1,
                         'column': (i - 1) % 2 + 1}
                        for i, value in enumerate(pts, 1)],
        }
        (output / 'manifest.json').write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        (output / 'decode-metadata.txt').write_text(result.stderr, encoding='utf-8')
        print(f'{len(frames)} timestamped frames, {(len(frames) + 9) // 10} sheets.')


if __name__ == '__main__':
    main()
