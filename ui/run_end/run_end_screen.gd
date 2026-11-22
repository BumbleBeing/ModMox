class_name RunEndScreen
extends Control
## Run Won and Run Lost (game glossary; milestone 19, signed off as step 2 of
## prototypes/run_ends): the screens a run ends on, full screens on the slate. They call a
## run a trial, so their titles read "Trial won" and "Trial lost".
##
## Run Won: "Trial won", the five Stages in Tier order, each its Boss's disc with the
## Stage's name under it, then the gold held and the Hearts left, each on a plate drawn as
## the inverse of the button under it, and Continue, which opens the Credits.
## Run Lost: "Trial lost", the Villain that took the last Heart (a Boss in its disc at the
## Stage Intro's size, any other in the Deckbox's rounded Portrait frame), its name, the
## Stage and Tier where the run fell, "Stages beaten" over the beaten Stages' discs (both
## left out at Tier 1), and Main Menu.
##
## Each Stage's disc is twice the Stage Map's, filled with its Stage's ground color and
## ringed with a jewel in that hue, and still; only Run Lost's Boss, not beaten, breathes.
## The screen comes in as RunEndReveal says, at the Game Speed; a click ends it at once, and
## the button takes no clicks until it has come in.
##
## Opened on its own (the main menu's --run-won or --run-lost) it shows a debug run's end:
## --run-seed=N and --stage=red as for the Stage Map, and for Run Lost --tier=N, where the
## Boss takes the last Heart; --screenshot=/absolute/path.png saves a picture and quits.

const WON_FLAG: String = "--run-won"
const LOST_FLAG: String = "--run-lost"
const GROUND: Color = StageIntro.GROUND
const TEXT: Color = StageIntro.TEXT
const MUTED: Color = StageIntro.MUTED
const TRIAL_WON: String = "Trial won"
const TRIAL_LOST: String = "Trial lost"
const STAGES_BEATEN: String = "Stages beaten"
const CONTINUE: String = "Continue"
const MAIN_MENU: String = "Main Menu"
## Each Stage's disc: twice the Stage Map's, in a column STAGE_WIDTH wide.
const DISC_RADIUS: float = StageMapLayout.BOSS_RADIUS * 2.0
const DISC_ROOM: Vector2 = Vector2(320, 260)
const STAGE_WIDTH: float = 320.0
## A Villain that is not a Boss, in the Deckbox's rounded Portrait frame at six screen pixels
## to each of its own.
const PORTRAIT_SIZE: int = 192
const FRAME_FILL: Color = Color("#1c1d20")
const FRAME_EDGE: Color = Color("#575a60")
## The gold's and the Hearts' plates: the button's frame turned inside out.
const PLATE_WIDTH: int = 320
const PLATE_HEIGHT: int = 80
const PLATE_SIDE: int = 24
const PLATE_GAP: int = 24
const INK: Color = Color8(32, 34, 42)
const ICONS: String = "res://ui/sprites/run_bar/%s.png"
const ICON_SCALE: int = 3
const BUTTON_HEIGHT: int = 56
const BUTTON_WIDTH: int = 220
const SHADOW: Color = Color(0, 0, 0, 0.55)
## The stand-in a placeholder Stage's disc is filled with, having no ground color of its own:
## a muted shade of its Magic color.
const PLACEHOLDER_GROUNDS: Dictionary[MmCardTypes.CardColor, Color] = {
	MmCardTypes.CardColor.WHITE: Color8(222, 208, 174), MmCardTypes.CardColor.BLUE: Color8(92, 118, 160),
	MmCardTypes.CardColor.BLACK: Color8(82, 72, 94), MmCardTypes.CardColor.RED: Color8(170, 92, 82),
	MmCardTypes.CardColor.GREEN: Color8(98, 140, 96),
}

## Whether this is Run Won; Run Lost otherwise. Set in each screen's scene.
@export var is_won: bool = true

## Whether the screen reads the run from RunFlow when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)
## Whether the screen comes in over time. Off in a screen a test makes, and for a picture,
## which show everything at once.
var is_paced: bool = false
var game_speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL

## Whether a run's end has been left, so the menu's --run-won or --run-lost does not open it
## again.
static var has_left: bool = false

