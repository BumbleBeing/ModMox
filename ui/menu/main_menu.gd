class_name MainMenu
extends Control
## The main menu: a plain list of where the game can go, in a window edged in the Steel Rim
## (WindowLook) on the slate ground, with the Spoils screen's buttons. A request on the command line
## (--hero=, --villain= or --seed=) skips it and opens the Encounter Screen (A246), unless
## it names something that does not exist, which the menu then says. --deckbuilder opens
## the deckbuilder on a made-up run, for pictures. --stage-map opens the Stage Map of a
## debug run (--run-seed=N, --stage=red, --tier=N), for pictures, --satchel the same with
## the Satchel open (milestone 24), --store the Store beside its Start Node (milestone 24),
## and --spoils the Spoils
## screen of a win in one (--rank=lesser, elite or boss). --run-won and --run-lost open the
## end of a debug run, and --credits the Credits (milestone 19). Start Run (debug) begins a debug
## run at the Deckbox, in Kitty Keep, the Stage being built first (milestones 16 and 17).
## A playtest build (the playtest feature its export sets, milestone 20) hides those
## developer entries, though every flag above still works in it; every build shows its
## version at the screen's bottom right. Behind it all is the Menu Backdrop, a castle tower at
## nightfall, flickering, the window set into its parapet: the window's top lies on the
## parapet's line, centered across the screen (game ADR 0081). The Menu Soldier stands on top
## of the window, playing his animations, casting the Soldier Shadow on it. The Logo heads the window,
## under him, its cogs turning. The Wisp floats about them,
## bringing him his effects, trailing the Wisp Sparks, which fall and come to rest on the
## window's top, and casts the Wisp Light on the window when it comes near. As
## he takes each effect on, its Effect Callout floats off from him.
##
## Continue heads the menu while a run of this build's format is saved (milestone 21), and
## takes it up where it was saved; starting a new run asks before replacing one. A saved run
## of another format is refused with a notice and deleted. A playtest build asks once, on its
## first launch, whether to share Run Logs. Questions and notices are MenuDialogs.

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
## The project setting that names the build's version, which the menu shows as "Demo 0.0.1"
## (milestone 20), in the Credits' muted 18-point text, VERSION_INSET pixels in from the
## screen's bottom right corner: the Credits' buttons' inset.
const VERSION_SETTING: String = "application/config/version"
const VERSION_SIZE: int = 18
const VERSION_INSET: int = 32
## The custom feature every playtest export sets (milestone 20), and the entries a build
## with it does not offer.
const PLAYTEST_FEATURE: String = "playtest"
const DEVELOPER_ENTRIES: Array[String] = ["Start Encounter", "Start Run (debug)", "Card Gallery"]
const CONTINUE: String = "Continue"
const START_RUN: String = "Start Run (debug)"
const REPLACE_TITLE: String = "Start a new run?"
const REPLACE_BODY: String = "Your saved run will be lost."
const REPLACE: String = "Start new run"
const BACK: String = "Back"
const REFUSAL_TITLE: String = "Your saved run can't be continued"
const REFUSAL_BODY: String = "It was saved by Demo %s, and this is Demo %s."
const OK: String = "OK"
const OPT_IN_TITLE: String = "Share your Run Logs?"
const OPT_IN_BODY: String = "When a run ends, ModMox can send its Run Log, a record of every choice made in the run, to the developer's Discord to help improve the game. Nothing else is sent, and a copy is always kept on your computer. You can change this in Settings."
const SHARE: String = "Share"
const DONT_SHARE: String = "Don't share"

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
## Whether this is a playtest build, whose menu leaves out DEVELOPER_ENTRIES. Tests replace it.
var is_playtest: bool = OS.has_feature(PLAYTEST_FEATURE)
## Where runs are saved, Run Logs written and settings kept: the game's own files, which
## main_menu.tscn names. A menu made in a test keeps none unless it is given files.
@export var save_path: String = ""
@export var log_folder: String = ""
@export var settings_path: String = ""

