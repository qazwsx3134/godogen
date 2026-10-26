extends Node2D

const AtomicFile=preload("res://addons/proto_kit/atomic_file.gd")
const Synth=preload("res://addons/proto_kit/synth.gd")
const Card=preload("res://scenes/fish_card.tscn")
const FISH=["潮光魚","莓月魟","蜂蜜鰭","霧藍鯉","珊瑚吻","星紗鰻"]
const DESCRIPTIONS=["像把月亮的一小片帶回岸邊。","喜歡有發光水草的安靜角落。","鱗片裡藏著薄暮的金色。","湖面起霧時，牠就會出現。","給牠一點耐心，牠會靠近。","在遠岸等候的，一封星空來信。"]
enum Phase {IDLE,ACTIVE,CAUGHT}
var phase: Phase=Phase.IDLE
var clock:=0.0
var phase_time:=0.0
var auto_fish:=false
var coins:=0
var materials:=0
var caught:=0
var friendship:=0
var gifted_today:=false
var decorated:=false
var inventory: Array=[0,0,0,0,0,0]
var discovered: Array=[false,false,false,false,false,false]
var recent_fish:=0
var toast_time:=0.0
var has_talked:=false
var testing:=false
var rng:=RandomNumberGenerator.new()
var walk_target:=-1.0
var approach_mira:=false
var furnishings: Array=[{"kind":0,"x":320,"y":448,"flip":false},{"kind":1,"x":960,"y":448,"flip":false},{"kind":2,"x":448,"y":512,"flip":false}]

func _ready() -> void:
	testing=OS.get_cmdline_user_args().has("--smoke-test")
	rng.randomize()
	if not testing: load_progress()
	%FishButton.pressed.connect(fish_action)
	%Fishing.landed.connect(land_fish)
	%Fishing.closed.connect(func():auto_fish=false;%AutoButton.text="輔助釣魚  [ Tab ]";enter_phase(Phase.IDLE))
	%Fishing.assistance_changed.connect(func(enabled: bool):auto_fish=enabled;%AutoButton.text="輔助示範中 · Tab 停止" if enabled else "輔助釣魚  [ Tab ]")
	%AutoButton.pressed.connect(toggle_auto)
	%BookButton.pressed.connect(toggle_book)
	%CloseBook.pressed.connect(func():%Journal.hide())
	%RecycleButton.pressed.connect(recycle)
	%HomeButton.pressed.connect(toggle_cabin)
	%Cabin.layout_changed.connect(func(layout: Array):furnishings=layout;save_progress())
	%Cabin.upgrade_requested.connect(decorate)
	%GiftButton.pressed.connect(gift)
	%CloseDialog.pressed.connect(func():%Dialog.hide())
	for i in range(6):
		var card:=Card.instantiate()
		%FishGrid.add_child(card)
		card.get_node("Content/Picture").texture=load("res://assets/fish%d.svg"%i)
	update_ui()
	if not testing:
		var song:=Synth.notes([196.0,246.94,293.66,369.99,329.63,293.66,246.94,220.0],1.2,true)
		song.loop_mode=AudioStreamWAV.LOOP_FORWARD;song.loop_end=song.data.size()/2
		%Ambient.stream=song;%Ambient.play()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_SPACE:fish_action()
		KEY_TAB:toggle_auto()
		KEY_B:toggle_book()
		KEY_E:talk()
		KEY_H:toggle_cabin()
		KEY_ESCAPE:
			%Journal.hide();%Dialog.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if phase==Phase.IDLE and not %Journal.visible and not %Dialog.visible and not %Cabin.active:
			walk_target=clampf(get_global_mouse_position().x,80,2310)
			approach_mira=absf(walk_target-1040)<50

