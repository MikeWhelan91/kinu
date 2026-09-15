extends Node
var last_pulse: int = 0
func pulse(duration: int = 20, strength: float = 0.4) -> void:
	if not Save.data.get("haptics", true) or OS.has_feature("headless"):
		return
	var now := Time.get_ticks_msec()
	if now - last_pulse < 140:
		return
	last_pulse = now
	if OS.has_feature("ios") or OS.has_feature("android"):
		Input.vibrate_handheld(duration, strength)
