extends Node
## Firebase is opt-in for production exports. Local runs and test iOS builds never configure it.

var bridge: Object
var session_started_at := 0

func _ready() -> void:
	if OS.get_name() != "iOS" or not OS.has_feature("production") or not Engine.has_singleton("FirebaseBridge"):
		return
	bridge = Engine.get_singleton("FirebaseBridge")
	bridge.call("configure")
	session_started_at = Time.get_ticks_msec()
	track("game_session_started", {"platform": "ios"})

func track(name: String, params: Dictionary = {}) -> void:
	if bridge == null or name.is_empty():
		return
	bridge.call("log_event", name, params)

func screen(name: String) -> void:
	if bridge == null:
		return
	bridge.call("set_screen_name", name, "godot_screen")
	track("navigation", {"screen": name})

func run_started(mode: String, tutorial: bool) -> void:
	track("run_started", {"mode": mode, "tutorial": tutorial})

func run_finished(stats: Dictionary) -> void:
	track("run_finished", {
		"mode": str(stats.get("mode", "classic")),
		"score": int(stats.get("score", 0)),
		"placed": int(stats.get("placed", 0)),
		"tumbles": int(stats.get("tumbles", 0)),
		"time_seconds": int(stats.get("time", 0.0)),
		"new_flavours": int(stats.get("new_flavours", 0)),
		"boxes": int(stats.get("boxes", 0)),
	})

func purchase_started(product_id: String, price: String) -> void:
	track("purchase_started", {"product_id": product_id, "price": price})

func purchase_finished(product_id: String, beans: int, tickets: int) -> void:
	track("purchase_completed", {"product_id": product_id, "beans": beans, "tickets": tickets})

func purchase_failed(product_id: String, reason: String) -> void:
	track("purchase_failed", {"product_id": product_id, "reason": reason})
