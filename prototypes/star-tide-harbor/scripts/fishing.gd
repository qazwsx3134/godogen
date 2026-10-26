extends Control
## Numerical tuning is original prototype design, not measured Orion Blue values.
signal landed(kind: int)
signal closed
signal assistance_changed(enabled: bool)
enum Stage { AIM, CAST, LURE, FIGHT, STRUGGLE, RESULT, FAILED }
@export var reel_speed: float = 66.0
@export var release_speed: float = 85.0
@export var attraction_radius: float = 240.0
@export var break_grace: float = 1.2
@export var struggle_taps: int = 7
var stage: Stage = Stage.AIM
var active := false
var assist := false
var age := 0.0
var elapsed := 0.0
var bait := Vector2(700, 410)
var cast_target := Vector2(700, 410)
var cast_start := Vector2(230, 180)
var spool := 520.0
var tension := 0.0
var danger := 0.0
var slack := 0.0
var interest := 0.0
var lure_motion := 0.0
var distance_left := 460.0
var next_struggle := 4.5
var taps := 0
var struggle_elapsed := 0.0
var fish_index := 0
var left_held := false
var right_held := false
var tap_cooldown := 0.0
var result_text := ""
var far_shore := false
var fish_types: Array = [0,0,1,2,3,3]

func _ready() -> void:
	%Leave.pressed.connect(stop)
	hide()

func begin(helped: bool = false, far: bool = false) -> void:
	assist=helped;active=true;left_held=false;right_held=false
	far_shore=far
	fish_types=[1,2,3,4,5,5] if far else [0,0,1,2,3,3]
	tension=0;danger=0;slack=0;interest=0;lure_motion=0;distance_left=460
	spool=520;fish_index=2;next_struggle=4.5
	for i in range(%Shoal.get_child_count()):
		%Shoal.get_child(i).position=Vector2(450+i*135,380+(i%3)*78)
		%Shoal.get_child(i).texture=load("res://assets/fish%d.svg"%fish_types[i])
	set_stage(Stage.AIM);show()

func stop() -> void:
	active=false;hide();left_held=false;right_held=false;closed.emit()

func set_stage(value: Stage) -> void:
	stage=value;age=0
	if value==Stage.STRUGGLE:
		taps=0;struggle_elapsed=0

func cast_at(point: Vector2) -> void:
	if not active or stage!=Stage.AIM:return
	cast_target=Vector2(clampf(point.x,330,1160),clampf(point.y,330,600))
	spool=cast_start.distance_to(cast_target)
	bait=cast_start;set_stage(Stage.CAST)

func tap() -> void:
	if stage==Stage.STRUGGLE and tap_cooldown<=0:
		taps+=1;tap_cooldown=.09

func _input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_S]:stop()
		elif event.keycode==KEY_TAB:
			assist=not assist;assistance_changed.emit(assist)
		elif event.keycode==KEY_SPACE:
			if stage==Stage.AIM:cast_at(get_global_mouse_position())
			elif stage==Stage.STRUGGLE:tap()
			elif stage in [Stage.RESULT,Stage.FAILED]:begin(assist,far_shore)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if %Leave.get_global_rect().has_point(event.position):return
		if event.button_index==MOUSE_BUTTON_LEFT:
			left_held=event.pressed
			if event.pressed:
				if stage==Stage.AIM:cast_at(event.position)
				elif stage==Stage.STRUGGLE:tap()
				elif stage in [Stage.RESULT,Stage.FAILED]:begin(assist,far_shore)
		elif event.button_index==MOUSE_BUTTON_RIGHT:right_held=event.pressed
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:return
	var pull := left_held or Input.is_physical_key_pressed(KEY_SPACE)
	step(delta,pull,right_held)

