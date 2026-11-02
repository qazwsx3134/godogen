// Plays the web build in a real Chrome and checks the song clock the game judges against.
//   node tools/web_clock_probe.mjs --playwright <playwright-core dir> --chromium <chrome binary> [--url http://127.0.0.1:8796/] [--seconds 8] [--dump log.json] [--shot game.png]
// Serve build/web first (python3 -m http.server 8796 --directory build/web). Opens ?qa=1, clicks Start (which also
// unlocks audio), taps through the opening and round-1 lines, then samples window.__dangoLog ([wall, audio] per frame) in minigame 1.
// Reports whether the audio position advances, how it compares with the wall clock, and how much it jitters.
import { createRequire } from "node:module";

const arg = (name, fallback) => {
	const i = process.argv.indexOf(`--${name}`);
	return i >= 0 ? process.argv[i + 1] : fallback;
};
const require = createRequire(import.meta.url);
const { chromium } = require(arg("playwright"));
const url = arg("url", "http://127.0.0.1:8796/") + "?qa=1";
const seconds = Number(arg("seconds", "8"));

const browser = await chromium.launch({ executablePath: arg("chromium"), headless: true, args: ["--autoplay-policy=user-gesture-required"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
page.on("pageerror", (e) => errors.push(String(e)));
await page.goto(url);
await page.waitForFunction(() => window.__dango && window.__dango.screen === "Title", null, { timeout: 60000 });
const canvas = await page.$("canvas");
const box = await canvas.boundingBox();
// Start sits a little below the middle of the title column.
await page.mouse.click(box.x + box.width / 2, box.y + box.height * 0.555);
// Tap through the referee's opening and the round's lines until a round is on screen.
const ROUNDS = ["ThreeEat", "TossGame"];
for (let i = 0; i < 60; i++) {
	const s = await page.evaluate(() => window.__dango.screen);
	if (ROUNDS.includes(s)) break;
	await page.mouse.click(box.x + box.width / 2, box.y + box.height * 0.3);
	await page.waitForTimeout(120);
}
await page.waitForFunction((r) => r.includes(window.__dango.screen), ROUNDS, { timeout: 10000 });
await page.waitForTimeout(seconds * 1000);
if (arg("shot")) await page.screenshot({ path: arg("shot") });
const log = await page.evaluate(() => window.__dangoLog || []);
const state = await page.evaluate(() => window.__dango);
await browser.close();

// Web "Sample" playback starts late (the WAV is first uploaded to Web Audio): until then the position sits at 0.
// Measure from the first frame where the song has clearly started.
const startAt = log.findIndex(([, a]) => a > 0.1);
const playing = startAt < 0 ? [] : log.slice(startAt);
// Conductor.time() never goes backwards (it keeps the max), so a small step back only holds the clock for a frame.
let backwards = 0, maxBack = 0;
for (let i = 1; i < playing.length; i++) {
	const back = playing[i - 1][1] - playing[i][1];
	if (back > 1e-6) { backwards++; maxBack = Math.max(maxBack, back); }
}
const diffs = playing.map(([w, a]) => w - a);
const mean = diffs.reduce((s, d) => s + d, 0) / Math.max(1, diffs.length);
const sd = Math.sqrt(diffs.reduce((s, d) => s + (d - mean) ** 2, 0) / Math.max(1, diffs.length));
const first = playing[0], last = playing[playing.length - 1];
const rate = playing.length > 1 ? (last[1] - first[1]) / (last[0] - first[0]) : 0;
let maxStep = 0;
for (let i = 1; i < playing.length; i++) maxStep = Math.max(maxStep, Math.abs(diffs[i] - diffs[i - 1]));
const report = {
	frames: log.length, playing_frames: playing.length, start_delay_s: Number(mean.toFixed(3)),
	audio_backwards_steps: backwards, max_backwards_ms: Number((maxBack * 1000).toFixed(1)), audio_rate_vs_wall: Number(rate.toFixed(4)),
	jitter_sd_ms: Number((sd * 1000).toFixed(2)), max_frame_jump_ms: Number((maxStep * 1000).toFixed(1)),
	last_state: state, errors,
};
console.log(JSON.stringify(report, null, 1));
if (arg("dump")) (await import("node:fs")).writeFileSync(arg("dump"), JSON.stringify(log));
const ok = playing.length > seconds * 20 && maxBack < 0.03 && Math.abs(rate - 1) < 0.01 && sd < 0.01 && maxStep < 0.04 && errors.length === 0;
console.log(ok ? "WEB CLOCK PROBE PASSED" : "WEB CLOCK PROBE FAILED");
process.exit(ok ? 0 : 1);
