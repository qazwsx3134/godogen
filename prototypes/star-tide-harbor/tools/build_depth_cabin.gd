extends SceneTree
## One-time authoring migration, 2026-10-25. Never regenerates existing scenes.
const B=preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:run.call_deferred()
func add(parent: Node,child: Node,title: String,unique: bool = true) -> Node:
	if unique:B.unique(child)
	return B.add(parent,child,title)
func sprite(parent: Node,title: String,path: String,pos: Vector2) -> Sprite2D:
	var n:=Sprite2D.new();n.texture=load("res://assets/"+path);n.position=pos;n.centered=false
	return add(parent,n,title) as Sprite2D
func label(parent: Node,title: String,text: String,pos: Vector2,font: int) -> Label:
	var n:=Label.new();n.text=text;n.position=pos;n.add_theme_font_size_override("font_size",font)
	return add(parent,n,title) as Label
func button(parent: Node,title: String,text: String,x: float,width: float) -> void:
	var n:=Button.new();n.text=text;n.position=Vector2(x,83);n.size=Vector2(width,44);n.focus_mode=Control.FOCUS_NONE
	add(parent,n,title)
func rect(parent: Node,title: String,pos: Vector2,dimensions: Vector2,color: Color) -> ColorRect:
	var n:=ColorRect.new();n.position=pos;n.size=dimensions;n.color=color;n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return add(parent,n,title) as ColorRect
func run() -> void:
	if not FileAccess.file_exists("res://scenes/furniture.tscn"):
		var item:=Node2D.new();item.name="Furniture";item.set_script(load("res://scripts/furniture.gd"))
		var glow:=sprite(item,"Glow","prop_glow.svg",Vector2(-128,-218));glow.visible=false
		sprite(item,"Art","prop_lamp.svg",Vector2(-64,-160))
		if not B.save_scene(item,"res://scenes/furniture.tscn").ok:quit(1);return
	if not FileAccess.file_exists("res://scenes/cabin.tscn"):
		var cabin:=Control.new();cabin.name="Cabin";cabin.set_script(load("res://scripts/cabin.gd"));cabin.theme=load("res://assets/harbor_theme.tres")
		cabin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);cabin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		sprite(cabin,"CabinArt","cabin.svg",Vector2.ZERO)
		var grid:=Node2D.new();add(cabin,grid,"Grid")
		for x in range(16):rect(grid,"Column%d"%x,Vector2(160+x*64,352),Vector2(1,256),Color(1,.9,.7,.12))
		for y in range(5):rect(grid,"Row%d"%y,Vector2(160,352+y*64),Vector2(960,1),Color(1,.9,.7,.12))
		add(cabin,Node2D.new(),"Placed")
		var cursor:=rect(cabin,"CursorCell",Vector2(162,355),Vector2(60,58),Color(.4,.9,.78,.16));cursor.z_index=2000
		var preview:=sprite(cabin,"Preview","prop_plant.svg",Vector2(320,450));preview.offset=Vector2(-64,-160);preview.modulate=Color(1,1,1,.5);preview.z_index=2001
		rect(cabin,"TopShade",Vector2.ZERO,Vector2(1280,148),Color("172d43"))
		label(cabin,"CabinTitle","我的小船　／　把漂泊的地方，佈置成家",Vector2(28,16),27)
		label(cabin,"CabinSubtitle","暖木、海色與一點來自異星的綠。家具樣品可免費試擺。",Vector2(30,55),16)
		button(cabin,"Lamp","暖光立燈",28,130);button(cabin,"Plant","異星盆栽",166,130)
		button(cabin,"Chair","木製躺椅",304,130);button(cabin,"Shelf","收藏層架",442,130)
		button(cabin,"Move","移動",590,92);button(cabin,"Remove","收回",690,92)
		button(cabin,"WarmLights","船外暖燈 · 2 素材",800,245);button(cabin,"ExitCabin","完成  [ Esc ]",1063,188)
		rect(cabin,"BottomShade",Vector2(0,615),Vector2(1280,105),Color("172d43"))
		label(cabin,"CabinStatus","已佈置 0 / 20",Vector2(30,629),20)
		label(cabin,"CabinHelp","點地板放置；R 翻轉；右鍵取消預覽。",Vector2(30,672),17)
		if not B.save_scene(cabin,"res://scenes/cabin.tscn").ok:quit(1);return
	if not FileAccess.file_exists("res://scenes/depth_layers.tscn"):
		var depth:=CanvasLayer.new();depth.name="DepthLayers";depth.layer=-7;depth.set_script(load("res://scripts/depth_layers.gd"))
		var mid:=Node2D.new();mid.position=Vector2(0,302);add(depth,mid,"MidShore")
		sprite(mid,"DistantForest","midshore.svg",Vector2.ZERO)
		var foreground:=CanvasLayer.new();foreground.layer=1;add(depth,foreground,"ForegroundLayer")
		var near:=Node2D.new();near.position=Vector2(0,460);add(foreground,near,"NearPlants")
		var plants:=sprite(near,"ForegroundPlants","foreground.svg",Vector2.ZERO)
		var wind:=ShaderMaterial.new();wind.shader=load("res://assets/foliage.gdshader");wind.set_shader_parameter("sway",3.0);plants.material=wind
		if not B.save_scene(depth,"res://scenes/depth_layers.tscn").ok:quit(1);return
	var game:Node=B.instance("res://scenes/harbor.tscn")
	if game.has_node("CabinLayer"):game.free();quit();return
	var layer:=CanvasLayer.new();layer.layer=4;layer.name="CabinLayer";game.add_child(layer)
	add(layer,B.instance("res://scenes/cabin.tscn"),"Cabin")
	add(game,B.instance("res://scenes/depth_layers.tscn"),"DepthLayers")
	game.get_node("HUD").layer=3
	game.get_node("%HomeButton").text="船艙佈置  [ H ]"
	for item:Node in game.get_node("World").get_children():
		if item is Sprite2D and item.name.begins_with("AlienTree"):
			var wind:=ShaderMaterial.new();wind.shader=load("res://assets/foliage.gdshader");wind.set_shader_parameter("phase",item.position.x*.01);item.material=wind
	var result:=B.save_scene(game,"res://scenes/harbor.tscn",{"overwrite":true,"expected_refs":["res://scenes/player.tscn","res://scenes/mira.tscn","res://scenes/fishing.tscn","res://scenes/cabin.tscn","res://scenes/depth_layers.tscn"]})
	quit(0 if result.ok else 1)
