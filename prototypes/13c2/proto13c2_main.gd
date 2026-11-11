extends SceneTree
## THROWAWAY: starts the 13c-2 prototype. Run:
## godot --path . -s res://prototypes/13c2/proto13c2_main.gd -- --hero=red_green --villain=white_black --seed=5

const Proto13c2Screen := preload("res://prototypes/13c2/proto13c2_screen.gd")


func _initialize() -> void:
	var screen: Control = Proto13c2Screen.new()
	root.add_child(screen)
	current_scene = screen
