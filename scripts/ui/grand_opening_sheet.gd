class_name GrandOpeningSheet
extends Control
## The Grand Opening, dressed like a shop's opening day: a red-and-white kohaku banner over the
## three launch exclusives, each with its goal and progress. It opens loud once as the launch
## announcement, sits on the event rail for the rest of the event, and gives every reward its own
## celebration the moment it's earned. Once all three are in, it hands the player on to the
## Monthly Showcase, the longer goal for the month.

const PANEL := Color("b92f35")
const DEEP := Color("6e1820")
const RED := Color("d8403f")
const WHITE := Color("fff7ec")
const GOLD := DailyTreats.GOLD
const GOLD_BRIGHT := DailyTreats.GOLD_BRIGHT
const SOFT := Color("ffd9d2")
const DONE_FILL := Color("fdf0dc")

var app: Node
var announcing := false

static func open(owner: Node, announce: bool = false) -> void:
	owner._close_modal()
	var sheet := GrandOpeningSheet.new()
	sheet.app = owner
	sheet.announcing = announce
	owner.modal = sheet
	sheet.add_to_group("modal_input_lock")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.screen.add_child(sheet)
	if announce:
		GrandOpening.mark_announced()
	sheet.build()

func _leave() -> void:
	var was_announcing := announcing
	app._close_modal()
	if was_announcing and app.page == "home":
		KinuShowcase.prompt(app)

