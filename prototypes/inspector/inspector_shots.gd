extends SceneTree
## THROWAWAY: plays the 13h prototype past the pregame, hovers and pins a card, and saves
## pictures. Run windowed:
## godot --path . -s res://prototypes/inspector/inspector_shots.gd -- --out=/absolute/folder

const ProtoScreen := preload("res://prototypes/inspector/inspector_screen.gd")

var _screen: ProtoScreen
var _out: String = ""
var _frames: int = 0
var _stage: int = 0
var _pregame: int = 0
var _stage_frames: int = 0


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
	var request: EncounterRequest = EncounterRequest.new()
	request.encounter_seed = 7
	request.has_sample_emblems = true
	_screen = ProtoScreen.new()
	_screen.starts_itself = false
	_screen.proto_request = request
	_screen.pretend_cursor = Vector2(-10, -10)
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_screen)
	current_scene = _screen


func _process(_delta: float) -> bool:
	_frames += 1
	_stage_frames += 1
	var overlay: OpeningHandOverlay = _screen.opening_overlay()
	if overlay.is_open() and not overlay.is_closing():
		if _frames % 45 == 0 and not overlay.button_texts().is_empty():
			var text: String = overlay.button_texts()[0]
			if text.begins_with("Keep") and _pregame < 3:
				# Hover a card of the opening hand, then pin another, before keeping.
				_pregame += 1
				var ids: Array[int] = overlay.shown_ids()
				if _pregame == 1:
					_screen.pretend_cursor = overlay.position + overlay.center_of(ids[2])
				elif _pregame == 2:
					_screen.pretend_right_click(overlay.position + overlay.center_of(ids[5]))
					_screen.pretend_cursor = Vector2(-10, -10)
					print("pinned ", _screen.pinned())
				_save.call_deferred("pregame_%d" % _pregame)
				return false
			print("pressing ", text)
			overlay.button(text).pressed.emit()
		return _frames > 3000
	if _screen._hand_faces.is_empty() or _stage_frames < 150:
		return _frames > 3000
	_stage_frames = 100
	var face: CardFace = _screen._hand_faces[_stage % _screen._hand_faces.size()]
	var at: Vector2 = face.get_global_transform() * (face.size * Vector2(0.5, 0.3))
	match _stage:
		0, 1, 2:
			_screen.pretend_cursor = at
			_save.call_deferred("hover_%d" % _stage)
		3:
			_screen.pretend_right_click(at)
			_screen.pretend_cursor = Vector2(900, 400)
			_save.call_deferred("pinned")
		4:
			# The sections no opening hand can show: a made-up State List on Serra Angel.
			var definition: MmCardDefinition = load("res://content/cards/alpha/serra_angel.tres") as MmCardDefinition
			var look: CardLook = CardLook.of_characteristics(MmCharacteristics.printed(definition), "serra_angel")
			var states: Array[Array] = [["Summoning sick", "It can't attack or tap for an ability until its controller's next turn."],
				["Giant Growth", "It gets +3/+3 until end of turn."], ["Damage", "2 damage is marked on it until end of turn."],
				["Samite Healer", "Prevent the next 1 damage that would be dealt to Serra Angel this turn."]]
			_screen.set_process(false)
			_screen._inspector.show_card(999, look, look, Color("#e89a2b"), states, true)
			_save.call_deferred("sections")
		_:
			return _stage_frames > 140
	_stage += 1
	return false


func _save(name: String) -> void:
	for frame: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)
