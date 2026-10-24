#!/usr/bin/env python3
"""Execute BRIEF-POSES within chars only. No approval, padding or animation.

Runs at most six master_still edit commands concurrently. Whole-pose wall time
is capped at 360s; each of its two media calls is capped at 175s (inner 165s).
A timed-out pose is retried once, preserving its failed attempt.
"""
from __future__ import annotations
import concurrent.futures
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import threading
import time
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
PY = '/Users/peter/repo/agent-sprite-forge/.venv/bin/python'
TOOL = '/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py'
ROLES = ('captain','guardian','medic','meadow_slime','briar_boar','ruin_hound')
STOP = threading.Event()
PRINT_LOCK = threading.Lock()


def say(message):
    with PRINT_LOCK:
        print(message,flush=True)


def snapshot():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
            for role in ROLES for p in (ROOT/role/'master').iterdir() if p.is_file()}


def terminate(proc):
    try:
        os.killpg(proc.pid,signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try: os.killpg(proc.pid,signal.SIGKILL)
        except ProcessLookupError: pass
        proc.wait()


def run_one(task,keep):
    role,pose,change=task
    if STOP.is_set(): return dict(role=role,pose=pose,status='skipped',reason='generation route blocked')
    parent=ROOT/role/'poses'
    parent.mkdir(exist_ok=True)
    output=parent/pose
    if output.exists():
        STOP.set()
        return dict(role=role,pose=pose,status='blocked',reason='output already exists; refusing overwrite')
    attempts=[]
    for attempt in (1,2):
        argv=[PY,TOOL,'edit','--master',str(ROOT/role/'master'),'--change',change,
              '--keep',keep,'--takes','2','--route','codex-cli','--timeout','175',
              '--media-arg=--timeout','--media-arg=165','--output-dir',str(output)]
        log=parent/f'{pose}-attempt{attempt}.log'
        env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1')
        started=time.monotonic()
        timed_out=False
        say(f'START {role}/{pose} attempt={attempt}')
        with log.open('w',encoding='utf-8') as stream:
            proc=subprocess.Popen(argv,stdout=stream,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            try:
                code=proc.wait(timeout=360)
            except subprocess.TimeoutExpired:
                timed_out=True
                terminate(proc)
                code=124
        record=dict(attempt=attempt,exit_code=code,seconds=round(time.monotonic()-started,3),log=str(log.relative_to(ROOT)))
        attempts.append(record)
        doc=None
        if (output/'run.json').exists():
            doc=json.loads((output/'run.json').read_text())
        if code==0 and doc and doc['status']=='ok' and len(doc['takes'])==2 and all(t['status']=='ok' for t in doc['takes']):
            say(f'OK {role}/{pose} {record["seconds"]}s')
            return dict(role=role,pose=pose,status='ok',attempts=attempts)
        text=log.read_text(errors='replace').lower()
        timed_out=timed_out or any(word in text for word in ('timeout','timed out','did not finish within'))
        if timed_out and attempt==1:
            if output.exists(): output.rename(parent/f'{pose}-attempt1-failed')
            say(f'RETRY {role}/{pose}: timeout, first attempt preserved')
            continue
        if timed_out:
            say(f'SKIP {role}/{pose}: second timeout')
            return dict(role=role,pose=pose,status='skipped',reason='timed out twice',attempts=attempts)
        STOP.set()
        say(f'BLOCKED {role}/{pose}: exit={code}; see {record["log"]}')
        return dict(role=role,pose=pose,status='blocked',reason=f'non-timeout generation failure (exit {code})',attempts=attempts)


def contacts(tasks):
    for role in ROLES:
        ordered=[('master',ROOT/role/'master/master.png')]
        for task in tasks:
            who,pose,change=task
            if who!=role: continue
            for take in (1,2):
                p=ROOT/role/'poses'/pose/'takes'/f'take-{take:02d}'/'generated.png'
                if p.is_file(): ordered.append((f'{pose} / take {take}',p))
        columns=4 if len(ordered)>9 else 3
        cell=320
        sheet=Image.new('RGB',(columns*cell,math.ceil(len(ordered)/columns)*(cell+24)),(32,32,32))
        draw=ImageDraw.Draw(sheet)
        for index,(label,path) in enumerate(ordered):
            image=Image.open(path).convert('RGB')
            image.thumbnail((cell,cell),Image.Resampling.LANCZOS)
            x=(index%columns)*cell
            y=(index//columns)*(cell+24)
            draw.text((x+6,y+5),label,fill='white')
            sheet.paste(image,(x+(cell-image.width)//2,y+24+(cell-image.height)//2))
        sheet.save(ROOT/role/'poses-contact.png')


def main():
    text=(ROOT/'POSES.md').read_text()
    keep=re.search(r'(?m)^共同 keep[^`\n]*`([^`]+)`',text).group(1)
    by_role={}
    for section in re.split(r'(?m)^## ',text)[1:]:
        role=re.match(r'(\w+)',section).group(1)
        assert role in ROLES
        by_role[role]=[(role,pose,change) for pose,change in re.findall(r'(?m)^- (\w+): (.+)$',section)]
    tasks=[task for index in range(5) for role in ROLES for task in by_role[role][index:index+1]]
    assert len(tasks)==27 and len(keep)>20
    masters=snapshot()
    results=[]
    start=time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        pending={pool.submit(run_one,task,keep):task for task in tasks}
        for future in concurrent.futures.as_completed(pending):
            result=future.result()
            results.append(result)
            state=dict(status='working',results=results,master_hashes=masters)
            (ROOT/'pose-batch-status.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    assert snapshot()==masters,'master source changed during generation'
    contacts(tasks)
    ok=sum(r['status']=='ok' for r in results)
    status='ok' if ok==27 else 'blocked'
    summary=dict(status=status,ok=ok,total=27,seconds=round(time.monotonic()-start,3),results=results,master_hashes=masters)
    (ROOT/'pose-batch-status.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    say(json.dumps({k:v for k,v in summary.items() if k not in ('results','master_hashes')}))
    return 0 if status=='ok' else 1


if __name__=='__main__':
    raise SystemExit(main())