func _process(delta: float) -> void:
	clock+=delta;phase_time+=delta
	if toast_time>0:
		toast_time-=delta
		%ToastPanel.visible=toast_time>0
	var modal: bool=%Journal.visible or %Dialog.visible or %Cabin.active
	var direction:=0.0
	if not modal and phase==Phase.IDLE and not testing:
		direction=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		if direction:walk_target=-1;approach_mira=false
		elif walk_target>=0:
			if absf(walk_target-%Player.position.x)<4:
				walk_target=-1
				if approach_mira:approach_mira=false;talk()
			else:direction=signf(walk_target-%Player.position.x)
	%Player.position.x=clampf(%Player.position.x+direction*180*delta,80,2310)
	var body: Sprite2D=%Player.get_node("Body")
	body.position.y=-74+sin(clock*(11 if direction else 2))* (2 if direction else 0.7)
	if direction:body.flip_h=direction<0
	%Camera.position.x=clampf(%Player.position.x,640,1760)
	%Islands.position.x=-(%Camera.position.x-640)*0.2
	%DepthLayers.follow(%Camera.position.x)
	%HomeBoat.position.y=314+sin(clock*.8)*1.5
	%HomeLights.visible=decorated
	%SceneHint.text="霧光蘆葦灣　／　遠岸有稀有魚影" if %Player.position.x>1500 else "薄暮海灣　／　這裡沒有需要趕上的時間。"
	if absf(%Player.position.x-1040)<125 and phase==Phase.IDLE:
		%SceneHint.text="米菈在看潮汐。按 E 和她說說話。"
	if auto_fish and not modal and phase==Phase.IDLE:fish_action()


func enter_phase(next: Phase) -> void:
	phase=next;phase_time=0
	%Rod.hide();%Bobber.hide();%FishingLine.hide()
	%CatchCard.visible=phase==Phase.CAUGHT and not %Fishing.active
	%FishButton.text="釣魚  [ 空白鍵 ]"

func fish_action() -> void:
	if %Journal.visible or %Dialog.visible or %Fishing.active or %Cabin.active:return
	enter_phase(Phase.ACTIVE)
	%Fishing.begin(auto_fish,%Player.position.x>1500)
	sound([293.66,196.0])

func land_fish(kind: int = -1) -> void:
	var pool: Array=[0,0,0,1,2,3] if %Player.position.x<1500 else [1,2,3,4,5,5]
	recent_fish=clampi(kind,0,5) if kind>=0 else int(pool[rng.randi_range(0,pool.size()-1)])
	var first:=not bool(discovered[recent_fish])
	inventory[recent_fish]+=1;discovered[recent_fish]=true;caught+=1
	%CatchPicture.texture=load("res://assets/fish%d.svg"%recent_fish)
	%CatchName.text=FISH[recent_fish]+"　✦" if first else FISH[recent_fish]
	%CatchDetail.text=("初次遇見，收錄圖鑑！" if first else "又收到海灣的一封來信。")+"  %.1f cm"%rng.randf_range(12,44)
	%Fishing.result_text=FISH[recent_fish]+"　｜　"+%CatchDetail.text
	enter_phase(Phase.CAUGHT)
	sound([392.0,493.88,587.33])
	update_ui();save_progress()

func toggle_auto() -> void:
	auto_fish=not auto_fish
	%AutoButton.text="輔助示範中 · Tab 停止" if auto_fish else "輔助釣魚  [ Tab ]"
	toast("輔助模式會示範拋竿、誘魚、控線與角力。" if auto_fish else "回到手動操作。")
	if %Fishing.active:%Fishing.assist=auto_fish

func toggle_book() -> void:
	if %Fishing.active or %Cabin.active:return
	%Dialog.hide();%Journal.visible=not %Journal.visible;update_ui()

func recycle() -> void:
	var count:=0
	for i in range(6):
		var extras:=maxi(0,int(inventory[i])-1)
		count+=extras;inventory[i]-=extras
	coins+=count*12;materials+=count*2
	toast("保留每種第一尾；重複魚換得 %d 星砂與 %d 素材。"%[count*12,count*2] if count else "還沒有重複的魚，再去海邊坐坐吧。")
	update_ui();save_progress()

func talk() -> void:
	if %Cabin.active:return
	if phase!=Phase.IDLE:toast("先把這尾魚釣完，再和米菈聊天吧。");return
	if absf(%Player.position.x-1040)>125:toast("向右走到米菈身旁，再按 E 交談。");return
	%Journal.hide();%Dialog.show()
	if not has_talked:friendship+=1;has_talked=true
	update_dialog();update_ui();save_progress()

