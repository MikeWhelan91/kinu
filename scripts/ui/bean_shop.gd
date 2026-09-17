class_name BeanShop
extends VBoxContainer
## One purchase destination shared by the home wallet and the cosmetic shop.
var app: Node
var balance: Label
var message: Label
var restore_button: Button
var retry_button: Button
var purchase_buttons: Dictionary = {}

static func open(owner: Node, back: Callable) -> void:
	owner._new_screen("beans", true)
	var layout: VBoxContainer = owner._header("Beans & Extras", back)
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var view := BeanShop.new()
	view.app = owner
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 12)
	scroll.add_child(view)
	view.build()

func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wallet := NestTheme.bean_pill("", 22)
	wallet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(wallet)
	balance = wallet.get_child(0).get_child(1)
	var intro := NestTheme.label("A little extra for your favourite looks.", 17, NestTheme.MUTED)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	for i in Store.PACKS.size():
		_pack(Store.PACKS[i], i)
	var extras := NestTheme.label("Extras", 23)
	add_child(extras)
	var card := _card()
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(content)
	content.add_child(NestTheme.label("Remove Ads", 21))
	var detail := NestTheme.label("One purchase. Permanently ad-free." if Store.ADS_ENABLED else "Available when ads arrive.", 15, NestTheme.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	var remove := _buy_button(Store.REMOVE_ADS)
	card.add_child(remove)
	message = NestTheme.label("", 16, NestTheme.MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(message)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)
	retry_button = NestTheme.button("Retry", Store.refresh_products)
	retry_button.add_theme_font_size_override("font_size", 16)
	retry_button.custom_minimum_size.y = 48
	actions.add_child(retry_button)
	restore_button = NestTheme.button("Restore Purchases", Store.restore)
	restore_button.add_theme_font_size_override("font_size", 16)
	restore_button.custom_minimum_size.y = 48
	restore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(restore_button)
	var note := NestTheme.label("Beans can also be earned by playing.\nRestore Purchases recovers Remove Ads; spent beans aren't restored.", 14, NestTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	Store.changed.connect(_refresh)
	Save.changed.connect(_refresh)
	_refresh()
	if Store.products.is_empty():
		Store.refresh_products()

func _card() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := NestTheme.box(NestTheme.CREAM, 22, NestTheme.INK, 4)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	return row

func _pack(pack: Dictionary, index: int) -> void:
	var row := _card()
	var art := PackArt.new()
	art.kind = index
	art.custom_minimum_size = Vector2(66, 88)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(NestTheme.label(pack.title, 17, NestTheme.MUTED))
	text.add_child(NestTheme.label(NestTheme.t("%s beans")%app._number(pack.beans), 27))
	if pack.bonus > 0:
		text.add_child(NestTheme.label(NestTheme.t("Includes %s bonus")%app._number(pack.bonus), 14, NestTheme.MUTED))
	var buy := _buy_button(pack.id)
	row.add_child(buy)

func _buy_button(id: String) -> Button:
	var button := NestTheme.button("", func() -> void: Store.buy(id), true)
	button.name = id.get_slice(".", id.get_slice_count(".")-1).capitalize()
	button.custom_minimum_size = Vector2(116, 52)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 17)
	purchase_buttons[id] = button
	return button

func _refresh() -> void:
	balance.text = NestTheme.t("%s beans")%app._number(Save.data.beans)
	for id in purchase_buttons:
		var button: Button = purchase_buttons[id]
		button.text = Store.price(id)
		button.disabled = not Store.can_buy(id)
		if Store.busy == id:
			button.text = "Waiting…"
		if id == Store.REMOVE_ADS:
			if Store.ads_removed():
				button.text = "Owned"
			elif not Store.ADS_ENABLED:
				button.text = "Coming soon"
	message.text = Store.status
	message.visible = not message.text.is_empty()
	retry_button.visible = Store.manager != null and not Store.status.is_empty()
	retry_button.disabled = Store.loading or not Store.busy.is_empty()
	restore_button.disabled = Store.manager == null or not Store.busy.is_empty()

class WalletButton extends Button:
	func _ready() -> void:
		name = "BeanWallet"
		custom_minimum_size = Vector2(90, 44)
		add_theme_font_size_override("font_size", 22)
		for state in ["normal", "hover", "pressed"]:
			var style := NestTheme.box(NestTheme.CREAM, 24, NestTheme.INK, 4)
			style.content_margin_left = 40
			style.content_margin_right = 14
			style.content_margin_top = 5
			style.content_margin_bottom = 5
			add_theme_stylebox_override(state, style)
		var bean := BeanIcon.new(26)
		bean.position = Vector2(9, 9)
		bean.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bean)
		Save.changed.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		text = str(int(Save.data.beans))+" +"

## Small inked packs, drawn in the same palette as the rest of the shop.
class PackArt extends Control:
	var kind := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fill: Color = [NestTheme.WOOD_LIGHT, NestTheme.BERRY, NestTheme.SKY, NestTheme.WOOD][kind]
		var body := StyleBoxFlat.new()
		body.bg_color = fill
		body.border_color = NestTheme.INK
		body.set_border_width_all(3)
		body.set_corner_radius_all(12 if kind < 3 else 5)
		draw_style_box(body, Rect2(6, 22, 54, 58))
		var lid := Rect2(12, 14, 42, 13)
		body.bg_color = NestTheme.WOOD_LIGHT
		body.set_corner_radius_all(4)
		draw_style_box(body, lid)
		draw_circle(Vector2(33, 51), 17, NestTheme.CREAM, true, -1, true)
		draw_circle(Vector2(33, 51), 10, NestTheme.SUN, true, -1, true)
		draw_arc(Vector2(33, 51), 10, 0, TAU, 32, NestTheme.INK, 2, true)
		draw_arc(Vector2(34, 50), 4, 0, PI*.9, 12, NestTheme.INK, 2, true)
