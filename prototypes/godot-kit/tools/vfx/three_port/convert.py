#!/usr/bin/env python3
"""Translate extracted GLSL and pack real source geometry; authoring tool, no JS at runtime."""
import json,re,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
DEST=ROOT/'addons/proto_kit/vfx/3d/00gamedevs/ported'
TYPES=r'(?:void|float|int|uint|bool|[biu]?vec[234]|mat[234])'

def matching(text,start,opening='(',closing=')'):
    depth=0
    for index in range(start,len(text)):
        if text[index]==opening:depth+=1
        if text[index]==closing:
            depth-=1
            if not depth:return index
    raise ValueError('Unclosed delimiter')

def split_args(text):
    depth=0;last=0;parts=[]
    for i,c in enumerate(text):
        if c in '([':depth+=1
        elif c in ')]':depth-=1
        elif c==',' and depth==0:parts.append(text[last:i].strip());last=i+1
    parts.append(text[last:].strip());return parts

def matrices(text):
    for kind,n in [('mat2',2),('mat3',3),('mat4',4)]:
        index=0
        while (m:=re.search(r'\b'+kind+r'\s*\(',text[index:])):
            start=index+m.start();op=text.index('(',start);end=matching(text,op)
            args=split_args(text[op+1:end])
            if len(args)==n*n:
                replacement=kind+'('+','.join('vec'+str(n)+'('+','.join(args[i:i+n])+')' for i in range(0,n*n,n))+')'
                text=text[:start]+replacement+text[end+1:];index=start+len(replacement)
            else:index=op+1
    return text

def declarations(text,keyword):
    results={}
    def remove(m):
        for item in split_args(m[2]):
            name=re.match(r'(\w+)(\[[^\]]+\])?',item)
            assert name,(keyword,item)
            results[name[1]]=(m[1],name[2] or '')
        return ''
    text=re.sub(r'\b'+keyword+r'\s+(\w+)\s+([^;]+);',remove,text)
    return text,results

