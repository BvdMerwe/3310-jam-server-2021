extends Node

# Server defaults

var server_settings = {
	"SERVER_PORT" : 46594,
	"SERVER_IP" : '0.0.0.0',
	"MIN_PLAYERS" : 1,
	"MAX_PLAYERS" : 100,
	"LOBBY_TIME" : 3, #seconds
	"END_SCREEN_TIME" : 5, #seconds
	"GAME_LENGTH" : 60, #seconds,

	"LEADERBOARD_SERVER":'0.0.0.0:42069',
}

var peer
var connected = false
var failed = false
var retry = 0
var retry_max = 3
var timeout = 0
var timeout_max = 2
var game_in_progress = false
var ending_message_sent = false


# Player info, associate ID to data
var won_last_game = 1
var player_info = {}
var players_in_lobby = {}
var players_in_game = {}
var players_sorted_by_score = []
# Info we send to other players
var my_info = { name = "Johnson Magenta", score = 0 }

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")

	$StartTimer.connect("timeout", self, "start_game")
	$GameTimer.connect("timeout", self, "end_game")
	$EndScreenTimer.connect("timeout", self, "back_to_lobby")
	
	get_server_settings()

	create_server()

	get_tree().network_peer = peer

func get_server_settings():
	var settings_file = File.new()
	#location - ~/.local/share/godot/ | %APPDATA%\Godot\ | ~/Library/Application Support/Godot/
	if not settings_file.file_exists("user://server_settings.save"):
		settings_file.open("user://server_settings.save", File.WRITE)
		settings_file.store_line(to_json(server_settings))
		settings_file.close()
		return
	else:
		settings_file.open("user://server_settings.save", File.READ)
		var file_read = ""
		while settings_file.get_position() < settings_file.get_len():
			file_read += settings_file.get_line()
		# server_settings = parse_json(file_read)
	pass

func _process(delta):
	if !game_in_progress:
		if $StartTimer.is_stopped() :
			for pid in players_in_lobby.keys():
				rpc_unreliable("waiting_for_players")
			if player_info.size() >= server_settings["MIN_PLAYERS"]:
				print("game starting in ", str(server_settings["LOBBY_TIME"]))
				$StartTimer.start(server_settings["LOBBY_TIME"])
		elif !$StartTimer.is_stopped() :
			for pid in players_in_lobby.keys():
				rpc_unreliable("show_time", stepify($StartTimer.time_left, 1))
			if player_info.size() < server_settings["MIN_PLAYERS"]:
				print("game aborted")
				$StartTimer.stop()
	else:
		# for pid in players_in_lobby.keys():
		if $EndScreenTimer.time_left > 0:
			rpc_unreliable("game_ending", won_last_game)
		else: 
			rpc_unreliable("game_in_progress", stepify($GameTimer.time_left, 1))
		
		players_sorted_by_score.sort_custom(self, "sort_player_scores")
		for pid in players_in_game.keys():
			var player_place = players_sorted_by_score.find(pid) + 1
			rpc_id(pid, "set_place", player_place, players_in_game.size())
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
	print('starting server on %s:%s' % [server_settings["SERVER_IP"], server_settings["SERVER_PORT"]] )
	peer = NetworkedMultiplayerENet.new()
	peer.create_server(server_settings["SERVER_PORT"], server_settings["MAX_PLAYERS"])
	peer.set_bind_ip(server_settings["SERVER_IP"])
	get_tree().network_peer = peer
	print("accessible at : %s" % [IP.get_local_addresses()])
	pass

func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("connected!")
	rpc_id(id, "register_player", my_info)


func _player_disconnected(id):
	print("player disconnected! lobby count: ", player_info.size())
	player_info.erase(id)  # Erase player from info.
	players_in_lobby.erase(id)  # Erase player from lobby.
	players_in_game.erase(id)  # Erase player from in_game.
	if players_in_game.size() < server_settings["MIN_PLAYERS"]:
		end_game(1)
	
remote func register_player(info):
	# Get the id of the RPC sender.
	var id = get_tree().get_rpc_sender_id()
	# if info["name"] == "" :
	# 	info["name"] = id
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
	ending_message_sent = false
	$GameTimer.start(server_settings["GAME_LENGTH"])
	#send players from lobby to in_game
	players_in_game = players_in_lobby.duplicate()
	players_sorted_by_score = players_in_game.keys()
	players_in_lobby = {}
	for pid in players_in_game.keys():
		rpc_id(pid, "game_started")
	pass

func end_game(winner = false):
	if !winner:
		winner = get_player_with_highest_score()
	if (winner == 1):
		won_last_game = "nobody"
	else:
		won_last_game = players_in_game[winner]["name"]
	for pid in players_in_game.keys():
		rpc_id(pid, "game_ended", won_last_game, winner)
	
	print(str(winner), " has won game")
	print("GAME HAS ENDED! SHOWING WINNER NAME")
	$GameTimer.stop()
	$EndScreenTimer.start(server_settings["END_SCREEN_TIME"])

func back_to_lobby():
	game_in_progress = false
	players_in_lobby = player_info.duplicate()
	players_in_game = {}
	for pid in players_in_lobby.keys():
		rpc_id(pid, "back_to_lobby")
	
	print("Sending players back to lobby")
	

remote func update_score(score):
	var id = get_tree().get_rpc_sender_id()
	if players_in_game.has(id):
		players_in_game[id]["score"] = score

remote func win_game():
	if game_in_progress:
		var id = get_tree().get_rpc_sender_id()
		end_game(id)
	pass

remote func win_time(time):
	var id = get_tree().get_rpc_sender_id()
	var name = player_info[id]["name"]
	$LeaderBoard.send_winner_time(server_settings["LEADERBOARD_SERVER"], {"id":id, "player":name, "score":time})


func get_player_with_highest_score():
	# var high_score = 0
	# var current_winner = 1
	# for p in players_in_game.keys():
	# 	if players_in_game[p]["score"] > high_score:
	# 		high_score = players_in_game[p]["score"]
	# 		current_winner = p
	# return current_winner
	return players_sorted_by_score[0]
	pass

func sort_player_scores(a, b):
	if players_in_game.has(a) && players_in_game.has(b):
		if (players_in_game[a]["score"] > players_in_game[b]["score"]):
			return true
		return false
	
	#determine which is missing and send that one as winner
	return players_in_game.has(a)

func _on_LineEdit_text_changed(text):
	server_settings["SERVER_PORT"] = int(text)

func _on_Create_pressed():
	stop_server()
	create_server()