var _buttons: Dictionary[String, Button] = {}
var _version: Label
var _backdrop: MenuBackdrop
## The Menu Soldier over the window, placed so that the window's top lies on the parapet.
var _stack: VBoxContainer
var _logo: MenuLogo
var _window: PanelContainer
var _soldier: MenuSoldier
## Over everything, so that the Soldier Shadow lies on the window.
var _shadow_layer: Control
## Over the shadow's, so that the Wisp Light lies over the shadow where the two meet.
var _light_layer: Control
var _callouts: MenuCallouts
var _wisp: MenuWisp
var _sparks: MenuSparks
var _refusal: String = ""
## Whether the menu is going straight to a scene the command line asked for.
var _is_skipping: bool = false
## The saved run of this build's format, as plain data, or empty.
var _saved: Dictionary = {}
## The dialog showing, and those waiting their turn.
var _dialog: MenuDialog = null
var _waiting: Array[MenuDialog] = []


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
	var wants_satchel: bool = arguments.has(SatchelWindow.FLAG)
	if (arguments.has(StageMapScreen.FLAG) or wants_satchel) and not StageMapScreen.has_left:
		_is_skipping = true
		StageMapScreen.opens_satchel = wants_satchel
		RunFlow.start(StageMapScreen.debug_run_from(arguments))
		navigate.call_deferred(Screens.scene(RunFlow.finish_intro()))
		return
	if arguments.has(StoreScreen.FLAG) and not StoreScreen.has_left:
		_is_skipping = true
		RunFlow.start(StageMapScreen.debug_run_from(arguments))
		RunFlow.finish_intro()
		StoreScreen.walk_to_a_store(RunFlow.run)
		navigate.call_deferred(Screens.scene(RunFlow.arrive()))
		return
	if arguments.has(SpoilsScreen.FLAG) and not SpoilsScreen.has_left:
		_is_skipping = true
		RunFlow.start(SpoilsScreen.debug_run_from(arguments))
		RunFlow.finish_intro()
		navigate.call_deferred(Screens.SPOILS)
		return
	for flag: String in [RunEndScreen.WON_FLAG, RunEndScreen.LOST_FLAG]:
		if arguments.has(flag) and not RunEndScreen.has_left:
			_is_skipping = true
			var is_won: bool = flag == RunEndScreen.WON_FLAG
			RunFlow.start(RunEndScreen.debug_run_from(arguments, is_won))
			navigate.call_deferred(Screens.RUN_WON if is_won else Screens.RUN_LOST)
			return
	if arguments.has(CreditsScreen.FLAG) and not CreditsScreen.has_left:
		_is_skipping = true
		navigate.call_deferred(Screens.CREDITS)
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
	_read_saved_run()
	_backdrop = MenuBackdrop.new()
	_backdrop.name = "MenuBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_add_version()
	# The soldier over the window, centered across the screen, the window's top on the
	# parapet. His picture's bottom row is empty, so it overlaps the window's top and his soles
	# rest on it.
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", -MenuSoldier.SCALE)
	stack.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(stack)
	_stack = stack
	_soldier = MenuSoldier.new()
	_soldier.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(_soldier)
	var window: PanelContainer = PanelContainer.new()
	WindowLook.shade(window)
	stack.add_child(window)
	_window = window
	_shadow_layer = Control.new()
	_shadow_layer.name = "SoldierShadow"
	_shadow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow_layer.draw.connect(_draw_shadow)
	add_child(_shadow_layer)
	_soldier.shadow_changed.connect(_shadow_layer.queue_redraw)
	stack.item_rect_changed.connect(_shadow_layer.queue_redraw)
	resized.connect(_place_stack)
	_place_stack()
	_light_layer = Control.new()
	_light_layer.name = "WispLight"
	_light_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_light_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_layer.draw.connect(_draw_light)
	add_child(_light_layer)
	_callouts = MenuCallouts.new(_soldier)
	_callouts.name = "EffectCallouts"
	add_child(_callouts)
	# Last, so that it floats in front of him and his callouts, its sparks just behind it.
	_wisp = MenuWisp.new(_soldier, window)
	_wisp.name = "Wisp"
	_sparks = MenuSparks.new(_wisp, window)
	_sparks.name = "WispSparks"
	add_child(_sparks)
	add_child(_wisp)
	_wisp.moved.connect(_light_layer.queue_redraw)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", BUTTON_GAP)
	window.add_child(column)
	_logo = MenuLogo.new()
	_logo.name = "Logo"
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_logo)
	if _refusal != "":
		var reason: Label = Label.new()
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.text = _refusal
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.add_theme_font_size_override("font_size", 20 + UiText.RAISE)
		reason.add_theme_color_override("font_color", REFUSAL_COLOR)
		column.add_child(reason)
	if not _saved.is_empty():
		_add(column, CONTINUE, func() -> void: navigate.call(Screens.scene(RunFlow.continue_run(_saved))))
	if not is_playtest:
		_add(column, "Start Encounter", func() -> void: navigate.call(START_FORM))
		_add(column, START_RUN, _ask_to_start_run)
		_add(column, "Card Gallery", func() -> void: navigate.call(CARD_GALLERY))
	_add(column, "Quit Game", func() -> void: quit.call())
	_ask_to_share()
	_show_next_dialog()


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


## The Menu Backdrop behind everything, or null when the menu went straight to another scene.
func backdrop() -> MenuBackdrop:
	return _backdrop


## The Logo heading the window, or null when the menu went straight to another scene.
func logo() -> MenuLogo:
	return _logo


## The Wisp, or null when the menu went straight to another scene.
func wisp() -> MenuWisp:
	return _wisp


## The Wisp Sparks, or null when the menu went straight to another scene.
func sparks() -> MenuSparks:
	return _sparks


## The Menu Soldier's Effect Callouts, or null when the menu went straight to another scene.
func callouts() -> MenuCallouts:
	return _callouts


