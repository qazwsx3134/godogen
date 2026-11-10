"""Verify committed audio without FFmpeg: Vorbis headers, Ogg granules, hashes and Git exclusions."""
from pathlib import Path
import hashlib,json,struct,subprocess
ROOT=Path(__file__).resolve().parents[1]
SOUND=ROOT/'assets/sound'
def ignored(path):
    r=subprocess.run(['git','check-ignore','-q','--',str(path)],capture_output=True)
    assert r.returncode in (0,1),r.stderr.decode()
    return r.returncode==0

def verify():
    manifest=json.loads((SOUND/'manifest.json').read_text())
    total=0
    for record in manifest['files']:
        path=SOUND/record['output'];data=path.read_bytes()
        assert data.startswith(b'OggS'),path
        header=data.find(b'\x01vorbis');assert header>=0,path
        assert data[header+11]==1,(path,'must be mono')
        rate=struct.unpack_from('<I',data,header+12)[0];assert rate==44100,path
        pos=0;last=0
        while pos<len(data):
            assert data[pos:pos+4]==b'OggS',path
            count=data[pos+26];size=sum(data[pos+27:pos+27+count])
            granule=struct.unpack_from('<Q',data,pos+6)[0]
            if granule!=0xffffffffffffffff:last=max(last,granule)
            pos+=27+count+size
        assert abs(last/rate-record['duration_seconds'])<.05,(path,'duration mismatch')
        assert hashlib.sha256(data).hexdigest()==record['output_sha256'],path
        assert record['peak_dbfs']<-1,path
        assert not ignored(path),path
        original=SOUND/record['source']
        assert ignored(original),(original,'raw original would enter Git')
        if original.exists(): assert hashlib.sha256(original.read_bytes()).hexdigest()==record['source_sha256'],original
        total+=len(data)
    assert total==manifest['runtime_total_bytes'] and total<250000,total
    print('AUDIO_ASSETS PASSED:',len(manifest['files']),'mono Vorbis clips,',total,'bytes; originals ignored and unchanged.')
if __name__=='__main__': verify()
