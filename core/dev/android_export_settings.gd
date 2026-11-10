@tool
## Applied inside the isolated APK editor process before native export validation.
extends EditorPlugin

func _enter_tree() -> void:
	var sdk_path: String = OS.get_environment("GODOTPARTY_ANDROID_SDK_PATH")
	EditorInterface.get_editor_settings().set_setting("export/android/android_sdk_path", sdk_path)
	print("ANDROID_SDK_PATH " + sdk_path)
