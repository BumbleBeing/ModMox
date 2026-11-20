extends Node
## PROTOTYPE (after milestone 13l): throwaway. The Pass Button's steel frame (SteelFrame,
## game ADR 0066) on every other button of the Encounter Screen: the sidebar's steps, Undo,
## Yield Turn, Emblems and Potions, the pregame's, the Pause Menu's, the Inspector's and the
## damage steppers'. Nothing in ui/ is touched: this opens the real game and, every frame,
## frames whatever plain button it finds under the Encounter Screen in that button's own
## color, read back from the style it was given. Nothing here is ported as it is; what the
## user signs off on is rebuilt test-first.
##
## Run: godot --path . res://prototypes/steel_frames/steel_frames.tscn -- --hero=red_green
##   --villain=white_black --seed=7
## Keys: F9 turns the frames off and on, to compare.
## For a picture: add --advance (plays first and keeps, to reach the board) --after=4
##   --shot=/absolute/path.png [--plain] (the game as it is, for a before picture)
##   [--settings] (opens the Pause Menu's settings page first)
## To measure flicker: --advance --check --after=14 --shot=... passes priority through the
##   steps and prints how many frames drew a button without its frame; add --lag to frame a
##   frame late, as this prototype first did, and see the count it catches.

const MAIN_MENU: String = "res://ui/menu/main_menu.tscn"
const STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]
## A button shorter than this has no room for a frame.
const SHORTEST: float = 22.0
const ORIGINALS: StringName = &"steel_prototype_originals"
const FRAMED_AS: StringName = &"steel_prototype_framed_as"

var _is_on: bool = true
var _shot: String = ""
var _after: float = 3.0
var _advances: bool = false
## For a picture: open the Pause Menu's settings page once the board is reached.
var _opens_settings: bool = false
var _elapsed: float = 0.0
var _colors: Dictionary[int, Color] = {}
## For --check: passes priority to change steps, and counts the frames drawn in which a
## button the game had just styled anew was still without its frame.
var _checks: bool = false
var _unframed_frames: int = 0
var _frames_drawn: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--after="):
			_after = float(argument.trim_prefix("--after="))
		elif argument == "--advance":
			_advances = true
		elif argument == "--settings":
			_opens_settings = true
		elif argument == "--check":
			_checks = true
		elif argument == "--plain":
			_is_on = false
	# After everything else each frame, so a button the game styles anew in its own redraw
	# is framed again before that frame is drawn, and never seen without its frame.
	process_priority = -1000 if OS.get_cmdline_user_args().has("--lag") else 1000
	RenderingServer.frame_pre_draw.connect(_before_draw)
	# This node outlives the scene it opens: it moves to the root, then opens the game.
	_open_game.call_deferred()


func _open_game() -> void:
	var tree: SceneTree = get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.change_scene_to_file(MAIN_MENU)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		_is_on = not _is_on


func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_visit(scene, false)
	# And once more after whatever the game deferred to the end of the frame.
	if not OS.get_cmdline_user_args().has("--lag"):
		_visit.call_deferred(scene, false)
	var screen: EncounterScreen = scene as EncounterScreen
	if _checks and screen != null and _elapsed > 3.0 and Engine.get_process_frames() % 20 == 0:
		screen.pass_priority()
	if _opens_settings and screen != null and _elapsed > _after - 1.5:
		_opens_settings = false
		screen.set_paused(true)
		screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	if _shot == "":
		return
	_elapsed += delta
	if _elapsed >= _after:
		if _checks:
			print("CHECK: %d of %d frames drew a button without its frame." % [_unframed_frames, _frames_drawn])
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()


## Just before a frame is drawn: counts it, and whether any framed button has lost its frame.
func _before_draw() -> void:
	if not _checks or not _is_on or not is_inside_tree() or get_tree().current_scene == null:
		return
	_frames_drawn += 1
	if _has_lost_frame(get_tree().current_scene):
		_unframed_frames += 1