var _run: Run
var _time: float = 0.0
var _length: float = 0.0
## Each part's holder, in the order they come in, the heading of Run Lost's beaten Stages
## included; each holds its part's index as "part" metadata.
var _holders: Array[Control] = []
var _part_count: int = 0
var _title: Label
var _run_seed: Label = null
var _title_holder: Control
var _button: Button
var _button_frame: Control
var _gold: Label = null
var _gold_part: int = 0
var _hearts: Array[TextureRect] = []
var _discs: Array[RunEndDisc] = []
var _villain_disc: RunEndDisc = null
var _villain_frame: PanelContainer = null
var _texts: Array[Label] = []
var _plates: Array[PanelContainer] = []


func _ready() -> void:
	if not starts_itself:
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var picture: String = EncounterScreen.screenshot_path(arguments)
	is_paced = picture == ""
	game_speed = GameSettings.load_from(GameSettings.PATH).game_speed
	if RunFlow.run == null:
		RunFlow.start(debug_run_from(arguments, is_won))
	begin(RunFlow.run)
	if picture != "":
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## A debug run at its end, as the command line asks: --run-seed=N and --stage=red as for the
## Stage Map. Won, it has beaten all five Bosses; lost, the Boss of --tier=N (1 unless
## given) took its last Heart.
static func debug_run_from(arguments: PackedStringArray, won: bool) -> Run:
	var run: Run = StageMapScreen.debug_run_from(arguments)
	if won:
		while not run.is_won():
			if run.is_stage_beaten():
				run.enter_next_stage()
			_walk_to_the_boss(run)
			run.record_encounter(true)
		return run
	_walk_to_the_boss(run)
	run.hearts = 1
	run.record_encounter(false)
	return run


static func _walk_to_the_boss(run: Run) -> void:
	while run.stage_visit.node().kind != StageMap.Kind.BOSS or not run.stage_visit.must_play():
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])


## The color [param stage]'s Boss disc is filled with: its Stage Intro's ground, or for a
## Stage without one, a stand-in in its Magic color.
static func ground_of(stage: StageDefinition) -> Color:
	return stage.intro_color if stage.has_intro_color() else PLACEHOLDER_GROUNDS[stage.color]


## Shows how [param run] ended.
func begin(run: Run) -> void:
	_run = run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var centered: CenterContainer = CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centered)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centered.add_child(column)
	_title = _text(TRIAL_WON if is_won else TRIAL_LOST, 64, TEXT, true)
	_title_holder = _holder_of(_title)
	column.add_child(_title_holder)
	if is_won:
		_build_won(column)
	else:
		_build_lost(column)
	_time = 0.0 if is_paced else _length
	_pose()
	_add_run_seed()


func title() -> String:
	return _title.text


## The Run Seed at the bottom right (milestone 21), or null before begin().
func run_seed_label() -> Label:
	return _run_seed


## The Run Seed, muted, where the main menu shows the version.
func _add_run_seed() -> void:
	_run_seed = Label.new()
	_run_seed.name = "RunSeed"
	_run_seed.text = PauseMenu.RUN_SEED % _run.run_seed
	_run_seed.add_theme_font_size_override("font_size", MainMenu.VERSION_SIZE)
	_run_seed.add_theme_color_override("font_color", CreditsScreen.MUTED)
	_run_seed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_run_seed)
	_run_seed.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MainMenu.VERSION_INSET)


## Everything the screen says, top to bottom, the gold and the button's words left out.
func texts() -> Array[String]:
	var said: Array[String] = []
	for label: Label in _texts:
		said.append(label.text)
	return said


func gold_text() -> String:
	return _gold.text if _gold != null else ""


## Whether each Heart is drawn full, left to right.
func hearts_shown() -> Array[bool]:
	var shown: Array[bool] = []
	for heart: TextureRect in _hearts:
		shown.append(heart.texture.resource_path.ends_with("heart_full.png"))
	return shown


## The plates the gold and the Hearts stand on, in that order.
func plates() -> Array[PanelContainer]:
	return _plates.duplicate()


## The Stages' discs, in Tier order: all five on Run Won, those beaten on Run Lost.
func stage_discs() -> Array[RunEndDisc]:
	return _discs.duplicate()


