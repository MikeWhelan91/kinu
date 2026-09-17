extends Node
var checks := 0
var failures: Array[String] = []

class Receipt extends RefCounted:
	var product_id := ""
	var transaction_id := ""
	var purchase_date := 100.0
	var revocation_date := 0.0
	var finished := 0
	func finish() -> void:
		finished += 1

class Product extends RefCounted:
	var product_id := ""
	var display_price := "€2.99"

class NativeStore extends RefCounted:
	var requested: Object
	var restored := 0
	var entitlements := 0
	var unfinished := 0
	func purchase(product: Object) -> void:
		requested = product
	func restore_purchases() -> void:
		restored += 1
	func fetch_current_entitlements() -> void:
		entitlements += 1
	func fetch_unfinished_transactions() -> void:
		unfinished += 1

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		print("FAIL ", description)

func receipt(id: String, product: String) -> Receipt:
	var value := Receipt.new()
	value.transaction_id = id
	value.product_id = product
	return value

func _ready() -> void:
	Save.save_path = "user://purchase_test.json"
	Save.data = Save.defaults()
	check(Store.PACKS.map(func(p: Dictionary) -> int: return p.beans) == [300,1000,2400,6500], "agreed bean totals include bonuses")
	var bridge := NativeStore.new()
	Store.manager = bridge
	var product := Product.new()
	product.product_id = Store.PACKS[1].id
	Store._products_received([product], 0)
	check(Store.price(product.product_id) == "€2.99", "price comes verbatim from StoreKit")
	check(not Store.can_buy(Store.PACKS[0].id), "missing products cannot be bought")
	Store.buy(product.product_id)
	check(bridge.requested == product and not Store.can_buy(product.product_id), "one purchase at a time")
	var purchase := receipt("9007199254740993", product.product_id)
	Store._purchase_completed(purchase, 0, "")
	check(Save.data.beans == 1000 and purchase.finished == 1, "direct purchase grants beans and then finishes")
	Store._deliver(purchase)
	check(Save.data.beans == 1000, "duplicate update does not grant twice")
	Save.load_data()
	Store._deliver(purchase)
	check(Save.data.beans == 1000, "transaction deduplication survives restart and preserves large IDs")
	var unverified := receipt("2", product.product_id)
	Store._unverified(unverified, 0)
	check(Save.data.beans == 1000 and unverified.finished == 0, "unverified purchases never award or finish")
	Store._purchase_completed(null, 4, "")
	check(Save.data.beans == 1000 and Store.busy.is_empty(), "cancellation clears busy without granting")
	Store._purchase_completed(null, 5, "")
	check(Save.data.beans == 1000 and Store.status.contains("approval"), "pending approval gives no early beans")
	Store._deliver(unverified)
	check(Save.data.beans == 2000, "later verified approval is delivered")
	var failed := receipt("3", product.product_id)
	Save.save_path = "user://missing_purchase_test_directory/save.json"
	Store._deliver(failed)
	check(Save.data.beans == 2000 and failed.finished == 0, "save failure rolls back balance and leaves transaction unfinished")
	Save.save_path = "user://purchase_test.json"
	Store._deliver(failed)
	check(Save.data.beans == 3000 and failed.finished == 1, "failed save can recover exactly once")
	var unknown := receipt("4", "unknown")
	Store._deliver(unknown)
	check(Save.data.beans == 3000 and unknown.finished == 0, "unrecognised products grant nothing")
	purchase.revocation_date = 200
	Store._deliver(purchase)
	Store._deliver(purchase)
	check(Save.data.beans == 2000, "refund reverses a credited pack only once")
	purchase.revocation_date = 0
	Store._deliver(purchase)
	check(Save.data.beans == 2000, "stale transaction cannot regrant a refund")
	var ad := receipt("5", Store.REMOVE_ADS)
	Store._deliver(ad)
	check(Store.ads_removed(), "verified non-consumable grants permanent entitlement")
	Save.load_data()
	check(Store.ads_removed(), "ad removal persists")
	ad.revocation_date = 200
	Store._deliver(ad)
	check(not Store.ads_removed(), "refunded ad removal revokes entitlement")
	Store.restore()
	check(bridge.restored == 1, "restore only begins from explicit action")
	Store._restore_completed(0, "")
	check(bridge.entitlements == 1 and bridge.unfinished == 1, "restore fetches entitlements and unfinished purchases")
	check(not Store.can_buy(Store.REMOVE_ADS), "do not sell ad removal before ads exist")
	Store.manager = null
	Store.products.clear()
	Store.status = "Purchases are available in the iPhone app."
	print("PURCHASE CHECKS=", checks, " FAILURES=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
