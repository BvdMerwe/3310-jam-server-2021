extends Node

# Connect all functions

var SERVER_PORT = 46594
export (String) var SERVER_IP = '127.0.0.1'
export (int) var MIN_PLAYERS = 1
export (int) var MAX_PLAYERS = 100
export (int) var LOBBY_TIME = 3 #seconds
export (int) var END_SCREEN_TIME = 10 #seconds
export (int) var GAME_LENGTH = 60 #seconds

export(bool) var is_server = false

var peer
var connected = false
var failed = false
var retry = 0
var retry_max = 3
var timeout = 0
var timeout_max = 2
var game_in_progress = false


func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")

	$StartTimer.connect("timeout", self, "start_game")
	$GameTimer.connect("timeout", self, "end_game")
	$EndScreenTimer.connect("timeout", self, "back_to_lobby")
	
	create_server()

	get_tree().network_peer = peer


func _process(delta):
	if !game_in_progress:
		if $StartTimer.is_stopped() :
			for pid in players_in_lobby.keys():
				rpc_unreliable("waiting_for_players")
			if player_info.size() >= MIN_PLAYERS:
				print("game starting in ", str(LOBBY_TIME))
				$StartTimer.start(LOBBY_TIME)
		elif !$StartTimer.is_stopped() :
			for pid in players_in_lobby.keys():
				rpc_unreliable("show_time", stepify($StartTimer.time_left, 1))
			if player_info.size() < MIN_PLAYERS:
				print("game aborted")
				$StartTimer.stop()
	else:
		# for pid in players_in_lobby.keys():
		rpc_unreliable("game_in_progress", stepify($GameTimer.time_left, 1))
		pass
	pass


func stop_server():
	print('stopping server')
	peer.close_connection()
	peer = null
	queue_free()
	print('stopping server')
	pass


func create_server():
	print('starting server on %s:%s' % [SERVER_IP, SERVER_PORT] )
	print("accessible at : %s" % [IP.get_local_addresses()])
	peer = NetworkedMultiplayerENet.new()
	peer.create_server(SERVER_PORT, MAX_PLAYERS)
	get_tree().network_peer = peer
	pass

# Player info, associate ID to data
var player_info = {}
var players_in_lobby = {}
var players_in_game = {}
# Info we send to other players
var my_info = { name = "Johnson Magenta", score = 0 }


func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("connected!")
	rpc_id(id, "register_player", my_info)


func _player_disconnected(id):
	print("player disconnected! lobby count: ", player_info.size())
	player_info.erase(id)  # Erase player from info.

remote func register_player(info):
	# Get the id of the RPC sender.
	var id = get_tree().get_rpc_sender_id()
	print("player: ", info, " - ", id)
	# Store the info
	player_info[id] = info
	players_in_lobby[id] = info
	print("register_player! lobby count: ", player_info.size())
	# Call function to update lobby UI here
	rpc("show_players", player_info.size())

func start_game():
	print("GAME HAS STARTED!")
	game_in_progress = true
	$GameTimer.start(GAME_LENGTH)
	#send players from lobby to in_game
	players_in_game = players_in_lobby.duplicate()
	players_in_lobby = {}
	for pid in players_in_game.keys():
		rpc_id(pid, "game_started")
	pass

func end_game(winner = false):
	if !winner:
		winner = get_player_with_highest_score()
	for pid in players_in_game.keys():
		rpc_id(pid, "game_ended", winner)
	print("GAME HAS ENDED! SHOWING WINNER NAME")
	$EndScreenTimer.start(END_SCREEN_TIME)

func back_to_lobby():
	game_in_progress = false
	players_in_lobby = player_info.duplicate()
	players_in_game = {}
	for pid in players_in_lobby.keys():
		rpc_id(pid, "back_to_lobby")
	

remote func update_score(score):
	var id = get_tree().get_rpc_sender_id()
	players_in_game[id]["score"] = score

remote func win_game():
	if game_in_progress:
		var id = get_tree().get_rpc_sender_id()
		print(str(id), " has won game")
		end_game(id)
	pass

func get_player_with_highest_score():
	var high_score = 0
	var current_winner = 1
	for p in players_in_game.keys():
		if players_in_game[p]["score"] > high_score:
			high_score = players_in_game[p]["score"]
			current_winner = p
	return current_winner
	pass

func _on_LineEdit_text_changed(text):
	SERVER_PORT = int(text)

func _on_Create_pressed():
	stop_server()
	create_server()
