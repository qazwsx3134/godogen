extends RefCounted

## main.gd 的調查：熱區、背景拖曳、對話／移動話題、調查時的角色透明度與收合列。

const InvestigationLayout = preload("res://scripts/investigation_layout.gd")
const InvestigationPicker = preload("res://scripts/investigation_picker.gd")
const HOTSPOT_SCENE: PackedScene = preload("res://scenes/ui/hotspot.tscn")
const INVESTIGATE_BAR_SCENE: PackedScene = preload("res://scenes/ui/investigate_bar.tscn")
const DEFAULT_HOTSPOT_SIZE: Array = [0.12, 0.12]
const SEARCH_CAST_ALPHA: float = 0.55
const DESIGN_WIDTH: float = 1920.0
const CSS_PX: float = DESIGN_WIDTH / 720.0
## Taps in a row that hit nothing on the picture before the toast turns into a hint.
const MISS_HINT_AFTER: int = 3

var m: DebtMain
var _empty_taps: int = 0


func _init(main: DebtMain) -> void:
	m = main


## The cast must not cover the room being searched: whoever has a spot on their portrait stays,
## see-through (their spot, checked or not, counts only while they are on stage); everyone else
## turns invisible (alpha 0, still on stage) until the search ends or a scene plays from it. Only
## alpha changes, so whoever was already leaving the stage still leaves.
func _set_search_cast(command: Dictionary) -> void:
	var tappable: Dictionary = {}
	for raw: Variant in command.get("hotspots", []):
		if raw is Dictionary and (raw as Dictionary).has("character"):
			tappable[str((raw as Dictionary)["character"])] = true
	for actor_id: String in m._sprites:
		var sprite: Control = m._sprites[actor_id]
		if not sprite.visible:
			continue
		sprite.modulate.a = SEARCH_CAST_ALPHA if tappable.has(actor_id) else 0.0
	m._search_cast_active = true


## The stage is being set anew (new story, a save, an empty stage): nobody comes back from a search.
func forget_search_cast() -> void:
	m._search_cast_active = false


func restore_search_cast() -> void:
	if not m._search_cast_active:
		return
	for sprite: Control in m._sprites.values():
		sprite.modulate.a = 1.0
	m._search_cast_active = false


func present_investigation(command: Dictionary, restored: bool) -> void:
	m._current_command = command.duplicate(true)
	m._current_speaker = m._default_pov()  # whoever thinks while searching
	m._full_text = m._dict_string(command, "prompt", "調查現場，尋找線索。")
	m._current_line_key = m._line_key(command, "investigate")
	if m._dict_string(command, "place", "home") != "home":
		m._current_line_key += ":" + m._dict_string(command, "place")
	m._line_logged = m._history_has_key(m._current_line_key)
	m._line_generation += 1
	m._story_busy = false
	m._set_auto(false)
	m._set_skip(false)
	m._clear_choices()
	m._hide_story_parts()
	m._screen = DebtMain.Screen.INVESTIGATE
	m._tutorial_ctl.maybe_tutorial.call_deferred("investigate")
	m._dialog_layer.visible = true
	m._dialog_panel.visible = true  # the prompt shows first; 收起 folds the box away
	m._investigation_continue_button.visible = true
	m._dialog_panel.set_reading_enabled(false)
	m._set_name_plate(m._default_pov(), true)
	if m._dict_bool(command, "keep_cast"):
		var home_key: String = m._dict_string(command, "id", m._dict_string(command, "node"))
		var place: String = m._dict_string(command, "place", "home")
		if not m._investigation_home_casts.has(home_key) or (place == "home" and (m._dict_string(command, "bg").is_empty() or m._current_bg_id == m._dict_string(command, "bg"))):
			m._investigation_home_casts[home_key] = (m._saves.build_save_payload("").get("sprites", {}) as Dictionary).duplicate(true)
		var home_cast: Dictionary = m._investigation_home_casts[home_key]
		for actor_id: String in m._sprites:
			var sprite: Control = m._sprites[actor_id]
			var pose: Dictionary = home_cast.get(actor_id, {})
			sprite.visible = place == "home" and bool(pose.get("visible", false))
			sprite.set_meta("portrait_lighting", pose.get("lighting", "auto"))
			sprite.set_meta("entrance_transition", pose.get("entrance_transition", "fade"))
			if sprite.visible:
				m._actor_slots[actor_id] = str(pose.get("position", "center"))
				sprite.call("set_expression", str(pose.get("expression", "neutral")))
			sprite.modulate = m._portrait_color(sprite, true)
		_set_search_cast(command)
	else:
		m._clear_stage()  # the player searches the room itself
	var place_bg: String = m._dict_string(command, "bg")
	if not place_bg.is_empty() and place_bg != m._current_bg_id:
		m._apply_background(place_bg)  # each place of the search shows its own picture
		m._library.unlock(m._gallery_key("bg"), place_bg)
	m._set_text_tone("thought")
	m._layout()
	m._set_visible_text(m._full_text, true)
	m._current_command = m._runner_current()
	_build_hotspots(m._current_command)
	show_topics(m._current_command)
	_update_investigation_controls()
	if not m._line_logged:
		m._append_history({"key": m._current_line_key, "kind": "investigate", "speaker": m._default_pov(),
			"text": m._full_text})
		m._line_logged = true
	m._refresh_phase3_hud()
	m._qa_ctl.publish_qa_state()


