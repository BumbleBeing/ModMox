class_name SpoilsScreen
extends Control
## The Spoils screen (game glossary; milestone 18, signed off as prototypes/spoils_screen):
## what the win just recorded paid, already in the run (ADR 0039). On the Stage Intro's
## ground, one window: "Found Items" on a dithered gray bar, the gold on parchment, a Card
## Face for each card glowing its Rarity, and Continue, which opens the Stage Map. It is
## revealed at the Game Speed (SpoilsReveal), and a click during the reveal ends it.
## Later (milestone 24): an Item on parchment beside the gold.
##
## --spoils opens it on a debug run's win (--run-seed=N, --stage=red, --rank=lesser, elite
## or boss), honoring --screenshot=/absolute/path.png.

const FLAG: String = "--spoils"
## What --rank= may name.
const RANKS: Dictionary[String, StageMap.Kind] = {
	"lesser": StageMap.Kind.LESSER, "elite": StageMap.Kind.ELITE, "boss": StageMap.Kind.BOSS,
}
const HEADING: String = "Found Items"
const CONTINUE: String = "Continue"
## The window: a warm dark gray, the "Run won" notice's and the Run Bar's too.
const WINDOW_COLOR: Color = Color("#4b3f3f")
const WINDOW_EDGE: Color = Color("#14171c")
const WINDOW_RADIUS: int = 24
const WINDOW_MARGIN: int = 24
const ROW_GAP: int = 24
const TEXT: Color = Color8(228, 231, 238)
## The "Found Items" bar.
const BAR_COLOR: Color = Color("#656a75")
const BAR_EDGE: Color = Color("#1b1e23")
const BAR_HEIGHT: int = 64
const BAR_RADIUS: int = 14
## Continue: the bar's gray darkened a fifth.
const BUTTON_FILL: Color = Color("#51555e")
const BUTTON_HEIGHT: int = 56
const BUTTON_RADIUS: int = 12
## The parchment the gold sits on.
const PAPER: Color = Color("#e9dcbc")
const PAPER_EDGE: Color = Color("#7a6243")
const PAPER_EDGE_WIDTH: int = 2
const PAPER_LIGHTEN: float = 0.08
const PAPER_DARKEN: float = 0.15
const PAPER_RADIUS: int = 14
const PAPER_WIDTH: int = 320
const PAPER_PADDING: Vector2 = Vector2(24, 12)
const INK: Color = Color8(46, 40, 36)
const COIN: String = "res://ui/sprites/run_bar/gold_coin.png"
const COIN_SCALE: int = 3
const CARD_HEIGHT: float = 400.0
const CARD_GAP: int = 24
## Every card casts a shadow straight down, as if lit from above; the bar, the parchment
## and the button cast the same one, dropped less.
const SHADOW: Color = Color(0, 0, 0, 0.55)
const SHADOW_SIZE: int = 12
const CARD_SHADOW_DROP: float = 8.0
const PART_SHADOW_DROP: float = 3.0
## Each card's Rarity glow pulses between these opacities once every PULSE_SECONDS, each
## from a point in the pulse of its own, so no two beat together.
const PULSE_SECONDS: float = 3.2
const PULSE_LOW: float = 0.45
const PULSE_HIGH: float = 1.0
## Most cards a win pays, which the card row is always wide enough for.
const MOST_CARDS: int = 3

## Whether the screen reads the run from RunFlow when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)
## Whether the reveal plays; a screen that is not paced shows everything at once.
var is_paced: bool = false
var game_speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
## Whether a Spoils screen has been left, so the --spoils flag opens it only once.
static var has_left: bool = false

var _run: Run
var _spoils: Spoils
## Seconds into the reveal, at Blazing.
var _reveal_time: float = 0.0
var _lift: Control
var _window: PanelContainer
var _bar_text: Label
var _gold_panel: Control
var _gold_text: Label
var _cards: Array[Control] = []
var _faces: Array[CardFace] = []
var _backs: Array[Control] = []
var _names: Array[String] = []
var _glows: Array[Control] = []
var _phases: Array[float] = []
var _button_frame: Control
var _button: Button
var _time: float = 0.0


func _ready() -> void:
	if not starts_itself:
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var picture: String = EncounterScreen.screenshot_path(arguments)
	is_paced = picture == ""
	game_speed = GameSettings.load_from(GameSettings.PATH).game_speed
	if RunFlow.run == null:
		RunFlow.start(debug_run_from(arguments))
		RunFlow.finish_intro()
	begin(RunFlow.run)
	if picture != "":
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## A debug run won at the Rank the command line names: --run-seed=N and --stage=red as for
## the Stage Map, and --rank=lesser, elite or boss (elite if not given). The Hero walks
## toward a Node of that Rank, winning every encounter on the way, and wins there, or at
## the Boss if no Node of that Rank lies ahead.
static func debug_run_from(arguments: PackedStringArray) -> Run:
	var run: Run = StageMapScreen.debug_run_from(arguments)
	var rank: StageMap.Kind = StageMap.Kind.ELITE
	for argument: String in arguments:
		if argument.begins_with("--rank="):
			rank = RANKS.get(argument.trim_prefix("--rank=").to_lower(), rank)
	var visit: StageVisit = run.stage_visit
	while not visit.is_won:
		if visit.must_play():
			var is_there: bool = visit.node().kind == rank
			run.record_encounter(true)
			if is_there:
				break
			continue
		var choices: Array[int] = visit.choices()
		var next: int = choices[0]
		for id: int in choices:
			if _leads_to(visit.map, id, rank):
				next = id
				break
		run.move_to(next)
	return run


