extends RefCounted
## The phone's vibration motor, behind rules that keep a room full of events from turning into a hum.
## `const Haptics = preload("res://addons/proto_kit/haptics.gd")`
##
## A tier is an index into `durations_ms` and `amplitudes` (0 = the lightest buzz; three tiers by default).
##   var haptics := Haptics.new()
##   haptics.enabled = saved.haptics                 # the player's switch
##   haptics.buzz(0)                                 # a tick for a small event
##   haptics.buzz(2)                                 # a thump for a big one
##   haptics.vibrated.connect(func(ms: int, strength: float) -> void: print("buzz ", ms, " ms at ", strength))
##   if not haptics.supported():                     # no motor here: hide the settings switch (buzz() is harmless anyway)
##       switch_row.hide()
##   haptics.clock = func() -> int: return game_ms   # headless tests and bots: the rules follow game time, not the wall clock
##
## Rules (all in buzz()):
##  1. `enabled` off, or `scale` 0: nothing at all.
##  2. Buzzes are `min_gap_ms` apart, and at most `max_per_second` in any one second.
##  3. A weaker buzz never cuts off a stronger one that is still running (a new buzz replaces the running
##     one on the phone).
## A bigger tier than the last buzz passes rule 2 (a boss killed by a crit: small, then large in the same
## frame; the large must not be swallowed).
##
## Why the web check asks for a touch screen: navigator.vibrate exists on a desktop browser too (a function in
## Chromium with no touch screen: measured with godot-kit/tools/web/web_probe.mjs), so asking only for the
## function would make a desktop think it can buzz. iPhone Safari has no vibrate at all. Godot's web side logs a
## warning on every call that cannot work, which is why supported() is checked before the motor is asked.

## One buzz of the phone's motor went out (any device: it is sent when the rules let the buzz through,
## whether or not this device has a motor).
signal vibrated(duration_ms: int, amplitude: float)

## The player's switch. Off = the phone never buzzes.
var enabled: bool = true
## Scales how long every buzz runs. 0 = no buzzing at all.
var scale: float = 1.0
## Two buzzes are at least this many ms apart. A bigger tier than the last one cuts through (see buzz()).
var min_gap_ms: int = 70
## At most this many buzzes in any one second, so a room full of kills does not hum. A bigger tier than the last one cuts through.
var max_per_second: int = 6
## One buzz per tier: how long it runs (ms) and how hard (0..1; only Android uses the strength).
## Under about 10 ms most phones feel nothing; over about 150 ms it is a hum, not a hit.
var durations_ms: PackedInt32Array = PackedInt32Array([14, 38, 90])
## 64-bit on purpose: a PackedFloat32Array hands 0.35 back as 0.3499999940395355, so `vibrated` would stop reporting what was set.
var amplitudes: PackedFloat64Array = PackedFloat64Array([0.35, 0.65, 1.0])
## Milliseconds for the rules. Empty = the wall clock: the motor runs in real time, not in game
## time. Tests and bots set one that follows game time; setting it forgets earlier buzzes.
var clock: Callable:
	set(value):
		clock = value
		_last_buzz_ms = -1000000
		_last_tier = -1
		_buzz_until_ms = 0
		_recent_buzzes.clear()

var _supported: int = -1         # supported(), asked once: -1 not yet, 0 no, 1 yes
var _last_buzz_ms: int = -1000000
var _last_tier: int = -1         # the tier of the last buzz that went out
var _buzz_until_ms: int = 0      # when that buzz ends
var _recent_buzzes: Array[int] = []   # when the buzzes of the last second went out

## Web: only a touch device whose browser has navigator.vibrate (see the top of this file).
const WEB_HAPTICS_PROBE: String = "typeof navigator.vibrate === 'function' && (navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches)"

## Milliseconds on the clock the rules use: `clock` if one is set, else the wall clock.
func now_ms() -> int:
	return clock.call() if clock.is_valid() else Time.get_ticks_msec()

## Whether this device can buzz, asked once. Android and iOS: yes. Web: only a touch device whose browser has
## navigator.vibrate (Android Chrome and Firefox). That is checked here because Godot's web side logs a
## warning on every call that cannot work. Desktop: no.
func supported() -> bool:
	if _supported < 0:
		if OS.has_feature("web"):
			_supported = 1 if bool(JavaScriptBridge.eval(WEB_HAPTICS_PROBE, true)) else 0
		else:
			_supported = 1 if OS.has_feature("android") or OS.has_feature("ios") else 0
	return _supported == 1

## One buzz at this tier, if the rules let it through. They are all here:
##  1. `enabled` off, or `scale` 0: nothing at all.
##  2. Buzzes are `min_gap_ms` apart, and at most `max_per_second` in any second.
##  3. A weaker buzz never cuts off a stronger one that is still running (a new buzz replaces the
##     running one on the phone).
## A bigger buzz than the last one passes rule 2 (a boss killed by a crit: small, then large in the same
## frame; the large must not be swallowed).
## `vibrated` is sent for every buzz that passes, on any device; the motor is only asked on a device that has one.
## ponytail: `tier` is not range-checked; one past the arrays is a script error, which says "the config is short" loudly enough.
func buzz(tier: int) -> void:
	if not enabled or scale <= 0.0:
		return
	var now: int = now_ms()
	var bigger: bool = tier > _last_tier
	if not bigger and now - _last_buzz_ms < min_gap_ms:
		return
	if now < _buzz_until_ms and tier < _last_tier:
		return
	while not _recent_buzzes.is_empty() and now - _recent_buzzes[0] >= 1000:
		_recent_buzzes.pop_front()
	if not bigger and _recent_buzzes.size() >= max_per_second:
		return
	var duration: int = maxi(1, roundi(durations_ms[tier] * scale))
	var amplitude: float = amplitudes[tier]
	_last_buzz_ms = now
	_last_tier = tier
	_buzz_until_ms = now + duration
	_recent_buzzes.append(now)
	vibrated.emit(duration, amplitude)
	if supported():
		Input.vibrate_handheld(duration, -1.0 if OS.has_feature("web") else amplitude)   # the web ignores the strength
