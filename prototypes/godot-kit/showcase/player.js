/* Animation clock shared by the preview and Node tests. No DOM or dependencies. */
class SpritePlayer {
  constructor(count, fps, loop) { this.count=count; this.fps=fps; this.loop=loop; this.frame=0; this.playing=false; this.accumulator=0; }
  seek(frame) { this.frame=Math.min(this.count-1,Math.max(0,Math.floor(frame))); this.accumulator=0; }
  play() { if(this.frame===this.count-1&&!this.loop)this.seek(0); this.playing=true; }
  tick(seconds) {
    if(!this.playing||!Number.isFinite(seconds)||seconds<0)return;
    this.accumulator+=seconds*this.fps;
    const steps=Math.floor(this.accumulator+1e-9); this.accumulator-=steps;
    if(this.loop)this.frame=(this.frame+steps)%this.count;
    else { const next=this.frame+steps; this.frame=Math.min(next,this.count-1); if(next>=this.count)this.playing=false; }
  }
}
if(typeof module!=='undefined')module.exports={SpritePlayer};