## The Wisp Light's blocks as they are drawn now, on the screen: none while the Wisp is far
## from the window.
func light_blocks() -> Array[Rect2]:
	if not _wisp.flight().is_flying():
		return []
	return WispLight.blocks(_wisp.drawn_rect(), _window.get_global_rect(), WindowLook.CORNER)


## The Soldier Shadow's blocks as they are drawn now, on the screen, faint or strong.
func shadow_blocks() -> Array[Rect2]:
	return _shadow_blocks_under(_soldier.shadow().columns())


## The button labeled [param text], or null.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


## The build's version at the screen's bottom right, or null when the menu went straight to
## another scene.
func version_label() -> Label:
	return _version


## Puts the soldier and the window where the window's top lies on the Menu Backdrop's parapet,
## on a whole pixel.
func _place_stack() -> void:
	var top: float = roundf(MenuBackdrop.parapet_y(size.y)) - (_soldier.custom_minimum_size.y - MenuSoldier.SCALE)
	_stack.offset_top = top
	_stack.offset_bottom = top


func _add_version() -> void:
	_version = Label.new()
	_version.name = "Version"
	_version.text = "Demo %s" % ProjectSettings.get_setting(VERSION_SETTING, "")
	_version.add_theme_font_size_override("font_size", VERSION_SIZE)
	_version.add_theme_color_override("font_color", CreditsScreen.MUTED)
	_version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version)
	_version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, VERSION_INSET)


## One of the menu's buttons reading [param text]: the Spoils screen's, in its Steel Frame.
static func menu_button(text: String) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(0, SpoilsScreen.BUTTON_HEIGHT)
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.add_theme_font_override("font", UiText.bold())
	made.add_theme_font_size_override("font_size", 24)
	made.add_theme_color_override("font_color", SpoilsScreen.TEXT)
	SteelFrame.frame_roomy(made, SpoilsScreen.BUTTON_FILL, SpoilsScreen.BUTTON_HEIGHT)
	return made


func _add(column: VBoxContainer, text: String, on_press: Callable) -> void:
	var made: Button = menu_button(text)
	made.pressed.connect(on_press)
	column.add_child(_shadowed(made))
	_buttons[text] = made


## The shadow's blocks under [param columns] of the soldier's sprite, on the screen.
func _shadow_blocks_under(columns: Array[int]) -> Array[Rect2]:
	var his: Rect2 = _soldier.get_global_rect()
	var window: Rect2 = _window.get_global_rect()
	# The window's dither starts past its stepped corner and rim.
	var grid_left: float = window.position.x + WindowLook.CORNER
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


## The dialog over the menu, or null when none is open.
func dialog() -> MenuDialog:
	return _dialog


## Hands RunFlow the game's files, and reads the saved run: one of this build's format is
## Continue's; one of another is refused with a notice, and deleted.
func _read_saved_run() -> void:
	if save_path == "":
		return
	RunFlow.use_storage(save_path, log_folder)
	RunFlow.run_ended = RunLogShare.send
	var data: Dictionary = SavedRun.read(save_path)
	if data.is_empty():
		return
	if SavedRun.is_current(data):
		_saved = data
		return
	SavedRun.delete(save_path)
	_queue_dialog(MenuDialog.make(REFUSAL_TITLE, REFUSAL_BODY % [SavedRun.build_of(data), SavedRun.build()], [OK]),
		func(_answer: String) -> void: pass)


## Start Run (debug): a debug run begins at once, or once the player agrees to lose the saved
## one.
func _ask_to_start_run() -> void:
	var start: Callable = func() -> void:
		navigate.call(Screens.scene(RunFlow.start(Run.debug(randi(), load(DEMO_STAGE) as StageDefinition))))
	if _saved.is_empty():
		start.call()
		return
	_queue_dialog(MenuDialog.make(REPLACE_TITLE, REPLACE_BODY, [REPLACE, BACK]), func(answer: String) -> void:
		if answer == REPLACE:
			start.call())
	_show_next_dialog()


## A playtest build asks once whether to share Run Logs, and keeps the answer.
func _ask_to_share() -> void:
	var settings: GameSettings = GameSettings.load_from(settings_path)
	if not is_playtest or settings.has_answered_sharing:
		return
	_queue_dialog(MenuDialog.make(OPT_IN_TITLE, OPT_IN_BODY, [SHARE, DONT_SHARE]), func(answer: String) -> void:
		var kept: GameSettings = GameSettings.load_from(settings_path)
		kept.has_answered_sharing = true
		kept.is_sharing_run_logs = answer == SHARE
		kept.save_to(settings_path))


## Puts [param made] in line to be shown, [param on_answer] called with the answer.
func _queue_dialog(made: MenuDialog, on_answer: Callable) -> void:
	made.chosen.connect(func(answer: String) -> void:
		_dialog = null
		on_answer.call(answer)
		_show_next_dialog())
	_waiting.append(made)


func _show_next_dialog() -> void:
	if _dialog != null or _waiting.is_empty():
		return
	_dialog = _waiting.pop_front()
	add_child(_dialog)


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
