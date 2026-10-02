class_name ShowcaseSheet
extends Control
## The Monthly Showcase, built as a sister to the Daily Treats sheet: the month's exclusive
## spotlit over its four goals. It opens loud once a month as an announcement, is always one tap
## away on the home rail, and has its own full-screen celebration for the moment it's earned.

const PANEL := Color("25205a")
const DEEP := Color("120e31")
const RIBBON := Color("d8407a")
const GOLD := DailyTreats.GOLD
const GOLD_BRIGHT := DailyTreats.GOLD_BRIGHT
const LOCKED := Color("352f6b")
const MISSED := Color("2a2440")
const DONE_FILL := DailyTreats.DONE_FILL
const DONE_INK := DailyTreats.DONE_INK
const SOFT := Color("cfc6f2")

var app: Node
var announcing := false

static func open(owner: Node, announce: bool = false) -> void:
	owner._close_modal()
	var sheet := ShowcaseSheet.new()
	sheet.app = owner
	sheet.announcing = announce
	owner.modal = sheet
	sheet.add_to_group("modal_input_lock")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.screen.add_child(sheet)
	if announce:
		KinuShowcase.mark_announced()
	sheet.build()

## Leaves the sheet; after the monthly announcement the day's treat gets its turn.
func _leave() -> void:
	var was_announcing := announcing
	app._close_modal()
	if was_announcing and app.page == "home":
		DailyCalendar.prompt(app)

