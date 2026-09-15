"""Process v2 body actions with a shared per-character idle scale profile.
Run with Python containing Pillow and NumPy; raw art comes from imagegen.
"""
from pathlib import Path
import concurrent.futures, json, shutil, subprocess, sys
ROOT = Path(__file__).resolve().parents[1] / 'assets/visual-v2'
TOOL = Path('/home/ronghao/.codex/skills/generate2dsprite/scripts/generate2dsprite.py')

def process_character(hero):
    records = []
    profile = ROOT / f'{hero}-scale-profile.json'
    for action in ['idle', 'attack', 'hurt']:
        asset = f'hero-{hero}-{action}'
        output = ROOT / 'processed' / asset
        cmd = [sys.executable, str(TOOL), 'process', '--input', str(ROOT/'raw'/f'{asset}.png'),
               '--target', 'player', '--mode', action, '--output-dir', str(output),
               '--rows','2','--cols','2','--cell-size','256','--trim-border','0',
               '--align','feet','--shared-scale','--component-mode','largest',
               '--threshold','128','--edge-threshold','180','--strict-qc','--duration','150']
        if action == 'idle':
            cmd += ['--scale-strategy','fit','--fit-scale','0.82','--write-scale-profile',str(profile)]
        else:
            # Crouch/recoil intentionally reduce silhouette area; keep the same locked
            # pixel scale while permitting up to 22% silhouette-metric variation.
            cmd += ['--scale-profile',str(profile), '--max-profile-scale-drift','0.22']
        result = subprocess.run(cmd,capture_output=True,text=True)
        record = {'asset':asset,'command':cmd,'passed':result.returncode==0}
        if result.returncode:
            record['error'] = (result.stdout+result.stderr)[-2500:]
        else:
            shutil.copy2(output/'sheet-transparent.png', ROOT/f'{asset}.png')
        records.append(record)
        print(json.dumps(record),flush=True)
        if result.returncode and action == 'idle': break
    return records

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    records = sum(pool.map(process_character,['shadow_ninja','ki_fighter','silver_ronin']),[])
report = {'passed':len(records)==9 and all(r['passed'] for r in records),'assets':records}
(ROOT/'qc.json').write_text(json.dumps(report,indent=2)+'\n')
sys.exit(0 if report['passed'] else 1)
