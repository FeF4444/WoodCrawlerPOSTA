extends Node3D


@onready var animation=$AnimatedSprite3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation.play("fuego")
