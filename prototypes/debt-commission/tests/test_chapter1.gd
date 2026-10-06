extends "res://addons/proto_kit/test_kit.gd"
const Runner = preload("res://scripts/story_runner.gd")
const STORY = "res://data/chapter1_story.json"
func _init() -> void:
	for route: String in ["perfect", "hidden", "super", "weak", "timeout", "retry", "one_fail", "two_fails", "four_fails"]:
		_route(route)
	_finish("CHAPTER 1 TESTS")
func _settle(r: RefCounted) -> Dictionary:
	for i in range(1500):
		var c: Dictionary = r.call("current")
		if c.get("op") in ["investigate", "boke_round", "result", "end"]:
			return c
		r.call("advance")
	_expect(false, "chapter flow settles")
	return {}
func _round(r: RefCounted, id: String) -> Dictionary:
	var c = _settle(r)
	_expect(c.get("id") == id, "expected %s, got %s" % [id,c.get("id")])
	return c
func _answer(r: RefCounted, index: int, method: String = "resolve_boke", answer: String = "a") -> Dictionary:
	r.call("set_boke_line", index)
	var hit: Dictionary = r.call(method,answer) if method == "resolve_boke" else r.call(method)
	_expect(not hit.is_empty(), "answer resolves %s on %d" % [method,index])
	return _settle(r)
func _roundtrip(r: RefCounted) -> void:
	var snapshot: Dictionary = r.call("snapshot")
	var copy = Runner.new()
	_expect(copy.load_story(STORY) and copy.restore(snapshot), "chapter snapshot validates")
	_expect(copy.snapshot() == snapshot, "restore does not change scoring, materials or progress")
func _route(route: String) -> void:
	var r = Runner.new()
	_expect(r.load_story(STORY), "chapter compiles")
	var search = _settle(r)
	r.cast=["gintoki","kagura"]
	search=r.current()
	_expect(search.get("progress") == [0,4], "four required home clues; kitchen is optional")
	if route == "perfect":
		for topic in ["ch1_topic_1","ch1_topic_2","ch1_topic_3"]:
			_expect(r.talk_topic(topic), "optional conversation plays")
			_settle(r)
		_expect(r.move_to("kitchen") and r.inspect_hotspot("ch1_fridge"), "kitchen reaction plays")
		search=_settle(r)
		_expect(search.get("place")=="home", "kitchen returns to living room")
	for spot in ["desk_underside","gintoki_mouth","sofa_underside","floor_prints"]:
		_expect(r.inspect_hotspot(spot), "clue %s grants its material" % spot)
		_settle(r)
		_roundtrip(r)
	_expect(r.current().complete and r.items.size()==4, "all four clues unlock continue exactly once")
	r.advance()
	_round(r,"ch1_r1")
	if route in ["one_fail","two_fails","four_fails","retry"]:
		var failures = {"one_fail":1,"two_fails":2,"four_fails":4,"retry":5}[route]
		for i in range(failures):
			_answer(r,1,"resolve_boke","c")
		if route=="retry":
			_expect(r.snapshot().game_over_active and r.retry_checkpoint(), "fifth miss allows checkpoint retry")
			_expect(r.current().get("source_id")=="G05", "retry starts with approved G05 reply")
			_round(r,"ch1_r1")
			_expect(r.gameplay.glasses==5 and r.stats.get("game_overs",0)==1, "retry restores glasses and counts the game over")
	if route=="timeout":
		_answer(r,1,"timeout_boke")
	var weak: bool = route=="weak"
	if not weak:
		r.set_boke_line(0)
		_expect(r.listen_boke_line(), "Gintoki line one can be heard out")
		_round(r,"ch1_r1")
		_expect(r.items.has("gin_sleep_testimony"), "listening grants testimony")
	_answer(r,1,"resolve_boke","b" if weak else "a")
	_answer(r,3,"resolve_boke","b" if weak else "a")
	_round(r,"ch1_r2")
	_answer(r,0,"resolve_boke","b" if weak else "a")
	_answer(r,1,"resolve_boke" if weak else "resolve_placard","b")
	_roundtrip(r)
	_answer(r,2,"resolve_boke","d" if route=="hidden" else ("b" if weak else "a"))
	_round(r,"ch1_r3")
	if route=="hidden":_expect(r.flags.hidden_sadaharu and r.stats.get("hidden",0)==1, "conditional give-up opens Sadaharu's hidden route")
	if route=="super":
		_expect(r.current().super_available and not r.use_super().is_empty(), "full power fires the ultimate tsukkomi")
		_settle(r)
	else:
		for i in range(4):
			if weak and i==2:
				_expect(not r.current().current_line.options.any(func(o: Dictionary)->bool:return o.id=="a"), "missing listening material hides perfect combo answer")
			_answer(r,i,"resolve_boke","b" if weak else "a")
			_roundtrip(r)
	_expect(not r.current().current_line.qte.is_empty(), "C5 still requires a QTE after normal or super route")
	_expect(r.resolve_qte(true,0.0).get("result")=="perfect", "C5 QTE completes")
	var result=_settle(r)
	_expect(result.get("op")=="result" and r.items.has("salary_envelope"), "salary twist reaches chapter result")
	var expected = {"perfect":"S","hidden":"S","super":"S","weak":"S","timeout":"A","retry":"A","one_fail":"A","two_fails":"B","four_fails":"C"}[route]
	_expect(r.chapter_result().get("grade")==expected, "%s route grade %s (got %s)" % [route,expected,r.chapter_result().get("grade")])
	_roundtrip(r)
