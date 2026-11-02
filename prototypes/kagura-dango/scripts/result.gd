extends Control
## Result screen. Round mode: rank, score, grade counts, a comment, then Next / replay the round / title.
## Final mode: who won the match, both teams' skewer counts, the average score, then play again / title.

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
	%Counts.text = "完美 %d　不錯 %d　勉強 %d　漏掉 %d" % [c.ace, c.good, c.barely, c.miss]
	%Comment.text = "%s：「%s」" % StoryData.comment(r.id, r.rank)
	%Next.text = "看比賽結果" if last_round else "下一回合"
	%Retry.text = "重來這回合"


func show_final() -> void:
	var won := MatchState.team_total() > MatchState.rival
	%LevelTitle.text = "比賽結果"
	%Rank.text = "萬事屋隊勝利！" if won else "對手隊勝利…"
	%Score.text = "平均 %d 分　%s" % [MatchState.final_score(), Judge.RANK_TEXT[Judge.rank(MatchState.final_score())]]
	%Counts.text = "萬事屋 %d 串　vs　對手隊 %d 串" % [MatchState.team_total(), MatchState.rival]
	%Comment.text = "神樂，生日快樂！" if won else "神樂，生日快樂！明年再贏回來！"
	%Next.visible = false
	%Retry.text = "再比一次"
