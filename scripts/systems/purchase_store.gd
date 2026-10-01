extends Node
## RevenueCat-backed App Store purchases with the native StoreKit 2 bridge as fallback.
signal changed
signal notice(text: String)

const REMOVE_ADS := "com.kinutumble.app.removeads"
const BEAN_PACKS := [
	{"id": "com.kinutumble.app.beans.bag", "title": "Little Bean Bag", "beans": 1500, "bonus": 0},
	{"id": "com.kinutumble.app.beans.pouch", "title": "Bean Pouch", "beans": 5000, "bonus": 500},
	{"id": "com.kinutumble.app.beans.jar", "title": "Bean Jar", "beans": 12000, "bonus": 2000},
	{"id": "com.kinutumble.app.beans.pantry", "title": "Bean Pantry", "beans": 32500, "bonus": 7500},
]
## Consumable products to create in App Store Connect. Prices are always supplied by StoreKit.
const TICKET_PACKS := [
	{"id": "com.kinutumble.app.tickets.trio", "title": "Ticket Trio", "tickets": 3},
	{"id": "com.kinutumble.app.tickets.bundle", "title": "Ticket Bundle", "tickets": 10},
	{"id": "com.kinutumble.app.tickets.stack", "title": "Ticket Stack", "tickets": 25},
	{"id": "com.kinutumble.app.tickets.roll", "title": "Ticket Roll", "tickets": 60},
]
const ADS_ENABLED := true
const REVENUECAT_IOS_API_KEY := "appl_uxAhnmyustMeBUHCCMtRcsHEyky"
const REVENUECAT_PRO_ENTITLEMENT := "com_kinutumble_app_pro"

var manager: Object
var revenuecat: Object
var products: Dictionary = {}
var loading := false
var busy := ""
var status := ""
var _load_generation := 0
var _retry_transactions: Dictionary = {}
var _retry_revenuecat_transactions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "iOS" and Engine.has_singleton("GodotxRevenueCat"):
		revenuecat = Engine.get_singleton("GodotxRevenueCat")
		revenuecat.connect("products", _revenuecat_products_received)
		revenuecat.connect("purchase_result", _revenuecat_purchase_result)
		revenuecat.connect("restore_finished", _revenuecat_restore_finished)
		revenuecat.connect("entitlement", _revenuecat_entitlement)
		revenuecat.call("initialize", REVENUECAT_IOS_API_KEY, "", OS.is_debug_build())
		revenuecat.call("check_entitlement", REVENUECAT_PRO_ENTITLEMENT)
		revenuecat.call("get_customer_info")
		refresh_products()
	elif OS.get_name() == "iOS" and ClassDB.class_exists("StoreKitManager"):
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
	var product: Variant = products[id]
	# The two backends hand back different shapes: the StoreKit bridge stores a native object whose
	# price is a property, while RevenueCat stores a plain Dictionary. Reading a Dictionary through
	# _field() finds nothing, which empties every price and disables every buy button.
	if product is Dictionary:
		for key in ["display_price", "displayPrice", "price_string", "localized_price"]:
			var found := str(product.get(key, ""))
			if not found.is_empty():
				return _repair_utf8(found)
		return ""
	return _repair_utf8(str(_field(product, ["display_price", "displayPrice"], "")))

## The RevenueCat bridge hands back price strings whose UTF-8 bytes have already been decoded as
## Latin-1, so a euro price arrives with its symbol split into stray accented characters. Reading
## those characters back as raw bytes and decoding them as UTF-8 restores the symbol. Anything
## already correct is returned untouched: a character above U+00FF cannot be a mis-decoded byte,
## and invalid UTF-8 falls back to the original rather than blanking a price.
static func _repair_utf8(text: String) -> String:
	if text.is_empty():
		return text
	var bytes := PackedByteArray()
	for i in text.length():
		var code := text.unicode_at(i)
		if code > 0xFF:
			return text
		bytes.append(code)
	var decoded := bytes.get_string_from_utf8()
	return text if decoded.is_empty() else decoded

func ads_removed() -> bool:
	return bool(Save.data.get("ads_removed", false))

func can_buy(id: String) -> bool:
	return (manager != null or revenuecat != null) and busy.is_empty() and products.has(id) and not price(id).is_empty() and (id != REMOVE_ADS or (ADS_ENABLED and not ads_removed()))

func refresh_products() -> void:
	if (manager == null and revenuecat == null) or loading:
		return
	loading = true
	status = "Connecting to the App Store…"
	_load_generation += 1
	var generation := _load_generation
	changed.emit()
	if revenuecat != null:
		revenuecat.call("fetch_products", all_ids())
	else:
		manager.call("request_products", all_ids())
	get_tree().create_timer(20).timeout.connect(func() -> void:
		if loading and generation == _load_generation:
			loading = false
			status = "The App Store is taking a while. Please try again."
			changed.emit()
	)
	for transaction in _retry_transactions.values():
		_deliver(transaction)
	for transaction in _retry_revenuecat_transactions.values():
		_deliver_revenuecat(transaction)

