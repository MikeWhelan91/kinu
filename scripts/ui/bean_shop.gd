class_name BeanShop
extends VBoxContainer
## One purchase destination for bean packs, Kinu Catcher tickets and extras.
var app: Node
var initial_section := "beans"
var balance_labels: Dictionary = {}
var section_views: Dictionary = {}
var section_tabs: Dictionary = {}
var message: Label
var restore_button: Button
var retry_button: Button
var purchase_buttons: Dictionary = {}
var free_reset_label: Label
var _clock_elapsed := 0.0

static func open(owner: Node, back: Callable, section: String = "beans") -> void:
	owner._new_screen("beans", true)
	var layout: VBoxContainer = owner._header("Beans & Tickets", back)
	var scroll := DragScroll.new()
	layout.add_child(scroll)
	var view := BeanShop.new()
	view.app = owner
	view.initial_section = section if section in ["beans", "tickets"] else "beans"
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 12)
	scroll.add_child(view)
	view.build()

func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for id in ["beans", "tickets"]:
		var tab := NestTheme.button("Beans" if id == "beans" else "Kinu Claw", func() -> void: _set_section(id), id == initial_section)
		tab.name = id.capitalize()+"Tab"
		tab.custom_minimum_size.y = 52
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 18)
		tabs.add_child(tab)
		section_tabs[id] = tab
	_currency_view("beans", Store.BEAN_PACKS, "A little extra for your favourite looks.")
	_currency_view("tickets", Store.TICKET_PACKS, "One ticket gives you one Kinu Claw play.")
	var extras := NestTheme.label("Extras", 23)
	add_child(extras)
	var card := _card(self)
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
	var note := NestTheme.label("Beans are also earned by playing. Two free Kinu Claw tickets refill together every 24 hours after the first is used; unused free tickets expire.\nRestore Purchases recovers Remove Ads; spent consumables aren't restored.", 14, NestTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	Store.changed.connect(_refresh)
	Save.changed.connect(_refresh)
	_set_section(initial_section)
	_refresh()
	if Store.products.is_empty():
		Store.refresh_products()
	_refresh_free_status()

func _refresh_free_status() -> void:
	await KinuCatcher.refresh_free_status()
	if is_instance_valid(self):
		_update_free_display()

func _process(delta: float) -> void:
	_clock_elapsed += delta
	if _clock_elapsed >= 1.0:
		_clock_elapsed = 0.0
		_update_free_display()

func _update_free_display() -> void:
	if is_instance_valid(free_reset_label):
		free_reset_label.text = KinuCatcher.free_reset_text()
	if balance_labels.has("tickets"):
		(balance_labels.tickets as Label).text = NestTheme.t("%s tickets")%app._number(KinuCatcher.total_tickets())

func _currency_view(currency: String, packs: Array, intro_text: String) -> void:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 12)
	add_child(view)
	section_views[currency] = view
	var wallet := NestTheme.bean_pill("", 22) if currency == "beans" else NestTheme.ticket_pill("", 22)
	wallet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_labels[currency] = wallet.get_child(0).get_child(1)
	# The balance and the thing you do with it share one centred line, the same shape the Kinu Shop
	# uses for its purse, instead of stacking as two separate centred blocks.
	var purse_row := HBoxContainer.new()
	purse_row.alignment = BoxContainer.ALIGNMENT_CENTER
	purse_row.add_theme_constant_override("separation", 8)
	view.add_child(purse_row)
	purse_row.add_child(wallet)
	if currency == "tickets":
		# What a ticket actually buys you, readable before any money is spent rather than only
		# from inside the machine.
		var odds := NestTheme.button("See the Odds", func() -> void: KinuCatcherScreen.odds_page(app), false, "book")
		odds.name = "TicketOdds"
		odds.custom_minimum_size = Vector2(176, 50)
		odds.add_theme_font_size_override("font_size", 18)
		odds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		purse_row.add_child(odds)
		free_reset_label = NestTheme.label("", 15, NestTheme.MUTED)
		free_reset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		view.add_child(free_reset_label)
	var intro := NestTheme.label(intro_text, 17, NestTheme.MUTED)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.add_child(intro)
	for i in packs.size():
		_pack(view, packs[i], i, currency)

func _set_section(section: String) -> void:
	initial_section = section
	for id in section_views:
		(section_views[id] as Control).visible = id == section
	for id in section_tabs:
		NestTheme.set_primary(section_tabs[id] as Button, id == section)

