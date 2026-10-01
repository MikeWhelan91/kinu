extends Node

func _ready() -> void:
	Save.save_path = "user://daily_rail_test.json"
	Save.data = Save.defaults()
	ProjectSettings.set_setting("supabase/url", "https://example.invalid")
	ProjectSettings.set_setting("supabase/publishable_key", "test")
	DailyCalendar._server_remote = {}
	DailyCalendar._server_status_received_at_ms = -1
	var rail := EventRail.build(self)
	add_child(rail)
	var okay := not rail.visible
	DailyCalendar.apply_server_status({"ready": false, "streak": 1, "seconds_remaining": 7200})
	rail.refresh()
	okay = okay and rail.visible and DailyCalendar.seconds_to_reset() > 7000
	Save.setting("mode", "tower")
	Save.load_data()
	rail.refresh()
	okay = okay and rail.visible and DailyCalendar.status_known() and DailyCalendar.seconds_to_reset() > 7000
	DailyCalendar._server_status_received_at_ms = -1
	rail.refresh()
	okay = okay and not rail.visible
	DailyCalendar.apply_server_status({"ready": false, "streak": 1, "seconds_remaining": 7000})
	rail.refresh()
	okay = okay and rail.visible
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.save_path + suffix))
	print("daily rail: ", "PASS" if okay else "FAIL")
	get_tree().quit(0 if okay else 1)
