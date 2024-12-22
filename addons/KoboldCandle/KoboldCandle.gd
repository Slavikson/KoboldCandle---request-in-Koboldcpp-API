extends Node

class_name KoboldCandle
#Conect info
const url = "localhost" # Host only, no protocol or path
const url_after_domain = "/api/v1/generate" 
const url_after_domain_stream = "/api/extra/generate/stream"
const url_after_domain_check = "/api/extra/generate/check"
const url_after_domain_abort = "/api/extra/abort"
@export var port : int = 5001 #Change if you have another PORT
const headers = ["Content-Type: application/json"]
var httpclient = HTTPClient.new()
var http = HTTPRequest.new()

#Option
@export var stream : bool = true 
@export var continued : bool = false #Automatically continue generation if max_length was exceeded

#Technical variables
var is_connected = false
var connection_in_progress = false
var request_in_progress = false
var finish = false
var current_message : Dictionary = {}
var last_massage : String
var generate = false
var last_status
var last_result : String
var last_chunk : String
var last_finish_reason

#Signal
signal generated(Text : String)
signal generating_completed(Text : String)

func _ready() -> void:
	add_child(http)
	attempt_to_connect()
	
func _process(delta: float) -> void:
	check_HTTPClient_Status()
	if !is_connected:
		attempt_to_connect()
	
	if generate and !request_in_progress:
		request()
	elif request_in_progress:
		if !stream:
			read_response()
		else:
			get_check()

func send_message(message: Dictionary):
	current_message = message
	finish = false
	generate = true

func attempt_to_connect():
	if !connection_in_progress:
		var err = httpclient.connect_to_host(url, port)
		if err == OK:
			connection_in_progress = true
		else:
			print("Connection error:", str(err))

func creating_body(prompt : Dictionary) -> String:
	var body = JSON.stringify(prompt)
	return body

func request():#Sends a request for generation to Koboldccp
	if check_HTTPClient_Status() == HTTPClient.STATUS_CONNECTED:
		if last_finish_reason != "length":
			last_result = ""
		var prompt = current_message
		var body 
		var result 
		if !stream:
			prompt["prompt"] = current_message["prompt"] + last_chunk
			body = creating_body(prompt)
			result = httpclient.request(HTTPClient.METHOD_POST, url_after_domain, headers, body)
		else:
			prompt["prompt"] = current_message["prompt"] + last_result
			body = creating_body(prompt)
			result = httpclient.request(HTTPClient.METHOD_POST, url_after_domain_stream, headers, body)
		if result != OK:
			print("Error sending request: ", result)
		else:
			print("Request body: ", body)
			last_chunk = ""
			request_in_progress = true
	
func read_response(): #Reads the response at the end of generation if stream == false
	if check_HTTPClient_Status() == HTTPClient.STATUS_BODY:
		var body = httpclient.read_response_body_chunk()
		if body.size() > 0:
			var json = JSON.new()
			json.parse(body.get_string_from_utf8())
			var response = json.get_data()
			last_chunk += response["results"][0]["text"]
			var  finish_reason = response["results"][0]["finish_reason"]
			if finish_reason:
				status_finished(finish_reason)

func get_check():#Reads generation if stream == true
	if check_HTTPClient_Status() == HTTPClient.STATUS_CONNECTED:
		var result = httpclient.request(HTTPClient.METHOD_POST, url_after_domain_check, ["accept: text/event-stream"])
		if result != OK:
			print("Error sending request: ", result)
		else:
			var chunk = httpclient.get_response_headers()
			if !chunk.size() > 0:
				return
			if chunk[0]!= "Server: ConcedoLlamaForKoboldServer":
				last_chunk = ""
				chunk = chunk[1].replace("\\\\", "\\")
				var chunk_dic = chunk.replace('data: ', '')
				var json = JSON.new()
				json.parse(chunk_dic)
				var response = json.get_data()
				last_chunk += response["token"]
				print("["+last_result+last_chunk+"]")
				emit_signal("generated",last_result+last_chunk)
				var finish_reason = response["finish_reason"]
				if finish_reason:
					status_finished(finish_reason)

func abort():#Stop generate
	http.cancel_request()
	var result = http.request("http://localhost:5001/api/extra/abort", headers, HTTPClient.METHOD_POST)
	if result != OK:
		print("Error sending request: ", result)
	else:
		print("---!Abort!---")

func finished():
	request_in_progress = false
	last_massage = current_message["prompt"]
	last_result += last_chunk
	current_message = {}
	generate = false
	finish = true
	print("---finished!---")
	print("["+last_result+last_chunk+"]")
	emit_signal("generating_completed",last_result)

#STATE_MACHINE
func check_HTTPClient_Status():
	httpclient.poll()
	var Status = httpclient.get_status()
	match Status:
		HTTPClient.STATUS_DISCONNECTED:
			if last_status != Status:
				print("DISCONNECT")
			is_connected = false
			connection_in_progress = false
		HTTPClient.STATUS_RESOLVING :
			#if last_status != Status:
				#print("STATUS_RESOLVING")
				pass
		HTTPClient.STATUS_CANT_RESOLVE :
			#if last_status != Status:
				#print("STATUS_CANT_RESOLVE")
				pass
		HTTPClient.STATUS_CONNECTING :
			#if last_status != Status:
				#print("STATUS_CONNECTING")
				pass
		HTTPClient.STATUS_CANT_CONNECT:
			if last_status != Status:
				print("STATUS_CANT_CONNECT")
			is_connected = false
			connection_in_progress = false
		HTTPClient.STATUS_CONNECTED :
			#if last_status != Status:
				#print("STATUS_CONNECTED")
			is_connected = true
			connection_in_progress = false
		HTTPClient.STATUS_REQUESTING  :
			#if last_status != Status:
				#print("STATUS_REQUESTING")
			pass
		HTTPClient.STATUS_BODY:
			#if last_status != Status:
				#print("STATUS_BODY")
			pass
		HTTPClient.STATUS_CONNECTION_ERROR:
			#if last_status != Status:
				#print("STATUS_CONNECTION_ERROR")
			if continued and !finish:
				request_in_progress = false
			is_connected = false
			connection_in_progress = false
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			if last_status != Status:
				print("STATUS_TLS_HANDSHAKE_ERROR")
	last_status = Status
	return Status

func status_finished(finish_reason):#Checks how the generation ended
	last_finish_reason = finish_reason
	last_result += last_chunk
	if last_finish_reason != finish_reason:
		print(finish_reason)
	match finish_reason:
		"stop":
			finished()
		"length":
			if !continued:
				finished()

func _exit_tree() -> void:
	httpclient.close()
	http.queue_free()
