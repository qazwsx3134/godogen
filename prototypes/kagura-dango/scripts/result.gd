extends Control
## Result screen. Round mode: rank, score, grade counts, a comment, then Next / replay the round / title.
## Final mode: who won the match (MatchState.won), the match score counting up, the average, then play again / title.

signal next_requested
signal retry_requested
signal back_requested


func _ready() -> void:
	%Next.pressed.connect(next_requested.emit)
	%Retry.pressed.connect(retry_requested.emit)
	%Back.pressed.connect(back_requested.emit)


func show_result(r: Dictionary, last_round: bool) -> void:
	%LevelTitle.text = r.title
	%Rank.text = Judge.RANK_TEXT[r.rank]
	%Score.text = "%d 分" % r.score
	var c: Dictionary = r.counts
	%Counts.text = "完美 %d　不錯 %d　勉強 %d　漏掉 %d\n本回合 +%s　總分 %s" % [c.ace, c.good, c.barely, c.miss,
		Judge.format_points(r.get("points", 0)), Judge.format_points(MatchState.score)]
	%Counts.text += "\n最大連擊 %d%s" % [r.get("max_combo", 0), "　全連擊！" if r.get("full_combo", false) else ""]
	var down: bool = r.get("knocked_down", false)  # round 3 ran out of lives: Kagura ended it lying on the ground
	%Comment.text = "%s：「%s」" % StoryData.comment(r.id, &"fail" if down else r.rank)
	%Next.text = "看比賽結果" if last_round else "下一回合"
	%Next.visible = true
	%Retry.text = "重來這回合"


func show_final() -> void:
	var won := MatchState.won()
	%LevelTitle.text = "比賽結果"
	%Rank.text = "萬事屋隊勝利！" if won else "對手隊勝利…"
	%Counts.text = "平均 %d 分　%s" % [MatchState.final_score(), Judge.RANK_TEXT[Judge.rank(MatchState.final_score())]]
	var tw := create_tween()
	tw.tween_method(func(v: int): %Score.text = "總分 %s" % Judge.format_points(v), 0, MatchState.score, 1.2).set_ease(Tween.EASE_OUT)
	%Comment.text = "神樂，生日快樂！" if won else "神樂，生日快樂！明年再贏回來！"
	%Next.visible = false
	%Retry.text = "再比一次"