## Run Lost's Boss that took the last Heart, or null.
func villain_disc() -> RunEndDisc:
	return _villain_disc


## Run Lost's Villain that took the last Heart in its frame, when it was not a Boss.
func villain_frame() -> PanelContainer:
	return _villain_frame


func button() -> Button:
	return _button


func is_revealing() -> bool:
	return _time < _length


## Moves the reveal on by [param delta] seconds at the Game Speed.
func advance(delta: float) -> void:
	if is_revealing():
		_time += delta / GameSpeed.scale_of(game_speed)
		_pose()


## Ends the reveal at once, everything where it comes to rest.
func finish_reveal() -> void:
	_time = _length
	_pose()


func _process(delta: float) -> void:
	if _run != null:
		advance(delta)


## A press anywhere while the screen is coming in ends it.
func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and is_revealing():
		finish_reveal()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)


func _build_won(column: VBoxContainer) -> void:
	column.add_child(_gap(16))
	var row: HBoxContainer = _row()
	column.add_child(row)
	for visit: StageVisit in _run.stages_played():
		row.add_child(_held(_stage_column(visit)))
	column.add_child(_gap(16))
	var tally: HBoxContainer = _row()
	tally.add_theme_constant_override("separation", PLATE_GAP)
	var coin: HBoxContainer = _row()
	coin.add_theme_constant_override("separation", 12)
	coin.add_child(_icon("gold_coin"))
	_gold = Label.new()
	_gold.add_theme_font_override("font", UiText.bold())
	_gold.add_theme_font_size_override("font_size", 40)
	_gold.add_theme_color_override("font_color", INK)
	_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_child(_gold)
	tally.add_child(_plate(coin))
	var hearts: HBoxContainer = _row()
	hearts.add_theme_constant_override("separation", 8)
	for index: int in Run.STARTING_HEARTS:
		var heart: TextureRect = _icon("heart_full" if index < _run.hearts else "heart_empty")
		_hearts.append(heart)
		hearts.add_child(heart)
	tally.add_child(_plate(hearts))
	_gold_part = _part_count
	column.add_child(_held(tally))
	column.add_child(_gap(24))
	_button_frame = _make_button(CONTINUE, func() -> void:
		has_left = true
		navigate.call(Screens.scene(RunFlow.finish_run_won())))
	column.add_child(_button_frame)
	_length = RunEndReveal.length(_part_count, true)


func _build_lost(column: VBoxContainer) -> void:
	var who: VBoxContainer = VBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var villain: Villain = _run.fell_to
	var visit: StageVisit = _run.stage_visit
	if villain == visit.boss:
		_villain_disc = RunEndDisc.new(villain.sprite, ground_of(visit.stage), StageIntro.RING_RADIUS,
				Vector2.ONE * (StageIntro.RING_RADIUS * 2.0 + 40.0))
		_villain_disc.portrait_scale = StageIntro.PORTRAIT_SCALE
		_villain_disc.breathe()
		who.add_child(_villain_disc)
	else:
		_villain_frame = _portrait_frame(villain.sprite)
		who.add_child(_villain_frame)
	who.add_child(_text(villain.name, 36, TEXT, true))
	who.add_child(_text("%s, Tier %d" % [visit.stage.name, visit.stage.tier], 28, MUTED, false))
	column.add_child(_held(who))
	var beaten: Array[StageVisit] = _run.stages_beaten()
	if not beaten.is_empty():
		column.add_child(_gap(24))
		var heading: Label = _text(STAGES_BEATEN, 24, MUTED, false)
		var row: HBoxContainer = _row()
		var stages: VBoxContainer = VBoxContainer.new()
		stages.add_theme_constant_override("separation", 16)
		stages.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(stages)
		# The heading comes in with the first disc.
		stages.add_child(_held(heading, true))
		stages.add_child(row)
		for beaten_visit: StageVisit in beaten:
			row.add_child(_held(_stage_column(beaten_visit)))
	column.add_child(_gap(24))
	_button_frame = _make_button(MAIN_MENU, func() -> void:
		has_left = true
		StageMapScreen.has_left = true
		navigate.call(Screens.scene(RunFlow.finish_run_lost())))
	column.add_child(_button_frame)
	_length = RunEndReveal.length(_part_count, false)


