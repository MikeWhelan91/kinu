extends Node
var failures := 0

func _ready() -> void:
	ProjectSettings.set_setting("supabase/url", "")
	Save.save_path = "user://free_tickets_test.json"
	Save.load_data()
	var catalog: KinuCatalog = load("res://resources/kinu/catalog.tres")
	KinuProgress.register(catalog)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_check(KinuCatcher.free_remaining() == 2 and KinuCatcher.total_tickets() == 2, "two free tickets appear in the balance")
	var first := KinuCatcher.play(catalog, rng)
	_check(first.free and KinuCatcher.free_remaining() == 1, "first play leaves one free ticket")
	var second := KinuCatcher.play(catalog, rng)
	_check(second.free and KinuCatcher.free_remaining() == 0, "second play uses the last free ticket")
	Save.data.tickets = 0
	_check(KinuCatcher.play(catalog, rng).is_empty(), "third play is unavailable without a paid ticket")
	Save.load_data()
	_check(KinuCatcher.free_remaining() == 0, "free tickets do not reappear after reload")
	Save.data.crane.free_day = "2000-01-01"
	_check(KinuCatcher.free_remaining() == 2, "next cycle refills to two, without stacking")
	ProjectSettings.set_setting("supabase/url", "https://example.supabase.co")
	KinuCatcher.apply_time_status({"free_claw_remaining": 2, "free_claw_seconds_remaining": 3600})
	_check(KinuCatcher.total_tickets() == 2 and KinuCatcher.free_seconds_remaining() > 0, "server count and reset time control the balance")
	var wallet := BeanShop.TicketWalletButton.new()
	add_child(wallet)
	_check(wallet.amount_label.text == "2", "home ticket wallet shows the free balance")
	KinuCatcher.apply_time_status({"free_claw_remaining": 1, "free_claw_seconds_remaining": 3500})
	_check(KinuCatcher.total_tickets() == 1 and wallet.amount_label.text == "1", "server claim updates the displayed total")
	KinuCatcher.apply_time_status({"free_claw_remaining": 0, "free_claw_seconds_remaining": 1})
	await get_tree().create_timer(1.2).timeout
	_check(KinuCatcher.needs_status_refresh(), "the monotonic countdown requests a fresh server status")
	KinuCatcher.apply_time_status({"free_claw_remaining": 2, "free_claw_seconds_remaining": 0})
	_check(wallet.amount_label.text == "2", "new free tickets appear in the wallet when the server confirms refill")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(Save.save_path+suffix)
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: "+description)
		failures += 1