func update_dialog() -> void:
	%DialogName.text="米菈　／　潮汐觀測員　♡ %d"%friendship
	%DialogText.text="你聽，這裡的潮聲比鐘聲慢一點。\n如果釣到喜歡的魚，可以留一尾給我嗎？" if friendship<3 else "謝謝你留下的魚。我把今天最漂亮的一段潮聲，\n留在了你的船邊。明天也一起看海吧。"
	%GiftButton.disabled=gifted_today
	%GiftButton.text="這份心意已收到" if gifted_today else "送她一尾魚"

func gift() -> void:
	if gifted_today:return
	for i in range(6):
		if inventory[i]>0:
			inventory[i]-=1;friendship+=2;materials+=2;gifted_today=true
			update_dialog();update_ui();save_progress();toast("米菈收下了心意，送你 2 份素材。");return
	toast("帶一尾魚來就好，她不著急。")

func decorate() -> void:
	if decorated:toast("你的小船已亮起暖燈。今晚可以多待一會兒。");return
	if materials<2:toast("需要 2 份素材：分解重複魚，或送米菈一尾魚。");return
	materials-=2;decorated=true;update_ui();save_progress();toast("暖燈亮起，小船有了家的樣子。")

func toggle_cabin() -> void:
	if %Fishing.active:return
	if %Cabin.active:%Cabin.stop();return
	%Journal.hide();%Dialog.hide();walk_target=-1;auto_fish=false
	%AutoButton.text="輔助釣魚  [ Tab ]"
	%Cabin.begin(furnishings)

func update_ui() -> void:
	%Resources.text="星砂 %d　｜　素材 %d　｜　圖鑑 %d / 6"%[coins,materials,discovered.count(true)]
	%Quest.text="今日小願望已完成。剩下的時間，留給海。" if caught>=3 and has_talked else "今日小願望：魚 %d / 3　·　認識米菈 %s"%[mini(caught,3),"✓" if has_talked else "○"]
	for i in range(%FishGrid.get_child_count()):
		var card:Node=%FishGrid.get_child(i)
		card.get_node("Content/Picture").modulate=Color.WHITE if discovered[i] else Color(0.3,0.4,0.48,0.5)
		card.get_node("Content/FishName").text=FISH[i] if discovered[i] else "尚未遇見"
		card.get_node("Content/FishCount").text="持有 %d 尾　·　%s"%[inventory[i],"海灣" if i<4 else "遠岸"]
	%HomeButton.text="船艙佈置  [ H ]"
	%Cabin.get_node("%WarmLights").text="船外暖燈已點亮" if decorated else "船外暖燈 · 2 素材"

func toast(message: String) -> void:
	if %Cabin.active:%Cabin.get_node("%CabinStatus").text=message
	%ToastText.text=message;%ToastPanel.show();toast_time=4

func sound(notes: Array) -> void:
	if testing:return
	%SFX.stream=Synth.notes(notes,.12,true);%SFX.play()

func save_progress() -> void:
	if testing:return
	var data:Dictionary={"version":1,"inventory":inventory,"discovered":discovered,"coins":coins,"materials":materials,"caught":caught,"friendship":friendship,"gifted":gifted_today,"talked":has_talked,"decorated":decorated,"furnishings":furnishings}
	var err:=AtomicFile.write_text("user://harbor-v1.json",JSON.stringify(data))
	if err!=OK:toast("這次沒有成功存檔，請保留視窗稍後再試。")

func load_progress() -> void:
	var path:="user://harbor-v1.json"
	if not FileAccess.file_exists(path):return
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version")!=1:return
	if not data.get("inventory") is Array or data.inventory.size()!=6:return
	if not data.get("discovered") is Array or data.discovered.size()!=6:return
	for i in range(6):
		inventory[i]=maxi(0,int(data.inventory[i]));discovered[i]=bool(data.discovered[i])
	coins=maxi(0,int(data.get("coins",0)));materials=maxi(0,int(data.get("materials",0)))
	if data.get("furnishings") is Array:furnishings=data.furnishings
	caught=maxi(0,int(data.get("caught",0)));friendship=maxi(0,int(data.get("friendship",0)))
	gifted_today=bool(data.get("gifted",false));has_talked=bool(data.get("talked",false));decorated=bool(data.get("decorated",false))