func step(delta: float, pull: bool, release: bool) -> void:
	age+=delta;elapsed+=delta;tap_cooldown=maxf(0,tap_cooldown-delta)
	match stage:
		Stage.AIM:
			%Aim.position=Vector2(clampf(get_global_mouse_position().x,330,1160),clampf(get_global_mouse_position().y,330,600))
			if assist and age>.9:cast_at(Vector2(720,460))
		Stage.CAST:
			var t:=clampf(age/.9,0,1)
			bait=cast_start.lerp(cast_target,t)+Vector2(0,-sin(t*PI)*160)
			if t>=1:set_stage(Stage.LURE)
		Stage.RESULT,Stage.FAILED:
			if assist and age>2.5:begin(true,far_shore)
		Stage.LURE:
			if assist:
				pull=fmod(age,2.0)<.5;release=fmod(age,2.0)>1.2
			var old:=bait
			if pull and not release:spool=maxf(250,spool-reel_speed*delta)
			elif release:spool=minf(1080,spool+release_speed*delta)
			var ray:=(cast_target-cast_start).normalized()
			var desired:=cast_start+ray*spool
			desired.y=clampf(desired.y+sin(elapsed*2)*4,300,620)
			bait=bait.move_toward(desired,90*delta)
			lure_motion=move_toward(lure_motion,1.0 if pull or release else 0.0,delta*2)
			var closest:=99999.0
			for i in range(%Shoal.get_child_count()):
				var fish:Sprite2D=%Shoal.get_child(i)
				var d:=fish.position.distance_to(bait)
				if d<attraction_radius and lure_motion>.1:
					fish.position=fish.position.move_toward(bait,delta*(32+interest*.35))
				else:fish.position+=Vector2(sin(elapsed*.3+i)*delta*12,cos(elapsed+i)*delta*3)
				fish.flip_h=fish.position.x>bait.x
				if d<closest:closest=d;fish_index=i
			if closest<attraction_radius and lure_motion>.1:interest=minf(100,interest+delta*15)
			else:interest=maxf(0,interest-delta*7)
			tension=clampf(old.distance_to(bait)/maxf(delta,.001)/400,0,.35)
			if closest<48 and interest>=65:
				tension=.35;distance_left=maxf(280,bait.distance_to(cast_start));set_stage(Stage.FIGHT)
		Stage.FIGHT,Stage.STRUGGLE:
			if assist:
				pull=tension<.62;release=tension>.65
				if stage==Stage.STRUGGLE:tap()
			var surge:=.10+maxf(0,sin(age*2.2))*.22
			tension=clampf(tension+delta*(surge+(.32 if pull else -.12)-(.64 if release else 0)),0,1)
			if stage==Stage.FIGHT:
				if pull and not release and tension<.88:distance_left-=delta*reel_speed
				elif release:distance_left+=delta*release_speed*.32
				next_struggle-=delta
				if next_struggle<=0:set_stage(Stage.STRUGGLE)
			else:
				struggle_elapsed+=delta
				if taps>=struggle_taps:
					distance_left-=95;tension=maxf(.12,tension-.20);next_struggle=5.5;set_stage(Stage.FIGHT)
				elif struggle_elapsed>=3.8:
					distance_left+=90;tension=minf(.95,tension+.20);next_struggle=5.5;set_stage(Stage.FIGHT)
			danger=danger+delta if tension>=.97 else maxf(0,danger-delta*2)
			slack=slack+delta if tension<=.025 else 0.0
			bait=cast_start+(cast_target-cast_start).normalized()*maxf(100,distance_left)
			spool=maxf(100,distance_left)
			bait.y=maxf(280,bait.y)+sin(elapsed*12)*4
			%Shoal.get_child(fish_index).position=bait+Vector2(22,4)
			if danger>=break_grace:fail("魚線繃斷了。下次試著及早放線。")
			elif slack>=4.0:fail("魚線鬆了太久，魚兒回到了海裡。")
			elif distance_left<=125:
				result_text="釣到了！這尾魚已加入圖鑑。";set_stage(Stage.RESULT);landed.emit(int(fish_types[fish_index]))
	refresh()

func fail(message: String) -> void:
	result_text=message;set_stage(Stage.FAILED)

func refresh() -> void:
	%Aim.visible=stage==Stage.AIM
	%Lure.visible=stage not in [Stage.AIM,Stage.RESULT,Stage.FAILED]
	%Line.visible=%Lure.visible
	%Lure.position=bait
	%Line.default_color=Color("ff8f8c") if tension>.8 else Color("e7ead7")
	var sag:=Vector2(0,lerpf(75,0,tension))
	%Line.points=PackedVector2Array([cast_start,cast_start.lerp(bait,.5)+sag,bait])
	%Tension.value=tension*100
	%Tension.modulate=Color("ff827c") if tension>.8 else Color("85ead6")
	%StruggleBar.visible=stage==Stage.STRUGGLE
	%StruggleBar.value=float(taps)/struggle_taps*100
	%Telemetry.text="線長 %.1f m　｜　張力 %d%%　｜　%s"%[spool/60,tension*100,"輔助操作" if assist else "手動操作"]
	match stage:
		Stage.AIM:
			%StageTitle.text="01　選擇拋竿位置與方向"
			%Instructions.text="點選水域拋竿。落點決定魚餌的方向與起始深度。"
			%Status.text="從固定竿位向海灣拋出魚餌"
		Stage.CAST:
			%StageTitle.text="02　魚餌入水";%Instructions.text="看著魚餌沿拋物線落水。";%Status.text="等待入水…"
		Stage.LURE:
			%StageTitle.text="03　收放魚線，吸引魚兒"
			%Instructions.text="按住左鍵／空白鍵收線；按住右鍵放線。短收、停頓、再放線，讓魚餌在魚群附近活動。"
			%Status.text="魚的興趣 %d%%　｜　先讓附近的魚注意到餌"%interest
		Stage.FIGHT:
			%StageTitle.text="04　中魚了！控制張力"
			%Instructions.text="左鍵收線拉近魚；張力升高時右鍵放線。過緊會斷線，過鬆太久會脫鉤。"
			%Status.text="距離收獲 %.1f m　｜　魚正在拉扯"%maxf(0,(distance_left-125)/60)
		Stage.STRUGGLE:
			%StageTitle.text="05　角力！連點左鍵／空白鍵"
			%Instructions.text="放開再按才算一下；角力期間仍需留意張力，右鍵可放線卸力。"
			%Status.text="角力 %d / %d　｜　剩餘 %.1f 秒"%[taps,struggle_taps,maxf(0,3.8-struggle_elapsed)]
		Stage.RESULT,Stage.FAILED:
			%StageTitle.text="海灣的回信" if stage==Stage.RESULT else "再試一次就好"
			%Instructions.text="點一下再拋一竿；S／Esc 返回小港。"
			%Status.text=result_text
