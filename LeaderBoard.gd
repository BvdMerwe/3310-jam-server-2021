extends HTTPRequest

var http_client = HTTPClient.new()


func _ready():
	connect("request_completed", self, "_on_request_completed")

	var dict = {"hello":"world"}
	# var error = post_request("http://httpbin.org/post", dict, false)
	# if error != OK:
	# 	push_error("An error occurred in the HTTP request. " + str(error))


func get_request(url):
	return request(url)


func _on_request_completed(result, response_code, headers, body):
	push_warning("RETURNED" + body.get_string_from_utf8())
	var json = JSON.parse(body.get_string_from_utf8())
	print(json.result)


func post_request(url, data_to_send, use_ssl):
	# Convert data to json string:
	var query = JSON.print(data_to_send)

	#removed because we are not using form encoded data
	# var query_string = http_client.query_string_from_dict(data_to_send)
	var headers = [
		"Content-Type: application/json",
		# "Content-Length: " + str(query_string.length())
	]
	request(url, headers, use_ssl, HTTPClient.METHOD_POST, query)

func send_winner_time(server_addr, data):
	post_request('http://%s/scores?ctx=sioaoa-3310-2021' % server_addr, data, false)