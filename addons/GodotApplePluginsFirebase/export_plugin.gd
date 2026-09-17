@tool
extends EditorExportPlugin

const PLIST_RES_PATH := "res://addons/GodotApplePluginsFirebase/GoogleService-Info.plist"


func _get_name() -> String:
	return "GodotApplePluginsFirebase"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform.get_os_name() == "iOS"


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not features.has("ios"):
		return
	if not FileAccess.file_exists(PLIST_RES_PATH):
		push_warning("GodotApplePluginsFirebase: %s not found - Firebase will not be configured in this export. Drop your GoogleService-Info.plist there." % PLIST_RES_PATH)
		return
	add_ios_bundle_file(ProjectSettings.globalize_path(PLIST_RES_PATH))
