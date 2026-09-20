extends Node
## Verified StoreKit 2 purchases. No local currency prices or simulated live purchases.
signal changed
signal notice(text: String)

const REMOVE_ADS := "com.kinutumble.app.removeads"
const BEAN_PACKS := [
	{"id": "com.kinutumble.app.beans.bag", "title": "Little Bean Bag", "beans": 300, "bonus": 0},
	{"id": "com.kinutumble.app.beans.pouch", "title": "Bean Pouch", "beans": 1000, "bonus": 100},
	{"id": "com.kinutumble.app.beans.jar", "title": "Bean Jar", "beans": 2400, "bonus": 400},
	{"id": "com.kinutumble.app.beans.pantry", "title": "Bean Pantry", "beans": 6500, "bonus": 1500},
]
## Consumable products to create in App Store Connect. Prices are always supplied by StoreKit.
const TICKET_PACKS := [
	{"id": "com.kinutumble.app.tickets.trio", "title": "Ticket Trio", "tickets": 3},
	{"id": "com.kinutumble.app.tickets.bundle", "title": "Ticket Bundle", "tickets": 10},
	{"id": "com.kinutumble.app.tickets.stack", "title": "Ticket Stack", "tickets": 25},
	{"id": "com.kinutumble.app.tickets.roll", "title": "Ticket Roll", "tickets": 60},
]
const ADS_ENABLED := true

var manager: Object
var products: Dictionary = {}
var loading := false
var busy := ""
var status := ""
var _load_generation := 0
var _retry_transactions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "iOS" and ClassDB.class_exists("StoreKitManager"):
		manager = ClassDB.instantiate("StoreKitManager")
		if OS.is_debug_build():
			print("STOREKIT bridge ready")
			print("STOREKIT receipt fields=", ClassDB.class_get_property_list("StoreTransaction").map(func(p: Dictionary) -> String: return p.name))
		manager.connect("products_request_completed", _products_received)
		manager.connect("transaction_updated", _deliver)
		manager.connect("unverified_transaction_updated", _unverified)
		manager.connect("purchase_completed", _purchase_completed)
		manager.connect("restore_completed", _restore_completed)
		manager.call("start")
		manager.call("fetch_current_entitlements")
		refresh_products()
	else:
		status = "Purchases are available in the iPhone app."

func all_ids() -> PackedStringArray:
	var ids := PackedStringArray([REMOVE_ADS])
	for pack in BEAN_PACKS+TICKET_PACKS:
		ids.append(pack.id)
	return ids

func pack_for(id: String) -> Dictionary:
	for pack in BEAN_PACKS+TICKET_PACKS:
		if pack.id == id:
			return pack
	return {}

func price(id: String) -> String:
	if not products.has(id):
		return "Loading…" if loading else "Unavailable"
	return str(_field(products[id], ["display_price", "displayPrice"], ""))

func ads_removed() -> bool:
	return bool(Save.data.get("ads_removed", false))

func can_buy(id: String) -> bool:
	return manager != null and busy.is_empty() and products.has(id) and not price(id).is_empty() and (id != REMOVE_ADS or (ADS_ENABLED and not ads_removed()))

func refresh_products() -> void:
	if manager == null or loading:
		return
	loading = true
	status = "Connecting to the App Store…"
	_load_generation += 1
	var generation := _load_generation
	changed.emit()
	manager.call("request_products", all_ids())
	get_tree().create_timer(20).timeout.connect(func() -> void:
		if loading and generation == _load_generation:
			loading = false
			status = "The App Store is taking a while. Please try again."
			changed.emit()
	)
	for transaction in _retry_transactions.values():
		_deliver(transaction)

func buy(id: String) -> void:
	if not can_buy(id):
		return
	busy = id
	status = "Confirm your purchase with Apple."
	changed.emit()
	manager.call("purchase", products[id])

func restore() -> void:
	if manager == null or not busy.is_empty():
		return
	busy = "restore"
	status = "Restoring purchases…"
	changed.emit()
	manager.call("restore_purchases")

func _products_received(items: Array, result: int) -> void:
	loading = false
	products.clear()
	if result == 0:
		for item in items:
			if item == null:
				continue
			var id := str(_field(item, ["product_id", "productId"], ""))
			if all_ids().has(id):
				products[id] = item
				if OS.is_debug_build():
					print("STOREKIT product ", id, " price=", price(id))
	status = "" if products.size() == all_ids().size() else "Some purchases aren't available right now. Please try again."
	if OS.is_debug_build():
		print("STOREKIT catalog count=", products.size(), " status=", result)
	changed.emit()

## Native callbacks differ: direct purchases arrive on purchase_completed, while
## restores, unfinished purchases and refunds arrive on transaction_updated.
func _purchase_completed(transaction: Object, result: int, _error: String) -> void:
	busy = ""
	match result:
		0:
			if transaction != null:
				_deliver(transaction)
			else:
				status = "We couldn't confirm that purchase. Please try again."
		4:
			status = "Purchase cancelled."
		5:
			status = "Waiting for approval. Your purchase will arrive when Apple approves it."
		_:
			status = "Purchase couldn't be completed. Please try again."
	changed.emit()

func _deliver(transaction: Object) -> void:
	if transaction == null:
		return
	var product := str(_field(transaction, ["product_id", "productID"], ""))
	var pack := pack_for(product)
	if pack.is_empty() and product != REMOVE_ADS:
		return
	var id := str(_field(transaction, ["transaction_id", "transactionId"], ""))
	var revoked_at := float(_field(transaction, ["revocation_date", "revocationDate"], 0.0))
	var date := revoked_at if revoked_at > 0 else float(_field(transaction, ["purchase_date", "purchaseDate"], 0.0))
	if id.is_empty() or id == "0":
		status = "We couldn't confirm the purchase receipt. Please try Restore Purchases."
		changed.emit()
		return
	var applied := Save.apply_store_transaction(id, product, int(pack.get("beans", 0)), int(pack.get("tickets", 0)), revoked_at > 0, date, product == REMOVE_ADS)
	if applied < 0:
		_retry_transactions[id] = transaction
		status = "Your purchase couldn't be saved. Free some storage and tap Retry."
	else:
		_retry_transactions.erase(id)
		transaction.call("finish")
		if applied > 0:
			if revoked_at > 0:
				status = "Your refunded purchase has been updated."
			elif product == REMOVE_ADS:
				status = "Ads removed. Thank you!"
			elif int(pack.get("tickets", 0)) > 0:
				status = "%s Kinu Claw tickets added!" % str(pack.tickets)
				Sound.play("cashregister")
			else:
				status = NestTheme.t("%s beans added!") % str(pack.beans)
				Sound.play("cashregister")
			notice.emit(status)
	changed.emit()

func _unverified(_transaction: Object, _error: int) -> void:
	status = "Apple couldn't verify a purchase. Please try again later."
	changed.emit()

func _restore_completed(result: int, _error: String) -> void:
	busy = ""
	if result == 0:
		manager.call("fetch_current_entitlements")
		manager.call("fetch_unfinished_transactions")
		status = "Restore requested. Eligible purchases will appear shortly."
	else:
		status = "Restore couldn't be completed. Please try again."
	changed.emit()

func _field(object: Object, names: Array, fallback: Variant) -> Variant:
	for property in object.get_property_list():
		if property.name in names:
			return object.get(property.name)
	return fallback