## A Stage played: its Boss's disc, still, its name under it.
func _stage_column(visit: StageVisit) -> Control:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.custom_minimum_size = Vector2(STAGE_WIDTH, 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: RunEndDisc = RunEndDisc.new(visit.boss.sprite, ground_of(visit.stage), DISC_RADIUS, DISC_ROOM)
	_discs.append(disc)
	stack.add_child(disc)
	stack.add_child(_text(visit.stage.name, 24, TEXT, true, STAGE_WIDTH))
	return stack


## [param item] in a holder that keeps its room while it comes in as the reveal's next part,
## or with the next part when it [param shares_next] (and so is not counted as one).
func _held(item: Control, shares_next: bool = false) -> Control:
	var holder: Control = _holder_of(item)
	holder.set_meta("part", _part_count)
	if not shares_next:
		_part_count += 1
	_holders.append(holder)
	return holder


func _holder_of(item: Control) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(item)
	holder.custom_minimum_size = item.get_combined_minimum_size()
	return holder


func _pose() -> void:
	_place(_title_holder, RunEndReveal.title(_time))
	for holder: Control in _holders:
		_place(holder, RunEndReveal.part(_time, holder.get_meta("part")))
	if _gold != null:
		_gold.text = str(RunEndReveal.gold_shown(_time, _gold_part, _run.gold))
	var shown: float = RunEndReveal.button(_time, _part_count, is_won)
	_button_frame.modulate.a = shown
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_revealing() else Control.MOUSE_FILTER_STOP


## Puts the part in [param holder] [param pose].x below its place, [param pose].y opaque.
func _place(holder: Control, pose: Vector2) -> void:
	var item: Control = holder.get_child(0) as Control
	holder.custom_minimum_size = item.get_combined_minimum_size()
	item.size = holder.size
	item.position = Vector2(0.0, pose.x)
	item.modulate.a = pose.y


## [param content] on a plate drawn as the inverse of the button under it: the button's
## stepped pixel frame and lip, its face silver in Dither Shading inside a ring of the
## button's dark gray, with the button's shadow.
func _plate(content: Control) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PLATE_WIDTH, PLATE_HEIGHT)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", SteelFrame.plate(SteelFrame.STEEL, "normal", PLATE_HEIGHT, false,
			ButtonShading.DISABLED, PLATE_SIDE, true, 0, WindowLook.BUTTON))
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(content)
	_plates.append(panel)
	return _shadowed(panel, WindowLook.BUTTON_RADIUS + 1)


func _portrait_frame(sprite: Texture2D) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = FRAME_FILL
	back.border_color = FRAME_EDGE
	back.set_border_width_all(4)
	back.set_corner_radius_all(16)
	back.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", back)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = sprite
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	return frame


func _make_button(text: String, pressed: Callable) -> Control:
	_button = Button.new()
	_button.text = text
	_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_button.add_theme_font_override("font", UiText.bold())
	_button.add_theme_font_size_override("font_size", 26)
	SteelFrame.frame_roomy(_button, WindowLook.BUTTON, BUTTON_HEIGHT)
	_button.pressed.connect(pressed)
	var frame: Control = _shadowed(_button, WindowLook.BUTTON_RADIUS + 1)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return frame


## [param item] in a frame that draws only a drop shadow, rounded by [param radius].
func _shadowed(item: Control, radius: int) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(radius)
	style.shadow_color = SHADOW
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(item)
	return frame


func _icon(icon_name: String) -> TextureRect:
	var made: TextureRect = TextureRect.new()
	made.texture = load(ICONS % icon_name) as Texture2D
	made.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	made.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	made.custom_minimum_size = made.texture.get_size() * ICON_SCALE
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _gap(height: int) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## A centered label; wrapped within [param wraps_at] pixels when given.
func _text(text: String, font_size: int, color: Color, is_bold: bool, wraps_at: float = 0.0) -> Label:
	var made: Label = Label.new()
	if wraps_at > 0.0:
		made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		made.custom_minimum_size = Vector2(wraps_at, 0)
	made.text = text
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	_texts.append(made)
	return made
