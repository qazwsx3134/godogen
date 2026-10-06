extends "res://addons/proto_kit/test_kit.gd"
const Text = preload("res://scripts/dialogue_text.gd")
func _init() -> void:
	var plan: Dictionary = Text.compile("甲[pause=0.4][color=#123456][big]乙[/big][/color][speed=0.09]，丙[/speed]丁",0.032)
	_expect(plan.plain == "甲乙，丙丁", "markup and timing instructions are absent from readable dialogue")
	_expect(plan.rendered.contains("[font_size=60]") and not plan.rendered.contains("pause="), "visual markup is retained and timing markup is removed")
	_expect(is_equal_approx(Text.before_delay(plan,1),0.4), "a pause waits before the next readable character")
	_expect(is_equal_approx(plan.speeds[3],0.09) and is_equal_approx(plan.speeds[4],0.032), "local speed ends at its closing tag")
	_expect(Text.after_delay(plan,3) > 0.09, "punctuation has a natural reading pause")
	var combined: Dictionary = Text.compile("A❤️‍🔥B",0.032)
	_expect(combined.ends.size()==3 and combined.ends[1]>2, "an emoji grapheme reveals as one readable character")
	_expect(Text.compile("甲[未知]乙",0.032).plain == "甲[未知]乙", "unknown brackets remain readable literal content")
	_finish("DIALOGUE TEXT TESTS")
