class_name Game 
extends Node2D

@onready var spawnpoint_nodes: Node2D = $Spawnpoints
@onready var multiplayer_ui: Control = $UI/Multiplayer
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var msg_container: VBoxContainer = $Broadcasts/Control/MarginContainer/MsgContainer

@onready var game_ui: CanvasLayer = $GameUI

@onready var spawnpoints_num: int = len(spawnpoint_nodes.get_children())

const BROADCAST_LABEL := preload("res://broadcast_label.tscn")
const PLAYER_PATH := preload("res://player.tscn")
const PLAYER_CAMERA_PATH := preload("res://player_camera.tscn")
const PORT := 21212

const MAX_PLAYERS := 4
var players: Array[Player] = []
var red_team: Array[Player] = []
var blue_team: Array[Player] = []
var peer: ENetMultiplayerPeer

var red_score := 0
var blue_score := 0

func _ready() -> void:
	$UI.show()
	self.hide()
	game_ui.hide()
	await get_tree().process_frame
	
	$GameUI/Red.text = "Score: %d" % red_score
	$GameUI/Blue.text = "Score: %d" % blue_score
	
	peer = ENetMultiplayerPeer.new()
	multiplayer_spawner.spawn_function = add_player
	
	multiplayer.peer_disconnected.connect(_disconnect_peer)
	multiplayer.server_disconnected.connect(
		func():
			#if multiplayer.multiplayer_peer:
				#multiplayer.multiplayer_peer.close()
			
			players.clear()
			blue_team.clear()
			red_team.clear()
			
			call_deferred('_safe_reload')
	)

func _safe_reload():
	var tree := Engine.get_main_loop()
	if tree and tree is SceneTree:
		
		tree.change_scene_to_file("res://game.tscn")

func _disconnect_peer(pid) -> void:
	if !is_multiplayer_authority(): return
	
	var player = get_node_or_null(str(pid))
	if player:
		players.erase(player)
		red_team.erase(player)
		blue_team.erase(player)
		player.queue_free()

func _on_host_pressed() -> void:
	var host_name: String = %NameEntry.text
	## Check if name is too long
	if len(host_name.strip_edges()) >= 15:
		rpc_id(1, 'join_denied', "Name is too long. (15 chars max.)")
		return
	
	
	peer = ENetMultiplayerPeer.new()
	
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer

	self.show()
	
	var team: String
	if $"UI/Multiplayer/Pref Red".button_pressed or $"UI/Multiplayer/Pref Blue".button_pressed:
		if $"UI/Multiplayer/Pref Red".button_pressed:
			team = 'red'
		else:
			team = 'blue'
	else:
		## For host, choose first team by default
		team = 'red'
	
	
	multiplayer_spawner.spawn({
		"pid": multiplayer.get_unique_id(),
		"player_name": host_name.strip_edges(),
		'team': team
	})
	
	
	$UI/ishost.show()
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168."):
			$UI/ishost.text += addr + '\n'
	
	multiplayer_ui.hide()
	$GameUI.show()


@rpc("any_peer", "reliable")
func request_join(player_name: String, team: String) -> void:
	if !is_multiplayer_authority():
		return
		
	var pid := multiplayer.get_remote_sender_id()
	
	if players.size() >= MAX_PLAYERS:
		rpc_id(pid, "join_denied", "Server is full")
		return
	
	## Check if name is too long
	if len(player_name.strip_edges()) >= 15:
		rpc_id(pid, 'join_denied', "Name is too long. (15 chars max.)")
		return
	
	## Check if someone has the same name
	if player_name.strip_edges() != '' and not is_name_available(player_name):
		rpc_id(pid, "join_denied", "Name already exists")
		return
		
	
	## Resolve teams -> choose one that is available regardless of preferences (balancing)
	if are_teams_equal() == true:
		if team == 'any': 
			team = 'red' # Choose red by default
	elif are_teams_equal() == false:
		team = 'red' if red_team.size() < blue_team.size() else 'blue' # Auto balance
	
	var crt_score : int
	if team == 'red':
		crt_score = red_score
	else: crt_score = blue_score
	
	multiplayer_spawner.spawn({
		'pid': pid,
		'player_name': player_name.strip_edges(),
		'team': team,
		'team_score': crt_score # Update current team score accordingly
	})
	
	rpc_id(pid, "join_accepted")