func caption(parent: Node, text: String, points: int, color: Color) -> Label:
	var label := NestTheme.label(text, points, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func build() -> void:
	ShowcaseSheet._backdrop(self)
	var scroll := DragScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20
	scroll.offset_right = -20
	scroll.offset_top = 24
	scroll.offset_bottom = -24
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "GrandOpeningSheet"
	panel.custom_minimum_size.x = minf(440, get_viewport_rect().size.x-40)
	var style := NestTheme.box(PANEL, 30, GOLD, 9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	panel.add_child(stack)
	_banner(stack)
	if GrandOpening.complete():
		caption(stack, "All three launch exclusives are yours. Thank you for being here from day one!", 16, WHITE)
	elif GrandOpening.ended():
		caption(stack, "The Grand Opening has closed. Anything you earned is yours to keep.", 16, WHITE)
	else:
		caption(stack, "Kinu Tumble is open! Earn three launch exclusives before 31 October.", 16, WHITE)
	for row in GrandOpening.rewards():
		stack.add_child(_reward_card(row))
	if GrandOpening.complete() and KinuShowcase.active() and not KinuShowcase.earned():
		var next := NestTheme.button(NestTheme.t("See the %s Showcase")%KinuShowcase.month_only(KinuShowcase.current_month()), func() -> void: ShowcaseSheet.open(app), false, "plop")
		next.name = "GrandOpeningShowcase"
		stack.add_child(next)
	var close := NestTheme.button("LET'S GO!" if announcing else "Close", _leave, announcing, "plop")
	close.name = "GrandOpeningClose"
	close.custom_minimum_size.y = 64 if announcing else 50
	close.add_theme_font_size_override("font_size", 24 if announcing else 19)
	stack.add_child(close)
	if announcing:
		close.add_child(ButtonGloss.new())
		close.add_child(DailyTreats.Throb.new())
	caption(stack, "Earned items stay in your collection forever. They'll never be sold in the Shop or found in the Kinu Claw.", 12, SOFT)
	_entrance(panel)

func _entrance(panel: Control) -> void:
	panel.modulate.a = 0
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(panel, "modulate:a", 1.0, .25)
	if not announcing:
		return
	panel.pivot_offset = Vector2(panel.custom_minimum_size.x*.5, 300)
	panel.scale = Vector2.ONE*.7
	entrance.tween_property(panel, "scale", Vector2.ONE, .5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("special")
	Haptics.pulse(35, .6)
	get_tree().create_timer(.25).timeout.connect(func() -> void:
		if is_instance_valid(app) and app.modal == self:
			app._confetti())

## The kohaku banner: red and white stripes behind the title, like the curtain hung outside a
## shop on its first day.
func _banner(stack: Node) -> void:
	if announcing:
		var fresh := CenterContainer.new()
		stack.add_child(fresh)
		var tag := NestTheme.pill("LAUNCH CELEBRATION!", 15, DEEP)
		(tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GOLD_BRIGHT
		fresh.add_child(tag)
		tag.add_child(DailyTreats.Throb.new())
	var banner := PanelContainer.new()
	var banner_style := NestTheme.box(RED, 18, GOLD_BRIGHT, 6)
	banner_style.content_margin_top = 4
	banner_style.content_margin_bottom = 6
	banner.add_theme_stylebox_override("panel", banner_style)
	banner.clip_contents = true
	stack.add_child(banner)
	banner.add_child(Kohaku.new())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	banner.add_child(Kohaku.inset(body))
	var title := NestTheme.headline("GRAND OPENING", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var line := "%d / %d" % [GrandOpening.earned_count(), GrandOpening.rewards().size()]
	if not GrandOpening.ended():
		line += "  ·  " + GrandOpening.ends_text().to_upper()
	var sub := caption(body, "★  %s  ★" % line, 15, WHITE)
	sub.add_theme_color_override("font_outline_color", NestTheme.INK)
	sub.add_theme_constant_override("outline_size", 5)

func _reward_card(row: Dictionary) -> PanelContainer:
	var item: Resource = row.item
	var kind: String = row.kind
	var got := GrandOpening.earned(row.key)
	var card := PanelContainer.new()
	card.name = "Reward_"+item.id
	var card_style := NestTheme.box(DONE_FILL if got else WHITE, 20, GOLD if got else Color("e8b9a8"), 5)
	card_style.content_margin_left = 8
	card_style.content_margin_right = 10
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	var art := thumb(item, Vector2(92, 80))
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(art)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	line.add_child(copy)
	var kind_label := NestTheme.label(NestTheme.t(KinuShowcase.KINDS[kind]).to_upper(), 12, RED)
	copy.add_child(kind_label)
	var name_label := NestTheme.label(NestTheme.t(item.display_name), 21)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(name_label)
	var amount := int(row.amount)
	var done := mini(GrandOpening.progress(row), amount)
	if got:
		copy.add_child(NestTheme.label("Earned! It's in your collection.", 14, NestTheme.MUTED))
		var stamp := DailyTreats.Stamp.new()
		stamp.reach = 18.0
		card.add_child(stamp)
	else:
		var goal := NestTheme.label(GrandOpening.goal_text(row), 15)
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(goal)
		var bottom := HBoxContainer.new()
		bottom.add_theme_constant_override("separation", 8)
		copy.add_child(bottom)
		var bar := NestTheme.progress(done, amount)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bottom.add_child(bar)
		bottom.add_child(NestTheme.label("%d / %d" % [done, amount], 14, NestTheme.MUTED))
		if GrandOpening.ended():
			card.modulate.a = .6
	return card

## The small picture of a reward: its baked thumbnail, or the flat drawing for a room.
static func thumb(item: Resource, extent: Vector2) -> Control:
	var art: Control
	if GrandOpening.kind_of(item) == "room":
		art = DecorPreview.room_swatch(item, Vector2i(extent))
	else:
		var rect := TextureRect.new()
		rect.texture = CollectionThumb.outfit(item) if item is KinuOutfit else CollectionThumb.box(item)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art = rect
	art.custom_minimum_size = extent
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

## The pill that marks a launch exclusive, here and in the Kinu Book.
static func exclusive_pill(points: int) -> PanelContainer:
	var pill := NestTheme.pill("Grand Opening", points, WHITE)
	var style := (pill.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = RED
	style.border_color = DEEP
	pill.add_theme_stylebox_override("panel", style)
	return pill

# ---------- The reveal ----------

## The moment a launch exclusive is earned: the banner drops in, the prize pops onto its stage
## under confetti, and the three reward slots show how many are collected.
static func celebrate(owner: Node, reveal: Dictionary) -> void:
	owner._close_modal()
	var sheet := GrandOpeningSheet.new()
	sheet.app = owner
	owner.modal = sheet
	sheet.add_to_group("modal_input_lock")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.screen.add_child(sheet)
	sheet._celebration(reveal)

func _celebration(reveal: Dictionary) -> void:
	var item: Resource = reveal.item
	var kind: String = reveal.kind
	GrandOpening.clear_reveal(item)
	ShowcaseSheet._backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var sign := PanelContainer.new()
	sign.name = "GrandOpeningReveal"
	sign.custom_minimum_size.x = minf(430, get_viewport_rect().size.x-40)
	var sign_style := NestTheme.box(PANEL, 30, GOLD, 9)
	sign_style.content_margin_left = 14
	sign_style.content_margin_right = 14
	sign_style.content_margin_top = 14
	sign.add_theme_stylebox_override("panel", sign_style)
	center.add_child(sign)
	var stack: VBoxContainer = app._vbox(sign, 10)
	var banner := PanelContainer.new()
	var banner_style := NestTheme.box(RED, 18, GOLD_BRIGHT, 6)
	banner_style.content_margin_top = 4
	banner_style.content_margin_bottom = 6
	banner.add_theme_stylebox_override("panel", banner_style)
	banner.clip_contents = true
	stack.add_child(banner)
	banner.add_child(Kohaku.new())
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	banner.add_child(Kohaku.inset(heading))
	var title := NestTheme.headline("LAUNCH EXCLUSIVE!", 32, GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	var sub := caption(heading, "★  %s  ★" % NestTheme.t("GRAND OPENING"), 14, WHITE)
	sub.add_theme_color_override("font_outline_color", NestTheme.INK)
	sub.add_theme_constant_override("outline_size", 5)
	# One slot per reward, filled for everything collected so far; this one stamps in last.
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 10)
	stack.add_child(slots)
	var fresh_seal: Control
	for row in GrandOpening.rewards():
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slots.add_child(slot)
		var disc := Slot.new()
		disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(disc)
		if not GrandOpening.earned(row.key):
			continue
		var seal := DailyTreats.Stamp.new()
		seal.reach = 20.0
		seal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seal.pivot_offset = Vector2(23, 23)
		slot.add_child(seal)
		if row.item == item:
			seal.scale = Vector2.ZERO
			fresh_seal = seal
	var stage := PanelContainer.new()
	var stage_style := NestTheme.box(DEEP, 24, GOLD, 5)
	stage_style.content_margin_top = 8
	stage_style.content_margin_bottom = 10
	stage.add_theme_stylebox_override("panel", stage_style)
	stage.clip_contents = true
	stage.custom_minimum_size.y = 210
	stack.add_child(stage)
	var burst := CapsuleReveal.Rays.new()
	burst.color = GOLD
	burst.rotation_speed = .3
	burst.modulate.a = 0
	stage.add_child(burst)
	var stage_row := CenterContainer.new()
	stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(stage_row)
	var preview := DailyTreats.Bob.new()
	preview.add_child(CapsuleReveal.big_preview(app.run.catalog, kind, item, Vector2i(260, 190)))
	stage_row.add_child(preview)
	preview.modulate.a = 0
	var name_label := NestTheme.headline(NestTheme.t(item.display_name), 34, GOLD_BRIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.modulate.a = 0
	stack.add_child(name_label)
	var pills := HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_CENTER
	pills.add_theme_constant_override("separation", 8)
	pills.modulate.a = 0
	stack.add_child(pills)
	pills.add_child(NestTheme.pill(KinuShowcase.KINDS[kind], 16))
	pills.add_child(exclusive_pill(16))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.modulate.a = 0
	stack.add_child(buttons)
	var wear := NestTheme.button("Wear It" if kind == "outfit" else "Use It", func() -> void:
		Save.buy(kind, item.id, 0)
		Save.clear_fresh(kind+":"+item.id)
		Sound.play("wardrobe")
		_finish_celebration(true)
	, true, "wardrobe")
	wear.name = "GrandOpeningUse"
	buttons.add_child(wear)
	buttons.add_child(NestTheme.button("Lovely!", func() -> void: _finish_celebration(false), false, "plop"))
	sign.pivot_offset = Vector2(sign.custom_minimum_size.x*.5, 280)
	sign.scale = Vector2.ONE*.4
	sign.modulate.a = 0
	var show := create_tween()
	show.set_parallel(true)
	show.tween_property(sign, "scale", Vector2.ONE, .45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(sign, "modulate:a", 1.0, .2)
	show.set_parallel(false)
	if fresh_seal:
		show.tween_callback(func() -> void:
			Sound.play("plop", 1.2)
			Haptics.pulse(30, .5))
		show.tween_property(fresh_seal, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_interval(.15)
	show.tween_callback(func() -> void:
		Sound.play("yay")
		Haptics.pulse(80, 1.0)
		app._confetti())
	show.set_parallel(true)
	show.tween_property(preview, "modulate:a", 1.0, .15)
	show.tween_property(burst, "modulate:a", .45, .3)
	show.tween_method(func(grow: float) -> void: preview.pop = grow, 0.0, 1.0, .6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	show.tween_property(name_label, "modulate:a", 1.0, .25)
	show.tween_property(pills, "modulate:a", 1.0, .25)
	show.tween_property(buttons, "modulate:a", 1.0, .3).set_delay(.2)

func _finish_celebration(wear: bool) -> void:
	app._clear_confetti()
	app._close_modal()
	if wear:
		app._home()
	elif app.page == "home":
		GrandOpening.prompt(app)

## Red and white kohaku stripes, the curtain of a Japanese celebration, as trim bands along the
## banner's top and bottom edges. The title sits on the plain red between them, so no letter ever
## straddles a stripe.
class Kohaku extends Control:
	const BAND := 9.0
	## Wraps the banner's text so it sits clear of both bands.
	static func inset(child: Control) -> MarginContainer:
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_top", int(BAND)+2)
		margin.add_theme_constant_override("margin_bottom", int(BAND)+2)
		margin.add_child(child)
		return margin
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var count := 16
		var width := size.x/count
		for i in count:
			if i % 2 == 1:
				draw_rect(Rect2(Vector2(i*width, 0), Vector2(width, BAND)), WHITE)
				draw_rect(Rect2(Vector2(i*width, size.y-BAND), Vector2(width, BAND)), WHITE)

## An empty reward slot in the reveal, waiting for its stamp.
class Slot extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(size*.5, 20.0, DEEP)
		draw_arc(size*.5, 20.0, 0, TAU, 32, GOLD, 3.0, true)