func build_investigate_bar() -> void:
	m._investigate_bar = INVESTIGATE_BAR_SCENE.instantiate() as Control
	m._dialog_layer.add_child(m._investigate_bar)
	m._investigate_bar.visible = false
	m._investigate_bar.connect("expand_pressed", set_investigation_collapsed.bind(false))
	m._investigate_bar.connect("continue_pressed", on_investigation_continue_pressed)
	m._investigate_bar.call("set_reduce_motion", int(m._settings.get("motion", 0)) == 1)


## Folds the reading box into the one-line bar (or back) while searching.
func set_investigation_collapsed(value: bool) -> void:
	m._investigate_collapsed = value and m._screen == DebtMain.Screen.INVESTIGATE
	m._investigate_bar.visible = m._investigate_collapsed
	m._refresh_reading_ui()
	m._qa_ctl.publish_qa_state()


## The spots of this investigation, on a layer over the whole background picture: each sits over
## its object at the story's `pos` (centre) and `size`, fractions of the picture.
func _build_hotspots(command: Dictionary) -> void:
	clear_hotspots()
	m._pan_key = "%s/%s" % [m._dict_string(command, "id"), m._dict_string(command, "place", "home")]
	if bool(command.get("keep_cast",false)):
		for actor: String in m._sprites.keys():
			if (m._sprites[actor] as Control).visible:
				m._cast_pan_origins[actor] = (m._sprites[actor] as Control).position.x
				m._cast_pan_y_origins[actor] = (m._sprites[actor] as Control).position.y
	m._pan = float(m._investigation_pans.get(m._pan_key, 0.0))  # back from a reaction: where the player left it
	m._pan_y = float(m._investigation_pans_y.get(m._pan_key, 0.0))
	var frame: TextureRect = m._background_rect
	m._frame_offsets = [frame.offset_left, frame.offset_top, frame.offset_right, frame.offset_bottom]
	m._hotspot_layer = Control.new()
	m._hotspot_layer.name = "Hotspots"
	m._hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(m._hotspot_layer)
	m._hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for raw_hotspot: Variant in command.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = m._dict_string(hotspot, "id")
		var spot: Control = HOTSPOT_SCENE.instantiate() as Control
		spot.name = "Hotspot_" + hotspot_id
		if hotspot.has("character"):
			# A character's spot covers their portrait on the stage instead of a place on the picture:
			# it lies on the interaction layer (sized by layout_hotspots) and exists while they are on stage.
			if not m._dict_bool(hotspot, "present", true):
				spot.free()
				continue
			m._interaction_layer.add_child(spot)
		else:
			var pos: Array = hotspot.get("pos", [0.5, 0.5]) as Array
			var extent: Array = hotspot.get("size", DEFAULT_HOTSPOT_SIZE) as Array
			m._hotspot_layer.add_child(spot)
			spot.anchor_left = clampf(float(pos[0]) - float(extent[0]) * 0.5, 0.0, 1.0)
			spot.anchor_right = clampf(float(pos[0]) + float(extent[0]) * 0.5, 0.0, 1.0)
			spot.anchor_top = clampf(float(pos[1]) - float(extent[1]) * 0.5, 0.0, 1.0)
			spot.anchor_bottom = clampf(float(pos[1]) + float(extent[1]) * 0.5, 0.0, 1.0)
			spot.offset_left = 0.0
			spot.offset_top = 0.0
			spot.offset_right = 0.0
			spot.offset_bottom = 0.0
		spot.call("set_found", bool(hotspot.get("checked", false)), false)
		m._hotspots[hotspot_id] = spot
	layout_hotspots()


