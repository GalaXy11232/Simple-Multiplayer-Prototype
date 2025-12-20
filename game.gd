class_name Game 
extends Node2D

@onready var spawnpoint_nodes: Node2D = $Spawnpoints
@onready var multiplayer_ui: Control = $UI/Multiplayer
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var msg_container: VBoxContainer = $Broadcasts/Control/MarginContainer/MsgContainer

@onready var spawnpoints_num: int = len(spawnpoint_nodes.get_children())

const BROADCAST_LABEL := preload("res://broadcast_label.tscn")
const PLAYER_PATH := preload("res://player.tscn")
const PLAYER_CAMERA_PATH := preload("res://player_camera.tscn")
const PORT := 21212

const MAX_PLAYERS := 2
var players: Array[Player] = []
var peer: ENetMultiplayerPeer

func _ready() -> void:
	$UI.show()
	self.hide()
	await get_tree().process_frame
	
	peer = ENetMultiplayerPeer.new()
	multiplayer_spawner.spawn_function = add_player
	
	#multiplayer.peer_disconnected.connect(
		#func(id):
			#if is_instance_valid(get_node(str(id))):
				#get_node(str(id)).queue_free()
	#)
	
	## SERVER Disconnected
	multiplayer.server_disconnected.connect( func(): get_tree().quit() )
	
	## PEER Disconnected
	multiplayer.peer_disconnected.connect(
		func(pid): 
			var player = get_node_or_null(str(pid))
			if player: 
				player.queue_free()
			
			# Remove from players array 
			players = players.filter(func(p): return p != player)
			
			#get_tree().quit() 
	)

func _on_host_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	#get_tree().set_multiplayer(SceneMultiplayer.new(), self.get_path())
	self.show()
	
	var host_name: String = %NameEntry.text
	multiplayer_spawner.spawn({
		"pid": multiplayer.get_unique_id(),
		"player_name": host_name
	})
	#rpc("add_player", multiplayer.get_unique_id(), %NameEntry.text)
	
	$UI/ishost.show()
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168."):
			$UI/ishost.text += addr + '\n'
	
	multiplayer_ui.hide()
	#rpc("call_join_msg", host_name)
	

@rpc("any_peer", "reliable")
func request_join(player_name: String) -> void:
	if !is_multiplayer_authority():
		return
		
	var pid := multiplayer.get_remote_sender_id()
	
	if players.size() >= MAX_PLAYERS:
		rpc_id(pid, "join_denied", "Server is full")
		return
	
	multiplayer_spawner.spawn({
		'pid': pid,
		'player_name': player_name
	})
	
	#rpc("call_join_msg", player_name)
	rpc_id(pid, "join_accepted")

@rpc("any_peer", 'reliable')
func call_join_msg(player_name):
	if player_name == '':
		player_name = "Player " + str(players.size())
		
	rpc("_call_connect_message", player_name)
	

@rpc("call_local", "reliable")
func join_denied(reason: String):
	print("Join denied:", reason)
	$err.text = "Server is full!"

@rpc("call_local", "reliable")
func join_accepted():
	print("Joined successfully!")
	
	multiplayer_ui.hide()
	self.show()


func _on_join_pressed() -> void:
	#if multiplayer.multiplayer_peer != null:
		#multiplayer.multiplayer_peer.close()
		#multiplayer.multiplayer_peer = null
		
	peer = ENetMultiplayerPeer.new()
	peer.create_client($UI/Multiplayer/IPEntry.text, PORT)
	multiplayer.multiplayer_peer = peer
	
	await multiplayer.connected_to_server
	rpc_id(1, "request_join", %NameEntry.text)
	#multiplayer_ui.hide()
	#self.show()
	#
	#await get_tree().create_timer(.1).timeout ## Dont know why it tweaks without sleep()
	#rpc("_call_connect_message", __setup_playertag(%NameEntry.text))

#@rpc("any_peer", 'reliable')
#func configure_playertag(pid, player_name) -> void:
	#var size = players.size()
	#var player = get_node_or_null(str(pid))
	#if player == null:
		#return
	#
	#var ret: String
	#if len(player_name) == 0:
		#ret = "Player " + str(size + 1)
	#else: ret = player_name
	#
	#player.set_playertag(ret)

@rpc("call_local", "reliable")
func add_player(data):
	var player = PLAYER_PATH.instantiate()
	var pid = data.get('pid')
	var player_name = data.get('player_name', "")
	
	if get_node_or_null(str(pid)) != null:
		return  # already spawned
	
	var player_camera = PLAYER_CAMERA_PATH.instantiate()
	player.name = str(pid)
	
	if player_name == '':
		player_name = "Player " + str(players.size() + 1)
	player.set_playertag(player_name)
	
	player.global_position = spawnpoint_nodes.get_child(players.size() % spawnpoints_num).global_position
	players.append(player)
	
	## If not checking for multiplayer_authority, one message for each client appears
	if is_multiplayer_authority():
		rpc("_call_connect_message", player_name)

	player.add_child(player_camera)
	return player

func __setup_playertag(nume: String) -> String:
	var ret: String
	if len(nume) == 0:
		ret = "Player "# + str(rpc('get_number_of_players') + 1)
	else: ret = nume
	
	return ret

@rpc("call_local")
func _call_connect_message(txt) -> void:
	var joinmsg := BROADCAST_LABEL.instantiate()
	msg_container.add_child(joinmsg)
	joinmsg.summon_label(txt + " connected!", Color.GREEN)

#@rpc("any_peer")
#func peer_disconnected(pid):
	#var player = get_node_or_null(str(pid))
	#if player:
		#player.queue_free()
#
#func _notification(what: int) -> void:
	#if what == NOTIFICATION_WM_CLOSE_REQUEST:
		#if multiplayer.multiplayer_peer:
			#rpc_id(1, 'peer_disconnected', multiplayer.get_unique_id())
			#
			#multiplayer.multiplayer_peer.close()
			#multiplayer.multiplayer_peer = null
##func _exit_tree() -> void:
	##if multiplayer.multiplayer_peer:
		##rpc_id(1, 'peer_disconnected', multiplayer.get_unique_id())
		##
		##multiplayer.multiplayer_peer.close()
		##multiplayer.multiplayer_peer = null
		#
