class_name MainMenu
extends Control
## The main menu: a plain list of where the game can go, in the Spoils screen's dithered
## window on the slate ground, with its buttons. A request on the command line
## (--hero=, --villain= or --seed=) skips it and opens the Encounter Screen (A246), unless
## it names something that does not exist, which the menu then says. --deckbuilder opens
## the deckbuilder on a made-up run, for pictures. --stage-map opens the Stage Map of a
## debug run (--run-seed=N, --stage=red), for pictures, and --spoils the Spoils screen of
## a win in one (--rank=lesser, elite or boss). Start Run (debug) begins a debug
## run at the Deckbox, in Kitty Keep, the Stage being built first (milestones 16 and 17).
## The Menu Soldier stands on top of the window, playing his animations, casting the Soldier
## Shadow on it; the two are centered on the screen together. The Wisp floats about them,
## bringing him his effects, and casts the Wisp Light on the window when it comes near. As
## he takes each effect on, its Effect Callout floats off from him.

const START_FORM: String = "res://ui/encounter/start_form.tscn"
const ENCOUNTER: String = "res://ui/encounter/encounter_screen.tscn"
const CARD_GALLERY: String = "res://tools/card_gallery/card_gallery.tscn"
## The Stage a debug run begins in.
const DEMO_STAGE: String = "res://content/stages/kitty_keep.tres"
const DECKBUILDER: String = Screens.DECKBUILDER
const DECKBUILDER_FLAG: String = "--deckbuilder"
## The smallest the window may be made: four times a Backdrop's picture, so that its pixels
## stay even there as they do at 1920 x 1080 (ADR 0035).
const MIN_WINDOW: Vector2i = Vector2i(1280, 720)
const REFUSAL_COLOR: Color = Color("#e08a7a")
## The gap between the menu's rows: the Spoils screen's.
const BUTTON_GAP: int = SpoilsScreen.ROW_GAP
## How wide the window's edge is, in pixels.
const WINDOW_EDGE_WIDTH: int = 2

## How the menu opens another scene, and how it quits. Tests replace both. A scene asked
## for on the command line opens at once, so that a --screenshot is not taken mid-fade; one
## chosen from the menu fades in.
var navigate: Callable = func(scene: String) -> void:
	if _is_skipping:
		get_tree().change_scene_to_file(scene)
	else:
		SceneFade.change_scene(get_tree(), scene)
var quit: Callable = func() -> void: get_tree().quit()
## The command line, as given after "--". Tests replace it.
var arguments: PackedStringArray = OS.get_cmdline_user_args()

var _buttons: Dictionary[String, Button] = {}
var _window: PanelContainer
var _soldier: MenuSoldier
## Over everything, so that the Soldier Shadow lies on the window.
var _shadow_layer: Control
## Over the shadow's, so that the Wisp Light lies over the shadow where the two meet.
var _light_layer: Control
var _callouts: MenuCallouts
var _wisp: MenuWisp
var _refusal: String = ""
## Whether the menu is going straight to a scene the command line asked for.
var _is_skipping: bool = false


func _ready() -> void:
	# Here because the game always opens on this scene, whatever it goes on to.
	get_window().min_size = MIN_WINDOW
	# Every button of every screen lightens under the cursor with an ease (game ADR 0066).
	HoverEase.watch(get_tree())
	# Only until the deckbuilder is left, so that its Exit lands here and not back in it.
	if arguments.has(DECKBUILDER_FLAG) and not DeckbuilderScreen.has_left:
		_is_skipping = true
		navigate.call_deferred(DECKBUILDER)
		return
	if arguments.has(StageMapScreen.FLAG) and not StageMapScreen.has_left:
		_is_skipping = true
		RunFlow.start(StageMapScreen.debug_run_from(arguments))
		navigate.call_deferred(Screens.scene(RunFlow.finish_intro()))
		return
	if arguments.has(SpoilsScreen.FLAG) and not SpoilsScreen.has_left:
		_is_skipping = true
		RunFlow.start(SpoilsScreen.debug_run_from(arguments))
		RunFlow.finish_intro()
		navigate.call_deferred(Screens.SPOILS)
		return
	var asked_for: EncounterRequest = EncounterRequest.from_arguments(arguments)
	if asked_for != null:
		_refusal = asked_for.validate()
		if _refusal == "":
			EncounterScreen.request = asked_for
			_is_skipping = true
			navigate.call_deferred(ENCOUNTER)
			return
		# A deck, difficulty or backdrop that does not exist: the menu opens and says so.
		push_error(_refusal)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background: ColorRect = ColorRect.new()
	background.color = StageIntro.GROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# The soldier over the window, centered as one. His picture's bottom row is empty, so it
	# overlaps the window's top and his soles rest on it.
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", -MenuSoldier.SCALE)
	center.add_child(stack)
	_soldier = MenuSoldier.new()
	_soldier.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(_soldier)
	var window: PanelContainer = PanelContainer.new()
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.resized.connect(func() -> void: _shade_window(window))
	stack.add_child(window)
	_window = window
	_shadow_layer = Control.new()
	_shadow_layer.name = "SoldierShadow"
	_shadow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow_layer.draw.connect(_draw_shadow)
	add_child(_shadow_layer)
	_soldier.shadow_changed.connect(_shadow_layer.queue_redraw)
	center.sort_children.connect(_shadow_layer.queue_redraw)
	_light_layer = Control.new()
	_light_layer.name = "WispLight"
	_light_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_light_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_layer.draw.connect(_draw_light)
	add_child(_light_layer)
	_callouts = MenuCallouts.new(_soldier)
	_callouts.name = "EffectCallouts"
	add_child(_callouts)
	# Last, so that it floats in front of him and his callouts.
	_wisp = MenuWisp.new(_soldier, window)
	_wisp.name = "Wisp"
	add_child(_wisp)
	_wisp.moved.connect(_light_layer.queue_redraw)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", BUTTON_GAP)
	window.add_child(column)
	_shade_window(window)
	var title: Label = Label.new()
	title.text = "ModMox"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", CardFonts.title())
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", SpoilsScreen.TEXT)
	column.add_child(title)
	if _refusal != "":
		var reason: Label = Label.new()
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.text = _refusal
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.add_theme_font_size_override("font_size", 20 + UiText.RAISE)
		reason.add_theme_color_override("font_color", REFUSAL_COLOR)
		column.add_child(reason)
	_add(column, "Start Encounter", func() -> void: navigate.call(START_FORM))
	_add(column, "Start Run (debug)", func() -> void: navigate.call(Screens.scene(RunFlow.start(Run.debug(randi(), load(DEMO_STAGE) as StageDefinition)))))
	_add(column, "Card Gallery", func() -> void: navigate.call(CARD_GALLERY))
	_add(column, "Quit Game", func() -> void: quit.call())