## Stretches the background frame to the whole picture (which covers the frame's own rect,
## centred) so every part of it can slide into view, and works out how far it may slide.
func layout_hotspots() -> void:
	if m._hotspot_layer == null or not is_instance_valid(m._hotspot_layer):
		return
	var frame: TextureRect = m._hotspot_layer.get_parent() as TextureRect
	var own: Rect2 = _anchored_rect_with(frame, m._frame_offsets, Rect2(Vector2.ZERO, m._game.size))
	var art := Vector2.ZERO
	if frame.texture != null and not frame.texture is GradientTexture2D:
		art = Vector2(frame.texture.get_width(), frame.texture.get_height())
	var layout := InvestigationLayout.coverage(own, art, m._game.size)
	m._picture = layout.picture
	m._pan_range = layout.horizontal
	m._pan_y_range = layout.vertical
	set_pan(m._pan, m._pan_y)
	place_cast_hotspots()


## A character's spot lies over their portrait as it is on screen (kept inside the game area).
func place_cast_hotspots() -> void:
	var screen: Rect2 = Rect2(m._game.global_position, m._game.size)
	for raw_hotspot: Variant in m._current_command.get("hotspots", []):
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var spot: Control = m._hotspots.get(m._dict_string(hotspot, "id")) as Control
		if spot == null or spot.get_parent() != m._interaction_layer:
			continue
		var portrait: Rect2 = (m._sprites[m._dict_string(hotspot, "character")] as Control).call("art_rect")
		if hotspot.has("art_region"):
			var region: Array = hotspot["art_region"]
			portrait = Rect2(portrait.position + portrait.size * Vector2(region[0],region[1]),
				portrait.size * Vector2(region[2],region[3]))
		var shown: Rect2 = portrait.intersection(screen)
		spot.visible = shown.has_area()
		if not spot.visible:
			continue  # no visible art region means no target, even after touch expansion
		spot.position = shown.position - m._interaction_layer.global_position
		spot.size = shown.size


func set_pan(value: float, vertical: Variant = null) -> void:
	m._pan = clampf(value, m._pan_range.x, m._pan_range.y)
	if vertical != null:
		m._pan_y = clampf(float(vertical), m._pan_y_range.x, m._pan_y_range.y)
	if m._hotspot_layer == null or not is_instance_valid(m._hotspot_layer):
		return
	var frame: TextureRect = m._hotspot_layer.get_parent() as TextureRect
	var offsets := InvestigationLayout.panned_offsets(m._picture, Vector2(m._pan, m._pan_y),
		Vector4(frame.anchor_left, frame.anchor_top, frame.anchor_right, frame.anchor_bottom), m._game.size)
	frame.offset_left = offsets.x
	frame.offset_top = offsets.y
	frame.offset_right = offsets.z
	frame.offset_bottom = offsets.w
	for actor: String in m._cast_pan_origins.keys():
		(m._sprites[actor] as Control).position.x = float(m._cast_pan_origins[actor]) + m._pan
		(m._sprites[actor] as Control).position.y = float(m._cast_pan_y_origins.get(actor, (m._sprites[actor] as Control).position.y)) + m._pan_y
	if not m._pan_key.is_empty():
		m._investigation_pans[m._pan_key] = m._pan
		m._investigation_pans_y[m._pan_key] = m._pan_y
	place_cast_hotspots()


