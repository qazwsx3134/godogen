extends Control
## Original simplified decoration workflow, not verified Orion Blue editing controls.
signal layout_changed(layout: Array)
signal upgrade_requested
signal closed
const Furniture=preload("res://scenes/furniture.tscn")
const TITLES=["暖光立燈","異星盆栽","木製躺椅","收藏層架"]
enum Mode { PLACE, MOVE, REMOVE }
@export var item_limit: int = 20
var active := false
var mode: Mode = Mode.PLACE
var selected_kind := 1
var flipped := false
var moving: Node2D
var cursor := Vector2i.ZERO

func _ready() -> void:
	%Lamp.pressed.connect(func():choose(0))
	%Plant.pressed.connect(func():choose(1))
	%Chair.pressed.connect(func():choose(2))
	%Shelf.pressed.connect(func():choose(3))
	%Move.pressed.connect(func():set_mode(Mode.MOVE))
	%Remove.pressed.connect(func():set_mode(Mode.REMOVE))
	%WarmLights.pressed.connect(func():upgrade_requested.emit())
	%ExitCabin.pressed.connect(stop)
	hide()

func begin(layout: Array) -> void:
	apply_layout(layout);active=true;show();choose(1)

func stop() -> void:
	active=false;moving=null;hide();closed.emit()

func choose(kind: int) -> void:
	selected_kind=clampi(kind,0,3);flipped=false;set_mode(Mode.PLACE)

func set_mode(value: Mode) -> void:
	mode=value;moving=null
	%CabinHelp.text="點地板放置 %s；R 翻轉；右鍵取消預覽。"%TITLES[selected_kind] if mode==Mode.PLACE else ("點選物件，再點空格移動；右鍵取消移動。" if mode==Mode.MOVE else "點選物件收回；預設家具可免費再放。")

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x-160)/64),floori((point.y-352)/64))

func valid_cell(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.x<15 and cell.y>=0 and cell.y<4

func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(192+cell.x*64,384+cell.y*64)

func item_at(cell: Vector2i) -> Node2D:
	for item:Node2D in %Placed.get_children():
		if cell_at(item.position-Vector2(0,1))==cell:return item
	return null

func hit_item(point: Vector2) -> Node2D:
	var picked:Node2D
	for item:Node2D in %Placed.get_children():
		var art:Sprite2D=item.get_node("Art")
		if art.get_rect().has_point(art.to_local(point)) and (picked==null or item.position.y>=picked.position.y):picked=item
	return picked

func place(cell: Vector2i, kind: int, mirror: bool = false) -> bool:
	if not valid_cell(cell) or item_at(cell)!=null or %Placed.get_child_count()>=item_limit:return false
	var item:Node2D=Furniture.instantiate();item.position=cell_position(cell)
	%Placed.add_child(item);item.configure(kind,mirror)
	return true

func edit_cell(cell: Vector2i) -> bool:
	if not valid_cell(cell):return false
	var item:=item_at(cell)
	var changed:=false
	match mode:
		Mode.PLACE:changed=place(cell,selected_kind,flipped)
		Mode.MOVE:
			if moving==null:
				moving=item
				if moving!=null:selected_kind=moving.kind;flipped=moving.flipped
			elif item==null:
				moving.position=cell_position(cell);moving.configure(moving.kind,moving.flipped);moving=null;changed=true
		Mode.REMOVE:
			if item!=null:%Placed.remove_child(item);item.queue_free();changed=true
	if changed:layout_changed.emit(export_layout())
	%CabinStatus.text="已佈置 %d / %d　｜　%s"%[%Placed.get_child_count(),item_limit,"已保存" if changed else "選擇空格或物件"]
	return changed

func export_layout() -> Array:
	var result:Array=[]
	for item:Node2D in %Placed.get_children():
		result.append({"kind":item.kind,"x":item.position.x,"y":item.position.y,"flip":item.flipped})
	return result

func apply_layout(layout: Array) -> void:
	for item:Node in %Placed.get_children():%Placed.remove_child(item);item.queue_free()
	for value:Variant in layout.slice(0,item_limit):
		if not value is Dictionary:continue
		var kind:=int(value.get("kind",-1))
		if kind<0 or kind>3:continue
		place(cell_at(Vector2(float(value.get("x",-999)),float(value.get("y",-999)))-Vector2(0,1)),kind,bool(value.get("flip",false)))
	%CabinStatus.text="已佈置 %d / %d　｜　家具樣品免費使用"%[%Placed.get_child_count(),item_limit]

func _input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:stop()
		elif event.keycode==KEY_R:flipped=not flipped
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.position.y<150 or event.position.y>610:return
		if event.pressed:
			if event.button_index==MOUSE_BUTTON_LEFT:
				var picked:=hit_item(event.position) if mode!=Mode.PLACE and moving==null else null
				edit_cell(cell_at(picked.position-Vector2(0,1)) if picked!=null else cell_at(event.position))
			elif event.button_index==MOUSE_BUTTON_RIGHT:moving=null;set_mode(Mode.MOVE)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not active:return
	cursor=cell_at(get_global_mouse_position())
	var can_preview:=valid_cell(cursor) and (mode==Mode.PLACE or moving!=null)
	%Preview.visible=can_preview
	%CursorCell.visible=valid_cell(cursor)
	if not valid_cell(cursor):return
	%CursorCell.position=cell_position(cursor)-Vector2(30,29)
	%CursorCell.color=Color(.4,.9,.78,.16) if item_at(cursor)==null else Color(1,.4,.35,.2)
	if can_preview:
		%Preview.position=cell_position(cursor)
		%Preview.texture=load("res://assets/prop_%s.svg"%["lamp","plant","chair","shelf"][selected_kind])
		%Preview.flip_h=flipped
		%Preview.modulate=Color(1,1,1,.55) if item_at(cursor)==null else Color(1,.5,.5,.45)
