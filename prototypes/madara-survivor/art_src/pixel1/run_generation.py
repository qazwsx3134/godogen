from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,wait,FIRST_COMPLETED
import json,re,subprocess,sys,time
ROOT=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1')
PYTHON='/Users/peter/repo/agent-sprite-forge/.venv/bin/python'
MASTER='/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py'
ART=Path('/Users/peter/repo/godot/godogen/prototypes/madara-survivor/docs/art-spec.md')
ROOT.joinpath('inputs').mkdir(exist_ok=True)
blocks=re.findall(r'```text\n(.*?)\n```',ART.read_text(),re.S)
common=re.findall(r'```text\n(.*?)\n```',(ROOT/'BRIEF.md').read_text(),re.S)[0]
names=['madara','genin','masked','heavy','caster-fire','caster-water','caster-earth','elite']
descriptions=blocks[1:5]+[blocks[5].replace('<ELEMENT>',e)for e in ['orange fire','blue water','brown earth and stone']]+[blocks[6]]
recaps=['Uchiha Madara in crimson segmented armour with long spiky black hair and a white-and-red war fan','a young ninja in an olive flak vest with a plain metal headband and kunai','a masked ninja in dark grey armour with two kunai','a broad heavy ninja in brown armour carrying a wooden war hammer','a dark-red-coated ninja caster with orange-red fire chakra around sealed hands','a blue-coated ninja caster with light-blue water chakra around sealed hands','a brown-coated ninja caster with yellow-brown earth chakra around sealed hands','an elite ninja commander in a white hooded cloak with red trim over dark armour']
specs={}
for i,name in enumerate(names):
 extra='The above pixel-art styling and the NEW slightly overhead 20-degree camera and compact four-head proportions govern this design. No smooth anime line-art illustration or vector-painted treatment. Forehead protectors have completely plain unmarked metal plates, no village emblem or symbol. Full body and all weapons inside the image with safe padding.'
 if name.startswith('caster-'):
  coat,glow={'caster-fire':('dark red','orange-red'),'caster-water':('blue','light blue'),'caster-earth':('brown','yellow-brown')}[name]
  extra+=f' The sleeveless short coat is {coat}, with {glow} chakra closely around the hands. Use one consistent compact lean adult body build and the same costume cut for all three elemental casters; distinguish them by coat colour and hand chakra only.'
 specs[name]={'identity':descriptions[i]+'\n\n'+common,'recap':recaps[i],'class':'hero'if name=='madara'else'mob','key':'green'if name in ['madara','caster-fire','caster-earth']else'magenta','takes':2,'facing':'right','view':'front three-quarter view from slightly above (about 20 degrees), body and face turned toward the lower-right','extra':extra}
prop_extra='For this object image, the shared style describes pixel shading, palette, outlines and camera only: ignore its humanoid proportions, head count, standing pose and feet clauses. Do not draw any person or creature. Draw only the requested object(s), completely contained with safe margins, no ground plate or cast shadow. No smooth vector or anime illustration. The flat magenta outside the objects is the chroma-key backdrop.'
specs['chakra']={'identity':'One pickup comparison group containing exactly FOUR separate glowing swirling chakra-flame energy orbs arranged in one horizontal row with clear empty spacing. From LEFT to RIGHT strictly: a SMALL BLUE orb, a larger GREEN orb, a larger PURPLE orb, and a LARGE GOLD orb. Sizes increase progressively in that exact order. Each has a bright luminous core and pixel-shaded swirling chakra flames, with its own complete isolated silhouette and no connecting beam, pedestal, character or label. Purple is deep blue-violet rather than pink; keep it distinct from the magenta key background.\n\n'+common,'recap':'four separate blue, green, purple and gold chakra pickup orbs increasing in size from left to right','class':'prop','key':'magenta','takes':1,'facing':'none','view':'front three-quarter view from slightly above (about 20 degrees)','extra':prop_extra+' This is intentionally one group of FOUR objects; retain all four separated orbs and generous gaps, not a single merged subject.'}
for name,desc in [('hoodoo','a tall slender wind-eroded sandstone hoodoo rock pillar, layered strata and a broader caprock at the top, warm desert sandstone colours'),('boulder','one large rounded sandstone boulder, weathered warm desert stone with detailed pixel-shaded facets and subtle strata'),('shrub','one dry desert shrub or tumbleweed, an isolated tangled cluster of dry golden-brown branching twigs, no soil patch, no pot')]:
 specs['props/'+name]={'identity':desc+'\n\n'+common,'recap':desc,'class':'prop','key':'magenta','takes':1,'facing':'none','view':'front three-quarter view from slightly above (about 20 degrees)','extra':prop_extra}
