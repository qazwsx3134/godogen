extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	if not condition:failures.append(message);push_error(message)
func run() -> void:
	var path:="res://scenes/harbor.tscn"
	var before:=FileAccess.get_file_as_string(path)
	var game:Node=load(path).instantiate()
	game.get_node("%Title").text="可編輯場景標題"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.get_node("%Title").text=="可編輯場景標題","Runtime overwrote authored title")
	game.fish_action()
	var fishing:Node=game.get_node("%Fishing")
	fishing.set_process(false)
	check(fishing.active and fishing.stage==fishing.Stage.AIM,"Fishing did not begin with aim selection")
	fishing.cast_at(Vector2(720,460))
	check(fishing.stage==fishing.Stage.CAST,"Chosen target did not start cast")
	fishing.step(1.0,false,false)
	check(fishing.stage==fishing.Stage.LURE,"Cast did not enter underwater lure state")
	var initial_spool:float=fishing.spool
	fishing.step(.2,true,false)
	check(fishing.spool<initial_spool,"Reeling did not shorten line")
	fishing.step(.4,false,true)
	check(fishing.spool>initial_spool,"Releasing did not extend line")
	for i in range(100):fishing.step(.05,false,false)
	check(fishing.stage==fishing.Stage.LURE,"Passive timer created a bite without attracting fish")
	fishing.begin(true)
	for i in range(4000):fishing.step(.05,false,false)
	check(game.caught>=3,"Automatic fishing failed to complete three catches")
	check(game.discovered.count(true)>0,"Catch did not enter collection")
	fishing.assist=false;fishing.set_stage(fishing.Stage.FIGHT);fishing.tension=.6
	fishing.next_struggle=99;fishing.distance_left=500
	fishing.step(.2,true,false)
	check(fishing.tension>.6 and fishing.distance_left<500,"Pull must increase tension and retrieve fish")
	var tight:float=fishing.tension
	fishing.step(.3,false,true)
	check(fishing.tension<tight,"Release must reduce tension")
	fishing.set_stage(fishing.Stage.STRUGGLE);fishing.tension=.4;fishing.distance_left=500
	fishing.tap_cooldown=0;fishing.tap();var once:int=fishing.taps
	fishing.tap()
	check(fishing.taps==once,"One press bypassed tap cooldown")
	for i in range(fishing.struggle_taps):
		fishing.step(.12,false,false);fishing.tap()
	fishing.step(.01,false,false)
	check(fishing.stage==fishing.Stage.FIGHT and fishing.distance_left<500,"Tapping did not win struggle")
	fishing.set_stage(fishing.Stage.FIGHT);fishing.tension=1;fishing.danger=0;fishing.next_struggle=99
	for i in range(40):fishing.step(.05,true,false)
	check(fishing.stage==fishing.Stage.FAILED,"Sustained excessive tension did not break line")
	fishing.set_stage(fishing.Stage.FIGHT);fishing.tension=0;fishing.slack=0
	for i in range(100):fishing.step(.05,false,true)
	check(fishing.stage==fishing.Stage.FAILED,"Sustained slack did not lose fish")
	fishing.stop()
	game.auto_fish=false;game.enter_phase(game.Phase.IDLE)
	game.inventory=[3,0,0,0,0,0];game.discovered=[true,false,false,false,false,false]
	game.coins=0;game.materials=0
	game.recycle()
	check(game.inventory[0]==1 and game.coins==24 and game.materials==4,"Duplicate recycling did not preserve first fish / return resources")
	game.get_node("%Player").position.x=1040
	game.talk()
	check(game.has_talked and game.friendship==1,"NPC talk did not increase friendship")
	game.gift()
	check(game.inventory[0]==0 and game.friendship==3 and game.materials==6,"Gift transaction invalid")
	game.gift()
	check(game.friendship==3,"Repeated gift bypassed one-gift limit")
	game.decorate()
	check(game.decorated and game.materials==4,"Decoration did not consume two materials")
	game.decorate()
	check(game.materials==4,"Repeated decoration charged twice")
	game.get_node("%Dialog").hide()
	game.toggle_cabin()
	var cabin:Node=game.get_node("%Cabin")
	check(cabin.active and cabin.export_layout().size()==3,"Cabin did not open with starter furnishings")
	cabin.choose(3);cabin.flipped=true
	check(cabin.edit_cell(Vector2i(8,2)),"Furniture could not be placed")
	check(not cabin.edit_cell(Vector2i(8,2)),"Furniture overlap was accepted")
	check(not cabin.edit_cell(Vector2i(-1,2)),"Furniture outside floor was accepted")
	check(cabin.item_at(Vector2i(8,2)).flipped,"Furniture mirror state was not applied")
	cabin.set_mode(cabin.Mode.MOVE);cabin.edit_cell(Vector2i(8,2));cabin.edit_cell(Vector2i(9,3))
	check(cabin.item_at(Vector2i(8,2))==null and cabin.item_at(Vector2i(9,3))!=null,"Furniture move did not preserve one item")
	check(game.furnishings.size()==4,"Layout change did not reach harbor persistence data")
	var serialized:String=JSON.stringify(cabin.export_layout())
	cabin.apply_layout(JSON.parse_string(serialized))
	check(cabin.export_layout().size()==4 and cabin.item_at(Vector2i(9,3)).flipped,"Layout serialization lost furniture/position/mirror")
	cabin.set_mode(cabin.Mode.REMOVE);cabin.edit_cell(Vector2i(9,3))
	check(cabin.export_layout().size()==3,"Furniture recall failed")
	cabin.stop()
	game.get_node("%Player").position.x=1800
	game._process(.1)
	check(game.get_node("%Camera").position.x==1760,"Camera did not clamp at far shore")
	var depth:Node=game.get_node("%DepthLayers")
	var mid_delta:float=depth.mid_origin.x-depth.get_node("%MidShore").position.x
	var near_delta:float=depth.foreground_origin.x-depth.get_node("%NearPlants").position.x
	check(mid_delta>0 and near_delta>mid_delta,"Foreground did not scroll faster than midground")
	game.rng.seed=19
	for i in range(30):game.land_fish()
	check(game.discovered[4] or game.discovered[5],"Far shore did not yield its fish pool")
	check(FileAccess.get_file_as_string(path)==before,"Runtime modified saved scene")
	var report:={"passed":failures.is_empty(),"failures":failures,"checks":["authored scene survives ready","aim/cast/underwater lure","reel/release changes line length","no bite from passive timer","attraction/fight/struggle/catch with assistance","tension versus retrieval","release lowers tension","tap cooldown and struggle reward","line-break and slack escape","collection","duplicate-only recycle","resident talk/gift limit","decoration cost/idempotence","furniture placement/bounds/overlap","furniture move/mirror/recall","layout persistence serialization","camera bounds","depth layer relative speeds","far-shore fish pool","scene immutability"]}
	FileAccess.open("res://evidence/smoke-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
