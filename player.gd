class_name Player 
extends CharacterBody2D

#@onready var camera: Camera2D = %Camera
@onready var health_label: ProgressBar = $Health
@onready var msg_container: VBoxContainer = get_parent().get_node("Broadcasts/Control/MarginContainer/MsgContainer")
@onready var invulnerability_timer: Timer = $invulnerability
@onready var gun_container: Node2D = $GunContainer

const BROADCAST_LABEL := preload("res://broadcast_label.tscn")
const BULLET_PATH := preload("res://bullet.tscn")

const SPEED := 350.0
const JUMP_VELOCITY := -400.0
const MAX_HEALTH := 100
const INVULNERABILITY_TIME := 0.1

var health = MAX_HEALTH
var camera_following: bool = true
var can_doublejump: bool = false
var invulnerable: bool = false

func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))

func _ready() -> void:
	invulnerability_timer.wait_time = INVULNERABILITY_TIME
	invulnerability_timer.one_shot = true
	
	invulnerable = true
	invulnerability_timer.start()
	
	if !is_multiplayer_authority():
		get_node("Sprite").modulate = Color.RED
	else:
		health = MAX_HEALTH
		get_parent().get_node("GameUI/TeamLabel").text = get_meta('team').to_upper()

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	health_label.value = health
	
	gun_container.look_at(get_global_mouse_position())
	gun_container.get_node("GFX").flip_v = get_global_mouse_position().x < global_position.x
	
	if Input.is_action_just_pressed("shoot"):
		rpc("shoot_bullet", multiplayer.get_unique_id())
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_doublejump = true
		else:
			if can_doublejump:
				velocity.y = JUMP_VELOCITY
				can_doublejump = false
		
	if is_on_floor() and not can_doublejump:
		can_doublejump = true

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func set_playertag(name_entry_text):
	var playertag := $playertag
	playertag.text = name_entry_text

@rpc("call_local")
func shoot_bullet(shooter_pid) -> void:
	var bullet = BULLET_PATH.instantiate()
	bullet.set_multiplayer_authority(shooter_pid)
	bullet.set_meta('shooter', self)
	bullet.set_meta('shooter_pid', shooter_pid)
	get_parent().add_child(bullet)
	
	#if is_multiplayer_authority():
		#print(get_meta('team'))
	
	bullet.global_position = $GunContainer/GFX/Muzzle.global_position
	bullet.transform = $GunContainer/GFX/Muzzle.global_transform
	bullet.scale = Vector2.ONE * 0.8

@rpc('any_peer', 'call_local')
func damage(value: int, damager) -> void:
	if invulnerable: return
	
	health -= value
	
	## Player died
	if health <= 0:
		var new_spawnpoint = get_parent().get_node("Spawnpoints").get_children().pick_random().global_position
		
		self.global_position = new_spawnpoint
		health = MAX_HEALTH
		## Spawn invulnerability
		invulnerability_timer.stop()
		invulnerable = true
		invulnerability_timer.start()
		
		## Broadcast death message
		var ann_label := BROADCAST_LABEL.instantiate()
		msg_container.add_child(ann_label)
		
		## Damager is sent as pid through rpc
		if damager is int:
			var player_by_pid = get_parent().get_node_or_null(str(damager))
			if player_by_pid == null:
				ann_label.summon_label($playertag.text + " was killed by old age")
			else:
				ann_label.summon_label($playertag.text + " was killed by " + player_by_pid.get_node('playertag').text)
				
				var team = player_by_pid.get_meta('team')
				#if is_multiplayer_authority():
				get_parent().increment_team_score.rpc(team)
		else:
			ann_label.summon_label($playertag.text + " was killed by " + damager.name)
			
	
	else:
		invulnerable = true
		invulnerability_timer.start()


func _on_invulnerability_timeout() -> void: 
	invulnerable = false