## Why the request on the command line could not be played, or "" if there was none or it
## could. The menu shows it under its title.
func refusal() -> String:
	return _refusal


## The Menu Soldier, or null when the menu went straight to another scene. What brings him
## his effects asks his sequence what comes next.
func soldier() -> MenuSoldier:
	return _soldier


## The window the menu's buttons sit in, or null when the menu went straight to another scene.
func window() -> PanelContainer:
	return _window


## The Wisp, or null when the menu went straight to another scene.
func wisp() -> MenuWisp:
	return _wisp


## The Menu Soldier's Effect Callouts, or null when the menu went straight to another scene.
func callouts() -> MenuCallouts:
	return _callouts


## The Wisp Light's blocks as they are drawn now, on the screen: none while the Wisp is far
## from the window.
func light_blocks() -> Array[Rect2]:
	if not _wisp.flight().is_flying():
		return []
	return WispLight.blocks(_wisp.drawn_rect(), _window.get_global_rect(), SpoilsScreen.WINDOW_RADIUS + WINDOW_EDGE_WIDTH)


## The Soldier Shadow's blocks as they are drawn now, on the screen, faint or strong.
func shadow_blocks() -> Array[Rect2]:
	return _shadow_blocks_under(_soldier.shadow().columns())


## The button labeled [param text], or null.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func _add(column: VBoxContainer, text: String, on_press: Callable) -> void:
	var made: Button = Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(0, SpoilsScreen.BUTTON_HEIGHT)
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.add_theme_font_override("font", UiText.bold())
	made.add_theme_font_size_override("font_size", 24)
	made.add_theme_color_override("font_color", SpoilsScreen.TEXT)
	var fill: Color = SpoilsScreen.BUTTON_FILL
	var height: int = SpoilsScreen.BUTTON_HEIGHT
	SteelFrame.frame_roomy(made, fill, height)
	made.pressed.connect(on_press)
	column.add_child(_shadowed(made))
	_buttons[text] = made


## The shadow's blocks under [param columns] of the soldier's sprite, on the screen.
func _shadow_blocks_under(columns: Array[int]) -> Array[Rect2]:
	var his: Rect2 = _soldier.get_global_rect()
	var window: Rect2 = _window.get_global_rect()
	# The window's dither starts past its rounded corner and edge.
	var grid_left: float = window.position.x + SpoilsScreen.WINDOW_RADIUS + WINDOW_EDGE_WIDTH
	return SoldierShadow.blocks(columns, his.position.x, MenuSoldier.SCALE, grid_left, window.position.y)


func _draw_shadow() -> void:
	var shadow: SoldierShadow = _soldier.shadow()
	for column: int in shadow.columns():
		for block: Rect2 in _shadow_blocks_under([column]):
			var drawn: Rect2 = Rect2(block.position - _shadow_layer.global_position, block.size)
			_shadow_layer.draw_rect(drawn, shadow.color_of(column))


func _draw_light() -> void:
	var color: Color = WispLight.color_of(_wisp.flight().color(), _wisp.flight().opacity())
	for block: Rect2 in light_blocks():
		_light_layer.draw_rect(Rect2(block.position - _light_layer.global_position, block.size), color)


## The window the menu sits in: the Spoils screen's, shaded over its own height.
func _shade_window(window: PanelContainer) -> void:
	var color: Color = SpoilsScreen.WINDOW_COLOR
	var radius: int = SpoilsScreen.WINDOW_RADIUS
	var face: StyleBoxTexture = DitherShading.plate(color.lightened(0.06), color.darkened(0.3), SpoilsScreen.WINDOW_EDGE,
			radius, WINDOW_EDGE_WIDTH, 0, maxi(int(window.size.y), radius * 2 + 4))
	face.set_content_margin_all(SpoilsScreen.WINDOW_MARGIN)
	window.add_theme_stylebox_override("panel", face)


## [param item] in a frame that draws only the Spoils screen's drop shadow under a button.
func _shadowed(item: Control) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(SpoilsScreen.BUTTON_RADIUS + 1)
	style.shadow_color = SpoilsScreen.SHADOW
	style.shadow_size = SpoilsScreen.SHADOW_SIZE
	style.shadow_offset = Vector2(0, SpoilsScreen.PART_SHADOW_DROP)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(item)
	return frame
