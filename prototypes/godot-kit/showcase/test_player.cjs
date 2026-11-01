const {test}=require('node:test');const assert=require('node:assert/strict');
const {SpritePlayer}=require('./player.js');
test('one shot ends at final frame and restarts from beginning',()=>{const p=new SpritePlayer(18,15,false);p.play();p.tick(2);assert.equal(p.frame,17);assert.equal(p.playing,false);p.play();assert.equal(p.frame,0)});
test('loop wraps and remains playing',()=>{const p=new SpritePlayer(16,12,true);p.play();p.tick(3);assert.equal(p.frame,4);assert.equal(p.playing,true)});
test('paused clock and seek keep exact frame',()=>{const p=new SpritePlayer(12,18,false);p.seek(8);p.tick(20);assert.equal(p.frame,8);p.seek(99);assert.equal(p.frame,11)});
test('frame advances by elapsed time with a fractional remainder',()=>{const p=new SpritePlayer(24,12,true);p.play();p.tick(.04);assert.equal(p.frame,0);p.tick(.06);assert.equal(p.frame,1);p.tick(.0666666666666667);assert.equal(p.frame,2)});
test('invalid delta does not corrupt animation',()=>{const p=new SpritePlayer(24,12,true);p.play();p.tick(NaN);p.tick(-1);assert.equal(p.frame,0);p.tick(1);assert.equal(p.frame,12)});
test('fps controls playback without changing source frame count',()=>{const p=new SpritePlayer(24,12,true);p.fps=24;p.play();p.tick(.5);assert.equal(p.frame,12);assert.equal(p.count,24)});
test('one shot displays the final frame for its full duration',()=>{const p=new SpritePlayer(18,15,false);p.play();p.tick(17/15);assert.equal(p.frame,17);assert.equal(p.playing,true);p.tick(1/15);assert.equal(p.playing,false)});
