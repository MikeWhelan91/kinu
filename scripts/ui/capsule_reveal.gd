class_name CapsuleReveal
extends Control
## The prize reveal: the capsule rattles in the middle of the screen, each tap shakes it harder, and
## the third tap pops it open onto the prize with a burst of light sized to how rare it was.

signal closed(action: String)

const TAPS := 3
const GRADE_COLORS := {"legendary": Color("ffb62e"), "epic": Color("b077ff"), "rare": Color("3fa9f5"), "common": Color("ffe7a3")}

var app: Node
var prize: Dictionary = {}
var taps: int = 0
var opened: bool = false
var capsule: Node3D
var holder: SubViewportContainer
var hint: Label
var rays: Rays
var card: Control
var spin: float = 0.0
var shake: float = 0.0

static func open(owner: Node, won: Dictionary) -> CapsuleReveal:
	var reveal := CapsuleReveal.new()
	reveal.app = owner
	reveal.prize = won
	reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.screen.add_child(reveal)
	return reveal

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(.1, .06, .12, .72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	rays = Rays.new()
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rays.color = GRADE_COLORS.get(grade(), Color("ffe7a3"))
	rays.modulate.a = 0.0
	add_child(rays)
	holder = SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(320, 320)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	holder.offset_left = -160
	holder.offset_right = 160
	holder.offset_top = -230
	holder.offset_bottom = 90
	add_child(holder)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	holder.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = TofuShop.make_environment()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_energy = .25
	viewport.add_child(env)
	var sun := TofuShop.make_sun()
	sun.shadow_enabled = false
	viewport.add_child(sun)
	capsule = CatcherMachine.capsule_model()
	capsule.scale = Vector3.ONE*2.2
	viewport.add_child(capsule)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(0, .5, 5)
	camera.rotation.x = -.1
	viewport.add_child(camera)
	hint = NestTheme.headline("Tap to open!", 34)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.offset_left = -200
	hint.offset_right = 200
	hint.offset_top = 110
	hint.offset_bottom = 160
	hint.pivot_offset = Vector2(200, 25)
	add_child(hint)
	var bounce := create_tween().set_loops()
	bounce.tween_property(hint, "scale", Vector2.ONE*1.08, .45).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(hint, "scale", Vector2.ONE, .45).set_trans(Tween.TRANS_SINE)
	# The capsule drops in from above.
	capsule.position.y = 3.0
	var arrive := create_tween()
	arrive.tween_property(capsule, "position:y", 0.0, .5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sound.play("drop")

func grade() -> String:
	return KinuCatcher.grade({"kind": prize.kind, "amount": prize.get("amount", 0), "rarity": prize.item.rarity if prize.has("item") else ""})

func _process(delta: float) -> void:
	spin += delta*(.8 if not opened else 0.0)
	shake = maxf(0.0, shake-delta*3.0)
	if is_instance_valid(capsule) and not opened:
		capsule.rotation = Vector3(sin(Time.get_ticks_msec()*.05)*shake*.5, spin, sin(Time.get_ticks_msec()*.043)*shake*.6)
	rays.rotation_speed = .25 if opened else .1

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped or opened:
		return
	accept_event()
	taps += 1
	shake = .6+taps*.35
	Sound.play("plop", 1.0+taps*.15)
	Haptics.pulse(20+taps*15, .3+taps*.15)
	var punch := create_tween()
	punch.tween_property(capsule, "scale", Vector3.ONE*(2.2+taps*.18), .08)
	punch.tween_property(capsule, "scale", Vector3.ONE*(2.2+taps*.06), .18).set_trans(Tween.TRANS_BACK)
	if taps == 1:
		hint.text = tr("Again!")
	elif taps == 2:
		hint.text = tr("One more!")
		create_tween().tween_property(rays, "modulate:a", .35, .3)
	if taps >= TAPS:
		_pop()

func _pop() -> void:
	opened = true
	hint.hide()
	var top := capsule.get_node("Top") as Node3D
	var bottom := capsule.get_node("Bottom") as Node3D
	var inner := capsule.get_node("Inner") as Node3D
	var burst := create_tween().set_parallel(true)
	burst.tween_property(top, "position", Vector3(.6, 2.4, 0), .45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(top, "rotation", Vector3(0, 0, -1.6), .45)
	burst.tween_property(bottom, "position", Vector3(-.4, -2.6, 0), .5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	burst.tween_property(bottom, "rotation", Vector3(0, 0, 1.2), .5)
	burst.tween_property(inner, "scale", Vector3.ONE*2.5, .3)
	burst.tween_property(holder, "modulate:a", 0.0, .4).set_delay(.15)
	burst.tween_property(rays, "modulate:a", 1.0, .3)
	var legendary := grade() == "legendary"
	# Every capsule is a prize won, so every one gets the cheer; how big a moment it is comes
	# through in the haptics and the confetti below.
	Sound.play("yay")
	Haptics.pulse(80 if legendary else 50, 1.0 if legendary else .7)
	if grade() != "common":
		app._confetti()
		if legendary:
			get_tree().create_timer(.5).timeout.connect(func() -> void:
				if is_instance_valid(app) and is_instance_valid(self):
					app._confetti())
	_show_card()

func _show_card() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sign := SignBoard.new()
	sign.ropes = false
	sign.custom_minimum_size.x = minf(430, get_viewport_rect().size.x-40)
	center.add_child(sign)
	card = sign
	var stack: VBoxContainer = app._vbox(sign, 10)
	var level := grade()
	var titles := {"legendary": "LEGENDARY!", "epic": "EPIC!", "rare": "RARE!", "common": ""}
	var title_text: String = titles[level]
	if prize.kind == "beans" and int(prize.amount) >= KinuCatcher.JACKPOT:
		title_text = "JACKPOT!"
	var title := NestTheme.headline(title_text, 50, GRADE_COLORS[level] if level != "common" else NestTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Everyday prizes speak for themselves; only rare and better get a headline.
	if title_text != "":
		stack.add_child(title)
	var stage := NestTheme.stage(NestTheme.STAGES[["legendary", "epic", "rare", "common"].find(level) % 4])
	var stage_row := CenterContainer.new()
	stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(stage_row)
	stack.add_child(stage)
	var name_text := ""
	var detail := ""
	if prize.kind == "beans" or prize.kind == "tickets":
		var won := HBoxContainer.new()
		won.alignment = BoxContainer.ALIGNMENT_CENTER
		won.custom_minimum_size = Vector2(260, 170)
		won.add_child(TicketIcon.new(84) if prize.kind == "tickets" else BeanIcon.new(96))
		won.add_child(NestTheme.headline("+%s"%app._number(prize.amount), 64, NestTheme.SUN))
		stage_row.add_child(won)
		if prize.kind == "tickets":
			name_text = NestTheme.t("1 free play") if prize.amount == 1 else NestTheme.t("%d free plays")%prize.amount
			detail = NestTheme.t("Another go at the machine")
		else:
			name_text = NestTheme.t("%s beans")%app._number(prize.amount)
	else:
		var item: Resource = prize.item
		stage_row.add_child(big_preview(app.run.catalog, prize.kind, item, Vector2i(260, 190)))
		name_text = NestTheme.t(item.display_name)
		var kinds := {"outfit": "New outfit", "box": "New box", "room": "New room"}
		detail = NestTheme.t(kinds[prize.kind])
		if prize.get("crane_only", false):
			detail = NestTheme.t({"outfit": "Kinu Claw-only outfit", "box": "Kinu Claw-only box", "room": "Kinu Claw-only room"}[prize.kind])
	var name_label := NestTheme.headline(name_text, 34)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(name_label)
	var pills := HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_CENTER
	pills.add_theme_constant_override("separation", 8)
	stack.add_child(pills)
	if prize.has("item") and KinuCatcher.tier_pill(prize.item.rarity, 16):
		pills.add_child(KinuCatcher.tier_pill(prize.item.rarity, 16))
	if detail != "":
		pills.add_child(NestTheme.pill(detail, 16, NestTheme.PURPLE if prize.get("crane_only", false) else NestTheme.INK))
	if prize.get("lucky", false):
		var lucky_row := CenterContainer.new()
		lucky_row.add_child(NestTheme.pill("The lucky meter paid out!", 16, Color("e0a81f").darkened(.2)))
		stack.add_child(lucky_row)
	if KinuCatcher.is_item(prize):
		var wear := NestTheme.button("Wear It" if prize.kind == "outfit" else "Use It", func() -> void:
			Save.buy(prize.kind, prize.id, 0)
			Save.clear_fresh(prize.kind+":"+prize.id)
			Sound.play("wardrobe")
			_close("wear")
		, true, "wardrobe")
		stack.add_child(wear)
	stack.add_child(NestTheme.button("Keep Playing" if KinuCatcher.is_item(prize) else "Lovely!", func() -> void: _close("continue"), not KinuCatcher.is_item(prize), "plop"))
	sign.pivot_offset = Vector2(sign.custom_minimum_size.x*.5, 260)
	sign.scale = Vector2.ONE*.3
	sign.modulate.a = 0.0
	var pop := create_tween().set_parallel(true)
	pop.tween_property(sign, "scale", Vector2.ONE, .45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(.2)
	pop.tween_property(sign, "modulate:a", 1.0, .2).set_delay(.2)

## A large, happy preview of a won item.
static func big_preview(catalog: KinuCatalog, kind: String, item: Resource, pixels: Vector2i) -> Control:
	match kind:
		"outfit":
			var kinu := KinuPreview.new()
			if item.finish:
				kinu.setup(catalog.shapes[0], item.finish, true, pixels, "happy", null, true)
			else:
				kinu.setup(catalog.shapes[0], catalog.flavours[0], true, pixels, "happy", item, true)
			return kinu
		"box":
			var box := DecorPreview.new()
			box.setup_box(item, pixels)
			return box
	return DecorPreview.room_swatch(item, pixels)

func _close(action: String) -> void:
	# The burst belongs to this reveal. Closing it takes the stars with it, however quickly the
	# player taps away — otherwise they carry on raining over the machine behind.
	if is_instance_valid(app):
		app._clear_confetti()
	closed.emit(action)
	queue_free()

## Slowly turning light rays behind the prize.
class Rays extends Control:
	var color := Color.WHITE
	var rotation_speed := .1
	var angle := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		angle += delta*rotation_speed
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x*.5, size.y*.42)
		var reach := size.length()
		for i in 16:
			var a := angle+TAU*i/16.0
			var tone := color
			tone.a = .28 if i % 2 == 0 else .14
			draw_colored_polygon(PackedVector2Array([center, center+Vector2(cos(a-.09), sin(a-.09))*reach, center+Vector2(cos(a+.09), sin(a+.09))*reach]), tone)
		for ring in 3:
			var glow := color
			glow.a = .16-ring*.04
			draw_circle(center, 120+ring*60, glow)