func buy(id: String) -> void:
	if not can_buy(id):
		return
	Analytics.purchase_started(id, price(id))
	busy = id
	status = "Confirm your purchase with Apple."
	changed.emit()
	if revenuecat != null:
		revenuecat.call("purchase", id)
	else:
		manager.call("purchase", products[id])

func restore() -> void:
	if (manager == null and revenuecat == null) or not busy.is_empty():
		return
	Analytics.track("restore_started")
	busy = "restore"
	status = "Restoring purchases…"
	changed.emit()
	if revenuecat != null:
		revenuecat.call("restore_purchases")
	else:
		manager.call("restore_purchases")

func _revenuecat_products_received(result: Dictionary) -> void:
	loading = false
	products.clear()
	var error := str(result.get("error", ""))
	if error.is_empty():
		for item in result.get("products", []):
			if not item is Dictionary:
				continue
			var id := str(item.get("id", ""))
			if all_ids().has(id):
				products[id] = {"product_id": id, "display_price": str(item.get("price", "")), "revenuecat": item}
		status = "" if products.size() == all_ids().size() else "Some purchases aren't available right now. Please try again."
	else:
		status = "RevenueCat couldn't load the App Store products. Please try again."
	Analytics.track("store_catalog_loaded", {"available_count": products.size(), "expected_count": all_ids().size(), "source": "revenuecat"})
	if OS.is_debug_build():
		print("REVENUECAT catalog count=", products.size(), " error=", error)
	changed.emit()

func _revenuecat_purchase_result(result: Dictionary) -> void:
	busy = ""
	if not str(result.get("error", "")).is_empty():
		Analytics.purchase_failed(str(result.get("product_id", "")), "revenuecat_error")
		status = "Purchase couldn't be completed. Please try again."
	elif bool(result.get("cancelled", false)):
		Analytics.purchase_failed(str(result.get("product_id", "")), "cancelled")
		status = "Purchase cancelled."
	else:
		_deliver_revenuecat(result)
	changed.emit()

func _deliver_revenuecat(result: Dictionary) -> void:
	var product := str(result.get("product_id", ""))
	var transaction_id := str(result.get("transaction_id", ""))
	var pack := pack_for(product)
	if pack.is_empty() and product != REMOVE_ADS:
		return
	if transaction_id.is_empty():
		status = "We couldn't confirm the purchase receipt. Please try again later."
		changed.emit()
		return
	var applied := Save.apply_store_transaction(transaction_id, product, int(pack.get("beans", 0)), int(pack.get("tickets", 0)), false, Time.get_unix_time_from_system(), product == REMOVE_ADS)
	if applied < 0:
		_retry_revenuecat_transactions[transaction_id] = result
		status = "Your purchase couldn't be saved. Free some storage and tap Retry."
	elif applied > 0:
		_retry_revenuecat_transactions.erase(transaction_id)
		Analytics.purchase_finished(product, int(pack.get("beans", 0)), int(pack.get("tickets", 0)))
		if product == REMOVE_ADS:
			status = "Ads removed. Thank you!"
		elif int(pack.get("tickets", 0)) > 0:
			status = "%s Kinu Claw tickets added!" % str(pack.tickets)
			Sound.play("cashregister")
		else:
			status = NestTheme.t("%s beans added!") % str(pack.beans)
			Sound.play("cashregister")
		notice.emit(status)
	changed.emit()

func _revenuecat_restore_finished(result: Dictionary) -> void:
	busy = ""
	Analytics.track("restore_completed", {"success": bool(result.get("success", false)), "source": "revenuecat"})
	if bool(result.get("success", false)):
		revenuecat.call("check_entitlement", REVENUECAT_PRO_ENTITLEMENT)
		status = "Purchases restored."
	else:
		status = "Restore couldn't be completed. Please try again."
	changed.emit()

func _revenuecat_entitlement(id: String, active: bool) -> void:
	if id != REVENUECAT_PRO_ENTITLEMENT:
		return
	Save.data["ads_removed"] = active
	Save.persist()
	changed.emit()

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
	Analytics.track("store_catalog_loaded", {"available_count": products.size(), "expected_count": all_ids().size(), "source": "storekit"})
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
		if applied > 0:
			Analytics.purchase_finished(product, int(pack.get("beans", 0)), int(pack.get("tickets", 0)))
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
	Analytics.track("restore_completed", {"success": result == 0, "source": "storekit"})
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
