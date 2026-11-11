extends SceneTree
## THROWAWAY: loads each hand-built board, clicks as the mouse would, and saves pictures.
## godot --path . -s res://prototypes/13c2/proto13c2_shots.gd -- --out=/abs/dir

const Proto13c2Screen := preload("res://prototypes/13c2/proto13c2_screen.gd")

var _out: String = ""
var _screen: Control


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	_run()


func _run() -> void:
	EncounterScreen.request = EncounterRequest.new()
	_screen = Proto13c2Screen.new()
	root.add_child(_screen)
	await process_frame
	_screen.load_board("Attack")
	await _shot("1_attack_start")
	_screen.combat_click(2)
	_screen.combat_click(3)
	await _shot("2_attack_two_chosen")
	_screen.pass_priority()
	await _shot("3_attack_confirmed")
	_screen.load_board("Block")
	await _shot("4_block_start")
	_screen.combat_click(2)
	await _shot("5_block_picked_up")
	_screen.combat_click(21)
	_screen.combat_click(1)
	_screen.combat_click(22)
	_screen.combat_click(3)
	_screen.combat_click(22)
	await _shot("6_block_two_on_one")
	_screen.load_board("Crowded")
	_screen.combat_click(1)
	_screen.combat_click(28)
	_screen.combat_click(3)
	_screen.combat_click(20)
	await _shot("7_crowded")
	_screen.load_board("Divide")
	await _shot("8_divide_default")
	_screen.change_amount(2, -1)
	await _shot("9_divide_one_unassigned")
	_screen.load_board("Trample")
	await _shot("10_trample")
	_screen.load_board("Villain blocked")
	await _shot("11_villain_blocked")
	quit()


func _shot(name: String) -> void:
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
