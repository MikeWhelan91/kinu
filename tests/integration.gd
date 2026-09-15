extends Node
var app: Node
var failures: Array[String] = []
var checks: int = 0
var simulated_frames: int = 0
var peak_bodies: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("FAIL: ",description)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		simulated_frames += 1

func click_button(text: String, root: Node = app.screen) -> bool:
	for child in root.get_children():
		if child is Button and child.text == text and not child.disabled:
			child.pressed.emit()
			return true
		if click_button(text,child):
			return true
	return false

func mouse(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func wait_for_turn(run: NestRun, limit: int = 400) -> void:
	for tick in limit:
		await frames(1)
		peak_bodies = maxi(peak_bodies,run.bodies.size())
		if run.state != "settle":
			return

## Aims just inside the highest Kinu, like a player building upward.
func smart_aim(run: NestRun, turn: int) -> void:
	var highest := Vector3(sin(turn*2.4), 0, cos(turn*2.4))*.6
	var top: KinuBody
	for body in run.bodies:
		if body.scored and not body.fallen and body.position.y > highest.y:
			highest = body.position
			top = body
	if top:
		# Spin the box so the new piece's edges line up with the top of the tower.
		var forward := top.global_basis.z
		var wanted := atan2(forward.x, forward.z)-run.active_yaw
		wanted += round((run.orbit.angle-wanted)/(PI*.5))*PI*.5
		run.orbit.stop_spin()
		run.orbit.angle = wanted
		run.orbit.target_angle = wanted
	var target := highest*Vector3(.5, 0, .5)
	run.orbit.lateral = target.dot(run.orbit.right())
	run.orbit.depth = target.dot(run.orbit.toward_camera())

func _ready() -> void:
	# All tests use isolated storage and never touch a player's real progress.
	Save.save_path = "user://integration_test.json"
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	Save.load_data()
	check(Save.data.best==0 and Save.data.discovered.is_empty(),"fresh install defaults")
	Save.setting("music",.27)
	Save.setting("sfx",.43)
	Save.setting("haptics",false)
	Save.discover("matcha")
	Save.finish_run(14,3.5)
	Save.load_data()
	check(Save.data.best==14 and is_equal_approx(Save.data.best_height,3.5) and Save.data.discovered.has("matcha"),"progress survives reload")
	check(is_equal_approx(Save.data.music,.27) and not Save.data.haptics,"settings survive reload")
	Save.persist()
	var malformed := FileAccess.open(Save.save_path,FileAccess.WRITE)
	malformed.store_string("{ this is broken")
	malformed.close()
	Save.load_data()
	check(Save.data.best==14,"corrupt main save recovers from backup")
	var old_save := FileAccess.open(Save.save_path,FileAccess.WRITE)
	old_save.store_string(JSON.stringify({"version": 1, "best": 19, "best_height": 5.0}))
	old_save.close()
	Save.load_data()
	check(Save.data.best==NestRun.height_cm(5.0) and int(Save.data.version)==2,"old piece-count best converts to height in cm")
	for suffix in ["",".bak"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	Save.load_data()
	Save.data.tutorial = true
	Save.data.sfx = 0
	Save.data.music = 0
	Sound.apply_settings()
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await frames(5)
	check(app.page=="home","main scene starts at home")
	check(app.run.catalog.shapes.size()==5 and app.run.catalog.flavours.size()==6,"data-driven Kinu shapes and flavours")
	check(click_button("Play"),"main play button connected")
	await frames(2)
	var run: NestRun = app.run
	check(app.page=="play" and run.state=="aim","start reaches aiming state")
	var yaws: Array[float] = []
	for i in 20:
		run.next_shape = run.catalog.shapes[i % run.catalog.shapes.size()]
		run.bodies.erase(run.active)
		run.active.queue_free()
		run.active = null
		run._spawn()
		await frames(1)
		var facing := run.active.global_basis.z
		var to_camera := (run.orbit.camera.global_position-run.active.global_position)*Vector3(1, 0, 1)
		check(facing.dot(run.orbit.toward_camera()) > cos(NestRun.SPAWN_MAX_TURN)-.02,"held Kinu roughly faces the player")
		var offset := Vector2(run.orbit.lateral, run.orbit.depth).length()
		check(offset >= NestRun.SPAWN_MIN_OFFSET-.001 and offset <= NestRun.SPAWN_MAX_OFFSET+.001,"held Kinu spawns off-centre over the box")
		yaws.append(run.active_yaw)
	check(yaws.max()-yaws.min() > .8,"spawn angles vary between drops")

	# Aim + spin reach different world positions; the aim axes follow the view.
	run.orbit.lateral = 1.2
	run.orbit.depth = .4
	var positions: Array[Vector3] = []
	for angle in [0.,PI/2,PI,3*PI/2]:
		run.orbit.angle = angle
		positions.append(run.orbit.drop_position(3))
		check(Vector2(positions[-1].x,positions[-1].z).length()<=OrbitController.PLACEMENT_RADIUS+.001,"drop point inside placement radius")
	check(positions[0].distance_to(positions[1])>1.5,"spinning moves the drop point around the nest")
	check(positions[0].is_equal_approx(Vector3(-positions[2].x,3,-positions[2].z)),"half a spin mirrors the drop point")
	run.orbit.angle = 0
	run.orbit.target_angle = 0
	run.orbit.lateral = 0
	await frames(2)

	check(Save.data.controls=="classic","classic controls are the default")
	var strip_touch := Vector2(270,run.spin_zone_top()+60)
	var above_strip := Vector2(40,run.spin_zone_top()-300)
	run._begin_gesture(strip_touch)
	check(run.gesture=="spin","classic: bottom strip spins")
	run._end_gesture()
	run.orbit.stop_spin()
	run._begin_gesture(above_strip)
	check(run.gesture=="aim","classic: dragging anywhere above the strip aims")
	run.gesture = ""
	var strip_rect := run.spin_strip_rect()
	check(strip_rect.end.y <= get_viewport().get_visible_rect().size.y-run.bottom_inset,"spin strip stays clear of the bottom safe area")
	run._begin_gesture(Vector2(270, strip_rect.end.y+4))
	check(run.gesture=="","classic: touches below the strip box don't spin")
	run.gesture = ""
	Save.data.controls = "grab"
	# Swiping anywhere away from Kinu spins, and never drops.
	var bottom := Vector2(40,900)
	check(not run.grabs_active(bottom),"a touch away from Kinu does not grab it")
	run._unhandled_input(mouse(bottom,true))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(90,0)
	motion.position = bottom+motion.relative
	run._unhandled_input(motion)
	run._unhandled_input(mouse(motion.position,false))
	check(absf(run.orbit.target_angle)>.5,"swipe away from Kinu spins the box")
	check(run.state=="aim","spinning does not drop Kinu")
	var after_release := run.orbit.target_angle
	await frames(10)
	check(absf(run.orbit.target_angle)>absf(after_release),"flicked nest keeps spinning with momentum")
	await frames(120)
	check(run.orbit.spin_velocity==0.0,"spin momentum eases to a stop")
	run.orbit.stop_spin()
	run.orbit.target_angle = 0
	run.orbit.lateral = 0
	run.orbit.depth = 0
	await frames(30)

	# Pressing on Kinu grabs it; releasing drops it.
	var held := run.orbit.camera.unproject_position(run.active.global_position)
	check(run.grabs_active(held),"a touch on Kinu grabs it")
	run._unhandled_input(mouse(held+Vector2(0,40),true))
	check(run.gesture=="aim","press on Kinu starts aiming")
	motion = InputEventMouseMotion.new()
	motion.position = held+Vector2(60,160)
	motion.relative = Vector2(60,40)
	run._unhandled_input(motion)
	check(run.orbit.lateral>.2 and run.orbit.depth>.2,"dragging moves the drop point in two dimensions")
	motion.relative = Vector2(4000,4000)
	run._unhandled_input(motion)
	check(Vector2(run.orbit.lateral,run.orbit.depth).length()<=OrbitController.PLACEMENT_RADIUS+.001,"drop point stays over the nest")
	run.orbit.lateral = 0
	run.orbit.depth = 0
	run._unhandled_input(mouse(held,false))
	check(run.state=="settle","releasing drops Kinu")
	var body_count := run.bodies.size()
	run.drop()
	check(run.bodies.size()==body_count,"repeat drops are ignored while settling")
	await wait_for_turn(run)
	check(run.score>0 and run.score==NestRun.height_cm(run.tower_height) and run.placed==1 and run.state=="aim","Kinu lands, scores its height in cm, and next spawns")
	check(Save.data.discovered.size()==1,"safe landing unlocks collection entry")

	for i in 60:
		await frames(1)
		if run.bodies[0].gripped:
			break
	check(run.bodies[0].gripped and run.bodies[0].freeze,"settled Kinu grips the pile")

	# An overhanging top section tips once it stays past its support.
	var base := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	base.position = Vector3(0,1.45,0)
	var top := run.make_body(run.catalog.shapes[0],run.catalog.flavours[1])
	top.position = Vector3(1.3,2.4,0)
	for body in [base,top]:
		body.scored = true
		body.grip()
	run._measure_balance()
	check(run.wobble>=1.0 and run.wobble_direction.x>.9,"overhang measured as over balance, leaning outward")
	var centred := run.make_body(run.catalog.shapes[0],run.catalog.flavours[2])
	centred.position = Vector3(0,2.3,0)
	top.position = Vector3(0,3.2,0)
	centred.scored = true
	centred.grip()
	run._measure_balance()
	check(run.wobble<.5,"centred stack measured as balanced")
	top.position = Vector3(1.3,2.4,0)
	centred.release()
	centred.fallen = true
	run.bodies.erase(centred)
	centred.queue_free()
	await frames(int(NestRun.TIP_HOLD*60)+12)
	check(not top.gripped,"over-balanced section tips loose")
	check(top.tipped,"tipped piece is marked")
	top.grip()
	run._measure_balance()
	check(run.wobble < 1.0,"a piece that was already tipped is not tipped again")
	check(base.gripped,"supporting Kinu below the cut stays gripped")
	var lander := run.make_body(run.catalog.shapes[2],run.catalog.flavours[0])
	base.release()
	base.grip()
	run._landed(lander,base,8.0)
	check(not base.gripped,"heavy landing knocks a Kinu loose")
	run.bodies.erase(lander)
	lander.queue_free()
	app._start()
	await frames(3)
	run.drop()
	await wait_for_turn(run)

	app._pause()
	var position_before := run.bodies[0].position
	await get_tree().process_frame
	check(get_tree().paused and run.bodies[0].position==position_before,"pause freezes simulation")
	check(click_button("Keep playing"),"pause resume button connected")
	check(not get_tree().paused,"resume unpauses tree")

	# One Kinu on the stump ends the run.
	var stray := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	stray.position = Vector3(3.0,.6,0)
	await frames(3)
	check(run.state=="falling","a single fall ends the tower")
	await frames(130)
	check(app.page=="results","fall reaches results")
	check(click_button("Play again"),"play again after stump fall")
	await frames(3)

	# A piece leaning against the outside of the nest, standing on the stump, still counts as fallen,
	# even if it has gripped in place.
	var leaner := run.make_body(run.catalog.shapes[3],run.catalog.flavours[0])
	leaner.position = Vector3(2.45,.74,0)
	leaner.scored = true
	for i in 30:
		await frames(1)
		if run.state=="falling":
			break
	check(run.state=="falling","Kinu leaning on the nest from the stump ends the run")
	check(not leaner.gripped or leaner.touched_ground,"piece on the stump never keeps the run alive by gripping")
	await frames(130)
	check(app.page=="results","leaning fall reaches results")
	check(int(Save.data.runs)==2,"each ended run counted exactly once")
	check(click_button("Play again"),"play again button connected")
	await frames(3)
	check(run.score==0 and run.bodies.size()==1 and run.state=="aim","restart resets bodies and run state")

	# A careful bot must be able to build a real tower with real physics.
	var best_run := 0
	var best_height := 0.0
	for cycle in 3:
		if cycle>0:
			app._start()
		run.rng.seed = 11+cycle
		for turn in 45:
			if run.state != "aim":
				break
			run.orbit.target_angle = turn*2.39996
			await frames(25)
			smart_aim(run,turn)
			run.drop()
			await wait_for_turn(run)
			check(run.state in ["aim","falling"],"settle timeout prevents stuck run")
			for body in run.bodies:
				check(body.position.is_finite(),"rigid body remains finite")
		best_run = maxi(best_run,run.placed)
		best_height = maxf(best_height,run.tower_height)
		print("RUN ",cycle," placed=",run.placed," height=",run.height_label()," state=",run.state," wobble=",snappedf(run.wobble,.01))
	check(best_run>=7 and best_height>=3.5,"sticky Kinu let a careful player build a tall tower")

	# Every shape must land safely in an empty nest, and every flavour can be found.
	for i in run.catalog.shapes.size():
		app._start()
		run.next_shape = run.catalog.shapes[i]
		run.next_flavour = run.catalog.flavours[i]
		run.bodies.erase(run.active)
		run.active.queue_free()
		run.active = null
		run._spawn()
		run.orbit.lateral = 0
		run.orbit.depth = 0
		run.drop()
		await wait_for_turn(run)
		check(run.placed==1 and run.state=="aim","individual landing: "+run.catalog.shapes[i].id)
	for flavour in run.catalog.flavours:
		Save.discover(flavour.id)
	check(KinuBookScreen.found(run.catalog.flavours)==6,"all six flavours discoverable")

	# Moods follow the pile: worried while swaying, happy after landing.
	var mood_body := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	mood_body.freeze = true
	mood_body.sway = .8
	await get_tree().process_frame
	await get_tree().process_frame
	check(mood_body.mood=="worried","wobbling Kinu looks worried")
	mood_body.sway = 0
	mood_body.cheer()
	await get_tree().process_frame
	await get_tree().process_frame
	check(mood_body.mood=="happy","landed Kinu looks happy")
	run.bodies.erase(mood_body)
	mood_body.queue_free()

	# Outfits are cosmetic: the hitbox never changes.
	Save.data.outfit = "bunny"
	var dressed := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	check(dressed.outfit != null and dressed.outfit.id=="bunny","equipped outfit applies to new Kinu")
	check((dressed.get_child(1) as CollisionShape3D).shape==KinuBody.hitbox(run.catalog.shapes[0]),"outfit shares the shape's hitbox")
	Save.data.outfit = ""
	run.bodies.erase(dressed)
	dressed.queue_free()

	# Soybeans: earned by height, spent on outfits, which then dress every Kinu.
	check(NestRun.beans_for(0,false)==0 and NestRun.beans_for(250,false)==35 and NestRun.beans_for(250,true)==45,"beans scale with height and reward a new best")
	Save.data.beans = 100
	Save.data.owned_outfits = []
	Save.data.outfit = ""
	check(not Save.buy_outfit("tanuki",200) and int(Save.data.beans)==100,"can't buy an outfit you can't afford")
	check(Save.buy_outfit("frog",90) and int(Save.data.beans)==10 and Save.data.outfit=="frog","buying spends beans and wears the outfit")
	check(Save.buy_outfit("frog",90) and int(Save.data.beans)==10,"buying something you own again is free")
	Save.persist()
	Save.load_data()
	check(Save.owns_outfit("frog") and int(Save.data.beans)==10,"beans and owned outfits survive reload")
	app._shop()
	await frames(2)
	check(app.page=="shop","shop navigation")
	Save.data.outfit = ""
	for cycle in 3:
		app._home()
		click_button("Kinu Book")
		await frames(2)
		check(app.page=="collection","book navigation")
		app._flavour_detail(run.catalog.flavours[0],true)
		click_button("Lovely")
		app._settings()
		await frames(2)
		check(app.page=="settings","settings navigation")
		app._credits()
		await frames(2)
		check(app.page=="credits","licences navigation")
		app._home()
	Save.data.tutorial = false
	app._start()
	for action in ["aim","drop","spin","settle"]:
		app._tutorial_action(action)
	check(app.tutorial_step==4,"tutorial progresses across all steps")
	app._finish_tutorial()
	Save.load_data()
	check(Save.data.tutorial,"tutorial completion persists")
	print("CHECKS=",checks," FAILURES=",failures.size()," PEAK_BODIES=",peak_bodies," BEST_RUN=",best_run," BEST_HEIGHT=",best_height)
	var report := FileAccess.open("res://docs/integration-results.txt",FileAccess.WRITE)
	report.store_string("Godot "+Engine.get_version_info().string+"\nChecks: "+str(checks)+"\nFailures: "+str(failures.size())+"\nBest bot tower: "+str(best_run)+"\nSimulated seconds: "+str(simulated_frames/60.0)+"\n"+"\n".join(failures))
	report.close()
	app.queue_free()
	await frames(2)
	Sound.shutdown()
	OS.delay_msec(180)
	get_tree().quit(0 if failures.is_empty() else 1)
