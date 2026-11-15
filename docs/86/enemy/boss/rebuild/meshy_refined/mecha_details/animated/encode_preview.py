"""Create animated GIF previews from the 10 fps PNG frames using Pillow."""
from pathlib import Path
import sys
from PIL import Image

here=Path(__file__).resolve().parent
frame_dir=Path(sys.argv[1]) if len(sys.argv)>1 else Path('/tmp/boss-animated-preview-20261115')
for name,expected in [('idle',30),('fly',18),('fire',12)]:
    paths=sorted(frame_dir.glob(f'{name}_*.png'))
    if len(paths)!=expected:
        raise RuntimeError(f'{name}: expected {expected} rendered frames, found {len(paths)}')
    frames=[]
    for path in paths:
        with Image.open(path) as image:
            frames.append(image.convert('RGB').quantize(colors=192,method=Image.Quantize.MEDIANCUT))
    dest=here/f'preview_{name}.gif'
    frames[0].save(dest,save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False,disposal=2)
    print('ANIMATED_PREVIEW',dest,'frames',len(frames),'duration_sec',len(frames)/10,'bytes',dest.stat().st_size)
