extends SceneTree
## 三種機器人玩家跑同一章，給「不操作／隨便選／知道答案」一個數字基準（不進出貨，export 排除 tools/）。
## 只用 StoryRunner（不讀時鐘），所以一局只要幾毫秒。
##
##   Godot --headless --path . --script res://tools/bot_players.gd -- [--story <res://…json>] [--runs 1000]
##
## 策略：
##   idle     不操作：證言回合不按吐槽（不會前進）；連擊回合計時到就逾時
##   random   隨便選：每次挑一句還沒抓到的，有槽點就從還沒試過的選項隨機挑一個，沒槽點就空揮；
##            QTE 在 ±0.4 秒內隨機按
##   repeat   隨便選，但會重複選已經錯過的選項
##   weak     知道槽點在哪，但一律選 weak（安全牌），QTE 正中
##   know     知道答案：只按有槽點的句子，選 perfect（拿不到就 weak），QTE 正中
## 劇情分歧一律選第一個，Game Over 後從檢查點重試，最多 3 次。BOT_TRACE=1 會印出每一步。
## 輸出每種策略的評價分布、平均冷場、Game Over、卡住（回合不前進）的局數。

const Runner = preload("res://scripts/story_runner.gd")
const DEFAULT_STORY: String = "res://tests/fixtures/stories/chapter1_story.json"
const STRATEGIES: Array[String] = ["idle", "random", "repeat", "weak", "know"]
const MAX_RETRIES: int = 3
const MAX_STEPS: int = 3000


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var story: String = _arg(args, "--story", DEFAULT_STORY)
	var runs: int = int(_arg(args, "--runs", "1000"))
	print("story %s, %d runs per strategy" % [story, runs])
	for strategy: String in STRATEGIES:
		var tally: Dictionary = {"S": 0, "A": 0, "B": 0, "C": 0, "stuck": 0, "gave_up": 0}
		var fails: int = 0
		var game_overs: int = 0
		var perfect: int = 0
		var caught: int = 0
		for i: int in runs:
			var outcome: Dictionary = _play(story, strategy, i)
			tally[outcome["end"]] = int(tally[outcome["end"]]) + 1
			fails += int(outcome["fails"])
			game_overs += int(outcome["game_overs"])
			perfect += int(outcome["perfect"])
			caught += int(outcome["caught"])
		print("%-6s 評價 S %d／A %d／B %d／C %d・卡住 %d・放棄 %d｜每局冷場 %.2f・Game Over %.2f・perfect %d/%d" % [
			strategy, tally["S"], tally["A"], tally["B"], tally["C"], tally["stuck"], tally["gave_up"],
			float(fails) / runs, float(game_overs) / runs, perfect, caught])
	quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback


