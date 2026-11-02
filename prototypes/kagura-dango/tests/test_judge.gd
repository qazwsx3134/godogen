extends "res://addons/proto_kit/test_kit.gd"
## Judge windows, level score and rank.


func _init() -> void:
	_expect(Judge.grade(0.0) == &"ace", "on the beat is ace")
	_expect(Judge.grade(-0.035) == &"ace" and Judge.grade(0.035) == &"ace", "±35 ms is still ace")
	_expect(Judge.grade(0.036) == &"good" and Judge.grade(-0.075) == &"good", "36..75 ms is good")
	_expect(Judge.grade(0.076) == &"barely" and Judge.grade(-0.12) == &"barely", "76..120 ms is barely")
	_expect(Judge.grade(0.121) == &"" and Judge.grade(-0.3) == &"", "beyond 120 ms answers nothing")
	_expect(Judge.score([]) == 0, "empty level scores 0")
	_expect(Judge.score([&"ace", &"ace"]) == 100, "all ace is 100")
	_expect(Judge.score([&"ace", &"miss"]) == 50, "a miss counts as 0 in the average")
	_expect(Judge.score([&"good", &"good", &"barely"]) == 73, "85,85,50 averages to 73")
	_expect(Judge.rank(80) == &"superb" and Judge.rank(79) == &"ok", "80 is the superb line")
	_expect(Judge.rank(60) == &"ok" and Judge.rank(59) == &"again", "60 is the ok line")
	_finish("JUDGE")