## Whether the Node [param id] is of [param kind] or leads to one that is, onward or
## sideways.
static func _leads_to(map: StageMap, id: int, kind: StageMap.Kind) -> bool:
	var seen: Dictionary[int, bool] = {id: true}
	var waiting: Array[int] = [id]
	while not waiting.is_empty():
		var here: MapNode = map.nodes[waiting.pop_back()]
		if here.kind == kind:
			return true
		var onward: Array[int] = here.forward.duplicate()
		if here.side != -1:
			onward.append(here.side)
		for next: int in onward:
			if not seen.has(next):
				seen[next] = true
				waiting.append(next)
	return false


## Shows what [param run] was last paid, on the ground of the Stage it is walking.
func begin(run: Run) -> void:
	_run = run
	_spoils = run.last_spoils if run.last_spoils != null else Spoils.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(StageIntro.ground_panel(run.stage_visit.stage))
	_lift = Control.new()
	_lift.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lift)
	var centered: CenterContainer = CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lift.add_child(centered)
	_window = PanelContainer.new()
	_window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_window.resized.connect(_shade_window)
	centered.add_child(_window)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	_window.add_child(column)
	column.add_child(_shadowed(_heading_bar(), BAR_RADIUS + 2, PART_SHADOW_DROP))
	var rewards: HBoxContainer = HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", CARD_GAP)
	_gold_panel = _shadowed(_on_paper(_gold_row()), PAPER_RADIUS, PART_SHADOW_DROP)
	rewards.add_child(_gold_panel)
	column.add_child(rewards)
	column.add_child(_card_row())
	_button_frame = _shadowed(_continue_button(), BUTTON_RADIUS + 1, PART_SHADOW_DROP)
	_button_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_button_frame)
	_shade_window()
	_reveal_time = 0.0 if is_paced else SpoilsReveal.length(_spoils.cards.size())
	_pose()


## The text of the bar across the window's top.
func heading() -> String:
	return _bar_text.text


## What the gold count shows now.
func gold_text() -> String:
	return _gold_text.text


func gold_panel() -> Control:
	return _gold_panel


## Later (milestone 24): the Item's panel. None yet.
func item_panel() -> Control:
	return null


func window() -> Control:
	return _window


## The names of the cards shown, left to right.
func card_names() -> Array[String]:
	return _names.duplicate()


func card_faces() -> Array[CardFace]:
	return _faces.duplicate()


func continue_button() -> Button:
	return _button


## The color the ground is shaded in.
func ground_color() -> Color:
	return StageIntro.ground_of(_run.stage_visit.stage)


func is_revealing() -> bool:
	return _reveal_time < SpoilsReveal.length(_spoils.cards.size())


## Moves the reveal on by [param delta] seconds at the Game Speed.
func advance(delta: float) -> void:
	if is_revealing():
		_reveal_time += delta / GameSpeed.scale_of(game_speed)
		_pose()


## Ends the reveal at once, everything where it comes to rest.
func finish_reveal() -> void:
	_reveal_time = SpoilsReveal.length(_spoils.cards.size())
	_pose()


func _process(delta: float) -> void:
	advance(delta)
	_time += delta
	for index: int in _glows.size():
		var wave: float = 0.5 - 0.5 * cos(TAU * (_time / PULSE_SECONDS + _phases[index]))
		_glows[index].modulate.a = lerpf(PULSE_LOW, PULSE_HIGH, wave)


## A click during the reveal ends it, and does nothing else.
func _input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT and is_revealing():
		finish_reveal()
		get_viewport().set_input_as_handled()


## Puts everything where the reveal has got to.
func _pose() -> void:
	var time: float = _reveal_time
	var rising: Vector2 = SpoilsReveal.window(time)
	_lift.position.y = rising.x
	_window.modulate.a = rising.y
	_gold_panel.modulate.a = SpoilsReveal.gold_panel(time)
	_gold_text.text = "+%d" % SpoilsReveal.gold_shown(time, _spoils.gold)
	for index: int in _cards.size():
		var dealt: Vector4 = SpoilsReveal.card(time, index)
		_cards[index].position.y = -dealt.x
		_cards[index].modulate.a = dealt.y
		_cards[index].scale.x = dealt.z
		_faces[index].visible = dealt.w > 0.5
		_backs[index].visible = dealt.w <= 0.5
	_button_frame.modulate.a = SpoilsReveal.button(time, _spoils.cards.size())