func caption(parent: Node, text: String, points: int, color: Color) -> Label:
	var label := NestTheme.label(text, points, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func build() -> void:
	var month := KinuShowcase.current_month()
	var item := KinuShowcase.item_for(month)
	_backdrop(self)
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
	panel.name = "ShowcaseSheet"
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
	_banner(stack, month)
	if item == null:
		caption(stack, "No showcase this month. Check back on the 1st!", 18, SOFT)
	else:
		_spotlight(stack, item)
		_goals(stack, item)
	var close := NestTheme.button("LET'S GO!" if announcing else "Close", _leave, announcing, "plop")
	close.name = "ShowcaseClose"
	close.custom_minimum_size.y = 64 if announcing else 50
	close.add_theme_font_size_override("font_size", 24 if announcing else 19)
	stack.add_child(close)
	if announcing:
		close.add_child(ButtonGloss.new())
		close.add_child(DailyTreats.Throb.new())
	caption(stack, "A new showcase starts on the 1st of every month.", 12, Color("a79fd6"))
	_entrance(panel)

static func _backdrop(host: Control) -> void:
	var shade := ColorRect.new()
	shade.color = Color(.04, .03, .12, .88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(shade)
	var rays := CapsuleReveal.Rays.new()
	rays.color = GOLD
	rays.modulate.a = .22
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(rays)
	var sparkles := DailyTreats.Sparkles.new()
	sparkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(sparkles)

func _entrance(panel: Control) -> void:
	panel.modulate.a = 0
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(panel, "modulate:a", 1.0, .25)
	if not announcing:
		return
	# The announcement lands like a prize dropping into the tray.
	panel.pivot_offset = Vector2(panel.custom_minimum_size.x*.5, 300)
	panel.scale = Vector2.ONE*.7
	entrance.tween_property(panel, "scale", Vector2.ONE, .5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("special")
	Haptics.pulse(35, .6)
	get_tree().create_timer(.25).timeout.connect(func() -> void:
		if is_instance_valid(app) and app.modal == self:
			app._confetti())

func _banner(stack: Node, month: String) -> void:
	if announcing:
		var fresh := CenterContainer.new()
		stack.add_child(fresh)
		var tag := NestTheme.pill("NEW THIS MONTH!", 15, Color("8a2150"))
		(tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GOLD_BRIGHT
		fresh.add_child(tag)
		tag.add_child(DailyTreats.Throb.new())
	var banner := PanelContainer.new()
	var banner_style := NestTheme.box(RIBBON, 18, GOLD_BRIGHT, 6)
	banner_style.content_margin_top = 6
	banner_style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	stack.add_child(banner)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	banner.add_child(body)
	var title := NestTheme.headline("MONTHLY SHOWCASE", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var ends := KinuShowcase.days_left_text(KinuShowcase.days_left()).to_upper()
	caption(body, "★  %s · %s  ★" % [KinuShowcase.month_name(month).to_upper(), ends], 14, Color("ffe0ee"))

func _spotlight(stack: Node, item: Resource) -> void:
	var kind := KinuShowcase.kind_of(item)
	var earned := KinuShowcase.earned()
	var spotlight := PanelContainer.new()
	var spot_style := NestTheme.box(DEEP, 24, GOLD, 5)
	spot_style.content_margin_top = 8
	spot_style.content_margin_bottom = 12
	spotlight.add_theme_stylebox_override("panel", spot_style)
	spotlight.clip_contents = true
	stack.add_child(spotlight)
	var burst := CapsuleReveal.Rays.new()
	burst.color = GOLD if not earned else Color("59d19a")
	burst.rotation_speed = .22
	burst.modulate.a = .34
	spotlight.add_child(burst)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	spotlight.add_child(body)
	caption(body, "EARNED THIS MONTH!" if earned else "THIS MONTH'S EXCLUSIVE", 13, GOLD_BRIGHT if earned else SOFT)
	var hero := CenterContainer.new()
	hero.custom_minimum_size.y = 220
	body.add_child(hero)
	var bob := DailyTreats.Bob.new()
	hero.add_child(bob)
	bob.add_child(_prize(kind, item, Vector2i(300, 220)))
	var name_label := NestTheme.headline(NestTheme.t(item.display_name), 30, GOLD_BRIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(name_label)
	var pills := HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_CENTER
	pills.add_theme_constant_override("separation", 6)
	body.add_child(pills)
	pills.add_child(NestTheme.pill(KinuShowcase.KINDS[kind], 14))
	pills.add_child(exclusive_pill(14))
	caption(body, "Never sold in the Shop or found in the Kinu Claw.", 13, SOFT)
	if earned:
		var seal := DailyTreats.Stamp.new()
		seal.reach = 22.0
		spotlight.add_child(seal)

## The prize, framed to fill its stage: a Kinu outfit is zoomed to its own silhouette rather than
## left at the default camera distance, where it read as a speck on the card.
func _prize(kind: String, item: Resource, pixels: Vector2i) -> Control:
	var preview := CapsuleReveal.big_preview(app.run.catalog, kind, item, pixels)
	if preview is KinuPreview:
		(preview as KinuPreview).fit_model(1.12)
	return preview

## The gold "Showcase exclusive" pill used here and in the Kinu Book.
static func exclusive_pill(points: int, text: String = "Showcase exclusive") -> PanelContainer:
	var pill := NestTheme.pill(text, points, Color("5b1e3c"))
	var style := (pill.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = GOLD
	style.border_color = Color("8c580b")
	pill.add_theme_stylebox_override("panel", style)
	return pill

## The month's four goals, any order, all month long. Each shows its progress and is stamped when
## done; once all four are in, the card hands over to wearing the reward.
func _goals(stack: Node, item: Resource) -> void:
	var paper := VBoxContainer.new()
	paper.add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	paper.add_child(header)
	var heading := NestTheme.label("SHOWCASE GOALS", 14, Color("9f562b"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(NestTheme.label(NestTheme.t("%d / %d done")%[KinuShowcase.progress(), KinuShowcase.goal_count()], 14, NestTheme.MUTED))
	for goal in KinuShowcase.GOALS:
		var row := VBoxContainer.new()
		row.name = "ShowcaseGoal_"+str(goal.id)
		row.add_theme_constant_override("separation", 3)
		paper.add_child(row)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		row.add_child(top)
		var done := KinuShowcase.goal_done(goal)
		var text := NestTheme.label(KinuShowcase.goal_text(goal), 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(text)
		var amount := int(goal.amount)
		var progress := KinuShowcase.goal_progress(goal)
		if done:
			var seal := DailyTreats.Stamp.new()
			seal.custom_minimum_size = Vector2(24, 24)
			top.add_child(seal)
		else:
			top.add_child(NestTheme.label("%d / %d" % [progress, amount], 14, NestTheme.MUTED))
		var bar := FancyCard.XpMeter.new()
		bar.show_levels = false
		bar.custom_minimum_size.y = 14
		bar.max_value = amount
		bar.value = progress
		if done:
			bar.fill_top = Color("b9f0cf")
			bar.fill_bottom = Color("3fb67a")
		row.add_child(bar)
	if KinuShowcase.earned():
		heading.text = NestTheme.t("SHOWCASE COMPLETE")
		var kind := KinuShowcase.kind_of(item)
		paper.add_child(NestTheme.button("Wear It" if kind == "outfit" else "Use It", func() -> void:
			Save.buy(kind, item.id, 0)
			Save.clear_fresh(kind+":"+item.id)
			app._close_modal()
			app._home()
		, true, "wardrobe"))
	else:
		var hint := NestTheme.label(NestTheme.t("Finish all %d before the month ends, in any order.")%KinuShowcase.goal_count(), 13, NestTheme.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paper.add_child(hint)
	stack.add_child(NestTheme.paper(paper))

# ---------- The reveal ----------

## The moment the month's reward is earned: the four goals stamp in one by one, then the prize
## bursts out onto its stage under a double shower of confetti.
static func celebrate(owner: Node, reveal: Dictionary) -> void:
	owner._close_modal()
	var sheet := ShowcaseSheet.new()
	sheet.app = owner
	owner.modal = sheet
	sheet.add_to_group("modal_input_lock")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.screen.add_child(sheet)
	sheet._celebration(reveal)

func _celebration(reveal: Dictionary) -> void:
	var item: Resource = reveal.item
	var kind: String = reveal.kind
	KinuShowcase.clear_reveal(item)
	_backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var sign := PanelContainer.new()
	sign.custom_minimum_size.x = minf(430, get_viewport_rect().size.x-40)
	var sign_style := NestTheme.box(PANEL, 30, GOLD, 9)
	sign_style.content_margin_left = 14
	sign_style.content_margin_right = 14
	sign_style.content_margin_top = 14
	sign.add_theme_stylebox_override("panel", sign_style)
	center.add_child(sign)
	var stack: VBoxContainer = app._vbox(sign, 10)
	var banner := PanelContainer.new()
	var banner_style := NestTheme.box(RIBBON, 18, GOLD_BRIGHT, 6)
	banner_style.content_margin_top = 6
	banner_style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	stack.add_child(banner)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	banner.add_child(heading)
	var title := NestTheme.headline("SHOWCASE COMPLETE!", 34, GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	caption(heading, "★  %s  ★" % KinuShowcase.month_name(str(reveal.month)).to_upper(), 14, Color("ffe0ee"))
	var stamps := HBoxContainer.new()
	stamps.alignment = BoxContainer.ALIGNMENT_CENTER
	stamps.add_theme_constant_override("separation", 10)
	stack.add_child(stamps)
	var seals: Array[Control] = []
	for goal in KinuShowcase.GOALS:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(46, 46)
		stamps.add_child(slot)
		var seal := DailyTreats.Stamp.new()
		seal.reach = 20.0
		seal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seal.pivot_offset = Vector2(23, 23)
		seal.scale = Vector2.ZERO
		slot.add_child(seal)
		seals.append(seal)
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
	# The preview manages its own scale, so the pop rides on a holder around it.
	var preview := DailyTreats.Bob.new()
	preview.add_child(_prize(kind, item, Vector2i(300, 230)))
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
	buttons.add_child(NestTheme.button("Wear It" if kind == "outfit" else "Use It", func() -> void:
		Save.buy(kind, item.id, 0)
		Save.clear_fresh(kind+":"+item.id)
		Sound.play("wardrobe")
		_finish_celebration(true)
	, true, "wardrobe"))
	buttons.add_child(NestTheme.button("Lovely!", func() -> void: _finish_celebration(false), false, "plop"))
	# The sign slams in, the goals stamp down, then the prize pops.
	sign.pivot_offset = Vector2(sign.custom_minimum_size.x*.5, 280)
	sign.scale = Vector2.ONE*.4
	sign.modulate.a = 0
	var show := create_tween()
	show.set_parallel(true)
	show.tween_property(sign, "scale", Vector2.ONE, .45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(sign, "modulate:a", 1.0, .2)
	show.set_parallel(false)
	for i in seals.size():
		var seal := seals[i]
		show.tween_callback(func() -> void:
			Sound.play("plop", 1.0+i*.12)
			Haptics.pulse(18+i*6, .3+i*.1))
		show.tween_property(seal, "scale", Vector2.ONE, .18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	show.set_parallel(false)
	show.tween_callback(func() -> void:
		if is_instance_valid(app) and app.modal == self:
			app._confetti())

func _finish_celebration(wear: bool) -> void:
	app._clear_confetti()
	app._close_modal()
	if wear:
		app._home()
	elif app.page == "home":
		KinuShowcase.prompt(app)
