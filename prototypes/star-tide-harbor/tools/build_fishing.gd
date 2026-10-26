extends SceneTree
## One-time authored migration, applied 2026-10-25. Existing fishing scene is never regenerated.
const B=preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:run.call_deferred()
func add(parent: Node,node: Node,title: String) -> Node:
	return B.add(parent,B.unique(node),title)
func label_at(parent: Node,title: String,text: String,pos: Vector2,font_size: int) -> Label:
	var n:=Label.new();n.text=text;n.position=pos;n.add_theme_font_size_override("font_size",font_size)
	add(parent,n,title);return n
func rect(parent: Node,title: String,pos: Vector2,dimensions: Vector2,color: Color) -> ColorRect:
	var n:=ColorRect.new();n.position=pos;n.size=dimensions;n.color=color;n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add(parent,n,title);return n
func run() -> void:
	if not FileAccess.file_exists("res://scenes/fishing.tscn"):
		var view:=Control.new();view.name="Fishing";view.set_script(load("res://scripts/fishing.gd"));view.theme=load("res://assets/harbor_theme.tres")
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.mouse_filter=Control.MOUSE_FILTER_IGNORE
		rect(view,"Sky",Vector2.ZERO,Vector2(1280,720),Color("182e50"))
		var sky:=TextureRect.new();sky.texture=load("res://assets/sky.svg");sky.position=Vector2.ZERO;sky.size=Vector2(1280,250);sky.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sky.stretch_mode=TextureRect.STRETCH_SCALE;sky.mouse_filter=Control.MOUSE_FILTER_IGNORE;add(view,sky,"SkyArt")
		rect(view,"Water",Vector2(0,250),Vector2(1280,470),Color("143f59"))
		var sea:=TextureRect.new();sea.texture=load("res://assets/underwater.svg");sea.position=Vector2(0,250);sea.size=Vector2(1280,470);sea.mouse_filter=Control.MOUSE_FILTER_IGNORE;add(view,sea,"SeaArt")
		rect(view,"WaterSurface",Vector2(0,249),Vector2(1280,3),Color("8dd8d4"))
		var boat:=Sprite2D.new();boat.texture=load("res://assets/boat.svg");boat.position=Vector2(140,168);boat.scale=Vector2(.8,.8);add(view,boat,"Boat")
		var rod:=Line2D.new();rod.points=PackedVector2Array([Vector2(180,205),Vector2(230,180)]);rod.width=4;rod.default_color=Color("f3cca3");add(view,rod,"Rod")
		var shoal:=Node2D.new();add(view,shoal,"Shoal")
		for i in range(6):
			var fish:=Sprite2D.new();fish.texture=load("res://assets/fish%d.svg"%i);fish.position=Vector2(450+i*135,380+(i%3)*78);fish.scale=Vector2(.7,.7);fish.modulate=Color(.65,.9,.9,.8);add(shoal,fish,"Fish%d"%i)
		var line:=Line2D.new();line.width=2;line.points=PackedVector2Array([Vector2(230,180),Vector2(500,390),Vector2(720,460)]);add(view,line,"Line")
		var lure:=Polygon2D.new();lure.polygon=PackedVector2Array([Vector2(-5,-8),Vector2(7,0),Vector2(0,10),Vector2(-7,3)]);lure.color=Color("ffdcb1");lure.position=Vector2(720,460);add(view,lure,"Lure")
		var aim:=Line2D.new();aim.points=PackedVector2Array([Vector2(-15,0),Vector2(15,0),Vector2.ZERO,Vector2(0,-15),Vector2(0,15)]);aim.width=2;aim.default_color=Color("f8deb0");aim.position=Vector2(720,460);add(view,aim,"Aim")
		rect(view,"TopShade",Vector2.ZERO,Vector2(1280,120),Color(0.035,.08,.14,.86))
		label_at(view,"StageTitle","01　選擇拋竿位置與方向",Vector2(30,18),26)
		label_at(view,"Telemetry","線長 8.0 m　｜　張力 0%　｜　手動操作",Vector2(30,62),17)
		var leave:=Button.new();leave.text="返回小港  [ S / Esc ]";leave.position=Vector2(1005,28);leave.size=Vector2(245,48);add(view,leave,"Leave")
		rect(view,"BottomShade",Vector2(0,598),Vector2(1280,122),Color(.035,.08,.14,.94))
		label_at(view,"Status","從固定竿位向海灣拋出魚餌",Vector2(30,610),22)
		var instructions:=label_at(view,"Instructions","點選水域拋竿。",Vector2(30,659),17);instructions.size=Vector2(1220,54);instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var bar:=ProgressBar.new();bar.position=Vector2(420,140);bar.size=Vector2(440,22);bar.show_percentage=false;add(view,bar,"Tension")
		label_at(view,"TensionLabel","魚線張力　鬆 ← → 緊",Vector2(505,113),16)
		var taps:=ProgressBar.new();taps.position=Vector2(420,178);taps.size=Vector2(440,17);taps.show_percentage=false;taps.visible=false;add(view,taps,"StruggleBar")
		if not B.save_scene(view,"res://scenes/fishing.tscn").ok:quit(1);return
	var game:Node=B.instance("res://scenes/harbor.tscn")
	if not game.has_node("FishingLayer"):
		var layer:=CanvasLayer.new();layer.name="FishingLayer";layer.layer=5;game.add_child(layer)
		var fishing:Node=B.instance("res://scenes/fishing.tscn");fishing.name="Fishing";fishing.unique_name_in_owner=true;layer.add_child(fishing)
		if not B.save_scene(game,"res://scenes/harbor.tscn",{"overwrite":true,"expected_refs":["res://scenes/player.tscn","res://scenes/mira.tscn","res://scenes/fishing.tscn"]}).ok:quit(1);return
	else:game.free()
	quit()
