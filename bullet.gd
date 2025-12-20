extends Area2D

@export var speed := 275
@export var damage := 20

@onready var lifespan_timer: Timer = $lifespan

const LIFESPAN := 2.5

func _ready() -> void:
	lifespan_timer.start(LIFESPAN)

func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if !is_multiplayer_authority(): return
	
	if body is Player and body != get_meta("shooter"):
		body.damage.rpc(damage, get_meta("shooter_pid"))
	
	if body != get_meta("shooter"):
		rpc("remove_bullet")

@rpc("call_local")
func remove_bullet() -> void: queue_free()

func _on_lifespan_timeout() -> void:
	if is_instance_valid(self):
		queue_free()
