class_name GameCenterService
extends RefCounted
# Thin wrapper around the GodotApplePlugins GameCenter extension
# (addons/GodotApplePluginsGameCenter, addons/GodotApplePluginsRuntime).
# Every native class is resolved by name through ClassDB rather than a static
# GDScript type, so this file parses fine on every platform - the editor, the
# headless test suite - even where the extension isn't bundled at all.
# `available` is the only thing callers need to check.
const LEADERBOARD_IDS := {
	"classic": "kinu.leaderboard",
	"tower": "tower",
}
# GKLeaderboard.PlayerScope.GLOBAL / TimeScope.ALL_TIME, mirrored here so this
# file never needs the GKLeaderboard type to read its constants.
const SCOPE_GLOBAL := 0
const TIME_SCOPE_ALL_TIME := 2

var available := false
var authenticated := false
var manager: Object

func _init() -> void:
	# The extension also ships macOS binaries so it can load in-editor without
	# erroring, but Game Center itself is only wired up for real iOS builds.
	available = OS.get_name() == "iOS" and ClassDB.class_exists("GameCenterManager")
	if not available: return
	manager = ClassDB.instantiate("GameCenterManager")
	manager.connect("authentication_result", _on_authentication_result)
	manager.connect("authentication_error", _on_authentication_error)

func authenticate() -> void:
	if not available: return
	manager.call("authenticate")

func _on_authentication_result(status: bool) -> void:
	authenticated = status

func _on_authentication_error(message: String) -> void:
	push_warning("Game Center authentication error: " + message)

# Resolves the leaderboard for a released mode. Falling back to Classic keeps an old or
# malformed save from opening a non-existent Game Center board.
static func leaderboard_id(mode: String) -> String:
	return str(LEADERBOARD_IDS.get(mode, LEADERBOARD_IDS.classic))

# Posts a score to the selected mode's leaderboard. Silently does nothing if the
# player was never signed in - there is no offline queue, since a missed post
# here and there does not warrant one for a personal-best board.
func submit_score(mode: String, value: int) -> void:
	if not available or not authenticated: return
	var local_player: Object = manager.get("local_player")
	if local_player == null: return
	var board_id := leaderboard_id(mode)
	ClassDB.class_call_static("GKLeaderboard", "load_leaderboards", PackedStringArray([board_id]),
		func(leaderboards, error):
			if error or leaderboards.is_empty(): return
			leaderboards[0].call("submit_score", value, 0, local_player,
				func(submit_error):
					if submit_error: push_warning("Game Center score submit failed for %s: %s" % [board_id, submit_error]))
	)

# Presents Apple's native sheet for the mode selected on the home screen.
func show_leaderboard(mode: String) -> void:
	if not available: return
	ClassDB.class_call_static("GKGameCenterViewController", "show_leaderboard_time_period", leaderboard_id(mode), SCOPE_GLOBAL, TIME_SCOPE_ALL_TIME)
