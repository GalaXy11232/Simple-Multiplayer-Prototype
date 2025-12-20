extends StaticBody2D

@export var DAMAGE_VALUE := 145.0
@onready var hitbox: Area2D = $Hitbox

#func _on_hitbox_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
	#if body is Player:
		#body.damage(DAMAGE_VALUE, self)

func _physics_process(_delta: float) -> void:
	for obj in hitbox.get_overlapping_bodies():
		if obj is Player:
			obj.damage(DAMAGE_VALUE, self)
