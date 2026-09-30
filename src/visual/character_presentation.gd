class_name CharacterPresentation
extends Node2D
## Visual identity only. Character input, movement, stats, and combat are out of scope.

@export var character_name: StringName = &"Heikki"
@export var accent_color: Color = Color("ffd45a")

@onready var sprite: Sprite2D = %Sprite


func _ready() -> void:
	if sprite.material is ShaderMaterial:
		var unique_material := sprite.material.duplicate() as ShaderMaterial
		unique_material.set_shader_parameter(&"glow_color", accent_color)
		sprite.material = unique_material

