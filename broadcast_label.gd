extends Label

@onready var timer: Timer = $Timer
@export var lifespan := 5.0

@rpc("any_peer")
func summon_label(txt: String, color: Color = Color.YELLOW) -> void:
	text = txt
	name = "BroadcastLabel_%d" % get_instance_id()
	modulate = color
	
	await get_tree().create_timer(lifespan).timeout
	
	var tn := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tn.tween_property(self, "modulate:a", 0, 0.5)
	
	await tn.step_finished
	call_deferred("queue_free")