func _has_lost_frame(node: Node) -> bool:
	var button: Button = node as Button
	if button != null and button.has_meta(FRAMED_AS) and button.get_meta(FRAMED_AS) != button.get_theme_stylebox("normal"):
		return true
	for child: Node in node.get_children():
		if _has_lost_frame(child):
			return true
	return false


## Frames, or unframes, every plain button under [param node] that is on the Encounter Screen.
func _visit(node: Node, is_in_encounter: bool) -> void:
	var inside: bool = is_in_encounter or node is EncounterScreen
	var button: Button = node as Button
	if button != null and inside and button.get_class() == "Button":
		if _advances and button.is_visible_in_tree() and not button.disabled \
				and (button.text == "Play first" or button.text.begins_with("Keep")) and _elapsed > 1.0:
			button.pressed.emit()
		elif _is_on:
			_frame(button)
		else:
			_unframe(button)
	for child: Node in node.get_children():
		_visit(child, inside)


## Gives [param button] the steel frame in its own color, keeping its text colors. A button
## that already has one (the Info Panel's, the Pass Button), has no fill to read, or is too
## short is left alone. A button the game styles anew is framed again.
func _frame(button: Button) -> void:
	if button.has_meta(HoverEase.OWN_META) or button.size.y < SHORTEST:
		return
	var normal: StyleBox = button.get_theme_stylebox("normal")
	if button.has_meta(FRAMED_AS) and button.get_meta(FRAMED_AS) == normal:
		return
	var color: Variant = _color_of(normal)
	if color == null:
		return
	var originals: Dictionary[String, StyleBox] = {}
	for state: String in STATES:
		originals[state] = button.get_theme_stylebox(state) if button.has_theme_stylebox_override(state) else null
	button.set_meta(ORIGINALS, originals)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var height: int = int(button.size.y)
	for state: String in STATES:
		button.add_theme_stylebox_override(state, SteelFrame.plate(color as Color, state, height))
	button.set_meta(FRAMED_AS, button.get_theme_stylebox("normal"))
	# So does its Glow, if it has one.
	var glowing: Array[Color] = BorderEffects.glow_colors(button)
	if glowing.size() == 1:
		BorderEffects.remove_glow(button)
		BorderEffects.add_glow(button, button.size, glowing[0])
	# The Pause Menu's gold ring round the Game Speed in use takes the new frame's shape.
	var ring: Panel = button.get_node_or_null(PauseMenu.RING) as Panel
	if ring != null:
		ring.add_theme_stylebox_override("panel",
			DitherShading.ring_round(button.get_theme_stylebox("normal") as StyleBoxTexture, PauseMenu.RING_WIDTH, PauseMenu.CHOSEN))


func _unframe(button: Button) -> void:
	if not button.has_meta(ORIGINALS):
		return
	var originals: Dictionary = button.get_meta(ORIGINALS)
	for state: String in STATES:
		if originals[state] == null:
			button.remove_theme_stylebox_override(state)
		else:
			button.add_theme_stylebox_override(state, originals[state])
	button.remove_meta(ORIGINALS)
	button.remove_meta(FRAMED_AS)


## The fill a style was painted in, as near as it can be read back: a flat style's own
## color, or the middle of a painted plate's shading. Null for a style with no fill.
func _color_of(style: StyleBox) -> Variant:
	if style == null:
		return null
	var key: int = style.get_instance_id()
	if _colors.has(key):
		return _colors[key]
	var flat: StyleBoxFlat = style as StyleBoxFlat
	if flat != null:
		return flat.bg_color if flat.bg_color.a >= 0.5 else null
	var painted: StyleBoxTexture = style as StyleBoxTexture
	if painted == null or painted.texture == null:
		return null
	var image: Image = painted.texture.get_image()
	if image == null:
		return null
	var x: int = image.get_width() / 2
	var upper: Color = image.get_pixel(x, int(image.get_height() * 0.25))
	var lower: Color = image.get_pixel(x, int(image.get_height() * 0.6))
	if upper.a < 0.5 or lower.a < 0.5:
		return null
	var color: Color = upper.lerp(lower, 0.5)
	color.a = 1.0
	_colors[key] = color
	return color
