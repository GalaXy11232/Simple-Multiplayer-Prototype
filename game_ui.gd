extends CanvasLayer
signal game_can_start

@onready var game_node: Game = $".."

@onready var time_left_label: Label = $TimeLeft
@onready var timer_left: Timer = $TimerLeft
@onready var pregame_timer: Timer = $"PreGame Timer"

const MATCH_DURATION := 150#50 # seconds
const PREGAME_DURATION := 3 # seconds
const DEFAULT_PENDING_STRING := "Waiting for players..."
var game_pending: bool = false
var game_running: bool = false
var game_ended: bool = false
var game_interrupted: bool = false

func _ready() -> void:
	timer_left.wait_time = MATCH_DURATION
	timer_left.one_shot = true
	
	pregame_timer.wait_time = PREGAME_DURATION
	pregame_timer.one_shot = true

func format_time_left(timer: Timer) -> Array:
	var left := timer.time_left
	var minutes_left := left / 60
	var seconds_left := int(left) % 60
	
	return [minutes_left, seconds_left + 1]

func _process(_delta: float) -> void:
	if not game_running and not game_ended and not game_pending:
		update_timer(false, DEFAULT_PENDING_STRING)
		
		if game_node.players.size() >= 2:
			emit_signal('game_can_start')
	
	elif game_pending:
		update_timer(false, "Starting in " + str(format_time_left(pregame_timer)[1]))
		if game_node.players.size() < 2:
			game_pending = false
			pregame_timer.stop()
		
	elif multiplayer.multiplayer_peer and not $"../UI/Multiplayer".visible:
		if not game_ended:
			if game_running:
				update_timer()
			
			## End game early
			if game_node.players.size() < 2:
				game_running = false
				game_interrupted = true
				
				var interrupt_message: String = 'Game interrupted due to leaving.\nIt would have been a '
				var red_score := game_node.red_score
				var blue_score := game_node.blue_score
				
				if red_score > blue_score:
					interrupt_message += "WIN for RED!"
				elif blue_score > red_score:
					interrupt_message += "WIN for BLUE!"
				else:
					interrupt_message += "DRAW!"
				
				update_timer(false, interrupt_message)
				_on_timer_left_timeout()
			
		elif not game_interrupted:
			var end_text: String
			var red_score := game_node.red_score
			var blue_score := game_node.blue_score
			
			if red_score > blue_score:
				end_text = "Red team won!"
			elif blue_score > red_score:
				end_text = "Blue team won!"
			else:
				end_text = "DRAW!"
			
			update_timer(false, end_text)
	


func update_timer(show_time_left: bool = true, custom_text: String = '') -> void:
	if (multiplayer.multiplayer_peer and multiplayer.has_multiplayer_peer()) and is_multiplayer_authority():
		if show_time_left:
			time_left_label.text = "%02d:%02d" % format_time_left(timer_left)
		else:
			time_left_label.text = custom_text

## game_can_start signal here
func _on_game_can_start() -> void:
	game_pending = true
	game_running = false
	game_ended = false
	pregame_timer.start()

func _start_game() -> void:
	game_pending = false
	game_running = true
	game_ended = false
	timer_left.start()


func _on_timer_left_timeout() -> void:
	game_running = false
	game_ended = true
	print("Red: %d\nBlue: %d" % [game_node.red_score, game_node.blue_score]) ## prints out ... server side
	
	for p in get_tree().get_nodes_in_group('player'):
		#print(p.get_node("playertag").text)
		p.change_immobility.rpc(true) # Immobilize all players (nustiu de ce trebuie rpc('any_peer', 'call_local') ca altfel nu merge)
	
	## Game finished timespan
	await get_tree().create_timer(4.0).timeout
	
	## Disconnect everyone
	for bullet in get_tree().get_nodes_in_group("bullets"):
		bullet.queue_free()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	await get_tree().process_frame
	await get_tree().create_timer(.05).timeout
	get_tree().change_scene_to_file("res://game.tscn")
