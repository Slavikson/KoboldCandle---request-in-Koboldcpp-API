@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_custom_type("KoboldCandle", "Node", preload("KoboldCandle.gd"), preload("icon_KoboldCandle.png"))
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_custom_type("HTTPSSEClient")
	pass