(ROOT/'inputs/specifications.json').write_text(json.dumps(specs,indent=2)+'\n')
for name,spec in specs.items():(ROOT/'inputs'/(name.replace('/','-')+'.txt')).write_text(spec['identity']+'\n')

def generate(name):
 spec=specs[name];out=ROOT/name;out.parent.mkdir(parents=True,exist_ok=True)
 if out.exists():return {'name':name,'status':'blocked','error':'output already exists, no reroll'}
 cmd=[PYTHON,MASTER,'generate','--name','pixel-'+name.replace('/','-'),'--subject',spec['recap'],'--identity-file',str(ROOT/'inputs'/(name.replace('/','-')+'.txt')),'--recap',spec['recap'],'--extra',spec['extra'],'--finish','pixel','--facing',spec['facing'],'--view',spec['view'],'--class',spec['class'],'--key',spec['key'],'--takes',str(spec['takes']),'--route','codex-cli','--output-dir',str(out)]
 ref=ROOT/'inputs/caster-body-reference.png'
 if name in ['caster-water','caster-earth']and ref.exists():cmd+=['--identity-ref',str(ref),'--identity-ref-what','the new PIXEL fire-caster body and costume-cut reference, not any previous HD illustration','--identity-copy','body proportions, pixel-art style, face, hair, costume cut and hand-seal pose; use the new element and coat colour from this prompt instead of the fire palette']
 (ROOT/'inputs'/(name.replace('/','-')+'-command.json')).write_text(json.dumps(cmd,indent=2)+'\n')
 print('START '+name,flush=True)
 with(ROOT/'inputs'/(name.replace('/','-')+'-generation.log')).open('w')as log:p=subprocess.run(cmd,cwd='/Users/peter/repo/agent-sprite-forge',stdout=log,stderr=subprocess.STDOUT)
 rec={'name':name,'exit_code':p.returncode,'requested':spec['takes']};run=out/'run.json'
 if run.exists():
  d=json.loads(run.read_text());rec.update(status=d.get('status'),takes=[v.get('status')for v in d.get('takes',[])],errors=[v.get('error')for v in d.get('takes',[])if v.get('error')])
 print('FINISH '+json.dumps(rec),flush=True);return rec

if __name__=='__main__':
 selected=sys.argv[1:];assert selected and len(set(selected))==len(selected)
 queue=iter(selected);results=[];stopped=False
 with ThreadPoolExecutor(max_workers=2)as pool:
  active={pool.submit(generate,n):n for n in [next(queue,None),next(queue,None)]if n}
  while active:
   done,_=wait(active,return_when=FIRST_COMPLETED)
   for f in done:
    active.pop(f);rec=f.result();results.append(rec)
    if rec.get('status')!='ok':stopped=True
   if not stopped:
    while len(active)<2:
     n=next(queue,None)
     if n is None:break
     active[pool.submit(generate,n)]=n
 suffix=str(int(time.time()));(ROOT/'inputs'/('generation-results-'+suffix+'.json')).write_text(json.dumps({'stopped':stopped,'results':results},indent=2)+'\n')
 sys.exit(1 if stopped else 0)