func clear_hotspots() -> void:
	for actor: String in m._cast_pan_origins.keys():
		(m._sprites[actor] as Control).position.x = float(m._cast_pan_origins[actor])
		if m._cast_pan_y_origins.has(actor):
			(m._sprites[actor] as Control).position.y = float(m._cast_pan_y_origins[actor])
	m._cast_pan_origins.clear()
	m._cast_pan_y_origins.clear()
	if not m._pan_key.is_empty() and m._hotspot_layer != null:
		m._investigation_pans[m._pan_key] = m._pan
		m._investigation_pans_y[m._pan_key] = m._pan_y
	m._pan_key = ""
	m._topic_buttons.clear()
	if m._dialog_panel != null:
		m._dialog_panel.set_topics([], [])
	if m._hotspot_layer != null and is_instance_valid(m._hotspot_layer):
		var frame: TextureRect = m._hotspot_layer.get_parent() as TextureRect
		frame.offset_left = m._frame_offsets[0]
		frame.offset_top = m._frame_offsets[1]
		frame.offset_right = m._frame_offsets[2]
		frame.offset_bottom = m._frame_offsets[3]
		m._hotspot_layer.queue_free()
	m._hotspot_layer = null
	for spot: Control in m._hotspots.values():
		if spot.get_parent() == m._interaction_layer:
			spot.queue_free()  # a character's spot lies on the interaction layer, not on the picture
	m._hotspots.clear()
	m._pan = 0.0
	m._pan_range = Vector2.ZERO
	m._pan_y = 0.0
	m._pan_y_range = Vector2.ZERO
	m._investigate_collapsed = false
	if m._investigate_bar != null:
		m._investigate_bar.visible = false


## Where a Control would sit inside parent_rect with the given offsets [left, top, right, bottom].
func _anchored_rect_with(node: Control, offsets: Array[float], parent_rect: Rect2) -> Rect2:
	return InvestigationLayout.anchored_rect(
		Vector4(node.anchor_left, node.anchor_top, node.anchor_right, node.anchor_bottom), offsets, parent_rect)


## A tap on the picture while searching: the spot under it, unless the reading box covers it.
## Found spots are done, except those with `lines`, which answer every tap. Where spots overlap, an
## object beats a character (a character's spot is their whole portrait, so no object may hide in it)
## and the smaller object wins; of two characters, the one in front wins.
func tap_investigation(at: Vector2) -> void:
	if m._story_busy or (m._dialog_panel.visible and m._dialog_panel.get_global_rect().has_point(at)):
		return
	var definitions := {}
	for hotspot_id: String in m._hotspots:
		definitions[hotspot_id] = hotspot_data(hotspot_id)
	var tapped := InvestigationPicker.pick(at, m._hotspots, definitions, m._sprites, 48.0 * CSS_PX * m._panel_scale)
	if not tapped.is_empty():
		_empty_taps = 0
		collect_hotspot(tapped)
		return
	# Nothing there: say so, and after a few misses in a row say how many spots are left.
	_empty_taps += 1
	var left: int = m._hotspots.values().filter(func(spot: Control) -> bool: return not bool(spot.get("found"))).size()
	if _empty_taps >= MISS_HINT_AFTER and left > 0:
		_empty_taps = 0
		m._show_toast("提示：還有 %d 個地方沒查過，人物和顯眼的東西都點點看" % left)
	else:
		m._show_toast("這裡沒什麼特別的")


## The runner's entry for a hotspot of the current search ({} when there is none).
func hotspot_data(hotspot_id: String) -> Dictionary:
	for raw_hotspot: Variant in m._current_command.get("hotspots", []):
		if raw_hotspot is Dictionary and m._dict_string(raw_hotspot as Dictionary, "id") == hotspot_id:
			return raw_hotspot as Dictionary
	return {}


## The spot's rect, grown to at least 48 CSS px each way so small objects stay tappable.
func hotspot_hit_rect(spot: Control) -> Rect2:
	return InvestigationPicker.hit_rect(spot, 48.0 * CSS_PX * m._panel_scale)