func _shade_window() -> void:
	var face: StyleBoxTexture = DitherShading.plate(WINDOW_COLOR.lightened(0.06), WINDOW_COLOR.darkened(0.3),
			WINDOW_EDGE, WINDOW_RADIUS, 2, 0, maxi(int(_window.size.y), WINDOW_RADIUS * 2 + 4))
	face.set_content_margin_all(WINDOW_MARGIN)
	_window.add_theme_stylebox_override("panel", face)


## "Found Items", bold, on a dithered gray bar.
func _heading_bar() -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_theme_stylebox_override("panel", DitherShading.plate(BAR_COLOR.lightened(0.1), BAR_COLOR.darkened(0.25),
			BAR_EDGE, BAR_RADIUS, 2, 0, BAR_HEIGHT))
	_bar_text = _text(HEADING, 32, TEXT)
	bar.add_child(_bar_text)
	return bar


## The coin at three times its size beside "+N".
func _gold_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var coin: TextureRect = TextureRect.new()
	coin.texture = load(COIN) as Texture2D
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = coin.texture.get_size() * COIN_SCALE
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(coin)
	_gold_text = _text("+%d" % _spoils.gold, 40, INK)
	row.add_child(_gold_text)
	return row


## [param content] on parchment, shaded over its own height, in a brown edge.
func _on_paper(content: Control) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PAPER_WIDTH, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade: Callable = func() -> void:
		var made: StyleBoxTexture = DitherShading.plate(PAPER.lightened(PAPER_LIGHTEN), PAPER.darkened(PAPER_DARKEN),
				PAPER_EDGE, PAPER_RADIUS - PAPER_EDGE_WIDTH, PAPER_EDGE_WIDTH, 0,
				maxi(int(panel.size.y), PAPER_RADIUS * 2 + 1))
		made.content_margin_left = PAPER_PADDING.x
		made.content_margin_right = PAPER_PADDING.x
		made.content_margin_top = PAPER_PADDING.y
		made.content_margin_bottom = PAPER_PADDING.y
		panel.add_theme_stylebox_override("panel", made)
	shade.call()
	panel.resized.connect(shade)
	panel.add_child(content)
	return panel


## A Card Face for each card paid, glowing its Rarity, over a card-shaped shadow and under
## its back, to be dealt and flipped. The row is wide enough for three.
func _card_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CARD_GAP)
	row.custom_minimum_size = Vector2(CARD_HEIGHT * CardGeometry.ASPECT * MOST_CARDS + CARD_GAP * (MOST_CARDS - 1),
			CARD_HEIGHT)
	var pulse: RandomNumberGenerator = RandomNumberGenerator.new()
	for run_card: MmRunCard in _spoils.cards:
		var look: CardLook = CardLook.of_definition(run_card.base)
		var face: CardFace = CardFace.new()
		face.setup(look, CARD_HEIGHT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		BorderEffects.add_glow(face, face.size, Inspector.glow_of(run_card.base.rarity))
		_glows.append(face.get_node(BorderEffects.GLOW) as Control)
		_phases.append(pulse.randf())
		_names.append(run_card.base.name)
		var holder: Control = Control.new()
		holder.custom_minimum_size = face.size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card: Control = Control.new()
		card.size = face.size
		card.pivot_offset = face.size / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(card)
		card.add_child(_card_shadow(face.size))
		card.add_child(face)
		var back: Panel = CardBack.make(face.size.y)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(back)
		_cards.append(card)
		_faces.append(face)
		_backs.append(back)
		row.add_child(holder)
	return row


func _card_shadow(card_size: Vector2) -> Panel:
	var shadow: Panel = Panel.new()
	shadow.size = card_size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.set_corner_radius_all(int(card_size.x * CardGeometry.CORNER))
	style.shadow_color = SHADOW
	style.shadow_size = SHADOW_SIZE
	style.shadow_offset = Vector2(0, CARD_SHADOW_DROP)
	shadow.add_theme_stylebox_override("panel", style)
	return shadow


func _continue_button() -> Button:
	_button = Button.new()
	_button.text = CONTINUE
	_button.custom_minimum_size = Vector2(220, BUTTON_HEIGHT)
	_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_button.add_theme_font_override("font", UiText.bold())
	_button.add_theme_font_size_override("font_size", 26)
	SteelFrame.frame_roomy(_button, BUTTON_FILL, BUTTON_HEIGHT)
	_button.pressed.connect(func() -> void:
		has_left = true
		navigate.call(Screens.scene(RunFlow.finish_spoils())))
	return _button


## [param item] in a frame that draws only a drop shadow, from a box rounded by
## [param radius], dropped [param drop] pixels.
func _shadowed(item: Control, radius: int, drop: float) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_horizontal = item.size_flags_horizontal
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(radius)
	style.shadow_color = SHADOW
	style.shadow_size = SHADOW_SIZE
	style.shadow_offset = Vector2(0, drop)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(item)
	return frame


func _text(text: String, font_size: int, color: Color) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.add_theme_font_override("font", UiText.bold())
	return made
