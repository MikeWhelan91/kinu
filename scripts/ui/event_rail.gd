class_name EventRail
extends VBoxContainer
## The home screen's event rail: a round button per live event on the left edge, halfway down the
## open scene, the way live games keep their calendar and current event one tap away. Each shows its
## state without being opened (a countdown, the month's goals) and a red dot when it wants
## the player. The Daily curtain is left to the missions.

const SIZE := 76.0
## Each event keeps its own sheet's colour on the rim and status pill; the face is cream like the
## curtain emblems, so the art reads on any room.
const TREAT_TINT := Color("c7307f")

var app: Node
var _treat: Dictionary = {}
var _showcase: Dictionary = {}
var _showcase_month := ""
var _opening: Dictionary = {}

static func build(owner: Node) -> EventRail:
	var rail := EventRail.new()
	rail.app = owner
	rail.name = "EventRail"
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_theme_constant_override("separation", 10)
	rail._treat = rail._button("DailyTreatRail", TREAT_TINT, DailyTreats.MysteryGift.new(52), func() -> void: DailyCalendar.show(owner))
	if GrandOpening.active() or not GrandOpening.pending_reveal().is_empty():
		var rewards := GrandOpening.rewards()
		if not rewards.is_empty():
			rail._opening = rail._button("GrandOpeningRail", GrandOpeningSheet.PANEL, _thumb(rewards[-1].item), func() -> void: GrandOpeningSheet.open(owner))
	if KinuShowcase.active():
		var item := KinuShowcase.item_for(KinuShowcase.current_month())
		rail._showcase = rail._button("ShowcaseRail", ShowcaseSheet.PANEL, _thumb(item), func() -> void: ShowcaseSheet.open(owner))
		rail._showcase_month = KinuShowcase.current_month()
	rail.refresh()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(rail.refresh)
	rail.add_child(timer)
	return rail

