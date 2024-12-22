extends Node2D

@onready var Candle :KoboldCandle = $KoboldCandle
@export var Prompt = {
		"prompt": "system: You are a kind virtual assistant.\nuser: Helow chat!\n",#Without "\n" the neural network will often continue your message first.
		"temperature": 0.6,
		"max_length": 100,
		"max_context_length": 8192,
	}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Candle.send_message(Prompt)
	#await get_tree().create_timer(2.0).timeout
	#Candle.abort()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
