// Authoring only: execute reviewed user exports against offline Three.js, never shipped in games.
import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import {pathToFileURL} from 'node:url';
import * as T from 'three';
const input=process.argv[2],output=process.argv[3];
fs.mkdirSync(output,{recursive:true});
const serialize=value=>{
 if(typeof value==='number')return Number.isFinite(value)?value:0;
 if(typeof value==='boolean'||value==null||typeof value==='string')return value;
 if(value.isColor)return {type:'color',value:[value.r,value.g,value.b,1]};
 if(value.isVector2||value.isVector3||value.isVector4||value.isMatrix3||value.isMatrix4||value.isQuaternion)return {type:value.constructor.name,value:value.toArray()};
 if(Array.isArray(value)||ArrayBuffer.isView(value))return Array.from(value,serialize);
 if(value.isTexture)throw new Error('External texture needs explicit port: '+value.name);
 throw new Error('Unknown uniform '+value?.constructor?.name);
};
const ids=fs.readdirSync(input).filter(x=>x.endsWith('.js')&&!x.startsWith('spell-indicator')&&!['impact-frame.js','weapon-smear.js'].includes(x));
const stats=[];
for(const name of ids){
 let seed=13579;const random=Math.random;Math.random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 try{
  const text=fs.readFileSync(path.join(input,name),'utf8');const preset=JSON.parse(text.match(/const preset = (\{[\s\S]*?\n\});/)[1]);
  const stage=fs.mkdtempSync(path.join(os.tmpdir(),'vfx-source-module-'));
  let module;try{
   const staged=path.join(stage,name+'.mjs');
   fs.writeFileSync(staged,text.replace(/from\s+(['"])three\1/g,"from '"+import.meta.resolve('three')+"'"));
   module=await import(pathToFileURL(staged));
  }finally{fs.rmSync(stage,{recursive:true,force:true})}const api=module.default();
  const camera=new T.PerspectiveCamera(50,1.5,.1,100);camera.position.set(0,4,8);camera.lookAt(0,0,0);camera.updateMatrixWorld();
  const renderer={info:{render:{frame:0}}};const objects=[];api.group.traverse(o=>{if(o.isMesh)objects.push(o)});
  function sync(){api.group.updateMatrixWorld(true);renderer.info.render.frame++;for(const o of objects)o.onBeforeRender(renderer,null,camera,o.geometry,o.material,null)}
  sync();
  const meshes=objects.map((o,index)=>{
   const g=o.geometry,m=o.material;const attributes={};
   for(const [key,attr]of Object.entries(g.attributes))attributes[key]={size:attr.itemSize,instanced:!!attr.isInstancedBufferAttribute,array:Array.from(attr.array)};
   return {index,name:o.name||`Part${index}`,attributes,indices:g.index?Array.from(g.index.array):null,
    instances:g.isInstancedBufferGeometry?Math.min(g.instanceCount,Math.min(...Object.values(g.attributes).filter(a=>a.isInstancedBufferAttribute).map(a=>a.count))):1,
    material:{type:m.type,vertex:m.vertexShader||null,fragment:m.fragmentShader||null,defines:m.defines||{},blending:m.blending,blendSrc:m.blendSrc,blendDst:m.blendDst,renderOrder:o.renderOrder,transparent:m.transparent,depthWrite:m.depthWrite,side:m.side,vertexColors:m.vertexColors,color:m.color?serialize(m.color):null,opacity:m.opacity},
    geometryType:g.type};
  });
  function snapshot(){sync();return objects.map(o=>{
   const relative=api.group.matrixWorld.clone().invert().multiply(o.matrixWorld);const m=o.material,g=o.geometry;
   const uniforms={};for(const[key,u]of Object.entries(m.uniforms||{})){
    if(!['uClipToGroup','uGroupToClip'].includes(key))uniforms[key]=serialize(u.value);
   }
   return {matrix:relative.toArray(),visible:o.visible,drawStart:g.drawRange.start,drawCount:Number.isFinite(g.drawRange.count)?g.drawRange.count:-1,
    instances:g.isInstancedBufferGeometry?g.instanceCount:1,uniforms,opacity:m.opacity,depthWrite:m.depthWrite,transparent:m.transparent};
  })}
  const duration=preset.duration, fps=30, samples=[];
  for(let frame=0;frame<=Math.ceil(duration*fps);frame++){if(frame)api.update(1/fps);samples.push(snapshot())}
  const ending=[];if(!preset.burst){api.stop();for(let f=0;f<=Math.ceil(api.lifecycle.end*fps);f++){if(f)api.update(1/fps);ending.push(snapshot())}}
  const data={id:preset.id,preset,options:module.defaultOptions,lifecycle:api.lifecycle,fps,meshes,samples,ending};
  fs.writeFileSync(path.join(output,preset.id+'.json'),JSON.stringify(data));
  stats.push([preset.id,meshes.length,meshes.map(m=>Object.entries(m.attributes).filter(([k])=>!['position','normal','uv'].includes(k)).reduce((a,[k,v])=>a+v.size,0)),meshes.map(m=>m.material.type)]);
  console.log(preset.id,meshes.length,'meshes');api.dispose();
 }finally{Math.random=random}
}
fs.writeFileSync(path.join(output,'stats.json'),JSON.stringify(stats,null,2));
