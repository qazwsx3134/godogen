"""Prepare original user uploads for Git and Godot. Requires FFmpeg with libvorbis.
Originals are never modified. FFMPEG_BIN or --ffmpeg selects the executable.
"""
from pathlib import Path
import argparse,array,hashlib,json,math,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
SOUND=ROOT/'assets/sound'
RATE=44100
SPECS=[
 ('ai_boot','enemy/ai-start-moving.wav',None,-23,'voice','Hove Audio'),
 ('ai_radio','enemy/ai-talking.wav',None,-23,'voice','Hove Audio'),
 ('explosion','explode/explodemini.wav',None,-18,'impact','Michel Baradari / CC-BY 3.0'),
 ('hit_heavy','hit/impactGlass_heavy_001.ogg',None,-22,'impact','Kenney / CC0'),
 ('scout_gun_a','machine-gun/417688__superphat__lightmachinegun1.wav',(17.09,17.75),-21,'weapon','SuperPhat / CC0'),
 ('scout_gun_b','machine-gun/417688__superphat__lightmachinegun1.wav',(21.10,21.76),-21,'weapon','SuperPhat / CC0'),
 ('scout_gun_c','machine-gun/417688__superphat__lightmachinegun1.wav',(25.11,25.77),-21,'weapon','SuperPhat / CC0'),
 ('scout_gun_burst','machine-gun/417688__superphat__lightmachinegun1.wav',(2.04,2.94),-21,'weapon','SuperPhat / CC0'),
 ('mech_step_a','machine-walk/557594__breviceps__battle-mech-walks-fast-slow-sequence.wav',(.16,.62),-23,'movement','Breviceps / CC0'),
 ('mech_step_b','machine-walk/557594__breviceps__battle-mech-walks-fast-slow-sequence.wav',(1.50,1.96),-23,'movement','Breviceps / CC0'),
 ('mech_contact','machine-walk/robotstep3.wav',None,-23,'movement','Lee Barkovich / CC-BY 3.0 (folder info.txt)'),
 ('mech_servo','machine-walk/robot1.wav',None,-24,'movement','Lee Barkovich / CC-BY 3.0 (folder info.txt)'),
 ('mech_land','machine-walk/jumpland44100.mp3',None,-20,'movement','Lee Barkovich / CC-BY 3.0 (folder info.txt)'),
 ('mech_walk_sequence','machine-walk/557594__breviceps__battle-mech-walks-fast-slow-sequence.wav',None,-23,'reference','Breviceps / CC0'),
]
def decode(ff,path):
    data=subprocess.check_output([ff,'-v','error','-i',str(path),'-ac','1','-ar',str(RATE),'-f','f32le','pipe:1'])
    a=array.array('f');a.frombytes(data)
    if os.sys.byteorder!='little': a.byteswap()
    return a

def db(value): return round(20*math.log10(max(value,1e-12)),2)
def metrics(a):
    return {'duration_seconds':round(len(a)/RATE,5),'peak_dbfs':db(max(map(abs,a),default=0)),
            'rms_dbfs':db(math.sqrt(sum(x*x for x in a)/max(1,len(a))))}
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--ffmpeg',default=os.environ.get('FFMPEG_BIN') or shutil.which('ffmpeg'))
    args=ap.parse_args()
    if not args.ffmpeg: ap.error('Install FFmpeg or supply --ffmpeg /path/to/ffmpeg')
    ff=args.ffmpeg
    out=SOUND/'runtime';out.mkdir(exist_ok=True)
    cache={};records=[]
    for name,source,cut,target,role,credit in SPECS:
        src=SOUND/source
        if source not in cache: cache[source]=decode(ff,src)
        a=array.array('f',cache[source])
        source_metrics=metrics(a)
        if cut: a=a[round(cut[0]*RATE):round(cut[1]*RATE)]
        mean=sum(a)/len(a)
        a=array.array('f',(x-mean for x in a))
        rms=math.sqrt(sum(x*x for x in a)/len(a));peak=max(map(abs,a))
        # RMS matching is limited by a conservative -6 dBFS peak ceiling.
        gain=min(10**(target/20)/max(rms,1e-9),10**(-6/20)/max(peak,1e-9))
        a=array.array('f',(x*gain for x in a))
        if role!='reference':
            active=[i for i,x in enumerate(a) if abs(x)>10**(-58/20)]
            if active: a=a[max(0,active[0]-round(.003*RATE)):min(len(a),active[-1]+round(.035*RATE))]
        for i in range(len(a)):
            a[i]*=min(1,i/((.003 if role=='voice' else .0005)*RATE),(len(a)-1-i)/(.015*RATE))
        dst=out/(name+'.ogg')
        encoded=array.array('f',a)
        if os.sys.byteorder!='little': encoded.byteswap()
        subprocess.run([ff,'-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','pipe:0',
                        '-c:a','libvorbis','-q:a','4','-map_metadata','-1',str(dst)],input=encoded.tobytes(),check=True)
        result=decode(ff,dst);stats=metrics(result)
        assert stats['peak_dbfs'] < -1 and len(result)>0,(name,stats)
        record={'name':name,'source':source,'source_sha256':sha(src),'source_bytes':src.stat().st_size,
                'source_analysis_mono':source_metrics,'crop_seconds':cut,'credit':credit,'role':role,
                'processing':{'channels':1,'sample_rate':RATE,'codec':'Vorbis','quality':4,
                              'target_rms_dbfs':target,'max_preencode_peak_dbfs':-6,'gain_db':db(gain),
                              'dc_removed':True,'fade_in_ms':3 if role=='voice' else .5,'fade_out_ms':15},
                'output':'runtime/'+dst.name,'output_bytes':dst.stat().st_size,'output_sha256':sha(dst),**stats}
        records.append(record)
        print(name,stats,dst.stat().st_size,'bytes')
    raw_bytes=sum((SOUND/p).stat().st_size for p in cache)
    total=sum(r['output_bytes'] for r in records)
    manifest={'schema_version':1,'source_total_bytes':raw_bytes,'runtime_total_bytes':total,
              'reduction_percent':round((1-total/raw_bytes)*100,2),'files':records}
    (SOUND/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('TOTAL',raw_bytes,'->',total,'bytes;',manifest['reduction_percent'],'% smaller')
if __name__=='__main__': main()
