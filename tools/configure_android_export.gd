extends SceneTree
## Configures Godot's Android export paths from explicit environment variables.


func _initialize() -> void:
	call_deferred(&"_configure")


func _configure() -> void:
	var java_sdk_path: String = OS.get_environment("BESPREN_JAVA_SDK_PATH")
	var android_sdk_path: String = OS.get_environment("BESPREN_ANDROID_SDK_PATH")
	if java_sdk_path.is_empty() or android_sdk_path.is_empty():
		push_error("ANDROID EXPORT CONFIG FAILED: BESPREN_JAVA_SDK_PATH and BESPREN_ANDROID_SDK_PATH are required")
		quit(1)
		return
	if not FileAccess.file_exists(java_sdk_path.path_join("bin/java.exe")):
		push_error("ANDROID EXPORT CONFIG FAILED: Java executable is missing")
		quit(1)
		return
	if not FileAccess.file_exists(android_sdk_path.path_join("platform-tools/adb.exe")):
		push_error("ANDROID EXPORT CONFIG FAILED: adb executable is missing")
		quit(1)
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	settings.set_setting("export/android/java_sdk_path", java_sdk_path)
	settings.set_setting("export/android/android_sdk_path", android_sdk_path)
	var save_error: Error = settings.save()
	if save_error != OK:
		push_error("ANDROID EXPORT CONFIG FAILED: %s" % error_string(save_error))
		quit(1)
		return
	print("ANDROID EXPORT CONFIG OK | settings=%s" % settings.resource_path)
	quit(0)
