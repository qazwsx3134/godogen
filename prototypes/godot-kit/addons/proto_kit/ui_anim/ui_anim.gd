class_name UiAnim
## 共用出場動畫：只動 modulate:a 與 offset_transform_*（visual only），
## 不碰 visible／scale／position，Container 不重排、點擊範圍不變。

enum Type { SCALE, SLIDE_IN_LEFT, SLIDE_IN_RIGHT }

const SLIDE_DISTANCE := 80.0


## 開啟 visual-only 的 offset transform，pivot 在中心。
static func enable(c: Control) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_visual_only = true
	c.offset_transform_pivot_ratio = Vector2(0.5, 0.5)


static func hide_for_anim(c: CanvasItem) -> void:
	c.modulate.a = 0.0


## 把 c 的出場動畫排進 tween（tween 需已 set_parallel）。
static func appear(tween: Tween, c: Control, type: Type, duration: float, delay: float) -> void:
	enable(c)
	match type:
		Type.SCALE:
			tween.tween_property(c, "offset_transform_scale", Vector2.ONE, duration).from(Vector2.ZERO) \
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Type.SLIDE_IN_LEFT, Type.SLIDE_IN_RIGHT:
			var dir := -1.0 if type == Type.SLIDE_IN_LEFT else 1.0
			tween.tween_property(c, "offset_transform_position", Vector2.ZERO, duration) \
				.from(Vector2(dir * SLIDE_DISTANCE, 0)).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(c, "modulate:a", 1.0, 0.01).set_delay(delay)


## 一次性 UI 音效：音高隨機 ±jitter 避免死板。播完自動釋放；stream 為 null 時不做事。
static func play_sfx(from: Node, stream: AudioStream, pitch := 1.0, jitter := 0.08) -> AudioStreamPlayer:
	if stream == null or not from.is_inside_tree():
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.finished.connect(p.queue_free)
	p.autoplay = true
	# 掛在 tree root，不污染呼叫端（例如手牌 Container）的子 node；deferred 避免 _ready 期間 root 忙碌
	from.get_tree().root.add_child.call_deferred(p)
	return p
