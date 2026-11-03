extends SceneTree
## itch.io page art into publishing/itch/: the cover (1260x1000 for high-DPI screens, plus 630x500, itch's size) and
## 1280x720 screenshots of the title, the story, each round mid-play (notes on the track, a combo, the score) and the
## birthday ending. Opens a window (needs a GPU); keep it in front while it runs.
##   godot --path . --resolution 1280x720 -s tools/store_art.gd -- --settings=/tmp/kd.cfg

const OUT := "res://publishing/itch/"
const COVER := Vector2i(1260, 1000)

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.load_all()
	await _cover()
	await _screen("01-title.png", await _attach("res://scenes/title.tscn"))
	var story: Node = await _attach("res://scenes/story.tscn")
	story.play([["神樂", "今天是我的生日阿魯！丸子全部吃光光！"]])
	await _screen("02-story.png", story)
	await _round("03-round1.png", "res://scenes/three_eat.tscn", "res://data/songs/eat3.json", 0.45, 24)
	await _round("04-round2.png", "res://scenes/feast.tscn", "res://data/songs/feast2.json", 0.5, 50)
	await _round("05-round3.png", "res://scenes/toss_game.tscn", "res://data/songs/toss3.json", 0.7, 88)
	var ending: Node = await _attach("res://scenes/story.tscn")
	ending.play([["萬事屋", "神樂，生日快樂！", "res://assets/sprites/kagura_birthday.png"]])
	await _screen("06-ending.png", ending)
	quit()


## The title art at 2x along the bottom, the game's name over a sky band above it.
func _cover() -> void:
	var vp := SubViewport.new()
	vp.size = COVER
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var top := Color(0.99, 0.78, 0.55)
	var sky := ColorRect.new()
	sky.color = top
	sky.size = Vector2(COVER)
	vp.add_child(sky)
	var art := TextureRect.new()
	art.texture = load("res://assets/sprites/title_art.png")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Vector2(1280, 720)
	art.position = Vector2((COVER.x - 1280) / 2.0, COVER.y - 720)
	vp.add_child(art)
	var fade := TextureRect.new()  # blends the sky band into the art's own sky
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, Color(top, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	fade.texture = gt
	fade.size = Vector2(COVER.x, 160)
	fade.position = Vector2(0, COVER.y - 720)
	vp.add_child(fade)
	var font: Font = load("res://assets/fonts/NotoSansTC.otf")
	_label(vp, "丸子大胃王", font, 170, Color(0.98, 0.95, 0.86), Color(0.55, 0.12, 0.12), 26, 40)
	_label(vp, "～神樂生日快樂～", font, 64, Color(0.98, 0.95, 0.86), Color(0.55, 0.12, 0.12), 16, 250)
	_label(vp, "銀魂同人節奏遊戲", font, 34, Color(0.55, 0.12, 0.12), Color(0.99, 0.9, 0.75), 8, 340)
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(_out.path_join("cover.png"))
	img.resize(630, 500, Image.INTERPOLATE_LANCZOS)
	img.save_png(_out.path_join("cover-630x500.png"))
	print("STORE cover.png, cover-630x500.png")
	vp.queue_free()
	await process_frame


func _label(parent: Node, text: String, font: Font, size: int, color: Color, outline: Color, outline_size: int, y: float) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(COVER.x, size * 1.4)
	l.position = Vector2(0, y)
	parent.add_child(l)


## A round at `share` of its length: earlier notes hit (so nothing is missed), the next cue thrown or served, a
## combo of `combo` with its effects, and the score so far.
func _round(file: String, scene: String, chart: String, share: float, combo: int) -> void:
	MatchState.reset()
	var level: Node = await _attach(scene, chart)
	var c: Conductor = level.get_node("%Conductor")
	var span: float = c.beat_time(float(level.chart.end_beat)) - c.beat_time(float(level.chart.count_in_beats))
	var t: float = c.beat_time(float(level.chart.count_in_beats)) + span * share
	c.clock = func(): return t
	level.start()
	var next := -1
	for i in level.hits.size():
		var h: Dictionary = level.hits[i]
		if h.time < t:
			h.grade = &"ace"
			if level.counts_as_skewer(i):
				MatchState.eaten[level.eater(i)] += 1
		elif next < 0 and c.beat_time(h.cue_beat) <= t:
			next = i
	level._next_cue = level.hits.filter(func(h): return c.beat_time(h.cue_beat) <= t).size()
	MatchState.score = combo * 1000 + 31000
	level.combo = combo
	level._refresh_bodies()
	if next >= 0:
		level._on_cue(next)
	level.hud.set_score(MatchState.score - 1000)
	level.hud.add_score(1000, MatchState.score, true)
	level.hud.set_combo(combo)
	level.hud.show_judge("完美！")
	level.hud.get_node("%NoteTrack").get_node("%JudgeCircle").burst(Color(1, 0.82, 0.2), true)
	level._beat(int(c.beat_at(t)))
	if level.hud.get_node("%CallLabel").text == "預備……":  # start()'s call stays up until the next one
		level.hud.call_out("")
	await create_timer(0.07).timeout
	await _screen(file, level)


func _attach(path: String, chart := "") -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	if chart != "":
		node.set("chart_path", chart)
	root.add_child(node)
	await process_frame
	await process_frame
	return node


func _screen(file: String, node: Node) -> void:
	DisplayServer.window_move_to_foreground()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(file))
	print("STORE ", file)
	node.queue_free()
	await process_frame
