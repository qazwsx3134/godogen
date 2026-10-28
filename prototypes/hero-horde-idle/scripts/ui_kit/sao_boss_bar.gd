extends Control
## The 樓層王's bar: the name centred over a wide framed gauge, the bars left on the right ("×2").


func set_boss(boss_name: String) -> void:
	%BossName.text = boss_name


## `within` = HP left in the bar being cut (0..1); `bars` = bars left, this one included.
func set_bar(within: float, bars: int) -> void:
	%Gauge.set_ratio(within)
	%Bars.text = "×%d" % bars