func are_teams_equal() -> Variant:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() == 1:
		return red_team.size() == blue_team.size()
	return 'Not server'


func is_name_available(player_name: String) -> bool:
	for child in get_children():
		if child is Player and child.get_node('playertag').text == player_name:
			return false
	return true 

@rpc("any_peer", 'reliable')
func call_join_msg(player_name):
	if player_name == '':
		player_name = "Player " + str(players.size())
		
	rpc("_call_connect_message", player_name)
	

@rpc("call_local", "reliable")
func join_denied(reason: String):
	#print("Join denied:", reason)
	$Broadcasts/err.text = reason
	$Broadcasts/err.show()

@rpc("call_local", "reliable")
func join_accepted():
	print("Joined successfully!")
	
	multiplayer_ui.hide()
	$GameUI.show()
	self.show()
	$Broadcasts/err.hide()


func _on_join_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client($UI/Multiplayer/IPEntry.text, PORT)
	multiplayer.multiplayer_peer = peer
	
	await multiplayer.connected_to_server
	
	## Also configure preferred team
	var team: String
	if $"UI/Multiplayer/Pref Red".button_pressed:
		team = 'red'
	elif $"UI/Multiplayer/Pref Blue".button_pressed:
		team = 'blue'
	else: team = 'any'
	
	rpc_id(1, "request_join", %NameEntry.text, team)


const SCORE_INCREMENT := 10
func increment_team_score(team: String, value = SCORE_INCREMENT, mode = 'add') -> void:
	if team == 'red':
		if mode == 'add':
			red_score += value
		else: red_score = value
		$GameUI/Red.text = "Score: %d" % red_score
	else:
		if mode == 'add':
			blue_score += value
		else: blue_score = value
		
		$GameUI/Blue.text = "Score: %d" % blue_score


#@rpc("call_local", "reliable")
func add_player(data):
	var player = PLAYER_PATH.instantiate()
	var pid = data.get('pid')
	var player_name = data.get('player_name', "")
	

	if get_node_or_null(str(pid)) != null:
		return  # already spawned
	
	var team = data.get('team')
	player.set_meta('team', team)
	if team == 'red':
		red_team.append(player)
	else:
		blue_team.append(player)
	
	## Update both team scores accordingly for newly joined users
	if is_multiplayer_authority():
		increment_team_score('red', red_score, 'set')
		increment_team_score('blue', blue_score, 'set')
	
	var player_camera = PLAYER_CAMERA_PATH.instantiate()
	player.name = str(pid)
	
	if player_name == '':
		player_name = "Player " + str(players.size() + 1)
	player.set_playertag(player_name)
	
	player.global_position = spawnpoint_nodes.get_child(0).global_position#((players.size() % spawnpoints_num)).global_position
	players.append(player)
	
	## If not checking for multiplayer_authority, one message for each client appears
	if is_multiplayer_authority():
		rpc("_call_connect_message", player_name)

	player.add_child(player_camera)
	return player

@rpc("call_local")
func _call_connect_message(txt) -> void:
	var joinmsg := BROADCAST_LABEL.instantiate()
	msg_container.add_child(joinmsg)
	joinmsg.summon_label(txt + " connected!", Color.GREEN)


func _on_pref_red_pressed() -> void: 
	$"UI/Multiplayer/Pref Blue".button_pressed = false
func _on_pref_blue_pressed() -> void:
	$"UI/Multiplayer/Pref Red".button_pressed = false


func _on_quit_pressed() -> void:
	for bullet in get_tree().get_nodes_in_group("bullets"):
		bullet.queue_free()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	await get_tree().process_frame
	await get_tree().create_timer(.05).timeout
	get_tree().change_scene_to_file("res://game.tscn")
	