def stage(text,stage_name,bindings):
    text=re.sub(r'/\*.*?\*/|//[^\n]*','',text,flags=re.S)
    text=re.sub(r'#include\s+<[^>]+>','',text)
    text=text.replace('gl_FrontFacing','source_front_facing').replace('texture2D(', 'texture(')
    text=re.sub(r'\bTAU\b',stage_name+'_TAU',text)
    text=re.sub(r'\bPI\b','SRC_PI',text)
    constants=set()
    for declaration in re.finditer(r'\bconst\s+'+TYPES+r'\s+([^;]+);',text):
        for item in split_args(declaration[1]):
            if m:=re.match(r'(\w+)',item):constants.add(m[1])
    for name in sorted(constants,key=len,reverse=True):
        text=re.sub(r'\b'+name+r'\b',stage_name+'_constant_'+name,text)
    text=matrices(text)
    text,uniforms=declarations(text,'uniform')
    text,varyings=declarations(text,'varying')
    text,attrs=declarations(text,'attribute')
    states={**attrs,**varyings}
    if stage_name=='vs':
        states.update({n:(t,'') for n,t in [('position','vec3'),('normal','vec3'),('uv','vec2'),('modelMatrix','mat4'),('viewMatrix','mat4'),('modelViewMatrix','mat4'),('projectionMatrix','mat4'),('normalMatrix','mat3'),('cameraPosition','vec3'),('uClipToGroup','mat4'),('uGroupToClip','mat4'),('gl_Position','vec4'),('isOrthographic','bool')]})
        uniforms.pop('uClipToGroup',None);uniforms.pop('uGroupToClip',None)
    else:
        states.update({n:(t,'') for n,t in [('gl_FragColor','vec4'),('gl_FragCoord','vec4'),('viewMatrix','mat4'),('cameraPosition','vec3'),('source_front_facing','bool'),('isOrthographic','bool')]})
    functions=[]
    pattern=re.compile(r'\b('+TYPES+r')\s+(\w+)\s*\(([^{};]*)\)\s*\{')
    pos=0
    while m:=pattern.search(text,pos):
        end=matching(text,m.end()-1,'{','}')+1
        functions.append(dict(start=m.start(),end=end,type=m[1],name=m[2],args=m[3],body=text[m.end():end-1]))
        pos=end
    names={f['name'] for f in functions}
    dependencies={name:set() for name in names}
    calls={name:set() for name in names}
    for f in functions:
        own_params=set(re.findall(r'\b\w+\s+(\w+)\s*(?:,|$)',f['args']))
        own_params.update(re.findall(r'\b'+TYPES+r'\s+(\w+)\s*(?:=|;|,)',f['body']))
        dependencies[f['name']]|={n for n in states if n not in own_params and re.search(r'\b'+n+r'\b',f['body'])}
        calls[f['name']]|={n for n in names if re.search(r'\b'+n+r'\s*\(',f['body'])}
    for _ in range(len(names)+1):
        changed=False
        for name in names:
            new=dependencies[name]|set().union(*(dependencies[n] for n in calls[name]))
            if new!=dependencies[name]:dependencies[name]=new;changed=True
        if not changed:break
    def rewrite_calls(body):
        # Apply from right to left, preserving nested expressions and argument positions.
        matches=list(re.finditer(r'\b('+'|'.join(map(re.escape,names))+r')\s*\(',body))
        for m in reversed(matches):
            op=body.index('(',m.start());end=matching(body,op)
            extra=', '.join(sorted(dependencies[m[1]]))
            insert=(', ' if body[op+1:end].strip() else '')+extra if extra else ''
            body=body[:end]+insert+body[end:]
            body=body[:m.start()]+stage_name+'_'+m[1]+body[m.start()+len(m[1]):]
        return body
    for f in reversed(functions):
        extras=', '.join('inout '+states[n][0]+' '+n+states[n][1] for n in sorted(dependencies[f['name']]))
        args=f['args']+(', ' if f['args'].strip() and extras else '')+extras
        body=rewrite_calls(f['body'])
        replacement=f['type']+' '+stage_name+'_'+f['name']+'('+args+'){'+body+'}'
        text=text[:f['start']]+replacement+text[f['end']:]
    # Global private helper names and source output variables are ordinary function parameters.
    # Matrix builtins are only read in the actual Godot entry point.
    globals_='\n'.join('varying '+t+' bridge_'+n+a+';' for n,(t,a) in varyings.items())
    init=[]
    for n in sorted(dependencies['main']):
        t,a=states[n]
        assert not a,('Varying/attribute array needs explicit handling',n,a)
        if n in varyings:expr=t+'(0)' if stage_name=='vs' else 'bridge_'+n
        elif n in bindings:expr=bindings[n]
        elif n in ['position','normal','uv']:expr={'position':'VERTEX','normal':'NORMAL','uv':'UV'}[n]
        elif n=='modelMatrix':expr='MODEL_MATRIX'
        elif n=='viewMatrix':expr='VIEW_MATRIX'
        elif n=='modelViewMatrix':expr='MODELVIEW_MATRIX'
        elif n=='projectionMatrix':expr='PROJECTION_MATRIX'
        elif n=='normalMatrix':expr='MODELVIEW_NORMAL_MATRIX'
        elif n=='cameraPosition':expr='INV_VIEW_MATRIX[3].xyz'
        elif n=='isOrthographic':expr='PROJECTION_MATRIX[3][3] > 0.5'
        elif n=='source_front_facing':expr='FRONT_FACING'
        elif n=='gl_FragCoord':expr='FRAGCOORD'
        elif n=='uGroupToClip':expr='PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * inverse(source_to_group)'
        elif n=='uClipToGroup':expr='inverse(PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * inverse(source_to_group))'
        else:expr=t+'(0)'
        init.append(t+' '+n+' = '+expr+';')
    call=stage_name+'_main('+', '.join(sorted(dependencies['main']))+');'
    if stage_name=='vs':
        init += [t+' '+n+' = '+t+'(0);' for n,(t,a) in varyings.items() if n not in dependencies['main']]
        init+=['source_draw = float(VERTEX_ID % source_vertices_per_instance);', 'source_instance = float(VERTEX_ID / source_vertices_per_instance);',call]+['bridge_'+n+' = '+n+';' for n in varyings]+['POSITION = gl_Position;']
    else:
        init=['if(source_instance >= source_instance_count || source_draw < source_draw_start || (source_draw_count >= 0.0 && source_draw >= source_draw_start + source_draw_count)) discard;']+init
        init+=[call,'ALBEDO = gl_FragColor.rgb; ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);']
    return globals_,text,'void '+('vertex' if stage_name=='vs' else 'fragment')+'(){\n'+'\n'.join(init)+'\n}',uniforms

