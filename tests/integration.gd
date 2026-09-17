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
		if child is Button and (child.text == text or child.name == text) and not child.disabled:
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
	KinuProgress.register(load("res://resources/kinu/catalog.tres"))
	var impossible := false
	for day in 60:
		for mission in KinuProgress._roll(Time.get_date_string_from_unix_time(1790000000+day*86400)):
			impossible = impossible or mission.type == "decorated"
	check(not impossible,"no box or room mission before owning a new box or room")
	Save.finish_run({"score": 14, "height": 3.5, "placed": 16, "tumbles": 0})
	Save.load_data()
	check(Save.is_fresh("flavour:matcha") and Save.is_fresh("outfit:leaf") and not Save.is_fresh("flavour:kinako") and not Save.is_fresh("flavour:yuzu"),"only found flavours and earned rewards wait as new in the Kinu Book")
	Save.clear_fresh("outfit:leaf")
	Save.load_data()
	check(not Save.is_fresh("outfit:leaf") and Save.fresh_count("flavour:") == 1,"looking at an unlock clears its badge")
	Save.mark_fresh("flavour:yuzu")
	check(Save.fresh_count("flavour:") == 1,"undiscovered legacy flavour keys never show unread badges")
	Save.clear_all_fresh()
	check(Save.fresh_count() == 0,"marking the Kinu Book read clears every badge")
	check(Save.data.best==14 and is_equal_approx(Save.data.best_height,3.5) and Save.data.discovered.has("matcha"),"progress survives reload")
	check(is_equal_approx(Save.data.music,.27) and not Save.data.haptics,"settings survive reload")
	Save.finish_run({"score": 9, "height": 2.0, "placed": 11, "tumbles": 2, "hearts": 1, "streak": 7, "turns": 3, "time": 95.4, "squirts": 2, "glazed": 1, "bonus": 5, "flavours": {"matcha": 4, "silken": 7}, "shapes": {"ball": 6}})
	Save.data.stats.day_streak = 3
	Save.data.last_played = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system())-86400)
	Save.finish_run({"score": 12, "height": 3.0, "placed": 14, "tumbles": 1, "time": 30.0, "flavours": {"matcha": 5}})
	Save.load_data()
	var stats: Dictionary = Save.data.stats
	check(Save.data.recent == [14, 9, 12] and stats.piled == 35 and stats.tumbles == 3 and stats.hearts == 1 and stats.streak == 7,"lifetime run stats add up and survive reload")
	check(stats.time == 125 and stats.longest_time == 95 and stats.squirts == 2 and stats.glazed == 1 and stats.bonus_beans == 5,"play time and shoyu stats are recorded")
	check(Save.data.flavour_counts == {"matcha": 9, "silken": 7} and Save.data.shape_counts == {"ball": 6} and int(Save.data.room_best.shop) == 14,"favourite flavour, shape and best room are counted")
	check(stats.day_streak == 4 and Save.day_streak() == 4 and Save.data.last_played == Time.get_date_string_from_system(),"playing the day after continues the day streak")
	Save.data.last_played = "2020-01-01"
	check(Save.day_streak() == 0,"a missed day shows the streak as broken")
	Save.persist()
	var malformed := FileAccess.open(Save.save_path,FileAccess.WRITE)
	malformed.store_string("{ this is broken")
	malformed.close()
	Save.load_data()
	check(Save.data.best==14,"corrupt main save recovers from backup")
	var old_save := FileAccess.open(Save.save_path,FileAccess.WRITE)
	old_save.store_string(JSON.stringify({"version": 2, "best": 150, "best_height": 5.0}))
	old_save.close()
	Save.load_data()
	check(Save.data.best==15 and int(Save.data.version)==3,"old height best in cm converts to a Kinu count")
	old_save = FileAccess.open(Save.save_path,FileAccess.WRITE)
	old_save.store_string(JSON.stringify({"version": 1, "best": 19}))
	old_save.close()
	Save.load_data()
	check(Save.data.best==19,"first piece-count best carries straight over")
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
	check(app.run.catalog.shapes.size()==5 and app.run.unlocked_flavours().size()==6 and app.run.catalog.flavours.size()==22 and app.run.catalog.finishes.size()==5,"data-driven shapes, six starting flavours, sixteen pile unlocks and five finishes")
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
	# 20 draws over a 1 rad range: a spread under .6 happens about 1 time in 2,000 (.8 failed ~7%).
	check(yaws.max()-yaws.min() > .6,"spawn angles vary between drops")

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
	run.state = "settle"
	run._begin_gesture(above_strip)
	check(run.gesture=="waiting","classic: a press while settling waits for the next Kinu instead of spinning")
	run.state = "aim"
	run._move_gesture(above_strip, Vector2(30,0))
	check(run.gesture=="aim","classic: the waiting press picks up the new Kinu when it appears")
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
	check(run.score==1 and run.tower_height>0 and run.placed==1 and run.state=="aim","Kinu lands, counts on the pile, and next spawns")
	check(Save.data.discovered.size()==1,"safe landing unlocks collection entry")

	for i in 60:
		await frames(1)
		if run.bodies[0].gripped:
			break
	check(run.bodies[0].gripped and run.bodies[0].freeze,"settled Kinu grips the pile")

	# An overhanging top section tips once it stays past its support.
	var base := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	base.position = Vector3(0,1.5435,0)
	var top := run.make_body(run.catalog.shapes[0],run.catalog.flavours[1])
	top.position = Vector3(1.43,2.4935,0)
	for body in [base,top]:
		body.scored = true
		body.grip()
	run._measure_balance()
	check(run.wobble>=1.0 and run.wobble_direction.x>.9,"overhang measured as over balance, leaning outward")
	var centred := run.make_body(run.catalog.shapes[0],run.catalog.flavours[2])
	centred.position = Vector3(0,2.3935,0)
	top.position = Vector3(0,3.2935,0)
	centred.scored = true
	centred.grip()
	run._measure_balance()
	check(run.wobble<.5,"centred stack measured as balanced")
	var corner := run.make_body(run.catalog.shapes[0],run.catalog.flavours[3])
	corner.position = Vector3(1.595,1.7135,1.595)
	corner.scored = true
	corner.grip()
	run._measure_balance()
	check(run.wobble<1.0,"a Kinu resting on the rim near a corner never counts as over balance")
	run.bodies.erase(corner)
	corner.free()
	# A glued Kinu carrying a big slab, with a block on the slab past the glued piece's edge:
	# the block rests on the slab, so nothing should wobble or tip.
	var glued := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	glued.position = Vector3(-1.32,.7335,-1.32)
	var slab := run.make_body(run.catalog.shapes[1],run.catalog.flavours[1])
	slab.position = Vector3(-.66,1.4735,-1.32)
	var perched := run.make_body(run.catalog.shapes[0],run.catalog.flavours[2])
	perched.position = Vector3(-.22,2.2135,-1.32)
	for body in [glued,slab,perched]:
		body.scored = true
		body.grip()
	glued.stuck = true
	slab.stuck = true
	await frames(2)
	run._measure_balance()
	check(run.wobble < NestRun.WOBBLE_WARN,"a block resting on a slab glued to a Shoyu Kinu doesn't wobble")
	for body in [glued,slab,perched]:
		body.stuck = false
		run.bodies.erase(body)
		body.free()
	top.position = Vector3(1.43,2.4935,0)
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
	check(click_button("Resume"),"pause resume button connected")
	check(not get_tree().paused,"resume unpauses tree")

	# A settled Kinu knocked onto the counter uses a tumble and leaves the pile count.
	var stray := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	stray.scored = true
	stray.position = Vector3(3.0,.6,0)
	await frames(3)
	check(run.tumbles==1 and run.score==1 and run.state in ["aim","settle"],"one tumble costs a life and the Kinu stops counting")
	await frames(int(NestRun.FALLEN_LINGER*60)+10)
	check(not run.bodies.has(stray),"fallen Kinu are cleared off the counter")
	var stray_two := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	stray_two.position = Vector3(-3.0,.6,0)
	await frames(3)
	check(run.tumbles==2 and run.state in ["aim","settle"],"a second tumble keeps the run going")
	var stray_three := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	stray_three.position = Vector3(0,.6,3.0)
	await frames(3)
	check(run.state=="falling","the third tumble ends the run")
	await frames(130)
	check(app.page=="results","three tumbles reach results")
	check(click_button("Play Again"),"play again after tumbles")
	await frames(3)

	# A piece leaning against the outside of the nest, standing on the stump, still counts as fallen,
	# even if it has gripped in place.
	var leaner := run.make_body(run.catalog.shapes[3],run.catalog.flavours[0])
	leaner.position = Vector3(2.45,.74,0)
	leaner.scored = true
	for i in 30:
		await frames(1)
		if leaner.fallen:
			break
	check(leaner.fallen and run.tumbles==1,"Kinu leaning on the nest from the stump counts as a tumble")
	check(not leaner.gripped or leaner.touched_ground,"piece on the stump never stays on the pile by gripping")
	run.end()
	await frames(3)
	check(app.page=="results","ending a run reaches results")
	check(int(Save.data.runs)==2,"each ended run counted exactly once")
	check(click_button("Play Again"),"play again button connected")
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
	check(best_run>=7 and best_height>=3.5,"sticky Kinu let a careful player pile high")

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
	var best_before := int(Save.data.best)
	Save.data.best = 10000
	check(KinuBookScreen.found(run.catalog.flavours)==run.catalog.flavours.size(),"every flavour discoverable")
	Save.data.best = best_before

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

	# Soybeans: earned per Kinu piled, spent on outfits, which then dress every Kinu.
	check(NestRun.beans_for(0,false)==0 and NestRun.beans_for(25,false)==29 and NestRun.beans_for(25,true)==34,"beans scale with the pile and reward a new best")
	check(Array(NestRun.unlocks_between(run.catalog.flavours,9,23))==["Yuzu","Ume","Mango","Hojicha"],"results name flavours unlocked by a new best pile")
	# Kinu Book rewards follow lifetime goals; daily missions pay out once.
	var saved_best_for_goals := int(Save.data.best)
	Save.data.best = 0
	check(not Save.owns("outfit","parcel"),"an earned outfit starts locked")
	Save.data.best = 25
	check(Save.owns("outfit","parcel") and Save.buy("outfit","parcel",0) and Save.data.outfit=="parcel","reaching the goal earns and wears the outfit")
	Save.data.outfit = ""
	Save.data.best = saved_best_for_goals
	Save.data.daily = {"day": Time.get_date_string_from_system(), "missions": [{"type": "pile", "amount": 10, "reward": 25, "progress": 0, "claimed": false, "flavour": ""}, {"type": "lucky", "amount": 1, "reward": 30, "progress": 0, "claimed": false, "flavour": ""}, {"type": "clean", "amount": 8, "reward": 25, "progress": 0, "claimed": false, "flavour": ""}]}
	var rolled := KinuProgress._roll("2026-09-16")
	var yesterday := KinuProgress._roll("2026-09-15", false).map(func(m: Dictionary) -> String: return m.type)
	var types := rolled.map(func(m: Dictionary) -> String: return m.type)
	check(rolled.size() == 3 and types[0] != types[1] and types[1] != types[2] and types[0] != types[2],"three different daily missions")
	check(not types.any(func(t: String) -> bool: return yesterday.has(t)),"daily missions don't repeat yesterday's types")
	var streak_mission := {"type": "streak", "amount": 10, "reward": 20, "progress": 0, "claimed": false, "flavour": "", "shape": ""}
	Save.data.daily.missions.append(streak_mission)
	KinuProgress.record_run({"score": 3, "streak": 11, "turns": 2})
	check(KinuProgress.complete(streak_mission),"streak missions track the best run of landings")
	Save.data.daily.missions.pop_back()
	var beans_before := int(Save.data.beans)
	check(KinuProgress.record_run({"score": 12, "placed": 14, "tumbles": 1, "lucky": 0, "height": 3.0}) == 1 and KinuProgress.claimable() == 1,"a run completes the matching daily mission only")
	check(KinuProgress.claim(0) == 25 and int(Save.data.beans) == beans_before+25 and KinuProgress.claim(0) == 0,"a daily reward is collected exactly once")
	# Heart Kinu give back a tumble; Lucky Kinu pay bonus beans.
	app._start()
	await frames(3)
	run.tumbles = 1
	run.next_special = "heart"
	run.bodies.erase(run.active)
	run.active.queue_free()
	run.active = null
	run._spawn()
	check(run.active.special == "heart" and is_instance_valid(run.active.special_marker),"a special Kinu shows its badge")
	run.orbit.lateral = 0
	run.orbit.depth = 0
	run.drop()
	await wait_for_turn(run)
	check(run.tumbles == 0 and run.placed == 1,"a Heart Kinu gives back a tumble when it lands")
	run.next_special = "lucky"
	run.bodies.erase(run.active)
	run.active.queue_free()
	run.active = null
	run._spawn()
	run.orbit.lateral = .5
	run.drop()
	await wait_for_turn(run)
	check(run.lucky_caught == 1 and run.summary().bonus == NestRun.LUCKY_BEANS,"a Lucky Kinu adds bonus beans to the run")
	var tiny := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0],"tiny")
	check(is_equal_approx(tiny.size().x,run.catalog.shapes[0].size.x*KinuBody.SCALE*NestRun.TINY_SCALE) and tiny.mass < run.catalog.shapes[0].mass,"a Tiny Kinu is smaller and lighter")
	run.bodies.erase(tiny)
	tiny.free()
	# The shoyu bottle: aim it like a Kinu, let go to glaze the Kinu below, which then glues.
	var base_kinu: KinuBody = null
	for body in run.bodies:
		if body.scored and not body.fallen and not body.stuck:
			base_kinu = body
	check(run.squirts == NestRun.SQUIRTS_START,"a run starts with a shoyu squirt")
	run.toggle_bottle()
	check(run.aim_mode == "bottle" and is_instance_valid(run.bottle) and not run.active.visible,"the bottle replaces the held Kinu")
	var over := base_kinu.position
	run.orbit.lateral = over.dot(run.orbit.right())
	run.orbit.depth = over.dot(run.orbit.toward_camera())
	await frames(2)
	run.drop()
	for i in 90:
		await frames(1)
		if run.state == "aim":
			break
	var sticky: KinuBody = base_kinu
	check(sticky.sticky and sticky.stuck and sticky.visual.has_node("Sauce") and run.squirts == NestRun.SQUIRTS_START-1 and run.aim_mode == "kinu" and run.active.visible,"letting go squirts glaze onto the Kinu below")
	# A plain Kinu dropped on glaze glues; glaze that one too and the next glues to it.
	for round in 2:
		var above := sticky.position+Vector3.UP*3.0
		run.orbit.lateral = above.dot(run.orbit.right())
		run.orbit.depth = above.dot(run.orbit.toward_camera())
		run.drop()
		var falling: KinuBody = run.pending
		for i in 150:
			await frames(1)
			if falling.stuck or not is_instance_valid(run.pending):
				break
		await frames(2)
		check(falling.stuck and falling.gripped,"a Kinu landing on glaze is glued (%d)"%round)
		await wait_for_turn(run)
		falling.glaze()
		sticky = falling
	run.squirts = 0
	run.toggle_bottle()
	check(run.aim_mode == "kinu","no bottle without squirts")
	run.squirts = NestRun.SQUIRTS_MAX
	run.next_milestone = run.score
	run.drop()
	await wait_for_turn(run)
	check(run.squirts == NestRun.SQUIRTS_MAX,"squirts are capped")
	sticky = base_kinu
	sticky.release(Vector3(4, 2, 0))
	check(sticky.gripped,"glued Kinu can't be knocked loose")
	Save.data.beans = 100
	Save.data.owned = []
	Save.data.outfit = ""
	check(not Save.buy("outfit","tanuki",600) and int(Save.data.beans)==100,"can't buy an outfit you can't afford")
	check(Save.buy("outfit","frog",90) and int(Save.data.beans)==10 and Save.data.outfit=="frog","buying spends beans and wears the outfit")
	check(Save.buy("outfit","frog",90) and int(Save.data.beans)==10,"buying something you own again is free")
	Save.persist()
	Save.load_data()
	check(Save.owns("outfit","frog") and int(Save.data.beans)==10,"beans and owned items survive reload")
	# Flavours unlock by best pile; finishes are bought and restyle every Kinu.
	var mango := run.catalog.flavours.filter(func(f: KinuFlavour) -> bool: return f.id == "mango")[0] as KinuFlavour
	var saved_best := int(Save.data.best)
	Save.data.best = mango.unlock_kinu-1
	check(not run.unlocked_flavours().has(mango),"mango can't spawn before its pile goal")
	Save.data.best = mango.unlock_kinu
	check(run.unlocked_flavours().has(mango),"reaching the pile goal unlocks mango")
	Save.data.best = saved_best
	# Runs begin with familiar flavours, space out discoveries, and reserve Lucky/Gold Star Kinu
	# until the player has built a meaningful pile.
	var saved_discovered: Array = Save.data.discovered.duplicate()
	var saved_placed := run.placed
	var saved_last_discovery := run.last_new_flavour_placed
	var saved_lucky_spawned := run.lucky_spawned
	var saved_active_flavour: KinuFlavour = run.active.flavour if is_instance_valid(run.active) else null
	Save.data.discovered = ["silken"]
	if is_instance_valid(run.active):
		run.active.flavour = run.catalog.flavours[0]
	run.placed = 0
	run.last_new_flavour_placed = -NestRun.NEW_FLAVOUR_GAP
	var early_discovery := false
	for i in 200:
		run.choose_next()
		early_discovery = early_discovery or not Save.data.discovered.has(run.next_flavour.id)
	check(not early_discovery,"unseen flavours never arrive in the opening drops")
	run.placed = 20
	run.last_new_flavour_placed = 20
	var close_discovery := false
	for i in 200:
		run.choose_next()
		close_discovery = close_discovery or not Save.data.discovered.has(run.next_flavour.id)
	check(not close_discovery,"discoveries have several familiar Kinu between them")
	run.last_new_flavour_placed = 0
	var paced_discovery := false
	for i in 200:
		run.choose_next()
		paced_discovery = paced_discovery or not Save.data.discovered.has(run.next_flavour.id)
	check(paced_discovery,"an unseen flavour can arrive once discovery pacing allows it")
	run.placed = NestRun.LUCKY_MIN_PLACED-1
	run.lucky_spawned = false
	var early_lucky := false
	for i in 500:
		run.choose_next()
		early_lucky = early_lucky or run.next_special == "lucky"
	check(not early_lucky,"Lucky Gold Star Kinu stay out of the first twelve placements")
	run.placed = NestRun.LUCKY_MIN_PLACED
	run.lucky_spawned = false
	var later_lucky := false
	for i in 500:
		run.choose_next()
		if run.next_special == "lucky":
			later_lucky = true
			break
	check(later_lucky,"Lucky Gold Star Kinu can appear after twelve placements")
	Save.data.discovered = saved_discovered
	run.placed = saved_placed
	run.last_new_flavour_placed = saved_last_discovery
	run.lucky_spawned = saved_lucky_spawned
	if is_instance_valid(run.active):
		run.active.flavour = saved_active_flavour
	Save.data.beans = 10000
	var gold: KinuFlavour = run.catalog.finish("gold")
	var gold_outfit: KinuOutfit = run.catalog.outfit("gold")
	check(gold_outfit.finish == gold and gold_outfit.goal == "missions" and not run.catalog.outfits.any(func(o: KinuOutfit) -> bool: return o.finish and o.goal == ""),"patterns are outfits, and every one is earned in the Kinu Book")
	check(not Save.owns("outfit","gold",gold_outfit.price) and not Save.buy("outfit","gold",gold_outfit.price),"patterns can't be bought before they're earned")
	Save.data.debug_unlocked = true
	check(Save.buy("outfit","gold",gold_outfit.price) and Save.data.outfit=="gold","wearing a pattern outfit")
	var golden := run.make_body(run.catalog.shapes[0],run.catalog.flavours[1])
	check(golden.look==gold and golden.outfit==null and golden.flavour.id==run.catalog.flavours[1].id,"every Kinu wears the pattern, with no costume, while its flavour is still tracked")
	var plain_kinu := run.make_body(run.catalog.shapes[3],run.catalog.flavours[2])
	check(plain_kinu.look==gold,"a pattern covers every Kinu, like a costume")
	Save.data.debug_unlocked = false
	var found_before: Array = Save.data.discovered.duplicate()
	Save.data.discovered = [run.catalog.flavours[0].id]
	var known := run.make_body(run.catalog.shapes[0],run.catalog.flavours[0])
	var unknown := run.make_body(run.catalog.shapes[0],run.catalog.flavours[1])
	check(known.look==gold and unknown.look==run.catalog.flavours[1],"a flavour not found yet lands without the pattern, so its discovery is visible")
	for body in [known, unknown]:
		run.bodies.erase(body)
		body.queue_free()
	Save.data.discovered = found_before
	Save.data.outfit = ""
	var bare := run.make_body(run.catalog.shapes[0],run.catalog.flavours[1])
	check(bare.look==run.catalog.flavours[1],"without an outfit Kinu show their flavour")
	run.bodies.erase(bare)
	bare.queue_free()
	run.bodies.erase(plain_kinu)
	plain_kinu.queue_free()
	run.bodies.erase(golden)
	golden.queue_free()
	Save.data.outfit = ""
	Save.data.debug_unlocked = false
	# Kinu Book mix toggle and the debug unlock switch.
	Save.set_flavour_in_mix("silken",false)
	check(not run.flavour_mix().any(func(f: KinuFlavour) -> bool: return f.id == "silken"),"switched-off flavours leave the mix")
	for item in run.unlocked_flavours():
		Save.set_flavour_in_mix(item.id,false)
	check(not run.flavour_mix().is_empty(),"the mix never ends up empty")
	Save.data.excluded_flavours = []
	Save.data.debug_unlocked = true
	check(run.unlocked_flavours().size()==run.catalog.flavours.size() and Save.owns("room","winter",1500),"debug unlock opens every flavour and shop item")
	Save.data.debug_unlocked = false
	check(not Save.owns("room","sakura_street",1800),"switching debug off restores normal progress")
	# Box and room skins swap the scene without changing the box's size.
	check(Save.buy("box","lacquer",250) and Save.buy("room","onsen",350),"buying skins equips them")
	check(not Save.buy("room","winter",0) and Save.data.room=="onsen","rewards from the Kinu Book can't be bought")
	run.refresh_decor()
	check(run.box.decor.id=="lacquer" and run.room.decor.id=="onsen","equipped box and room are built into the scene")
	Save.data.box = "hinoki"
	Save.data.room = "shop"
	run.refresh_decor()
	var old := FileAccess.open(Save.save_path,FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 2, "owned_outfits": ["bunny"]}))
	old.close()
	Save.load_data()
	check(Save.owns("outfit","bunny"),"outfits bought in the first shop build carry over")
	app.shop_tab = "outfit"
	app._shop()
	await frames(2)
	check(app.page=="shop","shop navigation")
	check(not KinuShopScreen.cards.any(func(c: Dictionary) -> bool: return c.item.goal != ""),"the shop only sells, never Kinu Book rewards")
	KinuShopScreen._choose(app,"outfit",run.catalog.outfit("bunny"))
	await frames(2)
	check(app.page=="wardrobe" and app.wardrobe_tab=="outfit","tapping something you own opens the wardrobe")
	var screen_before: Control = app.screen
	var bunny_card: Dictionary = WardrobeScreen.cards.filter(func(c: Dictionary) -> bool: return c.id == "bunny")[0]
	bunny_card.button.pressed.emit()
	await frames(1)
	check(app.screen==screen_before and Save.data.outfit=="bunny","the wardrobe wears an outfit without rebuilding")
	Save.data.outfit = ""
	Save.data.runs = 2
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