func _card(parent: Control) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := NestTheme.box(NestTheme.CREAM, 22, NestTheme.INK, 4)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	return row

func _pack(parent: Control, pack: Dictionary, index: int, currency: String) -> void:
	var row := _card(parent)
	var art: Control = PackArt.new() if currency == "beans" else TicketPackArt.new()
	art.set("kind", index)
	art.custom_minimum_size = Vector2(66, 88)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(NestTheme.label(pack.title, 17, NestTheme.MUTED))
	var amount := int(pack.beans) if currency == "beans" else int(pack.tickets)
	var amount_text := NestTheme.t("%s beans")%app._number(amount) if currency == "beans" else NestTheme.t("%s tickets")%app._number(amount)
	text.add_child(NestTheme.label(amount_text, 27))
	if int(pack.get("bonus", 0)) > 0:
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
	(balance_labels.beans as Label).text = NestTheme.t("%s beans")%app._number(Save.data.beans)
	_update_free_display()
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

## The wallet pills place their icon and amount by hand, so neither sizes itself. A long balance
## would run past the pill and leave the "+" sitting outside it, which the five-digit balances the
## bean redenomination produces make routine rather than rare.
static func _fit_wallet(button: Button, amount: Label, plus: Label) -> void:
	var font := amount.get_theme_font("font")
	var gap := 12.0+11.0
	var text_width := font.get_string_size(amount.text, HORIZONTAL_ALIGNMENT_LEFT, -1, amount.get_theme_font_size("font_size")).x
	var plus_width := plus.get_theme_font("font").get_string_size(plus.text, HORIZONTAL_ALIGNMENT_LEFT, -1, plus.get_theme_font_size("font_size")).x
	button.custom_minimum_size.x = maxf(120.0, 48.0+text_width+gap+plus_width+6.0)

## The wallet's backing: a glossy cream capsule with a deeper bottom lip, a gold coin socket on
## the left that the bean or ticket sits in, and a gold "+" bubble on the right.
class WalletSkin extends Control:
	var owner_button: Button

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if is_instance_valid(owner_button):
			owner_button.button_down.connect(queue_redraw)
			owner_button.button_up.connect(queue_redraw)
			owner_button.mouse_entered.connect(queue_redraw)
			owner_button.mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var pressed := is_instance_valid(owner_button) and owner_button.is_pressed()
		var drop := 1.0 if pressed else 3.5
		var body := Rect2(Vector2(0, 1 if pressed else 0), Vector2(size.x, size.y-4))
		var r := body.size.y*.5
		draw_colored_polygon(MyKinuScreen.rounded_points(Rect2(body.position+Vector2(0, drop), body.size), r), NestTheme.INK)
		var capsule := MyKinuScreen.rounded_points(body, r)
		var colors := PackedColorArray()
		for point in capsule:
			colors.append(Color("fffdf6").lerp(Color("f6e6c8"), clampf((point.y-body.position.y)/body.size.y, 0, 1)))
		draw_polygon(capsule, colors)
		draw_line(body.position+Vector2(r, body.size.y*.2), Vector2(body.end.x-r*1.8, body.position.y+body.size.y*.2), Color(1, 1, 1, .9), 2.5, true)
		var edge := capsule.duplicate()
		edge.append(capsule[0])
		draw_polyline(edge, NestTheme.INK, 3.0, true)
		# Coin socket for the icon.
		var socket := Vector2(r, body.get_center().y)
		draw_circle(socket, r-5, Color("ffe9a6"))
		draw_arc(socket, r-5, 0, TAU, 32, Color("e8b245"), 2.5, true)
		draw_arc(socket, r-9, PI*1.05, PI*1.6, 10, Color(1, 1, 1, .8), 2.0, true)
		# Gold "+" bubble.
		var bubble := Vector2(body.end.x-r+1, body.get_center().y)
		var bubble_r := r-7
		draw_circle(bubble+Vector2(0, 1.5), bubble_r, Color("b8690a"))
		draw_circle(bubble, bubble_r, Color("ffc83d"))
		draw_arc(bubble, bubble_r*.6, PI*1.1, PI*1.6, 8, Color(1, 1, 1, .7), 2.0, true)

