extends Node
var app: Node
var failures: Array[String] = []
var checks: int = 0

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		print("FAIL ",text)

func find_button(text: String, node: Node) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := find_button(text,child)
		if found:
			return found
	return null

func click(text: String) -> void:
	var button := find_button(text,app.screen)
	check(button != null,"button present: "+text)
	if not button:
		return
	var point := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	await get_tree().process_frame

func _ready() -> void:
	Save.save_path = "user://ui_test.json"
	Save.data = Save.defaults()
	Save.data.controls = "grab"
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	await click("Play")
	check(app.page=="play" and app.tutorial_step==0,"pointer click starts tutorial")
	for i in 4:
		await get_tree().physics_frame
	var run: NestRun = app.run
	var start := run.orbit.camera.unproject_position(run.active.global_position)
	var lateral_before := run.orbit.lateral
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start
	press.pressed = true
	get_viewport().push_input(press,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start+Vector2(40,0)
	drag.relative = Vector2(40,0)
	get_viewport().push_input(drag,true)
	check(app.tutorial_step==1 and run.orbit.lateral>lateral_before,"touch drag through HUD aims Kinu")
	press.pressed = false
	get_viewport().push_input(press,true)
	check(app.tutorial_step==2 and run.state=="settle","lifting the finger drops")
	var strip := Vector2(40,420)
	press = InputEventScreenTouch.new()
	press.index = 0
	press.position = strip
	press.pressed = true
	get_viewport().push_input(press,true)
	drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = strip+Vector2(-80,0)
	drag.relative = Vector2(-80,0)
	get_viewport().push_input(drag,true)
	press.pressed = false
	get_viewport().push_input(press,true)
	check(app.tutorial_step==3,"swiping away from Kinu spins through the HUD")
	for i in 400:
		await get_tree().physics_frame
		if run.state=="aim":
			break
	check(app.tutorial_step==4 and run.placed==1,"tutorial reaches final tip after landing")
	await click("Let’s stack!")
	check(Save.data.tutorial and app.tutorial_step == -1,"tutorial finishes through button")
	await click("II")
	check(get_tree().paused,"pointer pause works")
	await click("Keep playing")
	check(not get_tree().paused,"pointer resume works while tree paused")
	await click("II")
	await click("Return home")
	check(app.page=="home","pointer returns home")
	await click("Settings")
	check(app.page=="settings","pointer opens settings")
	await click("Haptics   On")
	check(not Save.data.haptics,"pointer toggles setting")
	await click("Controls   Grab")
	check(Save.data.controls=="classic","pointer switches control scheme")
	await click("Credits & licences")
	check(app.page=="credits","pointer opens licences")
	await click("‹")
	await click("‹")
	await click("Kinu Book")
	check(app.page=="collection","pointer opens book")
	for i in 3:
		await get_tree().process_frame
	var list: DragScroll = app.screen.find_children("*","DragScroll",true,false)[0]
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.position = Vector2(150,600)
	finger.pressed = true
	get_viewport().push_input(finger,true)
	for i in 10:
		var swipe := InputEventScreenDrag.new()
		swipe.index = 0
		swipe.position = Vector2(150,600-30*(i+1))
		swipe.relative = Vector2(0,-30)
		get_viewport().push_input(swipe,true)
		await get_tree().process_frame
	finger = finger.duplicate()
	finger.pressed = false
	get_viewport().push_input(finger,true)
	for i in 3:
		await get_tree().process_frame
	check(list.scroll_vertical > 150,"finger drag scrolls the book")
	check(app.page=="collection" and not is_instance_valid(app.modal),"scrolling over a card does not open it")
	await click("Missing")
	check(app.collection_filter=="Missing","pointer filters book")
	print("UI CHECKS=",checks," FAILURES=",failures.size())
	var file := FileAccess.open("res://docs/ui-results.txt",FileAccess.WRITE)
	file.store_string("Pointer/touch events routed through viewport GUI\nChecks: %d\nFailures: %d\n"%[checks,failures.size()]+"\n".join(failures))
	file.close()
	Sound.shutdown()
	app.queue_free()
	await get_tree().process_frame
	OS.delay_msec(180)
	get_tree().quit(0 if failures.is_empty() else 1)