def convert_shader(m,bindings):
    mat=m['material']
    vs=stage(mat['vertex'],'vs',bindings);fs=stage(mat['fragment'],'fs',bindings)
    uniforms={**vs[3],**fs[3]}
    prefix='// 00GameDevs MIT, 2026 @00vchannel; native Godot port of original GLSL.\n// Authoring source: tools/vfx/three_port; Compatibility spatial, no fragment texture loops.\nshader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, '
    custom_add=mat['blending']==5 and mat.get('blendSrc')==201 and mat.get('blendDst')==201
    custom_premul=mat['blending']==5 and mat.get('blendSrc')==201 and mat.get('blendDst')==205
    prefix+='blend_add' if mat['blending']==2 or custom_add else ('blend_premul_alpha' if custom_premul else 'blend_mix')
    if mat['side']==0:
        prefix=prefix.replace('cull_disabled','cull_back')
    prefix+=';\nuniform mat4 source_to_group;\nuniform float source_draw_start = 0.0;\nuniform float source_draw_count = -1.0;\nuniform int source_vertices_per_instance = 1;\nuniform float source_instance_count = 1.0;\nvarying flat float source_draw;\nvarying flat float source_instance;\n'
    for k,v in mat['defines'].items():prefix+='#define '+k+' '+str(v)+'\n'
    # Source sampler uniforms are Three transmission captures: map to Godot screen capture.
    for name,(t,a) in uniforms.items():
        if t=='sampler2D':prefix+='uniform sampler2D '+name+' : hint_screen_texture, repeat_disable, filter_linear_mipmap;\n'
        else:prefix+='uniform '+t+' '+name+a+';\n'
    varyings={}
    for glob in [vs[0],fs[0]]:
        for line in glob.splitlines():varyings[line]=True
    prefix+='\n'.join(varyings)+'\n'
    if custom_add or mat['blending']==0:
        fs=(fs[0],fs[1],fs[2].replace('ALPHA = clamp(gl_FragColor.a, 0.0, 1.0);','ALPHA = 1.0;'),fs[3])
    shader=prefix+vs[1]+'\n'+fs[1]+'\n'+vs[2]+'\n'+fs[2]+'\n'
    # Duplicate macro definitions from vertex and fragment shared libraries are redundant.
    seen=set();lines=[]
    for line in shader.splitlines():
        if line.strip().startswith('#define'):
            if line.strip() in seen:continue
            seen.add(line.strip())
        lines.append(line)
    return '\n'.join(lines)+'\n'

def main():
    source=Path(sys.argv[1]);dest=Path(sys.argv[2]) if len(sys.argv)>2 else DEST
    dest.mkdir(parents=True,exist_ok=True)
    for file in sorted(source.glob('*.json')):
        if file.name=='stats.json':continue
        data=json.loads(file.read_text());out=dest/data['id'];out.mkdir(exist_ok=True)
        for m in data['meshes']:
            extra={k:v for k,v in m['attributes'].items() if k not in ['position','normal','uv']}
            # CUSTOM0..3 carry 16 exact floats; UV2 carries the remaining two.
            # COLOR is not used: GPU vertex colour packing would clamp source data.
            cursor=0;bindings={};layout={}
            for key,attr in extra.items():
                size=attr['size'];assert cursor+size<=18,(data['id'],m['name'],list(extra))
                components=[]
                for offset in range(cursor,cursor+size):
                    components.append(('UV2.'+'xy'[offset-16]) if offset>=16 else ('CUSTOM'+str(offset//4)+'.'+'xyzw'[offset%4]))
                bindings[key]=components[0] if size==1 else 'vec'+str(size)+'('+','.join(components)+')'
                layout[key]=cursor;cursor+=size
            m['layout']=layout;m['channels']=min(4,(cursor+3)//4)
            m['extra_floats']=18 if cursor>16 else m['channels']*4
            m['has_uv2']=cursor>16
            indices=m['indices'] or list(range(len(m['attributes']['position']['array'])//3))
            # Godot front faces are clockwise; reverse each source CCW triangle.
            indices=[indices[i+j]for i in range(0,len(indices),3)for j in (0,2,1)]
            # Flatten triangles so VERTEX_ID can implement source draw ranges exactly.
            stride=8+m['extra_floats'];buf=bytearray()
            for instance in range(m['instances']):
                for index in indices:
                    attrs=m['attributes'];values=[]
                    for key,size,default in [('position',3,[0,0,0]),('normal',3,[0,1,0]),('uv',2,[0,0])]:
                        a=attrs.get(key);values.extend(a['array'][index*size:index*size+size] if a else default)
                    packed=[0.]*m['extra_floats']
                    for key,offset in layout.items():
                        a=extra[key];i=instance if a['instanced'] else index;values_=a['array'][i*a['size']:(i+1)*a['size']]
                        packed[offset:offset+a['size']]=values_
                    values+=packed
                    buf.extend(struct.pack('<'+'f'*stride,*values))
            (out/(str(m['index'])+'.bin')).write_bytes(buf)
            m['vertex_count']=len(indices)*m['instances'];m['vertices_per_instance']=len(indices)
            (out/('spatial_part_'+str(m['index'])+'.gdshader')).write_text(convert_shader(m,bindings))
            del m['attributes'];del m['indices']
        (out/'data.json').write_text(json.dumps(data,separators=(',',':')))
        print(data['id'],len(data['meshes']),'native shaders / geometry packed')

if __name__=='__main__':main()
