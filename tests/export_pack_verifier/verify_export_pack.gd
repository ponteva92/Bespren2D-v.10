extends SceneTree

const MANIFEST_PATH: String = "res://data/runtime_export_closure.json"
const DEPENDENCY_SCENE_PATH: String = "res://scenes/build/runtime_export_dependencies.tscn"

var _failures: PackedStringArray = []
var _loaded_count: int = 0
var _instantiated_count: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("Expected absolute exported PCK path as the first user argument")
		_finish()
		return
	var pack_path: String = args[0]
	if not FileAccess.file_exists(pack_path):
		_fail("Exported PCK does not exist: %s" % pack_path)
		_finish()
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		_fail("Could not mount exported PCK: %s" % pack_path)
		_finish()
		return
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("Closure manifest is absent from exported PCK")
		_finish()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_fail("Closure manifest JSON did not parse as a dictionary")
		_finish()
		return
	var document: Dictionary = parsed as Dictionary
	if int(document.get("schema_version", 0)) != 1:
		_fail("Unsupported closure manifest schema")
	var entries: Array = document.get("resources", []) as Array
	if entries.is_empty():
		_fail("Closure manifest has no resources")
	_validate_dependency_scene(entries)
	var manifest_paths: Dictionary = {}
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			var manifest_path: String = str((entry_value as Dictionary).get("path", ""))
			if manifest_paths.has(manifest_path):
				_fail("Duplicate closure manifest path: %s" % manifest_path)
			manifest_paths[manifest_path] = true
		_validate_entry(entry_value)
	_finish()


func _validate_dependency_scene(entries: Array) -> void:
	if not ResourceLoader.exists(DEPENDENCY_SCENE_PATH):
		_fail("Export dependency scene is absent from exported PCK")
		return
	var packed: PackedScene = ResourceLoader.load(DEPENDENCY_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Failed to load export dependency scene")
		return
	var root: Node = packed.instantiate()
	if root == null:
		_fail("Failed to instantiate export dependency scene")
		return
	var dependency_value: Variant = root.get_meta("export_dependencies", [])
	var declared_count: int = int(root.get_meta("export_dependency_count", -1))
	if not dependency_value is Array:
		_fail("Export dependency metadata is not an array")
		root.free()
		return
	var dependencies: Array = dependency_value as Array
	if declared_count != dependencies.size():
		_fail("Export dependency count mismatch: declared %d, loaded %d" % [declared_count, dependencies.size()])
	var dependency_paths: Dictionary = {}
	for dependency_value_item: Variant in dependencies:
		if not dependency_value_item is Resource:
			_fail("Export dependency metadata contains a non-resource value")
			continue
		var dependency: Resource = dependency_value_item as Resource
		var dependency_path: String = dependency.resource_path
		if dependency_path.is_empty():
			_fail("Export dependency metadata contains a resource without a path")
			continue
		if dependency_paths.has(dependency_path):
			_fail("Duplicate export dependency path: %s" % dependency_path)
		dependency_paths[dependency_path] = true
	if dependencies.size() != entries.size() + 1:
		_fail("Export dependency scene must contain every manifest resource plus the closure manifest")
	if not dependency_paths.has(MANIFEST_PATH):
		_fail("Export dependency scene does not retain the closure manifest")
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var path: String = str((entry_value as Dictionary).get("path", ""))
		if not dependency_paths.has(path):
			_fail("Closure resource is not explicit in export dependency scene: %s" % path)
	root.free()


func _validate_entry(entry_value: Variant) -> void:
	if not entry_value is Dictionary:
		_fail("Closure entry is not a dictionary")
		return
	var entry: Dictionary = entry_value as Dictionary
	var path: String = str(entry.get("path", ""))
	var expected_type: String = str(entry.get("type", ""))
	if not path.begins_with("res://"):
		_fail("Invalid closure resource path: %s" % path)
		return
	if not ResourceLoader.exists(path):
		_fail("Missing exported resource: %s" % path)
		return
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		_fail("Failed to load exported resource: %s" % path)
		return
	_loaded_count += 1
	if not _matches_type(resource, expected_type):
		_fail("Wrong type for %s: expected %s, got %s" % [path, expected_type, resource.get_class()])
		return
	if bool(entry.get("instantiate", false)):
		var packed: PackedScene = resource as PackedScene
		var instance: Node = packed.instantiate()
		if instance == null:
			_fail("Failed to instantiate exported scene: %s" % path)
			return
		_instantiated_count += 1
		instance.free()


func _matches_type(resource: Resource, expected_type: String) -> bool:
	match expected_type:
		"Script":
			return resource is Script
		"PackedScene":
			return resource is PackedScene
		"Texture2D":
			return resource is Texture2D
		"SpriteFrames":
			return resource is SpriteFrames
		"AudioStream":
			return resource is AudioStream
		"Shader":
			return resource is Shader
		_:
			return false


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("EXPORT PACK VALIDATION OK (%d resources, %d scenes instantiated)" % [_loaded_count, _instantiated_count])
		quit(0)
		return
	print("EXPORT PACK VALIDATION FAILED (%d failures)" % _failures.size())
	for failure: String in _failures:
		print(" - %s" % failure)
	quit(1)
