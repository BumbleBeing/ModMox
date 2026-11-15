class_name SceneFade
extends CanvasLayer
## Scene Fade, how the game goes from one scene to another: the screen fades to black, the
## scene is swapped behind it, and it fades back in, SECONDS in all, half each way. It is
## put on the window itself, over everything, so the swap does not take it away; while it
## plays it takes every click and key, so nothing is pressed twice on the way out. A screen
## opens another with change_scene(); tests hand play() a swap of their own.

signal swapped
signal finished

const SECONDS: float = 0.5
## Above every other layer the game draws.
const LAYER: int = 128
## The most of a fade one frame may take, in seconds.
const LONGEST_STEP: float = 1.0 / 30.0
## After the swap the screen stays solid black until the new scene has drawn this many
## frames in a row, each in no more than SMOOTH_FRAME seconds, so that nothing half built
## shows through, but never for more than LONGEST_HOLD seconds.
const SMOOTH_FRAMES: int = 2
## Frames that go by solid black before the swap. A slow swap leaves the last frame drawn
## on the screen while it works, so that frame must be all black (two, for a frame the GPU
## is still presenting).
const BLACK_FRAMES: int = 2
const SMOOTH_FRAME: float = 1.0 / 20.0
const LONGEST_HOLD: float = 1.0

static var _playing: SceneFade = null

var _curtain: ColorRect = null


## Fades out, opens [param scene] and fades back in. While one is playing, another is
## dropped and the one playing is handed back.
static func change_scene(tree: SceneTree, scene: String) -> SceneFade:
	return play(tree, func() -> void:
		tree.change_scene_to_file(scene)
		await tree.scene_changed)


## Fades out, calls [param swap] (awaited, if it waits) and fades back in.
static func play(tree: SceneTree, swap: Callable) -> SceneFade:
	var playing: SceneFade = playing_in(tree)
	if playing != null:
		return playing
	var made: SceneFade = SceneFade.new()
	_playing = made
	tree.root.add_child(made)
	made._run(swap)
	return made


## The fade playing in [param tree], or null.
static func playing_in(tree: SceneTree) -> SceneFade:
	if not is_instance_valid(_playing) or _playing.is_queued_for_deletion() or _playing.get_tree() != tree:
		return null
	return _playing


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)


## The black drawn over the screen.
func curtain() -> ColorRect:
	return _curtain


func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _run(swap: Callable) -> void:
	await _fade_to(1.0)
	for frame: int in BLACK_FRAMES:
		await get_tree().process_frame
	await swap.call()
	# The new scene was added after this, so this goes back on top to keep taking input first.
	if is_inside_tree():
		get_parent().move_child(self, -1)
	_curtain.color.a = 1.0
	swapped.emit()
	await _hold_black()
	await _fade_to(0.0)
	finished.emit()
	queue_free()


## Eases the black to [param alpha] over half of SECONDS. It is stepped by hand rather than
## tweened so that a frame that hitches (as the one a scene change is asked for often does)
## counts for no more than LONGEST_STEP, and the fade is still seen whole.
func _fade_to(alpha: float) -> void:
	var from: float = _curtain.color.a
	var half: float = SECONDS / 2.0
	var gone: float = 0.0
	var last: int = Time.get_ticks_usec()
	while gone < half:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		gone += minf((now - last) / 1_000_000.0, LONGEST_STEP)
		last = now
		_curtain.color.a = lerpf(from, alpha, minf(gone / half, 1.0))


## Waits, the screen solid black, until the new scene draws smoothly (see SMOOTH_FRAMES).
func _hold_black() -> void:
	var began: int = Time.get_ticks_usec()
	var last: int = began
	var smooth: int = 0
	while smooth < SMOOTH_FRAMES and (last - began) / 1_000_000.0 < LONGEST_HOLD:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		smooth = smooth + 1 if (now - last) / 1_000_000.0 <= SMOOTH_FRAME else 0
		last = now