func collect_hotspot(hotspot_id: String) -> void:
	if m._screen != DebtMain.Screen.INVESTIGATE or m._story_busy:
		return
	m._sync_cast()
	var spot: Control = m._hotspots.get(hotspot_id) as Control
	var first_time: bool = spot == null or not bool(spot.get("found"))  # `lines` spots answer every tap
	if not bool(m._runner.inspect_hotspot(hotspot_id)):
		m._show_toast(m._runner_string("error_message", "這個位置目前不能調查。"))
		return
	var item_id: String = m._dict_string(hotspot_data(hotspot_id), "item")
	var item_info: Dictionary = (m._catalog.get("items", {}) as Dictionary).get(item_id, {}) as Dictionary
	var item_name: String = str(item_info.get("name", item_id))
	var next: Dictionary = m._runner_current()
	(m._hotspots[hotspot_id] as Control).call("set_found", true, first_time)
	if not item_id.is_empty() and first_time:
		m._show_toast("取得線索：" + item_name)
		m._effects.feedback("clue")
	if m._command_op(next) != "investigate":
		# The spot has something to say: its scene plays and leads back to the search.
		m._refresh_phase3_hud()
		m._story_busy = true
		m._screen = DebtMain.Screen.BUSY
		m._start_drive()
		return
	if m._dict_string(next, "place") != m._dict_string(m._current_command, "place"):
		present_investigation(next, true)  # a searched-out side place sends the player home
		m._saves.save_game()
		return
	m._current_command = next
	_update_investigation_controls()
	m._refresh_phase3_hud()
	m._saves.save_game()
	if not m._investigation_continue_button.disabled and m._investigate_collapsed:
		set_investigation_collapsed(false)  # every clue found: bring back 繼續
	m._qa_ctl.publish_qa_state()


## 繼續 opens once every required spot of every place is checked (runner `complete`/`progress`).
func _update_investigation_controls() -> void:
	var all_checked: bool = bool(m._current_command.get("complete", false))
	var progress: Array = m._current_command.get("progress", [0, 0]) as Array
	m._investigation_continue_button.disabled = not all_checked
	m._investigation_continue_button.text = "線索已取得・繼續" if all_checked else "先調查所有位置"
	m._investigate_bar.call("set_progress", int(progress[0]), int(progress[1]), all_checked)


## The 對話 and 移動 rows of the reading box for this place of the search.
func show_topics(command: Dictionary) -> void:
	m._topic_buttons = m._dialog_panel.set_topics(command.get("talk", []) as Array, command.get("moves", []) as Array)
	for key: String in m._topic_buttons.keys():
		var topic_id: String = key.get_slice(":", 1)
		(m._topic_buttons[key] as Button).pressed.connect(
			(on_talk_pressed if key.begins_with("talk:") else _on_move_pressed).bind(topic_id))


## A talk topic: its scene plays once and leads back to the search.
func on_talk_pressed(topic_id: String) -> void:
	if m._screen != DebtMain.Screen.INVESTIGATE or m._story_busy:
		return
	if not bool(m._runner.talk_topic(topic_id)):
		m._show_toast(m._runner_string("error_message", "這個話題現在不能聊。"))
		return
	m._story_busy = true
	m._screen = DebtMain.Screen.BUSY
	m._start_drive()


## Moving: another place of the search, with its own picture, spots and topics.
func _on_move_pressed(place_id: String) -> void:
	if m._screen != DebtMain.Screen.INVESTIGATE or m._story_busy:
		return
	if not bool(m._runner.move_to(place_id)):
		m._show_toast(m._runner_string("error_message", "現在不能去那裡。"))
		return
	present_investigation(m._runner_current(), true)
	m._saves.save_game()


func on_investigation_continue_pressed() -> void:
	if m._screen != DebtMain.Screen.INVESTIGATE or m._story_busy or m._investigation_continue_button.disabled:
		return
	var home_bg: String = m._dict_string(m._current_command, "home_bg")
	if not home_bg.is_empty() and home_bg != m._current_bg_id:
		clear_hotspots()
		m._apply_background(home_bg)  # the search ends where it began
	m._story_busy = true
	m._screen = DebtMain.Screen.BUSY
	m._sync_cast()
	var next: Dictionary = m._runner.advance() as Dictionary
	if m._command_op(next) == "investigate":
		m._story_busy = false
		present_investigation(next, true)
		return
	m._start_drive()
