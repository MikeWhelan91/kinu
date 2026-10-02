extends Node
var app: Node
func _ready() -> void:
	Save.save_path = "user://visual_test.json"
	Save.data = Save.defaults()
	Save.data.tutorial = true
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(1).timeout
	var mode := "home"
	var suffix := ""
	var tutorial_index := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("aspect="):
			var parts := arg.trim_prefix("aspect=").split("x")
			get_window().size = Vector2i(int(parts[0]),int(parts[1]))
			suffix = "-"+arg.trim_prefix("aspect=")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("step="):
			tutorial_index = int(arg.trim_prefix("step="))
			suffix += "-step"+str(tutorial_index)
		elif arg.begins_with("screen="):
			mode = arg.trim_prefix("screen=")
		elif arg.begins_with("outfit="):
			Save.data.outfit = arg.trim_prefix("outfit=")
			suffix += "-"+str(Save.data.outfit)
		elif arg.begins_with("room="):
			Save.data.room = arg.trim_prefix("room=")
			suffix += "-"+str(Save.data.room)
		elif arg.begins_with("box="):
			Save.data.box = arg.trim_prefix("box=")
			suffix += "-"+str(Save.data.box)
		elif arg.begins_with("runs="):
			Save.data.runs = int(arg.trim_prefix("runs="))
			suffix += "-runs"
		elif arg.begins_with("lang="):
			Save.data.language = arg.trim_prefix("lang=")
			app.apply_language()
			suffix += "-"+str(Save.data.language)
		elif arg.begins_with("finish="):
			Save.data.outfit = arg.trim_prefix("finish=")
			suffix += "-"+str(Save.data.outfit)
	match mode:
		"beans": app._bean_shop()
		"tickets": app._bean_shop("tickets")
		"kinu_intro":
			Save.data.runs = 1
			Save.data.my_kinu.xp = 45
			Save.data.my_kinu.home_seen_xp = 45
			Save.data.my_kinu.intro_seen = false
			await app._home()
			await get_tree().create_timer(1.5).timeout
		"home_my_kinu":
			Save.data.beans = 8137
			Save.data.tickets = 12
			Save.data.best = 30
			Save.data.my_kinu.xp = 560
			Save.data.my_kinu.home_seen_xp = 560
			Save.data.my_kinu.intro_seen = true
			Save.data.my_kinu.flavour = "matcha"
			Save.data.owned = ["part:top_hat", "part:cool_shades"]
			Save.data.fresh = ["part:top_hat", "part:cool_shades"]
			await app._home()
			await get_tree().create_timer(.5).timeout
		"home":
			await app._home()
			await get_tree().create_timer(.5).timeout
		"showcase":
			Save.data.showcase.goals[KinuShowcase.current_month()] = {"runs": 26, "land": 0, "pile_times": 0, "missions": 0}
			await app._home()
			await get_tree().create_timer(.3).timeout
			ShowcaseSheet.open(app)
		"rail":
			DailyCalendar.apply_server_status({"ready": false, "streak": 2, "seconds_remaining": 7200})
			await app._home()
			await get_tree().create_timer(1.2).timeout
		"play": app._start()
		"pause":
			app._start()
			app.run.score = 12
			app.run.placed = 14
			app.run.tumbles = 2
			app.run.tower_height = 6.4
			app._hud_update()
			app._pause()
		"toast":
			app._start()
			await get_tree().create_timer(.2).timeout
			app._toast("Oh no! Kinu tumbled off!", Color("e0463a"))
		"tall":
			Save.data.best_height = 7.5
			Save.data.best = 11
			app._start()
			var run: NestRun = app.run
			var ids := [1,0,0,3,0,4,0,1,0,0,3,0]
			for i in ids.size():
				var body := run.make_body(run.catalog.shapes[ids[i]],run.catalog.flavours[i%6])
				body.position = Vector3(sin(i*1.9)*.15,.1+i*.78,cos(i*1.9)*.15) if i>2 else Vector3(sin(i*2.1)*.8,.62,cos(i*2.1)*.8)
				body.rotation.y = i*.8
				body.scored = true
				body.grip()
			run.placed = ids.size()
			run.score = ids.size()
			run.bodies.erase(run.active)
			run.active.queue_free()
			run.active = null
			run._spawn()
			run.orbit.lateral = .9
			await get_tree().create_timer(2.5).timeout
		"tower":
			app._start()
			var run: NestRun = app.run
			run.rng.seed = 12
			for turn in 14:
				run.orbit.target_angle = turn*2.39996
				await get_tree().create_timer(.4).timeout
				var total := Vector3.ZERO
				var weight := 0.0
				for body in run.bodies:
					if body.scored:
						total += body.position*body.mass
						weight += body.mass
				var highest := Vector3.ZERO
				for body in run.bodies:
					if body.scored and body.position.y > highest.y:
						highest = body.position
				var aim := highest*Vector3(.5,0,.5)+Vector3(sin(turn*1.3),0,cos(turn*1.7))*(.9 if turn<6 else .15)
				run.orbit.lateral = aim.dot(run.orbit.right())
				run.orbit.depth = aim.dot(run.orbit.toward_camera())
				run.drop()
				while run.state == "settle":
					await get_tree().physics_frame
				if run.state != "aim":
					break
			run.orbit.lateral = .6
			run.orbit.depth = 0.0
			await get_tree().create_timer(1.5).timeout
		"tutorial_tower", "tutorial_toss":
			Save.data["tutorial_"+mode.trim_prefix("tutorial_")] = false
			Save.data.mode = mode.trim_prefix("tutorial_")
			Save.data.debug_unlocked = true
			app._start()
			await get_tree().create_timer(.6).timeout
			app.tutorial_step = tutorial_index
			app._tutorial_refresh()
			await get_tree().create_timer(.6).timeout
		"tutorial":
			Save.data.tutorial = false
			app._start()
			app.tutorial_step = tutorial_index
			app._tutorial_refresh()
		"patterns":
			Save.data.stats.lucky = 5
			Save.data.stats.best_day_streak = 4
			Save.data.stats.glazed = 18
			Save.data.stats.missions = 12
			Save.data.discovered = ["silken","fried","sesame","matcha","sakura","tamago","kinako","yuzu"]
			app.book_tab = "collection"
			app._collection()
			for i in 12:
				await get_tree().process_frame
			var scroll: ScrollContainer = app.screen.find_children("*","DragScroll",true,false)[0]
			for card in app.screen.find_children("*","Button",true,false):
				if card.get_parent() and str(card.get_parent().get_child_count()) != "" and card.find_children("*","Label",true,false).any(func(l: Label) -> bool: return l.text == "Wood"):
					scroll.scroll_vertical = int(card.get_global_rect().position.y-scroll.get_global_rect().position.y)-20
		"rewards":
			Save.data.best = 18
			Save.data.runs = 4
			Save.data.stats.total = 120
			app.book_tab = "collection"
			app._collection()
		"wardrobe":
			Save.data.owned = ["outfit:frog","outfit:bunny","box:gift","room:onsen","part:top_hat","part:cool_shades"]
			Save.data.runs = 3
			Save.data.outfit = "frog"
			Save.data.best = 20
			Save.data.my_kinu.xp = 520
			Save.data.my_kinu.flavour = "kinako"
			Save.data.my_kinu.equipped = {"body": "comfy_tee", "hat": "top_hat", "arms": "little_arms", "glasses": "cool_shades"}
			app._wardrobe()
		"daily":
			KinuProgress.server_day = Time.get_date_string_from_system()
			KinuProgress.today()[0].progress = 999
			KinuProgress.today()[2].progress = 999
			KinuProgress.today()[2].claimed = true
			KinuProgress.weekly().progress = 3
			KinuProgress.today()[1].progress = 1
			app._home()
			await get_tree().create_timer(.3).timeout
			NestMenuScreen.daily_missions(app)
		"bottle":
			app._start()
			await get_tree().create_timer(.3).timeout
			app.run.drop()
			while app.run.state == "settle":
				await get_tree().physics_frame
			app.run.toggle_bottle()
		"special", "special_heart":
			app._start()
			app.run.next_special = "heart" if mode == "special_heart" else "lucky"
			app.run.bodies.erase(app.run.active)
			app.run.active.queue_free()
			app.run.active = null
			app.run._spawn()
			app.run.next_special = "tiny"
			app._hud_update()
		"buy":
			Save.data.beans = 340
			app.shop_tab = "room"
			app._shop()
			KinuShopScreen._choose(app,"room",app.run.catalog.find_decor("room","onsen"))
		"credits":
			app._credits()
		"locked_reward":
			app.book_tab = "collection"
			app._collection()
			KinuBookScreen._item_detail(app,"room",app.run.catalog.find_decor("room","moon_viewing"))
		"tutorial_bottle":
			Save.data.tutorial = false
			app._start()
			await get_tree().create_timer(.3).timeout
			app.run.drop()
			while app.run.state == "settle":
				await get_tree().physics_frame
			app.tutorial_step = 4
			app._tutorial_refresh()
			await get_tree().create_timer(.8).timeout
		"tutorial_spin":
			Save.data.tutorial = false
			app._start()
			app.tutorial_step = 2
			app._tutorial_refresh()
		"collection":
			Save.data.discovered = ["silken","fried","sesame","matcha"]
			app._collection()
		"records":
			Save.data.runs = 42
			Save.data.best = 58
			Save.data.best_height = 7.1
			Save.data.discovered = ["silken","fried","sesame","matcha"]
			Save.data.stats = {"total": 1830, "clean": 31, "lucky": 12, "missions": 27, "piled": 1624, "tumbles": 118, "hearts": 9, "streak": 44, "spins": 356, "beans_earned": 2415, "bonus_beans": 310, "beans_spent": 1900, "time": 11520, "longest_time": 412, "squirts": 64, "glazed": 51, "day_streak": 0, "best_day_streak": 9}
			Save.data.first_played = "2026-08-02"
			Save.data.last_played = Time.get_date_string_from_system()
			Save.data.stats.day_streak = 5
			Save.data.flavour_counts = {"matcha": 212, "silken": 180}
			Save.data.shape_counts = {"ball": 300, "block": 250}
			Save.data.recent = [22, 31, 18, 40, 58, 27, 35, 44, 29, 49]
			Save.data.room_best = {"shop": 58, "night": 40}
			Save.data.outfit_best = {"": 44, "frog": 58}
			app.book_tab = "records"
			app._collection()
		"settings": app._settings()
		"loading":
			app._shop()
			Save.data.room = "winter"
			app._home()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/loading.png")
			await get_tree().create_timer(1.5).timeout
			mode = "loading_done"
		"flavour_detail":
			Save.data.discovered = ["silken","fried","sesame","matcha"]
			Save.data.excluded_flavours = ["sesame"]
			app._collection()
			app._flavour_detail(app.run.catalog.flavours[3],true)
		"shop", "shop_outfit", "shop_box", "shop_room":
			Save.data.beans = 340
			Save.data.owned = ["outfit:frog","box:bamboo","room:night"]
			Save.data.outfit = "frog"
			Save.data.box = "bamboo"
			app.shop_tab = {"shop": "outfit", "shop_outfit": "outfit", "shop_box": "box", "shop_room": "room"}[mode]
			app._shop()
		"my_kinu", "my_kinu_unworn", "my_kinu_hat", "my_kinu_bunny", "my_kinu_flavour", "shop_part", "my_kinu_play", "my_kinu_results", "my_kinu_home_progress":
			Save.data.best = 30
			Save.data.beans = 2400
			Save.data.my_kinu.xp = 520
			Save.data.my_kinu.flavour = "matcha"
			Save.data.owned = ["outfit:frog", "part:top_hat", "part:sky_tee", "part:cool_shades", "part:boxing_gloves"]
			Save.data.my_kinu.equipped = {"body": "sky_tee", "hat": "top_hat", "arms": "boxing_gloves", "glasses": "cool_shades"}
			MyKinu.wear(app.run.catalog, true)
			match mode:
				"my_kinu":
					MyKinuScreen.tab = "body"
					MyKinuScreen.show(app, app._home)
				"my_kinu_unworn":
					# The look is not worn, so the screen offers the Wear My Kinu button.
					MyKinu.wear(app.run.catalog, false)
					MyKinuScreen.tab = "flavour"
					MyKinuScreen.show(app, app._home)
				"my_kinu_bunny":
					Save.data.owned.append("part:bunny_band")
					Save.data.my_kinu.equipped.hat = "bunny_band"
					MyKinuScreen.tab = "hat"
					MyKinuScreen.shape_index = 0
					MyKinuScreen.show(app, app._home)
				"my_kinu_hat":
					MyKinuScreen.tab = "hat"
					MyKinuScreen.shape_index = 0
					MyKinuScreen.show(app, app._home)
				"my_kinu_flavour":
					MyKinuScreen.tab = "flavour"
					MyKinuScreen.show(app, app._home)
				"shop_part":
					app.shop_tab = "part"
					KinuShopScreen.part_slot = "hat"
					app._shop()
				"my_kinu_play":
					app._start()
					var run: NestRun = app.run
					var ids := [1,0,4,3,0,2,0,1]
					for i in ids.size():
						var body := run.make_body(run.catalog.shapes[ids[i]],MyKinu.base(run.catalog),"lucky" if i == 4 else "")
						body.position = Vector3(sin(i*1.9)*.15,.1+i*.78,cos(i*1.9)*.15) if i>2 else Vector3(sin(i*2.1)*.8,.62,cos(i*2.1)*.8)
						body.rotation.y = i*.8
						body.scored = true
						body.grip()
					run.placed = ids.size()
					run.score = ids.size()
					app._hud_update()
				"my_kinu_results":
					Save.data.my_kinu.xp = 1250
					app._start()
					app.initial_best = 30
					app.run.run_id = "visual"
					app._results({"score":24,"pile":24,"placed":26,"height":6.4,"run_id":"visual"})
				"my_kinu_home_progress":
					Save.data.my_kinu.xp = 1250
					Save.data.my_kinu.home_seen_xp = 1250
					app._start()
					app.initial_best = 30
					app.run.run_id = "visual-home"
					app._results({"score":24,"pile":24,"placed":26,"height":6.4,"run_id":"visual-home"})
					app._start()
					app.run.run_id = "visual-home-again"
					app._results({"score":15,"pile":15,"placed":15,"height":4.2,"run_id":"visual-home-again"})
					app._home()
		"night", "winter":
			Save.data.room = "night" if mode == "night" else "winter"
			Save.data.box = "lacquer" if mode == "night" else "goldbox"
			app._start()
		"results":
			app.initial_best = 0
			app._results({"score":12,"placed":14,"height":6.4})
		"results_many":
			# Everything at once: several flavours, two level-ups, Kinu Book items and missions.
			Save.data.runs = 9
			Save.data.stats.total = 380
			Save.data.my_kinu.xp = 230
			Save.data.my_kinu.home_seen_xp = 230
			Save.data.my_kinu.intro_seen = true
			KinuProgress.today()
			app._start()
			app.initial_best = 0
			app._results({"mode":"classic","score":40,"pile":40,"placed":160,"height":5.0,"run_id":"visual-many","tumbles":0})
		"results_tower":
			Save.data.mode_best = {"tower": 780}
			Save.data.mode = "tower"
			# Close to level 5, so this run's XP crosses a level and shows its rewards.
			Save.data.my_kinu.xp = 330
			Save.data.my_kinu.home_seen_xp = 330
			Save.data.my_kinu.intro_seen = true
			app._start()
			app.initial_best = 780
			app._results({"mode":"tower","score":290,"pile":8,"placed":12,"height":2.9,"run_id":"visual-tower"})
		"home_tour_my_kinu":
			Save.data.runs = 3
			Save.data.home_tour = false
			Save.data.my_kinu.intro_seen = true
			await app._home()
			await get_tree().create_timer(.4).timeout
			HomeTour.start(app)
			await get_tree().create_timer(.4).timeout
			var tour: HomeTour = app.modal as HomeTour
			if tour:
				for i in tour.steps.size():
					if tour.steps[i][0][0] == "MyKinuHome":
						tour._show_step(i, true)
	await get_tree().create_timer(4 if mode in ["my_kinu_home_progress", "my_kinu_results", "results_tower", "results_many"] else 1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/"+mode+suffix+".png")
	print("CAPTURE ",mode," ",get_viewport().get_visible_rect())
	get_tree().paused = false
	app.queue_free()
	await get_tree().process_frame
	KinuModel.clear_cache()
	Sound.shutdown()
	await get_tree().create_timer(.15).timeout
	get_tree().quit()
