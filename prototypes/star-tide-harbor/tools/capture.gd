extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game:Node=load("res://scenes/harbor.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/prototype-harbor.png")
	game.get_node("%Player").position.x=1350
	await create_timer(.15).timeout
	await snap("prototype-depth.png")
	game.toggle_cabin()
	game.get_node("%Cabin").choose(3)
	game.get_node("%Cabin").edit_cell(Vector2i(10,2))
	await snap("prototype-cabin.png")
	game.get_node("%Cabin").stop()
	game.fish_action()
	var fishing:Node=game.get_node("%Fishing")
	fishing.set_process(false)
	fishing.refresh()
	await snap("prototype-aim.png")
	fishing.cast_at(Vector2(720,460));fishing.step(1.0,false,false)
	for i in range(60):fishing.step(.05,true,false)
	await snap("prototype-fishing.png")
	fishing.set_stage(fishing.Stage.FIGHT);fishing.tension=.62;fishing.distance_left=390;fishing.step(.05,false,false)
	await snap("prototype-tension.png")
	fishing.set_stage(fishing.Stage.STRUGGLE);fishing.taps=3;fishing.step(.05,false,false)
	await snap("prototype-struggle.png")
	fishing.stop();game.auto_fish=false;game.enter_phase(game.Phase.IDLE)
	game.discovered=[true,true,true,false,false,false];game.inventory=[2,1,1,0,0,0]
	game.toggle_book()
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/prototype-journal.png")
	quit()

func snap(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/"+filename)
