"""Download a pinned public upstream snapshot for local asset/VFX study; execute no upstream tools."""
from urllib.request import Request, urlopen
from pathlib import Path
import hashlib, json, tarfile, datetime, shutil, subprocess, argparse
ROOT=Path(__file__).resolve().parent
BASE='https://api.github.com/repos/JPTER78/pokesurvivor'
def request(url):
    return urlopen(Request(url,headers={'User-Agent':'survivor-series-reference-study','Accept':'application/vnd.github+json'}),timeout=90)
parser=argparse.ArgumentParser()
parser.add_argument('--archive',type=Path,help='Reuse a downloaded archive; its embedded commit must match.')
args=parser.parse_args()
sha='c31715d183c0fd0b357e5ebc10fd85606132865e'
with request(BASE+'/commits/'+sha) as response:
    commit=json.load(response)
url=f'https://codeload.github.com/JPTER78/pokesurvivor/tar.gz/{sha}'
archive=ROOT/f'upstream-{sha[:12]}.tar.gz'
if args.archive:
    with tarfile.open(args.archive,'r:gz') as check:
        assert check.pax_headers.get('comment') == sha, 'archive commit mismatch'
    shutil.copyfile(args.archive,archive)
if not archive.exists():
    temporary=archive.with_suffix('.gz.part')
    with (ROOT/'download.log').open('w') as log:
        subprocess.run(['curl','--http2','-L','--fail','--retry','2','--connect-timeout','20','--max-time','180','--output',str(temporary),url],check=True,stderr=log)
    with tarfile.open(temporary,'r:gz') as check:
        assert check.pax_headers.get('comment') == sha, 'archive commit mismatch'
    temporary.replace(archive)
with tarfile.open(archive,'r:gz') as check:
    assert check.pax_headers.get('comment') == sha, 'archive commit mismatch'
source=ROOT/'upstream'
source.mkdir(exist_ok=True)
files=[]
with tarfile.open(archive,'r:gz') as package:
    for entry in package:
        relative=entry.name.partition('/')[2]
        if not relative:
            continue
        target=source/relative
        if not target.resolve().is_relative_to(source.resolve()):
            raise ValueError('unsafe archive path: '+entry.name)
        if entry.isdir():
            target.mkdir(parents=True,exist_ok=True)
        elif entry.isfile():
            target.parent.mkdir(parents=True,exist_ok=True)
            with package.extractfile(entry) as data,target.open('wb') as output:
                shutil.copyfileobj(data,output)
            payload=target.read_bytes()
            files.append({'path':relative,'bytes':len(payload),'sha256':hashlib.sha256(payload).hexdigest()})
        else:
            raise ValueError('unsupported archive entry: '+entry.name)
manifest={'repository':'https://github.com/JPTER78/pokesurvivor','commit':sha,'commit_date':commit['commit']['committer']['date'],'downloaded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'archive_url':url,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'archive_bytes':archive.stat().st_size,'file_count':len(files),'total_bytes':sum(x['bytes'] for x in files),'files':files}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:manifest[k] for k in ['commit','commit_date','archive_bytes','file_count','total_bytes']},indent=2))
