extends SceneTree
## THROWAWAY: starts the 13h Inspector prototype. Run:
## godot --path . -s res://prototypes/inspector/inspector_main.gd
## --hero= --villain= --seed= --difficulty= --hero-name= --villain-name= work as they do for
## the game. Both players always get a sample Emblem.

const ProtoScreen := preload("res://prototypes/inspector/inspector_screen.gd")


func _initialize() -> void:
	var request: EncounterRequest = EncounterRequest.from_arguments(OS.get_cmdline_user_args())
	if request == null:
		request = EncounterRequest.new()
		request.encounter_seed = 7
	request.has_sample_emblems = true
	var screen: ProtoScreen = ProtoScreen.new()
	screen.starts_itself = false
	screen.proto_request = request
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	current_scene = screen