class WalletButton extends Button:
	var amount_label: Label
	var plus_label: Label

	func _ready() -> void:
		name = "BeanWallet"
		# Reserve room for the gold add button so it remains inside the wallet at every balance.
		custom_minimum_size = Vector2(116, 44)
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_mode = Control.FOCUS_NONE
		var skin := WalletSkin.new()
		skin.owner_button = self
		add_child(skin)
		var bean := BeanIcon.new(28)
		bean.position = Vector2(8, 8)
		bean.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bean)
		var amount_row := HBoxContainer.new()
		amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_row.alignment = BoxContainer.ALIGNMENT_END
		amount_row.add_theme_constant_override("separation", 12)
		amount_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Leave a deliberate breathing gap after the artwork; the ticket is wider than the bean.
		amount_row.offset_left = 46
		amount_row.offset_right = -11
		amount_row.offset_top = 4
		amount_row.offset_bottom = -3
		add_child(amount_row)
		amount_label = NestTheme.label("", 22)
		amount_row.add_child(amount_label)
		plus_label = NestTheme.label("+", 24, NestTheme.CREAM)
		plus_label.add_theme_color_override("font_outline_color", Color("b8690a"))
		plus_label.add_theme_constant_override("outline_size", 5)
		amount_row.add_child(plus_label)
		Save.changed.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		amount_label.text = str(int(Save.data.beans))
		BeanShop._fit_wallet(self, amount_label, plus_label)

## The claw ticket balance, cut to match the bean wallet above it so the two read as one stack.
class TicketWalletButton extends Button:
	var amount_label: Label
	var plus_label: Label
	var _clock_elapsed := 0.0

	func _ready() -> void:
		name = "TicketWallet"
		# Every metric matches the bean wallet above it, so the pair reads as one stack.
		custom_minimum_size = Vector2(116, 44)
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_mode = Control.FOCUS_NONE
		var skin := WalletSkin.new()
		skin.owner_button = self
		add_child(skin)
		# A ticket is wider than it is tall, so it is sized by height and centred in the same
		# left margin the bean icon uses.
		var ticket := TicketIcon.new(20)
		ticket.position = Vector2(6, 12)
		ticket.pivot_offset = Vector2(16, 10)
		ticket.rotation = -.18
		ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ticket)
		var amount_row := HBoxContainer.new()
		amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_row.alignment = BoxContainer.ALIGNMENT_END
		amount_row.add_theme_constant_override("separation", 12)
		amount_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		amount_row.offset_left = 46
		amount_row.offset_right = -11
		amount_row.offset_top = 4
		amount_row.offset_bottom = -3
		add_child(amount_row)
		amount_label = NestTheme.label("", 22)
		amount_row.add_child(amount_label)
		plus_label = NestTheme.label("+", 24, NestTheme.CREAM)
		plus_label.add_theme_color_override("font_outline_color", Color("b8690a"))
		plus_label.add_theme_constant_override("outline_size", 5)
		amount_row.add_child(plus_label)
		Save.changed.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		amount_label.text = str(KinuCatcher.total_tickets())
		BeanShop._fit_wallet(self, amount_label, plus_label)

	func _process(delta: float) -> void:
		_clock_elapsed += delta
		if _clock_elapsed >= 1.0:
			_clock_elapsed = 0.0
			_refresh()

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

## Ticket bundles use the same card footprint as bean packs, with a small fanned ticket stack.
class TicketPackArt extends Control:
	var kind := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fills := [NestTheme.WOOD_LIGHT, NestTheme.BERRY, NestTheme.SKY, NestTheme.WOOD]
		for layer in 3:
			var offset := Vector2(4+layer*4, 20-layer*4)
			var body := StyleBoxFlat.new()
			body.bg_color = fills[kind].lightened(.1*layer)
			body.border_color = NestTheme.INK
			body.set_border_width_all(3)
			body.set_corner_radius_all(7)
			draw_style_box(body, Rect2(offset, Vector2(52, 58)))
		var center := Vector2(34, 45)
		draw_circle(center, 15, NestTheme.CREAM)
		draw_arc(center, 9, .15, PI-.15, 12, NestTheme.INK, 2.5, true)
		draw_line(center+Vector2(-9, 0), center+Vector2(0, 10), NestTheme.INK, 2.5, true)
		draw_line(center+Vector2(9, 0), center+Vector2(0, 10), NestTheme.INK, 2.5, true)
