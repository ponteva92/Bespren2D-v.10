class_name JuiceRig
extends Node
## Centralized no-shake tactile feedback for UI, damage, placements, and alerts.

const POP_SCALE: float = 1.15
const POP_DURATION_SECONDS: float = 0.25
const POP_RISE_SECONDS: float = 0.08
const WHITE_FLASH_SECONDS: float = 0.12
const WHITE_FLASH_SHADER: Shader = preload("res://shaders/solid_white_flash.gdshader")

var _pop_tweens: Dictionary[int, Tween] = {}
var _base_scales: Dictionary[int, Vector2] = {}
var _flash_tweens: Dictionary[int, Tween] = {}
var _flash_originals: Dictionary[int, Material] = {}


func bind_button(button: Button, audio_manager: AudioManager) -> void:
	if not is_instance_valid(button) or button.has_meta(&"juice_rig_bound"):
		return
	button.set_meta(&"juice_rig_bound", true)
	button.button_down.connect(_on_button_down.bind(button, audio_manager))


func pop(target: CanvasItem) -> void:
	if not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	var base_scale: Vector2 = _get_scale(target)
	if _base_scales.has(target_id):
		base_scale = _base_scales[target_id]
	else:
		_base_scales[target_id] = base_scale
	if _pop_tweens.has(target_id):
		var existing_tween: Tween = _pop_tweens[target_id]
		if existing_tween.is_valid():
			existing_tween.kill()
	_set_scale(target, base_scale)
	if target is Control:
		var control: Control = target as Control
		control.pivot_offset = control.size * 0.5
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		target,
		"scale",
		base_scale * POP_SCALE,
		POP_RISE_SECONDS
	)
	tween.tween_property(
		target,
		"scale",
		base_scale,
		POP_DURATION_SECONDS - POP_RISE_SECONDS
	)
	tween.finished.connect(_finish_pop.bind(target_id))
	_pop_tweens[target_id] = tween


func flash_white(target: CanvasItem, duration: float = WHITE_FLASH_SECONDS) -> void:
	if not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	if _flash_tweens.has(target_id):
		var existing_tween: Tween = _flash_tweens[target_id]
		if existing_tween.is_valid():
			existing_tween.kill()
		_restore_flash(target, target_id)
	var original_material: Material = target.material
	var flash_material: ShaderMaterial = ShaderMaterial.new()
	flash_material.shader = WHITE_FLASH_SHADER
	flash_material.set_shader_parameter(&"mix_weight", 1.0)
	_flash_originals[target_id] = original_material
	target.material = flash_material
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		flash_material,
		"shader_parameter/mix_weight",
		0.0,
		maxf(duration, 0.01)
	)
	tween.finished.connect(_restore_flash.bind(target, target_id))
	_flash_tweens[target_id] = tween


func stop_all() -> void:
	for tween: Tween in _pop_tweens.values():
		if tween.is_valid():
			tween.kill()
	for target_id: int in _base_scales:
		var target: Object = instance_from_id(target_id)
		if target is CanvasItem and is_instance_valid(target):
			_set_scale(target as CanvasItem, _base_scales[target_id])
	for tween: Tween in _flash_tweens.values():
		if tween.is_valid():
			tween.kill()
	for target_id: int in _flash_originals:
		var target: Object = instance_from_id(target_id)
		if target is CanvasItem and is_instance_valid(target):
			(target as CanvasItem).material = _flash_originals[target_id]
	_pop_tweens.clear()
	_base_scales.clear()
	_flash_tweens.clear()
	_flash_originals.clear()


func _exit_tree() -> void:
	stop_all()


func _on_button_down(button: Button, audio_manager: AudioManager) -> void:
	pop(button)
	if is_instance_valid(audio_manager):
		audio_manager.play_ui_thud()


func _get_scale(target: CanvasItem) -> Vector2:
	if target is Control:
		return (target as Control).scale
	if target is Node2D:
		return (target as Node2D).scale
	return Vector2.ONE


func _set_scale(target: CanvasItem, value: Vector2) -> void:
	if target is Control:
		(target as Control).scale = value
	elif target is Node2D:
		(target as Node2D).scale = value


func _finish_pop(target_id: int) -> void:
	_pop_tweens.erase(target_id)
	_base_scales.erase(target_id)


func _restore_flash(target: CanvasItem, target_id: int) -> void:
	if is_instance_valid(target) and _flash_originals.has(target_id):
		target.material = _flash_originals[target_id]
	_flash_tweens.erase(target_id)
	_flash_originals.erase(target_id)