## A round event button with its status line underneath and a red dot for "come and look".
func _button(title: String, fill: Color, art: Control, callback: Callable) -> Dictionary:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", -8)
	add_child(column)
	var button := NestTheme.button("", callback, false, "plop")
	button.name = title
	button.custom_minimum_size = Vector2(SIZE, SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		var style := NestTheme.box(NestTheme.CREAM if state != "pressed" else Color("f3e6cf"), int(SIZE*.5), fill, 3 if state == "pressed" else 6)
		style.set_border_width_all(5)
		style.border_width_bottom = 3 if state == "pressed" else 7
		style.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, style)
	column.add_child(button)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -4
	button.add_child(holder)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	var status := NestTheme.pill("", 14, NestTheme.CREAM)
	var style := (status.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = fill
	style.border_color = NestTheme.INK
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	status.add_theme_stylebox_override("panel", style)
	status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(status)
	var dot := RedDot.new()
	dot.position = Vector2(SIZE-18, -2)
	button.add_child(dot)
	var shine := Shine.new()
	shine.tint = fill
	shine.phase = get_child_count()*1.3
	button.add_child(shine)
	var throb := DailyTreats.Throb.new()
	throb.amount = .06
	button.add_child(throb)
	return {"column": column, "button": button, "status": status, "label": status.get_child(0), "dot": dot, "throb": throb, "shine": shine}

static func _thumb(item: Resource) -> Control:
	var kind := "outfit" if item is KinuOutfit else str(item.kind)
	if kind == "room":
		var swatch := DecorPreview.room_swatch(item, Vector2i(50, 42))
		swatch.custom_minimum_size = Vector2(50, 42)
		return swatch
	var rect := TextureRect.new()
	rect.texture = CollectionThumb.outfit(item) if kind == "outfit" else CollectionThumb.box(item)
	rect.custom_minimum_size = Vector2(62, 56)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect

## Called every second: the treat's countdown ticks and both dots follow the live state.
func refresh() -> void:
	# The local clock can disagree with the reward server (including across timezones).
	# Keep the whole rail out of sight until this launch has a server cooldown.
	visible = DailyCalendar.status_known()
	if not visible:
		return
	_sync_showcase_month()
	var ready := DailyCalendar.ready()
	(_treat.label as Label).text = NestTheme.t("Claim!") if ready else DailyCalendar.countdown_clock()
	_alert(_treat, ready)
	if not _opening.is_empty():
		(_opening.label as Label).text = "%d / %d" % [GrandOpening.earned_count(), GrandOpening.rewards().size()]
		_alert(_opening, not GrandOpening.pending_reveal().is_empty() or GrandOpening.should_announce())
	if _showcase.is_empty():
		return
	var earned := KinuShowcase.earned()
	(_showcase.label as Label).text = NestTheme.t("Earned!") if earned else "%d / %d" % [KinuShowcase.progress(), KinuShowcase.goal_count()]
	_alert(_showcase, not KinuShowcase.pending_reveal().is_empty() or KinuShowcase.should_announce())

func _sync_showcase_month() -> void:
	var month := KinuShowcase.current_month()
	if month == _showcase_month and (not _showcase.is_empty() or not KinuShowcase.active()):
		return
	if not _showcase.is_empty():
		(_showcase.column as Node).queue_free()
		_showcase = {}
	_showcase_month = month
	if KinuShowcase.active():
		_showcase = _button("ShowcaseRail", ShowcaseSheet.PANEL, _thumb(KinuShowcase.item_for(month)), func() -> void: ShowcaseSheet.open(app))

func _alert(entry: Dictionary, on: bool) -> void:
	(entry.dot as Control).visible = on
	(entry.shine as Shine).hot = on
	var throb: DailyTreats.Throb = entry.throb
	throb.set_process(on)
	if not on:
		(entry.button as Control).scale = Vector2.ONE

class RedDot extends Control:
	func _init() -> void:
		size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(size*.5, 11.0, NestTheme.INK)
		draw_circle(size*.5, 8.5, Color("e5383b"))

## A breathing gold halo behind a rail button with two sparkling arcs orbiting its rim, so the
## events catch the eye from the home screen. It burns brighter while the event wants the player.
class Shine extends Control:
	var tint := NestTheme.SUN
	var hot := false
	var phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()

	func _draw() -> void:
		var c := size*.5
		var r := minf(size.x, size.y)*.5
		var gold := DailyTreats.GOLD_BRIGHT
		var pulse := .5+.5*sin(phase*2.6)
		var strength := 1.0 if hot else .8
		# Soft breathing glow in gold.
		for ring in 4:
			draw_circle(c, r+2.0+ring*4.5+pulse*4.0, Color(gold, (.42-ring*.09)*(.6+.4*pulse)*strength))
		# A gold ring hugging the rim.
		draw_arc(c, r+3.5, 0, TAU, 56, NestTheme.INK, 6.0, true)
		draw_arc(c, r+3.5, 0, TAU, 56, Color("ffcf4a"), 3.5, true)
		var orbit := r+3.5
		for side in 2:
			var start := phase*1.7+side*PI
			# A comet of light running round the ring, fading along its tail.
			var tail := PackedVector2Array()
			var shades := PackedColorArray()
			for step in 14:
				var t := float(step)/13.0
				tail.append(c+Vector2.RIGHT.rotated(start-t*1.3)*orbit)
				shades.append(Color(1, 1, .92, (1.0-t)*strength))
			draw_polyline_colors(tail, shades, 3.5, true)
			var head := c+Vector2.RIGHT.rotated(start)*orbit
			var arm := 6.0+3.0*pulse
			draw_circle(head, 3.2, Color(1, 1, 1, strength))
			draw_line(head-Vector2(arm, 0), head+Vector2(arm, 0), Color(1, 1, 1, strength), 2.0, true)
			draw_line(head-Vector2(0, arm), head+Vector2(0, arm), Color(1, 1, 1, strength), 2.0, true)
