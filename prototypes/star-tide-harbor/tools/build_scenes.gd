extends SceneTree
## One-time authoring tool. Existing scenes are skipped to preserve editor changes.
const Builder = preload("res://addons/proto_kit/scene_builder.gd")
var theme: Theme

func _initialize() -> void:
	build.call_deferred()

func add(parent: Node, node: Node, title: String, unique := false) -> Node:
	node.name = title
	if unique: Builder.unique(node)
	parent.add_child(node)
	return node

func sprite(parent: Node, title: String, asset: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/" + asset)
	s.centered = false
	s.position = pos
	return add(parent, s, title) as Sprite2D

func style(color: Color, border := Color("8faaa6")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color; s.border_color=border
	s.set_border_width_all(1); s.set_corner_radius_all(8)
	s.content_margin_left=16; s.content_margin_right=16
	s.content_margin_top=9; s.content_margin_bottom=9
	return s

func panel(parent: Node, title: String, pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position=pos; p.size=size
	return add(parent,p,title,true) as PanelContainer

func label(parent: Node, title: String, text: String, font_size := 18) -> Label:
	var l := Label.new()
	l.text=text; l.add_theme_font_size_override("font_size",font_size)
	return add(parent,l,title,true) as Label

func button(parent: Node, title: String, text: String) -> Button:
	var b := Button.new()
	b.text=text; b.custom_minimum_size=Vector2(110,44)
	b.focus_mode=Control.FOCUS_NONE
	return add(parent,b,title,true) as Button

func box(parent: Node, title: String, vertical := true) -> BoxContainer:
	var b: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	b.add_theme_constant_override("separation",12)
	return add(parent,b,title) as BoxContainer

func build() -> void:
	theme=Theme.new()
	theme.default_font=load("res://assets/ui_font.ttf")
	theme.default_font_size=18
	theme.set_color("font_color","Label",Color("f7eed9"))
	theme.set_color("font_color","Button",Color("273f54"))
	theme.set_color("font_hover_color","Button",Color("273f54"))
	theme.set_stylebox("panel","PanelContainer",style(Color("293f54ed")))
	theme.set_stylebox("normal","Button",style(Color("d9d9b8")))
	theme.set_stylebox("hover","Button",style(Color("f3dfb2")))
	theme.set_stylebox("pressed","Button",style(Color("9cbeb1")))
	theme.set_stylebox("background","ProgressBar",style(Color("1d3146")))
	theme.set_stylebox("fill","ProgressBar",style(Color("a6cdb5")))
	ResourceSaver.save(theme,"res://assets/harbor_theme.tres")
	for character in ["player","mira"]:
		var actor := Node2D.new()
		actor.name=character.capitalize()
		var body := sprite(actor,"Body",character+".svg",Vector2(-24,-74))
		Builder.unique(body)
		Builder.save_scene(actor,"res://scenes/"+character+".tscn")
	var card := PanelContainer.new()
	card.name="FishCard";card.theme=theme;card.custom_minimum_size=Vector2(235,136)
	var cb:=box(card,"Content")
	var picture := TextureRect.new()
	picture.custom_minimum_size=Vector2(100,52);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture=load("res://assets/fish0.svg")
	add(cb,picture,"Picture",true)
	label(cb,"FishName","潮光魚",19)
	label(cb,"FishCount","尚未發現",15)
	Builder.save_scene(card,"res://scenes/fish_card.tscn")
	var root := Node2D.new()
	root.name="Harbor"
	root.set_script(load("res://scripts/harbor.gd"))
	var bg:=add(root,CanvasLayer.new(),"Background") as CanvasLayer
	bg.layer=-10
	sprite(bg,"Sky","sky.svg",Vector2.ZERO)
	var islands:=sprite(bg,"Islands","islands.svg",Vector2.ZERO)
	Builder.unique(islands)
	var water:=sprite(bg,"Water","water.svg",Vector2(0,480))
	var material:=ShaderMaterial.new();material.shader=load("res://assets/water.gdshader")
	water.material=material
	var world:=add(root,Node2D.new(),"World",true) as Node2D
	for x in [80,1330,1850,2240]:
		sprite(world,"AlienTree%d"%x,"tree.svg",Vector2(x,245))
	var reflection:=sprite(world,"BoatReflection","boat.svg",Vector2(190,785))
	reflection.scale=Vector2(1,-0.85);reflection.modulate=Color(0.65,0.8,0.84,0.2)
	var boat:=sprite(world,"HomeBoat","boat.svg",Vector2(190,314))
	Builder.unique(boat)
	sprite(world,"Pier","pier.svg",Vector2(0,521))
	for i in range(25):
		var reeds:=sprite(world,"Reeds%02d"%i,"reeds%d.svg"%(i%4),Vector2(i*99,570+(i%3)*10))
		reeds.modulate=Color(0.8,0.9,0.9,0.8)
	var mira:=Builder.instance("res://scenes/mira.tscn") as Node2D
	add(world,mira,"Mira",true);mira.position=Vector2(1040,521)
	var player:=Builder.instance("res://scenes/player.tscn") as Node2D
	add(world,player,"Player",true);player.position=Vector2(690,521)
	var rod:=Line2D.new();rod.width=3;rod.default_color=Color("e5d1ac")
	rod.points=PackedVector2Array([Vector2(707,481),Vector2(751,430)])
	add(world,rod,"Rod",true);rod.visible=false
	var line:=Line2D.new();line.width=1.2;line.default_color=Color("fff3d1")
	add(world,line,"FishingLine",true)
	var bob:=Sprite2D.new();bob.texture=load("res://assets/fish2.svg")
	bob.scale=Vector2(.13,.2);bob.visible=false
	add(world,bob,"Bobber",true)
	var camera:=Camera2D.new();camera.position=Vector2(690,360)
	camera.position_smoothing_enabled=false
	add(root,camera,"Camera",true)
	var hud:=add(root,CanvasLayer.new(),"HUD")
	var screen:=add(hud,Control.new(),"Screen") as Control
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.theme=theme
	var title:=panel(screen,"TitlePanel",Vector2(28,24),Vector2(280,104))
	var tb:=box(title,"TitleContent")
	label(tb,"Title","星 潮 小 港",28)
	label(tb,"Subtitle","STAR TIDE HARBOR  /  薄暮海灣",12)
	var status:=panel(screen,"StatusPanel",Vector2(850,24),Vector2(400,96))
	var sb:=box(status,"StatusContent")
	label(sb,"Resources","星砂 0　｜　素材 0　｜　圖鑑 0 / 6",17)
	label(sb,"Quest","今日小願望：釣起 3 尾魚，認識米菈",14)
	var hint:=label(screen,"SceneHint","這裡沒有需要趕上的時間。",17)
	hint.position=Vector2(30,145);hint.modulate=Color("f1dbc6")
	var action:=panel(screen,"ActionPanel",Vector2(28,628),Vector2(1224,66))
	var ab:=box(action,"Actions",false)
	label(ab,"WalkHint","A / D 散步　｜　E 交談",16)
	ab.add_spacer(false)
	button(ab,"FishButton","拋竿  [ 空白鍵 ]")
	button(ab,"AutoButton","放置釣魚  [ Tab ]")
	button(ab,"BookButton","魚類圖鑑  [ B ]")
	button(ab,"HomeButton","小船佈置")
	var fishing:=panel(screen,"FishingPanel",Vector2(420,483),Vector2(440,130))
	fishing.visible=false
	var fb:=box(fishing,"FishingContent")
	label(fb,"FishingTitle","等一個來自海裡的問候…",19)
	var meter:=Control.new();meter.custom_minimum_size=Vector2(400,22)
	add(fb,meter,"Meter")
	var track:=ColorRect.new();track.color=Color("1b3047");track.size=Vector2(400,20)
	add(meter,track,"Track")
	var target:=ColorRect.new();target.color=Color("83bca7");target.position=Vector2(150,0);target.size=Vector2(110,20)
	add(meter,target,"Target",true)
	var hook:=ColorRect.new();hook.color=Color("ffdf9c");hook.position=Vector2(190,-3);hook.size=Vector2(7,26)
	add(meter,hook,"Hook",true)
	var progress:=ProgressBar.new();progress.custom_minimum_size=Vector2(400,12);progress.show_percentage=false
	add(fb,progress,"CatchProgress",true)
	label(fb,"FishingHelp","咬鉤後按空白鍵；收線時按住往右，放開往左。",12)
	var journal:=panel(screen,"Journal",Vector2(228,140),Vector2(824,448))
	journal.visible=false
	var jb:=box(journal,"JournalContent")
	label(jb,"JournalTitle","海灣的六封來信　／　魚類圖鑑",24)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",12)
	add(jb,grid,"FishGrid",true)
	var jr:=box(jb,"JournalActions",false)
	button(jr,"RecycleButton","分解重複魚 → 星砂與素材")
	button(jr,"CloseBook","回到海邊")
	var dialog:=panel(screen,"Dialog",Vector2(340,348),Vector2(600,260))
	dialog.visible=false
	var db:=box(dialog,"DialogContent")
	label(db,"DialogName","米菈　／　潮汐觀測員",22)
	var dialogue:=label(db,"DialogText","",17)
	dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size=Vector2(560,86)
	var dr:=box(db,"DialogActions",false)
	button(dr,"GiftButton","送她一尾魚")
	button(dr,"CloseDialog","下次再聊")
	var result:=panel(screen,"CatchCard",Vector2(448,260),Vector2(384,193))
	result.visible=false
	var rb:=box(result,"CatchContent")
	var fishpic:=TextureRect.new();fishpic.custom_minimum_size=Vector2(100,70);fishpic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;fishpic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add(rb,fishpic,"CatchPicture",true)
	label(rb,"CatchName","潮光魚",25)
	label(rb,"CatchDetail","第一次遇見！已收錄圖鑑",15)
	var toast:=panel(screen,"ToastPanel",Vector2(390,190),Vector2(500,54))
	toast.visible=false
	label(toast,"ToastText","",16)
	var lights:=add(world,Node2D.new(),"HomeLights",true) as Node2D
	lights.visible=false
	for x in range(240,560,32):
		var light:=Polygon2D.new();light.polygon=PackedVector2Array([Vector2(-3,0),Vector2(3,0),Vector2(5,8),Vector2(-5,8)])
		light.color=Color("ffdda3");light.position=Vector2(x,365+sin(x)*5)
		add(lights,light,"Lamp%d"%x)
	var music:=AudioStreamPlayer.new();music.volume_db=-24
	add(root,music,"Ambient",true)
	var sfx:=AudioStreamPlayer.new();sfx.volume_db=-18
	add(root,sfx,"SFX",true)
	var saved:=Builder.save_scene(root,"res://scenes/harbor.tscn",{"expected_refs":["res://scenes/player.tscn","res://scenes/mira.tscn"]})
	quit(0 if saved.ok else 1)
