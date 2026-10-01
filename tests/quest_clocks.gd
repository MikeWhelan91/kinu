extends Node
var failures := 0

func _ready() -> void:
	ProjectSettings.set_setting("supabase/url", "https://example.supabase.co")
	ProjectSettings.set_setting("supabase/publishable_key", "test-key")
	KinuProgress.apply_time_status({"daily_key": "2026-09-30", "daily_seconds_remaining": 2, "weekly_seconds_remaining": 2})
	_check(KinuProgress.calendar_day() == "2026-09-30", "daily missions use the server date")
	_check(KinuProgress.daily_seconds_remaining() > 0 and KinuProgress.daily_seconds_remaining() <= 2, "daily mission clock uses server seconds")
	_check(KinuProgress.weekly_seconds_remaining() > 0 and KinuProgress.weekly_seconds_remaining() <= 2, "weekly challenge clock uses server seconds")
	_check(KinuProgress.week_of("2026-09-30") == 4 and KinuProgress.week_of("2026-10-01") == 1, "month boundary begins a new weekly challenge")
	await get_tree().create_timer(2.2).timeout
	_check(KinuProgress.needs_time_refresh(), "expired quest clocks request fresh server status")
	KinuProgress.apply_time_status({"daily_key": "2026-10-01", "daily_seconds_remaining": 86400, "weekly_seconds_remaining": 604800})
	_check(KinuProgress.calendar_day() == "2026-10-01" and not KinuProgress.needs_time_refresh(), "server rollover starts fresh daily and weekly clocks")
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: "+description)
		failures += 1