## One playthrough; end is a grade, "stuck" (the round cannot move on) or "gave_up" (too many Game Overs).
func _play(story: String, strategy: String, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var r: Runner = Runner.new()
	if not r.load_story(story):
		push_error("cannot load %s: %s" % [story, r.error_message])
		quit(1)
	var tried: Dictionary = {}  # "round:line" → option ids already chosen
	var retries: int = 0
	for _step: int in MAX_STEPS:
		if bool(r.snapshot().get("game_over_active", false)):
			retries += 1
			if retries > MAX_RETRIES or not r.retry_checkpoint():
				return _outcome(r, "gave_up")
			tried.clear()
			continue
		var c: Dictionary = r.current()
		if OS.get_environment("BOT_TRACE") == "1":
			print("%s %s %s %s" % [strategy, c.get("op", ""), c.get("node_id", ""), c.get("step_index", "")])
		match str(c.get("op", "")):
			"result":
				return _outcome(r, str(r.chapter_result().get("grade", "C")))
			"end":
				return _outcome(r, "C")
			"investigate":
				var spot: Variant = (c.get("hotspots", []) as Array).filter(func(h: Dictionary) -> bool: return not bool(h.get("checked", false)))
				if bool(c.get("complete", false)) or (spot as Array).is_empty():
					r.advance()
				else:
					# Character spots need that character on stage (the UI keeps the cast in sync)
					for h: Dictionary in c.get("hotspots", []):
						if h.has("character") and str(h["character"]) not in r.cast:
							r.cast.append(str(h["character"]))
					r.inspect_hotspot(str((spot as Array)[0]["id"]))
			"choice":
				var options: Array = c.get("options", []) as Array
				if options.is_empty() or not r.choose(str(options[0].get("id", ""))):
					r.advance()
			"boke_round":
				if not _round_move(r, c, strategy, rng, tried):
					return _outcome(r, "stuck")
			_:
				r.advance()
	return _outcome(r, "stuck")


## One move in a v2 round; false when this player would never move it on.
func _round_move(r: Runner, c: Dictionary, strategy: String, rng: RandomNumberGenerator, tried: Dictionary) -> bool:
	var lines: Array = c.get("lines", []) as Array
	var caught: Array = c.get("caught_line_ids", []) as Array
	var combo: bool = str(c.get("mode", "")) == "combo"
	if not combo:
		var open: Array[int] = []
		for i: int in lines.size():
			if str(lines[i].get("id", "")) in caught:
				continue
			if strategy in ["know", "weak"] and (lines[i].get("slot", {}) as Dictionary).is_empty():
				continue
			open.append(i)
		if strategy == "idle" or open.is_empty():
			return false
		r.set_boke_line(open[0] if strategy in ["know", "weak"] else open[rng.randi_range(0, open.size() - 1)])
		c = r.current()
	var line: Dictionary = c.get("current_line", {}) as Dictionary
	var raw: Dictionary = lines[int(c.get("line_index", 0))] as Dictionary
	var slot: Dictionary = raw.get("slot", {}) as Dictionary
	if strategy == "idle":
		return combo and not r.timeout_boke().is_empty()
	if not (line.get("qte", {}) as Dictionary).is_empty():
		var offset: float = 0.0 if strategy in ["know", "weak"] else rng.randf_range(-0.4, 0.4)
		return not r.resolve_qte(true, offset).is_empty()
	if not (line.get("censor", {}) as Dictionary).is_empty():
		return not r.resolve_censor().is_empty()
	if not (line.get("placard", {}) as Dictionary).is_empty() and strategy in ["know", "weak"]:
		return not r.resolve_placard().is_empty()
	var visible: Array = (line.get("options", []) as Array).map(func(o: Dictionary) -> String: return str(o.get("id", "")))
	if not bool(line.get("has_slot", false)) or visible.is_empty():
		return not r.whiff_boke().is_empty()
	var pick: String = ""
	if strategy in ["know", "weak"]:
		for wanted: String in (["perfect", "weak"] if strategy == "know" else ["weak", "perfect"]):
			for option: Dictionary in slot.get("options", []):
				if pick.is_empty() and str(option.get("result", "")) == wanted and str(option.get("id", "")) in visible:
					pick = str(option["id"])
		if pick.is_empty():
			pick = visible[0]
	else:
		var key: String = "%s:%s" % [c.get("id", ""), line.get("id", "")]
		var fresh: Array = visible.filter(func(id: String) -> bool: return strategy == "repeat" or id not in (tried.get(key, []) as Array))
		pick = (fresh if not fresh.is_empty() else visible)[rng.randi_range(0, (fresh if not fresh.is_empty() else visible).size() - 1)]
		tried[key] = (tried.get(key, []) as Array) + [pick]
	return not r.resolve_boke(pick).is_empty()


func _outcome(r: Runner, end: String) -> Dictionary:
	return {"end": end, "fails": int(r.stats.get("fails", 0)), "game_overs": int(r.stats.get("game_overs", 0)),
		"perfect": int(r.stats.get("perfect", 0)), "caught": int(r.stats.get("caught", 0))}
