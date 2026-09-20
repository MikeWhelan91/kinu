class_name CardGrid
extends RefCounted
## Borderless display tiles shared by the Kinu Book and the Kinu Shop. Items sit like small
## exhibits on the dotted backdrop: only the artwork gets a frame, never a giant box around it.

static func grid(parent: Node, columns: int = 2) -> GridContainer:
	var node := GridContainer.new()
	node.columns = columns
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("h_separation", 16)
	node.add_theme_constant_override("v_separation", 18)
	parent.add_child(node)
	return node

static func heading(parent: Node, text: String) -> void:
	var label := NestTheme.headline(text, 28, NestTheme.SUN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

## Returns {"button", "status"}; `status` is a centred slot for a pill or label.
static func card(target: GridContainer, preview: Control, title: String, tint: Color, callback: Callable, height: float = 210, sound: String = "tap", width: float = 200, name_font_size: int = 19, artwork_only: bool = false) -> Dictionary:
	var button := NestTheme.button("", callback, false, sound)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(width, height)
	NestTheme.style_card(button, "plain")
	target.add_child(button)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 0
	stack.offset_right = 0
	stack.offset_top = 0
	stack.offset_bottom = 0
	button.add_child(stack)
	# Room illustrations already paint their own complete, inked picture. Giving those a second
	# pastel stage makes the rarity colour leak around the picture instead of reading as one image.
	var stage: Control = NestTheme.stage(tint)
	if artwork_only:
		# A PanelContainer still participates in VBox layout and sizes itself to the room artwork.
		# A bare Control collapses to zero height, which puts the card title over the illustration.
		var artwork_stage := PanelContainer.new()
		artwork_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork_stage.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		stage = artwork_stage
	stack.add_child(stage)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	stage.add_child(holder)
	var name := NestTheme.label(title, name_font_size)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	stack.add_child(name)
	var status := CenterContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(status)
	return {"button": button, "status": status, "stage": stage}

## A small ownership marker belongs over the artwork, not in the metadata line. This keeps the
## title and rarity easy to scan while still making ownership visible at a glance.
static func corner_badge(stage: Control, label: Control) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Child order already places this above the preview. Keeping the default layer is important:
	# collection badges must remain behind a modal's dimmer when an entry is opened.
	stage.add_child(overlay)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.offset_top = 7
	label.offset_right = -7
	overlay.add_child(label)

static func tint(index: int) -> Color:
	return NestTheme.STAGES[index % NestTheme.STAGES.size()]
