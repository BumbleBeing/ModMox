extends Control
## PROTOTYPE, to be thrown away: the Menu Soldier's animations (SoldierAnimations), one button
## for each, and a Sequence button that plays them as the main menu does (SoldierSequence),
## with a stand-in dot for the magic ball, steered by the sequence's hook so that it reaches
## him on the frame he flashes its color.
##
## Run: godot --path . res://ui/menu/soldier_idle_prototype.tscn
## Escape goes back to the main menu.
## Screenshot and quit: add `-- --play=doze --at=6.0 --screenshot=/absolute/path.png`
## (`--play=sequence` for the sequence).

const SCALE: int = 12
const SEQUENCE: String = "sequence"
const DOT: float = 24.0

var _playing: String = ""
var _elapsed: float = 0.0
var _sequence: SoldierSequence
var _soldier: TextureRect
var _state: Label
var _dot: ColorRect
var _dot_from: Vector2 = Vector2.ZERO
var _dot_seconds: float = 1.0
var _textures: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	_build()
	_show()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var shot: String = ""
	for argument: String in arguments:
		if argument.begins_with("--play="):
			_play(argument.trim_prefix("--play="))
		elif argument.begins_with("--at="):
			_step(argument.trim_prefix("--at=").to_float())
		elif argument.begins_with("--screenshot="):
			shot = argument.trim_prefix("--screenshot=")
	if shot != "":
		set_process(false)
		await RenderingServer.frame_post_draw
		_show()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _process(delta: float) -> void:
	if _playing != "":
		_step(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		SceneFade.change_scene(get_tree(), "res://ui/menu/main_menu.tscn")


func _step(seconds: float) -> void:
	if _playing == SEQUENCE:
		_sequence.advance(seconds)
	else:
		_elapsed += seconds
		if _elapsed >= SoldierAnimations.SECONDS:
			_playing = ""
			_elapsed = 0.0
	_show()


func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.27, 0.29, 0.36)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 32)
	add_child(column)

	_soldier = TextureRect.new()
	_soldier.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_soldier.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_soldier.custom_minimum_size = Vector2.ONE * MenuSoldier.SPRITE_SIZE * SCALE
	_soldier.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_soldier)

	_state = Label.new()
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_state)

	var row: GridContainer = GridContainer.new()
	row.columns = 9
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	column.add_child(row)
	for animation: String in [SEQUENCE] + SoldierAnimations.TRANSITIONS.keys() + SoldierAnimations.EFFECTS.keys():
		var button: Button = Button.new()
		button.text = animation.capitalize()
		button.custom_minimum_size = Vector2(180, 56)
		button.pressed.connect(_play.bind(animation))
		row.add_child(button)

	_dot = ColorRect.new()
	_dot.size = Vector2.ONE * DOT
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	add_child(_dot)


func _play(animation: String) -> void:
	_playing = animation
	_elapsed = 0.0
	_dot.visible = animation == SEQUENCE
	if animation == SEQUENCE:
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.randomize()
		_sequence = SoldierSequence.new(random)
		_sequence.next_effect_changed.connect(func(_effect: String) -> void: _launch_dot())
		_launch_dot()
	_show()


## Sends the stand-in ball off again from a corner, to reach the soldier as he flashes.
func _launch_dot() -> void:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x - DOT, 0), Vector2(size.x - DOT, size.y - DOT), Vector2(0, size.y - DOT)]
	_dot_from = corners.pick_random()
	_dot_seconds = _sequence.seconds_until_flash()
	_dot.color = _sequence.next_color()


func _show() -> void:
	var frame: String = SoldierAnimations.NEUTRAL
	if _playing == SEQUENCE:
		frame = _sequence.frame()
	elif _playing != "":
		frame = SoldierAnimations.frame_at(_playing, _elapsed)
	if not _textures.has(frame):
		_textures[frame] = load(SoldierAnimations.SPRITES % frame) as Texture2D
	_soldier.texture = _textures[frame]
	if _playing == SEQUENCE:
		var target: Vector2 = _soldier.get_global_rect().get_center() - Vector2.ONE * DOT / 2
		var gone: float = 1.0 - _sequence.seconds_until_flash() / _dot_seconds
		_dot.position = _dot_from.lerp(target, clampf(gone, 0.0, 1.0))
		_state.text = "Sequence  ·  %s  ·  next effect %s flashes in %.1f s  ·  soldier_%s" % [
				_sequence.animation().capitalize(), _sequence.next_effect().capitalize(),
				_sequence.seconds_until_flash(), frame]
	elif _playing == "":
		_state.text = "Standing still  ·  soldier_%s" % frame
	else:
		_state.text = "%s  ·  %.1f of %.0f s  ·  soldier_%s" % [
				_playing.capitalize(), _elapsed, SoldierAnimations.SECONDS, frame]
