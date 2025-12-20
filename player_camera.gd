extends Camera2D

## MUST BE PARENTED TO A PLAYER NODE
@onready var player: Player = get_parent()
@onready var authority_id: String = player.name

var follows_player: bool = true

func _enter_tree() -> void:
	if is_multiplayer_authority():
		make_current()

func _ready() -> void:
	name = "Camera" + player.name

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_Y:
		switch_modes()

func _physics_process(_delta: float) -> void:
	if follows_player:
		self.global_position = player.global_position

func switch_modes(mode = !follows_player) -> void:
	follows_player = mode
	
	if !follows_player:
		self.reparent(player.get_parent()) ## Reparent to arena node
		#self.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		self.zoom = Vector2.ONE * 0.5
		self.global_position = Vector2.ZERO + Vector2(500, 50) # Offset
	else:
		self.reparent(player)
		self.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
		self.zoom = Vector2.ONE
