class_name CardGrid
extends RefCounted
## Two-column grids of wooden cards shared by the Kinu Book and the Kinu Shop: a preview on a
## tinted stage, a carved name and a status line underneath.

static func grid(parent: Node) -> GridContainer:
	var node := GridContainer.new()
	node.columns = 2
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("h_separation", 12)
	node.add_theme_constant_override("v_separation", 12)
	parent.add_child(node)
	return node

static func heading(parent: Node, text: String) -> void:
	var label := NestTheme.headline(text, 28, NestTheme.SUN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

## Returns {"button", "status"}; `status` is a centred slot for a pill or label.
static func card(target: GridContainer, preview: Control, title: String, tint: Color, callback: Callable, height: float = 246, sound: String = "tap") -> Dictionary:
	var button := NestTheme.button("", callback, false, sound)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(200, height)
	NestTheme.style_card(button, "plain")
	target.add_child(button)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 12
	stack.offset_right = -12
	stack.offset_top = 10
	stack.offset_bottom = -14
	button.add_child(stack)
	var stage := NestTheme.stage(tint)
	stack.add_child(stage)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	stage.add_child(holder)
	var name := NestTheme.headline(title, 19)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	stack.add_child(name)
	var status := CenterContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(status)
	return {"button": button, "status": status, "stage": stage}

static func tint(index: int) -> Color:
	return NestTheme.STAGES[index % NestTheme.STAGES.size()]
