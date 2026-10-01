class_name EventRail
extends VBoxContainer
## The home screen's event rail: a round button per live event on the left edge, halfway down the
## open scene, the way live games keep their calendar and current event one tap away. Each shows its
## state without being opened (a countdown, the month's week dots) and a red dot when it wants
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
	var throb := DailyTreats.Throb.new()
	throb.amount = .06
	button.add_child(throb)
	return {"column": column, "button": button, "status": status, "label": status.get_child(0), "dot": dot, "throb": throb}

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
	(_showcase.label as Label).text = NestTheme.t("Earned!") if earned else "%d / %d" % [KinuShowcase.progress(), KinuShowcase.required_weeks().size()]
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
