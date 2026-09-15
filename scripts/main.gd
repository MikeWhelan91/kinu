extends Node
var run: NestRun
var canvas: CanvasLayer
var screen: Control
var content: Control
var modal: Control
var toast: Label
var toast_panel: PanelContainer
var toast_tween: Tween
var page: String = ""
var score_label: Label
var best_label: Label
var height_label: Label
var hint_pill: PanelContainer
var next_slot: VBoxContainer
var tutorial_panel: PanelContainer
var tutorial_text: Label
var tutorial_title: Label
var tutorial_button: Button
var tutorial_step: int = -1
var initial_best: int = 0
var collection_filter: String = "All"
var last_stats: Dictionary = {}
var safe_top: float = 26
var safe_bottom: float = 20

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Sound.start_music()
	run = NestRun.new()
	add_child(run)
	run.updated.connect(_hud_update)
	run.message.connect(_toast)
	run.finished.connect(_results)
	run.action_done.connect(_tutorial_action)
	canvas = CanvasLayer.new()
	add_child(canvas)
	get_viewport().size_changed.connect(_resized)
	_home()

func _resized() -> void:
	_update_safe_area()
	if is_instance_valid(content):
		content.offset_top = safe_top
		content.offset_bottom = -safe_bottom

func _update_safe_area() -> void:
	safe_top = 26
	safe_bottom = 20
	if OS.has_feature("ios") or OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var window := DisplayServer.window_get_size()
		var viewport := get_viewport().get_visible_rect().size
		if window.y>0 and safe.size.y>0:
			var scale_factor := viewport.y/window.y
			safe_top = maxf(16,safe.position.y*scale_factor+8)
			safe_bottom = maxf(16,(window.y-safe.end.y)*scale_factor+8)

func _new_screen(name_: String, paper: bool = false) -> void:
	page = name_
	if is_instance_valid(screen):
		canvas.remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = NestTheme.theme()
	canvas.add_child(screen)
	var decoration := GardenOverlay.new()
	decoration.paper = paper
	decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(decoration)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26
	content.offset_right = -26
	screen.add_child(content)
	_resized()
	toast_panel = NestTheme.pill("",28)
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Messages sit low, above the controls, where they don't cover the tower.
	toast_panel.anchor_top = .72
	toast_panel.anchor_bottom = .72
	toast_panel.modulate.a = 0
	content.add_child(toast_panel)
	toast = toast_panel.get_child(0)
	modal = null
	tutorial_panel = null
	run.accepting_input = name_ == "play"

func _vbox(parent: Node, separation: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",separation)
	parent.add_child(box)
	return box

func _center_label(parent: Node, text: String, font_size: int, color: Color = NestTheme.INK) -> Label:
	var label := NestTheme.label(text,font_size,color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _home() -> void:
	NestMenuScreen.home(self)

func _start() -> void:
	get_tree().paused = false
	initial_best = int(Save.data.best)
	_new_screen("play")
	_build_hud()
	tutorial_step = -1 if Save.data.tutorial else 0
	run.begin()
	if tutorial_step == 0:
		_build_tutorial()

func _build_hud() -> void:
	var pad := HudOverlay.new()
	pad.run = run
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(pad)
	screen.move_child(pad,1)
	var score_card := PanelContainer.new()
	score_card.custom_minimum_size = Vector2(172,0)
	score_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(score_card)
	var column := _vbox(score_card,-6)
	_center_label(column,"HEIGHT",15,NestTheme.MUTED)
	score_label = NestTheme.headline("0 cm",40,NestTheme.SUN)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(score_label)
	best_label = _center_label(column,"BEST 0",15,NestTheme.MUTED)
	var next_card := PanelContainer.new()
	next_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	next_card.offset_left = -124
	next_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	content.add_child(next_card)
	next_slot = _vbox(next_card,0)
	var pause_button := NestTheme.button("II",_pause)
	pause_button.custom_minimum_size = Vector2(70,70)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_button.offset_left = -35
	pause_button.offset_right = 35
	pause_button.offset_bottom = 70
	content.add_child(pause_button)
	var height_pill := NestTheme.pill("0 Kinu",22)
	height_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	height_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	height_pill.offset_top = 82
	content.add_child(height_pill)
	height_label = height_pill.get_child(0)
	hint_pill = NestTheme.pill("Drag Kinu to move  ·  swipe to spin" if Save.data.controls == "grab" else "Drag to move  ·  let go to drop",18)
	hint_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_pill.offset_bottom = -12
	if Save.data.controls == "classic":
		hint_pill.anchor_top = .78
		hint_pill.anchor_bottom = .78
		screen.add_child(hint_pill)
	else:
		content.add_child(hint_pill)
	pad.hint = hint_pill
	pad.app = self

func _hud_update() -> void:
	if page != "play" or not is_instance_valid(score_label):
		return
	score_label.text = _number(run.score)+" cm"
	best_label.text = "BEST "+_number(Save.data.best)+" cm"
	height_label.text = "%d Kinu"%run.placed
	hint_pill.visible = run.placed < 3 and run.state == "aim" and tutorial_step < 0
	for child in next_slot.get_children():
		next_slot.remove_child(child)
		child.queue_free()
	_center_label(next_slot,"NEXT",15,NestTheme.MUTED)
	if run.next_shape:
		var preview := KinuPreview.new()
		preview.setup(run.next_shape,run.next_flavour,true,Vector2i(84,72))
		next_slot.add_child(preview)

func _toast(text: String, color: Color) -> void:
	if page != "play":
		return
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast.text = text
	# Messages sit in a cream pill, so their colour is darkened for contrast against it.
	toast.add_theme_color_override("font_color",color.darkened(.15))
	var extent := toast_panel.get_combined_minimum_size()
	toast_panel.offset_left = -extent.x*.5
	toast_panel.offset_right = extent.x*.5
	toast_panel.offset_top = -extent.y*.5
	toast_panel.offset_bottom = extent.y*.5
	toast_panel.modulate.a = 1
	toast_panel.pivot_offset = extent*.5
	toast_panel.scale = Vector2(.6,.6)
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel,"scale",Vector2.ONE,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(1.6)
	toast_tween.tween_property(toast_panel,"modulate:a",0.0,.4)

func _header(title: String, callback: Callable = _home) -> VBoxContainer:
	var layout := _vbox(content,18)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	layout.add_child(row)
	var back := NestTheme.button("‹",callback)
	back.custom_minimum_size = Vector2(66,66)
	row.add_child(back)
	var label := NestTheme.label(title,28)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 66
	row.add_child(spacer)
	return layout

func _collection() -> void:
	KinuBookScreen.show(self)

func _flavour_detail(flavour: KinuFlavour, known: bool) -> void:
	KinuBookScreen.flavour_detail(self, flavour, known)

func _shop() -> void:
	KinuShopScreen.show(self)

func _settings() -> void:
	NestSettingsScreen.show(self)

func _credits() -> void:
	NestSettingsScreen.credits(self)

func _modal(title: String) -> VBoxContainer:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(.12,.07,.05,.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	center.add_child(panel)
	var stack := _vbox(panel,16)
	_center_label(stack,title,32)
	return stack

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null

func _pause() -> void:
	if page != "play" or get_tree().paused:
		return
	run.gesture = ""
	run.pointer_id = -99
	get_tree().paused = true
	var stack := _modal("Paused")
	_center_label(stack,"Your tower will wait right here.",18,NestTheme.MUTED)
	stack.add_child(NestTheme.button("Keep playing",func() -> void:
		_close_modal()
		get_tree().paused = false
	,true))
	stack.add_child(NestTheme.button("Restart this nest",func() -> void:
		Save.finish_run(run.score)
		_start()
	))
	stack.add_child(NestTheme.button("Return home",func() -> void:
		Save.finish_run(run.score)
		_home()
	))

func _results(stats: Dictionary) -> void:
	NestMenuScreen.results(self, stats)

func _confetti() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 30:
		var star := NestTheme.headline("★",rng.randi_range(22,40),[NestTheme.SUN,NestTheme.BERRY,NestTheme.SKY,Color("7ed957")][i%4])
		star.position = Vector2(rng.randf_range(0,500),-80)
		screen.add_child(star)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(star,"position:y",1100,rng.randf_range(3.5,6)).set_delay(i*.05)
		tween.tween_property(star,"rotation",rng.randf_range(-3,3),4)
		tween.chain().tween_callback(star.queue_free)

func _tutorial_steps() -> Array:
	var grab: bool = Save.data.controls == "grab"
	return [
		["Grab Kinu","Press on Kinu and drag to move it. The shadow shows where it lands."] if grab else ["Drag to aim","Drag anywhere to move Kinu. The shadow shows where it lands."],
		["Let go to drop","Lift your finger and watch Kinu plop into the box."],
		["Spin the box","Swipe anywhere else to turn the box. Flick to keep it spinning."] if grab else ["Spin the box","Swipe along the bottom strip to turn the box. Flick to keep it spinning."],
		["Build a tower","Stack as high as you can. Wait for them to settle."],
		["Careful!","If any Kinu tumbles off onto the counter, the run is over."]]

func _build_tutorial() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if Save.data.controls == "classic":
		tutorial_panel.anchor_top = .78
		tutorial_panel.anchor_bottom = .78
	tutorial_panel.offset_top = -10
	tutorial_panel.offset_bottom = -10
	content.add_child(tutorial_panel)
	var box := _vbox(tutorial_panel,2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_title = _center_label(box,"",24,NestTheme.INK)
	tutorial_text = _center_label(box,"",17,NestTheme.MUTED)
	tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_button = NestTheme.button("Skip guide",_finish_tutorial)
	tutorial_button.custom_minimum_size.y = 56
	tutorial_button.add_theme_font_size_override("font_size",17)
	box.add_child(tutorial_button)
	_tutorial_refresh()

func _tutorial_refresh() -> void:
	if not is_instance_valid(tutorial_text):
		return
	var steps := _tutorial_steps()
	var step: Array = steps[clampi(tutorial_step,0,steps.size()-1)]
	tutorial_title.text = "%d / %d  ·  %s"%[tutorial_step+1,steps.size(),step[0]]
	tutorial_text.text = step[1]
	if tutorial_step == steps.size()-1:
		tutorial_button.text = "Let’s stack!"

func _tutorial_action(action: String) -> void:
	if tutorial_step<0 or page!="play":
		return
	var expected := ["aim","drop","spin","settle"]
	if tutorial_step<expected.size() and action==expected[tutorial_step]:
		tutorial_step += 1
		_tutorial_refresh()

func _finish_tutorial() -> void:
	Save.setting("tutorial",true)
	tutorial_step = -1
	_hud_update()
	if is_instance_valid(tutorial_panel):
		tutorial_panel.queue_free()
		tutorial_panel = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Save.persist()
		Sound.shutdown()
		await get_tree().create_timer(.15,true).timeout
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and page=="play":
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if page=="play":
			_pause()
		elif page in ["collection","settings","credits","shop"]:
			_home()

func _number(value: Variant) -> String:
	var raw := str(int(value))
	var result := ""
	for i in raw.length():
		if i>0 and (raw.length()-i)%3==0:
			result += ","
		result += raw[i]
	return result
