extends Control
## PROTOTYPE (milestone 26, Elites and the Trove): four layouts of the Trove to choose
## between, each offering the same three sample Items. It answers one question, "what
## should the Trove look like?", and nothing else: no run is changed, nothing is saved, and
## the Items are samples made in this file.
##
## CHOSEN: B, the list over the Stage Map. The other three layouts are kept as the record of
## what it was chosen over. Step 2, arriving and taking, which it opens on, is SIGNED OFF,
## and the prototype is complete. Throwaway: it stays here until milestone 26's port, which
## is test-first in ui/, then goes to a throwaway branch, prototype/trove-screen, and is
## deleted.
##
## godot --path . res://prototypes/trove_screen/trove_screen.tscn -- --run-seed=2 --stage=white
## (a Run Seed whose map has no Trove gives way to the next that has one)
##
## Left and Right (or 1 to 4, or the pill at the bottom) step through the layouts:
##   A, Spoils window: on the Stage's ground, in the Spoils' window, three parchment panels
##      side by side; a click selects one and the one Take button under them takes it.
##   B, List over the map: a window over the dimmed Stage Map, as the Satchel opens. The
##      Items are stacked as Satchel entries, each with its own Take button, which reads
##      Confirm after the first click, beside the Hero's Portrait and Armor Slots.
##   C, Showcase: no window. The Items stand as large pictures on the Stage's ground, and
##      the one selected, or under the cursor while none is, is read in one parchment below,
##      which holds Take.
##   D, Dealt like cards: each Item on a card-shaped parchment, dealt face down and flipped
##      as the Spoils' cards are, glowing its Rarity. A click lifts one and shows Take under it.
## I steps through what is offered (a Potion, a Mod and an Armor; three Mods; three Potions;
## and the wordiest of each), and R puts the layout back as it began. Since the sign-off a Mod
## has a picture, the cog in its Rarity's color (ui/sprites/mods/), drawn on no plate.
##
## Step 2 (key 5, and what it opens on): layout B on a live Stage Map. The Hero stands on
## the Elite Encounter just played, its Trove glowing ahead; a click on the Trove's Node
## glides them there, and the window fades in, with the dimming, over WINDOW_FADE_SECONDS.
## The dimming stops under the Run Bar, whose Satchel and Deckbox buttons stay lit (they
## open nothing here). Take, then Confirm, rings the taken entry in white while the other
## two fade, and after TAKEN_HOLD_SECONDS the window fades out to the Stage Map. A taken Armor is put on at
## once if its Armor Slot is empty (the wordy offer's Seer's Cuirass is; the mixed offer's
## Lionguard Helm is not). L steps between an Elite Encounter won and one lost.
##
## For a picture: --layout=a (to d), --items=mixed (mods, potions or wordy), --select=2,
## --hover=2 (layout C), --confirm=2 (layout B), --take, and --screenshot=/absolute/path.png,
## which saves the picture and quits. --click=2 clicks the second Item with a real mouse
## event first (in layout B, its Take button), and may be given more than once. For step 2:
## --layout=e, --lost-elite, --arrive (a real click on the Trove's Node, then the glide),
## --wait=0.3 (seconds to wait, after the clicks, before the picture), and --paced, which
## keeps the easing and the deal in a run that saves a picture.

enum Layout { SPOILS_WINDOW, LIST_OVER_MAP, SHOWCASE, DEALT, ARRIVING }
enum Offer { MIXED, MODS, POTIONS, WORDY }
enum ItemKind { POTION, MOD, ARMOR }
enum Slot { HELM, CUIRASS, GREAVES }

const STAGE_MAP: String = "res://ui/stage_map/stage_map_screen.tscn"
## The words on trial, agreed before this was built. PROMPT was taken out of layout B at
## step 2's review, and stays only in the layouts not chosen.
const TITLE: String = "Trove"
const PROMPT: String = "Take one."
const TAKE: String = "Take"
const CONFIRM: String = "Confirm"
const LAYOUT_NAMES: Dictionary[Layout, String] = {
	Layout.SPOILS_WINDOW: "A · Spoils window", Layout.LIST_OVER_MAP: "B · List over the map (chosen)",
	Layout.SHOWCASE: "C · Showcase", Layout.DEALT: "D · Dealt like cards",
	Layout.ARRIVING: "Step 2 · B, arriving and taking (signed off)",
}
const OFFER_NAMES: Dictionary[Offer, String] = {
	Offer.MIXED: "mixed", Offer.MODS: "mods", Offer.POTIONS: "potions", Offer.WORDY: "wordy",
}
## The Spoils screen's window, bar, button and parchment.
const WINDOW_COLOR: Color = Color("#4b3f3f")
const WINDOW_EDGE: Color = Color("#14171c")
const WINDOW_RADIUS: int = 24
const WINDOW_MARGIN: int = 24
const ROW_GAP: int = 24
const TEXT: Color = Color8(228, 231, 238)
const BAR_COLOR: Color = Color("#656a75")
const BAR_EDGE: Color = Color("#1b1e23")
const BAR_HEIGHT: int = 64
const BAR_RADIUS: int = 14
const BUTTON_FILL: Color = Color("#51555e")
const BUTTON_HEIGHT: int = 56
const BUTTON_RADIUS: int = 12
const PAPER: Color = Color("#e9dcbc")
const PAPER_EDGE: Color = Color("#7a6243")
const PAPER_EDGE_WIDTH: int = 2
const PAPER_LIGHTEN: float = 0.08
const PAPER_DARKEN: float = 0.15
const PAPER_RADIUS: int = 14
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
const SHADOW: Color = Color(0, 0, 0, 0.55)
const SHADOW_SIZE: int = 12
const CARD_SHADOW_DROP: float = 8.0
const PART_SHADOW_DROP: float = 3.0
const CARD_HEIGHT: float = 400.0
const CARD_GAP: int = 24
const PULSE_SECONDS: float = 3.2
const PULSE_LOW: float = 0.45
const PULSE_HIGH: float = 1.0
## The Satchel's dimming, set-in ground and plate colors: gray, silver, gold and sienna from
## Common to Mythic, and light purple for a Unique Item.
const DIM: Color = Color(0, 0, 0, 0.6)
const SLOT_GROUND: Color = Color("#221c1c")
const SET_IN_EDGE: Color = Color("#14171c")
const TINTS: Array[Color] = [Color("#8a8f98"), Color("#d5dbe3"), Color("#f2c744"), Color("#a0522d")]
const UNIQUE_TINT: Color = Color("#c8a8e6")
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Mythic", "Unique"]
const SLOT_NAMES: Dictionary[Slot, String] = { Slot.HELM: "Helm", Slot.CUIRASS: "Cuirass", Slot.GREAVES: "Greaves" }
const HERO_NAME: String = "Urza"
const LIFE_WORDS: String = "You start each encounter with %d more life."
const EMBLEM_WORDS: String = "You start each encounter with this Emblem:"
const MODS: String = "res://content/mods/%s.tres"
const POTION_ICONS: String = "res://ui/sprites/potions/%s.png"
const ARMOR_ICONS: String = "res://ui/sprites/armor/%s.png"
const ARMOR_TEMPLATES: String = "res://tools/sprites/armor_templates/%s.png"
## A Mod's picture, the cog, by its Rarity's name in lower case.
const MOD_ICONS: String = "res://ui/sprites/mods/%s.png"
const BIG_GULP: String = "res://content/potions/big_gulp.tres"
const DIVINERS_BOON: String = "res://content/emblems/diviners_boon.tres"
## What the Hero wears in layout B's Worn column: a Helm and Greaves, and no Cuirass.
const WORN: Dictionary[Slot, String] = { Slot.HELM: "hornward_helm", Slot.GREAVES: "thornwalker_greaves" }
## A picked Item's ring and the wash under the cursor.
const RING: Color = Color.WHITE
const RING_WIDTH: int = 4
const WASH: Color = Color(1, 1, 1, 0.22)
## Layout A: each panel's size, wide enough for a Mod's longest type line on two lines.
const A_PANEL: Vector2 = Vector2(420, 250)
## Layout B.
const B_WINDOW_WIDTH: float = 1240.0
const B_TAKE: Vector2 = Vector2(150, 52)
## Layout C: a stand is this many pixels square, a picked one this much higher, and the
## parchment that reads an Item out this big.
const C_STAND: int = 232
const C_LIFT: float = 20.0
const C_DETAIL: Vector2 = Vector2(1040, 250)
## Layout D: a picked card rises this far, and the deal starts this far into the Spoils'
## reveal, which first counts its gold.
const D_LIFT: float = 28.0
const D_REVEAL_START: float = 0.3
const D_CARD_EDGE: Color = Color("#3a2c1e")
## Step 2: how long a taken entry stays ringed before the window fades out, and how long
## the window, with the dimming, takes to fade in or out, as long as the Spoils' window
## takes to come in. Both are at Blazing.
const TAKEN_HOLD_SECONDS: float = 0.6
const WINDOW_FADE_SECONDS: float = 0.25


## One of the three Items on offer.
class Item extends RefCounted:
	var kind: ItemKind = ItemKind.POTION
	var name: String = ""
	var type_line: String = ""
	## What it does, a sentence to a line.
	var words: Array[String] = []
	## The Emblem an Armor brings, written under its words, or null.
	var emblem: MmCardDefinition = null
	## Its Potion Icon or Armor Icon, or a Mod's cog in its Rarity's color.
	var icon: Texture2D = null
	## A Potion's or a Mod's Rarity, from 0 for Common; -1 for an Armor, which has none.
	var rarity: int = -1
	## An Armor's Armor Slot.
	var slot: Slot = Slot.HELM


var _layout: Layout = Layout.ARRIVING
var _offer: Offer = Offer.MIXED
var _items: Array[Item] = []
## Which Item is under the cursor, selected, showing Confirm (layout B) and taken; -1 for none.
var _hovered: int = -1
var _selected: int = -1
var _confirming: int = -1
var _taken: int = -1
var _is_paced: bool = true
var _speed_scale: float = 1.0
var _run: Run = null
var _map: StageMapScreen = null
var _screen: Control = null
## What draws each Item's ring and wash, and what takes its clicks.
var _surfaces: Dictionary[int, Control] = {}
var _click_targets: Dictionary[int, Control] = {}
## Layout C's parchment and the frame that fades it.
var _detail: PanelContainer = null
var _detail_frame: Control = null
## Layout D's cards, their fronts, backs and glows, and how far into the deal it is.
var _cards: Array[Control] = []
var _fronts: Array[Control] = []
var _backs: Array[Control] = []
var _glows: Array[Control] = []
var _reveal_time: float = D_REVEAL_START
var _time: float = 0.0
## What the building functions add to: the screen, or step 2's window layer.
var _host: Control = null
## Layout B's entries, in order, and the Armor Icon Worn in each Armor Slot that has one.
var _entry_frames: Array[Control] = []
var _worn: Dictionary[Slot, Texture2D] = {}
## The Armor Slot a taken Armor was put on in, or -1.
var _put_on: int = -1
## Step 2: the run being walked, its live Stage Map, and where the Trove has got to.
var _arguments: PackedStringArray = PackedStringArray()
var _speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
var _ease_seconds: float = 0.0
var _fade_seconds: float = 0.0
var _is_elite_lost: bool = false
var _walk_run: Run = null
var _walk_map: StageMapScreen = null
var _is_trove_open: bool = false
var _is_trove_done: bool = false
var _trove_layer: Control = null
var _after_take: Tween = null
var _state_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--layout="):
			_layout = clampi("abcde".find(argument.trim_prefix("--layout=").to_lower()), 0, Layout.size() - 1) as Layout
		elif argument.begins_with("--items="):
			for offer: Offer in OFFER_NAMES:
				if OFFER_NAMES[offer] == argument.trim_prefix("--items=").to_lower():
					_offer = offer
		elif argument.begins_with("--select="):
			_selected = clampi(int(argument.trim_prefix("--select=")) - 1, -1, 2)
		elif argument.begins_with("--hover="):
			_hovered = clampi(int(argument.trim_prefix("--hover=")) - 1, -1, 2)
		elif argument.begins_with("--confirm="):
			_confirming = clampi(int(argument.trim_prefix("--confirm=")) - 1, -1, 2)
		elif argument == "--take":
			_taken = maxi(_selected, 0)
		elif argument == "--lost-elite":
			_is_elite_lost = true
	_arguments = arguments
	var picture: String = EncounterScreen.screenshot_path(arguments)
	_is_paced = picture == "" or arguments.has("--paced")
	_speed = GameSettings.load_from(GameSettings.PATH).game_speed
	_speed_scale = GameSpeed.scale_of(_speed)
	if _is_paced:
		_ease_seconds = GameSpeed.seconds(Pacing.EASE_SECONDS, _speed)
		_fade_seconds = GameSpeed.seconds(WINDOW_FADE_SECONDS, _speed)
	else:
		_reveal_time = SpoilsReveal.length(3)
	_run = _a_run_with_a_trove()
	_walk_toward_a_trove(_run, false)
	# The real Stage Map, under layout B alone. Arriving at a Node opens nothing here.
	_map = (load(STAGE_MAP) as PackedScene).instantiate() as StageMapScreen
	_map.starts_itself = false
	_map.navigate = func(_scene: String) -> void: pass
	add_child(_map)
	_map.begin(_run)
	# It stands still under the window: no gliding, no hover labels, no Pause Menu.
	_map.process_mode = Node.PROCESS_MODE_DISABLED
	_items = _items_of(_offer)
	var hovered: int = _hovered
	_worn = _worn_at_first()
	_enter_layout()
	_rebuild()
	if hovered != -1:
		_point_at(hovered)
	if arguments.has("--arrive") and _walk_map != null:
		for frame: int in 3:
			await get_tree().process_frame
		_click_at(_walk_map.node_spot(_trove_ahead()))
		for frame: int in 1200:
			await get_tree().process_frame
			if _is_trove_open:
				break
	# One after another with no frame between, so the real cursor, which is somewhere else,
	# does not leave a button between its two clicks.
	var has_waited: bool = false
	for argument: String in arguments:
		if argument.begins_with("--click="):
			if not has_waited:
				for frame: int in 3:
					await get_tree().process_frame
				has_waited = true
			_click_at(_click_targets[clampi(int(argument.trim_prefix("--click=")) - 1, 0, 2)].get_global_rect().get_center())
	for argument: String in arguments:
		if argument.begins_with("--wait="):
			await get_tree().create_timer(float(argument.trim_prefix("--wait="))).timeout
	if picture != "":
		var frames: int = 6
		for argument: String in arguments:
			if argument.begins_with("--frames="):
				frames = int(argument.trim_prefix("--frames="))
		for frame: int in frames:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


func _process(delta: float) -> void:
	_time += delta
	if _state_label != null:
		_state_label.text = _state_text()
	if _layout == Layout.ARRIVING and _walk_map != null:
		if _is_trove_open:
			# The map's own time is moved on from here while the window is open, so that it
			# names no Node under the cursor.
			_walk_map.advance(delta)
		elif not _is_trove_done and not _walk_map.is_gliding() \
				and _walk_run.stage_visit.node().kind == StageMap.Kind.TROVE:
			_open_trove()
	if _layout != Layout.DEALT:
		return
	if _is_dealing():
		_reveal_time += delta / _speed_scale
	_pose_cards()
	for index: int in _glows.size():
		var wave: float = 0.5 - 0.5 * cos(TAU * (_time / PULSE_SECONDS + index * 0.37))
		_glows[index].modulate.a = lerpf(PULSE_LOW, PULSE_HIGH, wave)


## A click while layout D is dealing ends the deal, as on the Spoils screen.
func _input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT \
			and _layout == Layout.DEALT and _is_dealing():
		_reveal_time = SpoilsReveal.length(3)
		_pose_cards()
		get_viewport().set_input_as_handled()


## A real click at [param point], the cursor moved there first.
func _click_at(point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	for is_pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		click.position = point
		click.global_position = point
		get_viewport().push_input(click, true)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT:
			_show_layout(posmod(_layout - 1, Layout.size()) as Layout)
		KEY_RIGHT:
			_show_layout(posmod(_layout + 1, Layout.size()) as Layout)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_show_layout((key.keycode - KEY_1) as Layout)
		KEY_L:
			_is_elite_lost = not _is_elite_lost
			_reset()
		KEY_I:
			_offer = posmod(_offer + 1, Offer.size()) as Offer
			_items = _items_of(_offer)
			_reset()
		KEY_R:
			_reset()


func _show_layout(layout: Layout) -> void:
	_layout = layout
	_reset()


## Puts the layout back as it began: nothing selected or taken, and layout D dealt again.
func _reset() -> void:
	_selected = -1
	_confirming = -1
	_taken = -1
	_put_on = -1
	_worn = _worn_at_first()
	_reveal_time = D_REVEAL_START if _is_paced else SpoilsReveal.length(3)
	_enter_layout()
	_rebuild()


## Leaves step 2's walk, and begins it again if step 2 is what is showing: a new debug run,
## the Hero on the Elite Encounter before a Trove, just played, on a Stage Map that is live.
func _enter_layout() -> void:
	if _after_take != null:
		_after_take.kill()
		_after_take = null
	if _walk_map != null:
		remove_child(_walk_map)
		_walk_map.queue_free()
		_walk_map = null
		RunFlow.clear()
	_is_trove_open = false
	_is_trove_done = false
	if _layout != Layout.ARRIVING:
		return
	# The Stage Map asks RunFlow where an arrival leads, so the run must be RunFlow's. Opened
	# as a scene of its own, RunFlow has nowhere to save to and keeps the run in memory.
	if RunFlow.save_path != "":
		push_error("The Trove prototype walks a run only where none is saved.")
		return
	_walk_run = _a_run_with_a_trove()
	_walk_toward_a_trove(_walk_run, true)
	RunFlow.start(_walk_run)
	RunFlow.finish_intro()
	_walk_map = (load(STAGE_MAP) as PackedScene).instantiate() as StageMapScreen
	_walk_map.starts_itself = false
	_walk_map.navigate = func(_scene: String) -> void: pass
	_walk_map.is_paced = _is_paced
	_walk_map.game_speed = _speed
	add_child(_walk_map)
	move_child(_walk_map, 1)
	_walk_map.begin(_walk_run)


## The Trove ahead of the Elite Encounter the Hero stands on.
func _trove_ahead() -> int:
	for id: int in _walk_run.stage_visit.choices():
		if _walk_run.stage_visit.map.nodes[id].kind == StageMap.Kind.TROVE:
			return id
	return _walk_run.stage_visit.current


## Step 2: the Hero has arrived at the Trove, and its window fades in over the Stage Map.
func _open_trove() -> void:
	_is_trove_open = true
	_walk_map.point_at(Vector2(-9999, -9999))
	_walk_map.set_process(false)
	_rebuild()
	_trove_layer.modulate.a = 0.0
	_fade(_trove_layer, 1.0)


## Fades [param layer] to [param alpha] over the window's fade, slow at both ends, then
## calls [param then], if given. At once where nothing is paced.
func _fade(layer: Control, alpha: float, then: Callable = Callable()) -> void:
	if _fade_seconds <= 0.0:
		layer.modulate.a = alpha
		if then.is_valid():
			then.call()
		return
	var fade: Tween = layer.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(layer, "modulate:a", alpha, _fade_seconds)
	if then.is_valid():
		fade.tween_callback(then)


## Step 2, once an Item is taken: the other two entries fade, the taken one stays ringed for
## TAKEN_HOLD_SECONDS at the Game Speed, and then the window fades out.
func _after_a_take() -> void:
	for index: int in _entry_frames.size():
		if index != _taken and _ease_seconds > 0.0:
			_entry_frames[index].modulate.a = 1.0
			_entry_frames[index].create_tween().tween_property(_entry_frames[index], "modulate:a", 0.25, _ease_seconds)
	_after_take = create_tween()
	_after_take.tween_interval(GameSpeed.seconds(TAKEN_HOLD_SECONDS, _speed))
	_after_take.tween_callback(_close_trove)


func _close_trove() -> void:
	_after_take = null
	_is_trove_open = false
	_is_trove_done = true
	_walk_map.set_process(true)
	# As anything leaving is: deaf to the mouse at once, and only drawn while it fades.
	var leaving: Control = _trove_layer
	_trove_layer = null
	leaving.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_fade(leaving, 0.0, _rebuild)


func _is_dealing() -> bool:
	return _reveal_time < SpoilsReveal.length(3)


## Selects the Item [param index], or lets go of it if it is the one selected.
func _pick(index: int) -> void:
	if _taken != -1:
		return
	_selected = -1 if _selected == index else index
	_rebuild()


## Takes the selected Item: an Armor is put on at once if its Armor Slot is empty. In the
## four layouts that only shows it taken (R offers the three again); in step 2 the window
## then closes.
func _take() -> void:
	if _selected == -1 or _taken != -1:
		return
	_taken = _selected
	var item: Item = _items[_taken]
	if item.kind == ItemKind.ARMOR and not _worn.has(item.slot):
		_worn[item.slot] = item.icon
		_put_on = item.slot
	_rebuild()
	if _layout == Layout.ARRIVING:
		_after_a_take()


## The cursor is over the Item [param index], or over none (-1).
func _point_at(index: int) -> void:
	_hovered = index
	for surface: Control in _surfaces.values():
		surface.queue_redraw()
	if _layout == Layout.SHOWCASE:
		_refresh_detail()


func _rebuild() -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_surfaces.clear()
	_click_targets.clear()
	_cards.clear()
	_fronts.clear()
	_backs.clear()
	_glows.clear()
	_detail = null
	_detail_frame = null
	_entry_frames.clear()
	_trove_layer = null
	_state_label = null
	_hovered = -1
	_map.visible = _layout == Layout.LIST_OVER_MAP
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_host = _screen
	match _layout:
		Layout.ARRIVING:
			_build_arriving()
		Layout.SPOILS_WINDOW:
			_build_spoils_window()
		Layout.LIST_OVER_MAP:
			_build_list_over_map()
		Layout.SHOWCASE:
			_build_showcase()
		Layout.DEALT:
			_build_dealt()
	_add_prototype_bar()


# ---------------------------------------------------------------------------------------
# Layout A: the Spoils' window, three panels side by side, one Take button.

func _build_spoils_window() -> void:
	_screen.add_child(_ground())
	var column: VBoxContainer = _window_column(0.0)
	column.add_child(_shadowed(_heading_bar(), BAR_RADIUS + 2, PART_SHADOW_DROP))
	column.add_child(_text(PROMPT, 26, TEXT, false, true))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(row)
	for index: int in _items.size():
		var item: Item = _items[index]
		var panel: PanelContainer = _paper_panel(Vector2(20, 16))
		panel.custom_minimum_size = A_PANEL
		var block: VBoxContainer = VBoxContainer.new()
		block.add_theme_constant_override("separation", 10)
		panel.add_child(block)
		# As the Spoils' Item panel has it: the picture, with the name and type line beside it.
		# Every header is as tall as a picture, so the words line up under one that has none.
		var header: HBoxContainer = HBoxContainer.new()
		header.custom_minimum_size = Vector2(0, 32 * 3 + 4)
		header.add_theme_constant_override("separation", 14)
		block.add_child(header)
		if item.icon != null:
			header.add_child(_icon_tile(item, 3))
		var titles: VBoxContainer = VBoxContainer.new()
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titles.alignment = BoxContainer.ALIGNMENT_CENTER
		titles.add_theme_constant_override("separation", 2)
		titles.add_child(_wrapping(_text(item.name, 26, INK, true)))
		titles.add_child(_wrapping(_text(item.type_line, 20, INK_MUTED, false)))
		header.add_child(titles)
		_add_words(block, item, 20)
		_make_pickable(panel, panel, index, PAPER_RADIUS)
		var frame: Control = _shadowed(panel, PAPER_RADIUS, PART_SHADOW_DROP)
		_fade_unpicked(frame, index)
		row.add_child(frame)
	var take: Control = _shadowed(_take_button(_selected != -1 and _taken == -1, 220), BUTTON_RADIUS + 1, PART_SHADOW_DROP)
	take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(take)


# ---------------------------------------------------------------------------------------
# Layout B: a window over the dimmed Stage Map, the Items listed as Satchel entries.

## Step 2: nothing over the live Stage Map until the Hero is on the Trove, then layout B's
## window, on a layer of its own that eases in and out.
func _build_arriving() -> void:
	if not _is_trove_open:
		return
	_trove_layer = Control.new()
	_trove_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trove_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_trove_layer)
	_host = _trove_layer
	_build_list_over_map()
	_host = _screen


func _build_list_over_map() -> void:
	# The dimming stops under the Run Bar, whose Satchel and Deckbox buttons stay lit. It
	# takes the clicks that miss the window, and does nothing with them.
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = RunBar.HEIGHT
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_host.add_child(dim)
	var column: VBoxContainer = _window_column(B_WINDOW_WIDTH)
	column.add_child(_shadowed(_heading_bar(), BAR_RADIUS + 2, PART_SHADOW_DROP))
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(body)
	body.add_child(_worn_column())
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	body.add_child(list)
	# No "Take one." here: it was taken out at step 2's review. A, C and D keep it, as shown.
	for index: int in _items.size():
		var item: Item = _items[index]
		var panel: PanelContainer = _paper_panel(Vector2(16, 12))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		if item.icon != null:
			var tile: Control = _icon_tile(item, 3)
			tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tile)
		var block: VBoxContainer = VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.alignment = BoxContainer.ALIGNMENT_CENTER
		block.add_theme_constant_override("separation", 2)
		row.add_child(block)
		block.add_child(_text(item.name, 26, INK, true))
		block.add_child(_text(item.type_line, 20, INK_MUTED, false))
		block.add_child(_gap(4))
		_add_words(block, item, 20)
		row.add_child(_entry_take_button(index))
		if index == _taken:
			_ring_on(panel, PAPER_RADIUS)
		var frame: Control = _shadowed(panel, PAPER_RADIUS, PART_SHADOW_DROP)
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_fade_unpicked(frame, index)
		_entry_frames.append(frame)
		list.add_child(frame)


## An entry's own Take button: the first click turns it to Confirm, the second takes the
## Item, and the cursor leaving turns it back, as the Satchel's Sell button does.
func _entry_take_button(index: int) -> Button:
	var button: Button = _take_button(_taken == -1, int(B_TAKE.x), int(B_TAKE.y), 24)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_click_targets[index] = button
	if _confirming == index:
		button.text = CONFIRM
	# _take_button() wired it to take the selected Item; here a click means this entry's.
	for wired: Dictionary in button.pressed.get_connections():
		button.pressed.disconnect(wired["callable"] as Callable)
	button.pressed.connect(func() -> void:
		if button.text == TAKE:
			_confirming = index
			button.text = CONFIRM
		else:
			_selected = index
			_take())
	button.mouse_exited.connect(func() -> void:
		if _taken == -1:
			_confirming = -1
			button.text = TAKE)
	return button


## The Worn column, as the Satchel has it: the Hero's Portrait and name, then the three
## Armor Slots, head to foot, each showing the Armor Worn there or its kind's faint outline.
func _worn_column() -> Control:
	var column: PanelContainer = PanelContainer.new()
	var ground: StyleBoxFlat = _flat(WINDOW_COLOR.darkened(0.45), 14)
	ground.set_border_width_all(2)
	ground.border_color = SET_IN_EDGE
	ground.set_content_margin_all(20)
	column.add_theme_stylebox_override("panel", ground)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 14)
	column.add_child(rows)
	var portrait_side: float = 32.0 * 5
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(portrait_side + 8, portrait_side + 8)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _set_in(6))
	var portrait: TextureRect = _picture(PlayerPortraits.texture_of(MmEncounterSetup.HERO_PLAYER_ID))
	portrait.position = Vector2(4, 4)
	portrait.size = Vector2(portrait_side, portrait_side)
	frame.add_child(portrait)
	rows.add_child(frame)
	rows.add_child(_text(HERO_NAME, 28, TEXT, true, true))
	for slot: Slot in [Slot.HELM, Slot.CUIRASS, Slot.GREAVES]:
		var side: float = 32.0 * 3
		var square: Panel = Panel.new()
		square.custom_minimum_size = Vector2(side + 4, side + 4)
		square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		square.add_theme_stylebox_override("panel", _set_in(0))
		var shown: TextureRect
		if _worn.has(slot):
			shown = _picture(_worn[slot])
			if _put_on == slot:
				_ring_on(square, 0)
		else:
			shown = _picture(_armor_template(slot))
			shown.modulate.a = 0.7
		shown.position = Vector2(2, 2)
		shown.size = Vector2(side, side)
		square.add_child(shown)
		rows.add_child(square)
	return column


# ---------------------------------------------------------------------------------------
# Layout C: the Items as large pictures on the ground, read out in one parchment below.

func _build_showcase() -> void:
	_screen.add_child(_ground())
	var ink: Color = _ground_ink()
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 20)
	_screen.add_child(column)
	column.add_child(_text(TITLE, 64, ink, true, true))
	column.add_child(_text(PROMPT, 28, ink, false, true))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 72)
	column.add_child(row)
	for index: int in _items.size():
		var item: Item = _items[index]
		var is_raised: bool = index == _selected or index == _taken
		var stand: VBoxContainer = VBoxContainer.new()
		stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stand.add_theme_constant_override("separation", 12)
		stand.add_child(_gap(0.0 if is_raised else C_LIFT))
		var plinth: Panel = _plinth(item)
		_make_pickable(plinth, plinth, index, 16)
		var frame: Control = _shadowed(plinth, 16, CARD_SHADOW_DROP if is_raised else PART_SHADOW_DROP)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stand.add_child(frame)
		var name_label: Label = _text(item.name, 28, ink, true, true)
		name_label.custom_minimum_size = Vector2(C_STAND + 48, 0)
		stand.add_child(name_label)
		stand.add_child(_gap(C_LIFT if is_raised else 0.0))
		_fade_unpicked(stand, index)
		row.add_child(stand)
	_detail = _paper_panel(Vector2(28, 20))
	_detail.custom_minimum_size = C_DETAIL
	_detail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_frame = _shadowed(_detail, PAPER_RADIUS, PART_SHADOW_DROP)
	column.add_child(_detail_frame)
	_refresh_detail()


## The stand an Item's picture is shown on: a plate in a Potion's Rarity's color, or dark
## slate for an Armor, which has no Rarity, and for a Mod, whose cog is in its Rarity's color
## itself.
func _plinth(item: Item) -> Panel:
	var plinth: Panel = Panel.new()
	plinth.custom_minimum_size = Vector2(C_STAND, C_STAND)
	plinth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var color: Color = _tint_of(item) if item.kind == ItemKind.POTION else Color("#3b4250")
	plinth.add_theme_stylebox_override("panel", DitherShading.plate(color.lightened(0.18), color.darkened(0.25),
			SET_IN_EDGE, 16, 3, 0, C_STAND))
	var picture: TextureRect = _picture(item.icon)
	picture.size = Vector2(192.0, 192.0)
	picture.position = ((Vector2(C_STAND, C_STAND) - picture.size) / 2.0).floor()
	plinth.add_child(picture)
	return plinth


## Writes the selected Item into the parchment, or the one under the cursor while none is
## selected, and nothing when there is neither.
func _refresh_detail() -> void:
	if _detail == null:
		return
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var shown: int = _taken if _taken != -1 else (_selected if _selected != -1 else _hovered)
	_detail_frame.modulate.a = 1.0 if shown != -1 else 0.4
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_detail.add_child(row)
	var block: VBoxContainer = VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 2)
	row.add_child(block)
	if shown != -1:
		var item: Item = _items[shown]
		block.add_child(_text(item.name, 30, INK, true))
		block.add_child(_text(item.type_line, 22, INK_MUTED, false))
		block.add_child(_gap(6))
		_add_words(block, item, 22)
	var take: Button = _take_button(_selected != -1 and _taken == -1, 180)
	take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(take)


# ---------------------------------------------------------------------------------------
# Layout D: each Item on a card-shaped parchment, dealt and flipped as the Spoils' cards.

func _build_dealt() -> void:
	_screen.add_child(_ground())
	var column: VBoxContainer = _window_column(0.0)
	column.add_child(_shadowed(_heading_bar(), BAR_RADIUS + 2, PART_SHADOW_DROP))
	column.add_child(_text(PROMPT, 26, TEXT, false, true))
	var card_size: Vector2 = Vector2(CARD_HEIGHT * CardGeometry.ASPECT, CARD_HEIGHT).floor()
	var corner: int = int(card_size.x * CardGeometry.CORNER)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(row)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(buttons)
	for index: int in _items.size():
		var item: Item = _items[index]
		var holder: Control = Control.new()
		holder.custom_minimum_size = card_size + Vector2(0, D_LIFT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card: Control = Control.new()
		card.size = card_size
		card.pivot_offset = card_size / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(card)
		card.add_child(_card_shadow(card_size, corner))
		var front: Control = _item_card(item, card_size, corner)
		if item.rarity != -1:
			BorderEffects.add_glow(front, card_size, Inspector.glow_of(mini(item.rarity, 3) as MmCardDefinition.Rarity))
			_glows.append(front.get_node(BorderEffects.GLOW) as Control)
		card.add_child(front)
		var back: Panel = CardBack.make(card_size.y)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(back)
		# Over both faces: it takes the card's clicks and draws its ring and wash.
		var over: Control = Control.new()
		over.size = card_size
		card.add_child(over)
		_make_pickable(over, over, index, corner)
		_cards.append(card)
		_fronts.append(front)
		_backs.append(back)
		row.add_child(holder)
		# Take stands under the card it would take, and nowhere else.
		var place: Control = Control.new()
		place.custom_minimum_size = Vector2(card_size.x, BUTTON_HEIGHT)
		place.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index == _selected and _taken == -1:
			var take: Button = _take_button(true, 180)
			take.position = Vector2((card_size.x - 180.0) / 2.0, 0)
			take.size = Vector2(180, BUTTON_HEIGHT)
			place.add_child(take)
		buttons.add_child(place)
	_pose_cards()


## An Item written as a card: its name and type line, its picture, and what it does.
func _item_card(item: Item, card_size: Vector2, corner: int) -> Control:
	var front: Control = Control.new()
	front.size = card_size
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper: Panel = Panel.new()
	paper.size = card_size
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_theme_stylebox_override("panel", DitherShading.plate(PAPER.lightened(PAPER_LIGHTEN),
			PAPER.darkened(PAPER_DARKEN), D_CARD_EDGE, corner - 4, 4, 0, int(card_size.y)))
	front.add_child(paper)
	var margin: MarginContainer = MarginContainer.new()
	margin.size = card_size
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	front.add_child(margin)
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	margin.add_child(block)
	block.add_child(_wrapping(_text(item.name, 26, INK, true, true)))
	block.add_child(_wrapping(_text(item.type_line, 18, INK_MUTED, false, true)))
	if item.icon != null:
		block.add_child(_gap(4))
		block.add_child(_icon_tile(item, 4))
	block.add_child(_gap(4))
	_add_words(block, item, 18)
	return front


func _card_shadow(card_size: Vector2, corner: int) -> Panel:
	var shadow: Panel = Panel.new()
	shadow.size = card_size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _flat(Color.BLACK, corner)
	style.shadow_color = SHADOW
	style.shadow_size = SHADOW_SIZE
	style.shadow_offset = Vector2(0, CARD_SHADOW_DROP)
	shadow.add_theme_stylebox_override("panel", style)
	return shadow


## Puts each card where the deal has got to, the picked one D_LIFT higher.
func _pose_cards() -> void:
	for index: int in _cards.size():
		var dealt: Vector4 = SpoilsReveal.card(_reveal_time, index)
		var is_raised: bool = index == _selected or index == _taken
		_cards[index].position.y = D_LIFT - dealt.x - (D_LIFT if is_raised else 0.0)
		_cards[index].modulate.a = dealt.y * (0.25 if _taken != -1 and index != _taken else 1.0)
		_cards[index].scale.x = dealt.z
		_fronts[index].visible = dealt.w > 0.5
		_backs[index].visible = dealt.w <= 0.5


# ---------------------------------------------------------------------------------------
# The sample Items.

func _items_of(offer: Offer) -> Array[Item]:
	var items: Array[Item] = []
	match offer:
		Offer.MIXED:
			items.append(_a_potion("Dragon's Breath", 3, "dragons_breath", "Dragon's Breath deals 3 damage to any target."))
			items.append(_a_mod("violent"))
			items.append(_an_armor("Lionguard Helm", Slot.HELM, "lionguard_helm", 3, null))
		Offer.MODS:
			items.append(_a_mod("tough"))
			items.append(_a_mod("flashy"))
			items.append(_a_mod("overloaded"))
		Offer.POTIONS:
			items.append(_big_gulp())
			items.append(_a_potion("Fogbrew", 1, "fogbrew", "Each opponent discards a card."))
			items.append(_a_potion("Dragon's Breath", 3, "dragons_breath", "Dragon's Breath deals 3 damage to any target."))
		Offer.WORDY:
			items.append(_an_armor("Seer's Cuirass", Slot.CUIRASS, "seers_cuirass", 2, load(DIVINERS_BOON) as MmCardDefinition))
			items.append(_a_mod("flashy"))
			items.append(_big_gulp())
	return items


## A made-up Potion on a Potion Icon the game has. Its words are the Satchel prototype's.
func _a_potion(potion_name: String, rarity: int, icon: String, words: String) -> Item:
	var item: Item = Item.new()
	item.kind = ItemKind.POTION
	item.name = potion_name
	item.rarity = rarity
	item.icon = load(POTION_ICONS % icon) as Texture2D
	item.type_line = "%s Potion" % RARITY_NAMES[rarity]
	item.words = [words]
	return item


## Big Gulp, the one Potion in Content, with its real rules text.
func _big_gulp() -> Item:
	var potion: MmCardDefinition = load(BIG_GULP) as MmCardDefinition
	var item: Item = _a_potion(potion.name, int(potion.rarity), "big_gulp", CardLook.of_definition(potion).rules_text)
	return item


## A Mod from Content, its words ModText's and its type line milestone 24's: its Rarity, the
## card types it accepts in alphabetical order joined by "/", and "Mod".
func _a_mod(file: String) -> Item:
	var mod: Mod = load(MODS % file) as Mod
	var item: Item = Item.new()
	item.kind = ItemKind.MOD
	item.name = mod.name
	item.rarity = int(mod.rarity)
	item.icon = load(MOD_ICONS % RARITY_NAMES[item.rarity].to_lower()) as Texture2D
	item.words = [ModText.of(mod)]
	var names: Dictionary[MmCardTypes.CardType, String] = {
		MmCardTypes.CardType.ARTIFACT: "Artifact", MmCardTypes.CardType.CREATURE: "Creature",
		MmCardTypes.CardType.ENCHANTMENT: "Enchantment", MmCardTypes.CardType.INSTANT: "Instant",
		MmCardTypes.CardType.LAND: "Land", MmCardTypes.CardType.SORCERY: "Sorcery",
	}
	var accepted: String = ""
	var has_land: bool = mod.card_types.has(MmCardTypes.CardType.LAND)
	if mod.card_types.size() >= names.size():
		accepted = "Omni"
	elif mod.card_types.size() == names.size() - 1 and not has_land:
		accepted = "Nonland"
	else:
		var named: Array[String] = []
		for card_type: MmCardTypes.CardType in mod.card_types:
			named.append(names[card_type])
		named.sort()
		accepted = "/".join(named)
	item.type_line = "%s %s Mod" % [RARITY_NAMES[item.rarity], accepted]
	return item


## A made-up Armor on an Armor Icon the game has, worded as the Satchel prototype's are.
func _an_armor(armor_name: String, slot: Slot, icon: String, life: int, emblem: MmCardDefinition) -> Item:
	var item: Item = Item.new()
	item.kind = ItemKind.ARMOR
	item.name = armor_name
	item.icon = load(ARMOR_ICONS % icon) as Texture2D
	item.type_line = SLOT_NAMES[slot]
	item.slot = slot
	if life > 0:
		item.words.append(LIFE_WORDS % life)
	item.emblem = emblem
	return item


## The color of [param item]'s Rarity plate.
func _tint_of(item: Item) -> Color:
	return UNIQUE_TINT if item.rarity >= TINTS.size() else TINTS[maxi(item.rarity, 0)]


## An Armor Slot's template, the faint outline an empty one shows. The templates are kept
## out of Godot's imports, so the file is read as it is.
func _armor_template(slot: Slot) -> Texture2D:
	var path: String = ProjectSettings.globalize_path(ARMOR_TEMPLATES % SLOT_NAMES[slot].to_lower())
	return ImageTexture.create_from_image(Image.load_from_file(path))


## The debug run the command line asks for. Not every map has a Trove: one that has none
## gives way to the next Run Seed's that has.
func _a_run_with_a_trove() -> Run:
	var run: Run = StageMapScreen.debug_run_from(_arguments)
	for run_seed: int in range(1, 60):
		if SpoilsScreen._leads_to(run.stage_visit.map, run.stage_visit.current, StageMap.Kind.TROVE):
			break
		var again: PackedStringArray = _arguments.duplicate()
		again.append("--run-seed=%d" % run_seed)
		run = StageMapScreen.debug_run_from(again)
	return run


## Walks the debug run toward a Trove, winning what stands in the way: onto the Trove, so
## that layout B's still Stage Map shows the Hero where one is opened, or, if it
## [param stops_at_its_elite], only as far as the Elite Encounter before it, just played.
## That one is lost when the prototype is set so. A map with no Trove ahead is left alone.
func _walk_toward_a_trove(run: Run, stops_at_its_elite: bool) -> void:
	var visit: StageVisit = run.stage_visit
	if not SpoilsScreen._leads_to(visit.map, visit.current, StageMap.Kind.TROVE):
		return
	for step: int in 60:
		if visit.node().kind == StageMap.Kind.TROVE:
			return
		if visit.must_play():
			var is_its_elite: bool = visit.node().kind == StageMap.Kind.ELITE
			run.record_encounter(not (is_its_elite and _is_elite_lost))
			if is_its_elite and stops_at_its_elite:
				return
			continue
		var choices: Array[int] = visit.choices()
		if choices.is_empty():
			return
		var next: int = choices[0]
		for id: int in choices:
			if SpoilsScreen._leads_to(visit.map, id, StageMap.Kind.TROVE):
				next = id
				break
		run.move_to(next)


# ---------------------------------------------------------------------------------------
# What the layouts share.

func _ground() -> Panel:
	return StageIntro.ground_panel(_run.stage_visit.stage)


## Ink or light text, whichever shows on the Stage's ground.
func _ground_ink() -> Color:
	return INK if StageIntro.ground_of(_run.stage_visit.stage).get_luminance() > 0.5 else TEXT


## The Spoils' window in the middle of the screen, at least [param width] wide, and the
## column inside it.
func _window_column(width: float) -> VBoxContainer:
	var centered: CenterContainer = CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(centered)
	var window: PanelContainer = PanelContainer.new()
	window.custom_minimum_size = Vector2(width, 0)
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade: Callable = func() -> void:
		var face: StyleBoxTexture = DitherShading.plate(WINDOW_COLOR.lightened(0.06), WINDOW_COLOR.darkened(0.3),
				WINDOW_EDGE, WINDOW_RADIUS, 2, 0, maxi(int(window.size.y), WINDOW_RADIUS * 2 + 4))
		face.set_content_margin_all(WINDOW_MARGIN)
		window.add_theme_stylebox_override("panel", face)
	shade.call()
	window.resized.connect(shade)
	centered.add_child(window)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	window.add_child(column)
	return column


## "Trove", bold, on the Spoils' dithered gray bar.
func _heading_bar() -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.add_theme_stylebox_override("panel", DitherShading.plate(BAR_COLOR.lightened(0.1), BAR_COLOR.darkened(0.25),
			BAR_EDGE, BAR_RADIUS, 2, 0, BAR_HEIGHT))
	var words: Label = _text(TITLE, 32, TEXT, true, true)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(words)
	return bar


## A parchment panel, shaded with Dither Shading over its own height.
func _paper_panel(padding: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade: Callable = func() -> void:
		var made: StyleBoxTexture = DitherShading.plate(PAPER.lightened(PAPER_LIGHTEN), PAPER.darkened(PAPER_DARKEN),
				PAPER_EDGE, PAPER_RADIUS - PAPER_EDGE_WIDTH, PAPER_EDGE_WIDTH, 0,
				maxi(int(panel.size.y), PAPER_RADIUS * 2 + 1))
		made.content_margin_left = padding.x
		made.content_margin_right = padding.x
		made.content_margin_top = padding.y
		made.content_margin_bottom = padding.y
		panel.add_theme_stylebox_override("panel", made)
	shade.call()
	panel.resized.connect(shade)
	return panel


## [param item]'s picture at [param scale] times its size: a Potion Icon on a raised plate
## in its Rarity's color, an Armor Icon straight on the parchment (ADR 0033), and a Mod's cog
## straight on it too, since the cog is in its Rarity's color itself.
func _icon_tile(item: Item, scale: int) -> Control:
	var side: float = 32.0 * scale
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(side + 4, side + 4)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = StyleBoxEmpty.new()
	if item.kind == ItemKind.POTION:
		var tint: Color = _tint_of(item)
		style = DitherShading.plate(tint.lightened(0.18), tint.darkened(0.2), SET_IN_EDGE, 8, 2, 0, int(side) + 4)
	frame.add_theme_stylebox_override("panel", style)
	var picture: TextureRect = _picture(item.icon)
	picture.position = Vector2(2, 2)
	picture.size = Vector2(side, side)
	frame.add_child(picture)
	return frame


## What [param item] does, under [param block]: a sentence to a line, then the Emblem an
## Armor brings, its name and its rules text set in.
func _add_words(block: VBoxContainer, item: Item, font_size: int) -> void:
	for line: String in item.words:
		block.add_child(_words(line, font_size))
	if item.emblem == null:
		return
	var look: CardLook = CardLook.of_definition(item.emblem)
	block.add_child(_words(EMBLEM_WORDS, font_size))
	var inset: MarginContainer = MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 20)
	var emblem: VBoxContainer = VBoxContainer.new()
	emblem.add_theme_constant_override("separation", 0)
	emblem.add_child(_text(look.name, font_size, INK, true))
	emblem.add_child(_words(look.rules_text, font_size))
	inset.add_child(emblem)
	block.add_child(inset)


## Makes [param surface] the place a click picks the Item [param index], with a pointing
## hand over it. Its ring while it is picked and its wash under the cursor are drawn on
## [param canvas], rounded by [param radius]. Everything under [param surface] is deaf to
## the mouse, so the cursor is over the surface wherever it is on it.
func _make_pickable(surface: Control, canvas: Control, index: int, radius: int) -> void:
	_deafen(surface)
	_surfaces[index] = canvas
	_click_targets[index] = surface
	var ring: StyleBoxFlat = _flat(Color(0, 0, 0, 0), radius)
	ring.draw_center = false
	ring.set_border_width_all(RING_WIDTH)
	ring.border_color = RING
	var wash: StyleBoxFlat = _flat(WASH, radius)
	canvas.draw.connect(func() -> void:
		var all: Rect2 = Rect2(Vector2.ZERO, canvas.size)
		if _hovered == index and _taken == -1:
			canvas.draw_style_box(wash, all)
		if _selected == index or _taken == index:
			canvas.draw_style_box(ring, all))
	if _taken != -1:
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	surface.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	surface.mouse_entered.connect(func() -> void: _point_at(index))
	surface.mouse_exited.connect(func() -> void:
		if _hovered == index:
			_point_at(-1))
	surface.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_pick.call_deferred(index))


## A white ring round [param canvas], drawn on it: on an entry just taken, and on the Armor
## Slot a taken Armor was put on in.
func _ring_on(canvas: Control, radius: int) -> void:
	var ring: StyleBoxFlat = _flat(Color(0, 0, 0, 0), radius)
	ring.draw_center = false
	ring.set_border_width_all(RING_WIDTH)
	ring.border_color = RING
	canvas.draw.connect(func() -> void: canvas.draw_style_box(ring, Rect2(Vector2.ZERO, canvas.size)))


## What the Hero wears before anything is taken.
func _worn_at_first() -> Dictionary[Slot, Texture2D]:
	var worn: Dictionary[Slot, Texture2D] = {}
	for slot: Slot in WORN:
		worn[slot] = load(ARMOR_ICONS % WORN[slot]) as Texture2D
	return worn


func _deafen(node: Node) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deafen(child)


## Grays [param part] while another Item is selected, and fades it once another is taken.
func _fade_unpicked(part: Control, index: int) -> void:
	if _taken != -1 and index != _taken:
		part.modulate = Color(1, 1, 1, 0.25)
	elif _taken == -1 and _selected != -1 and index != _selected:
		part.modulate = Color(0.72, 0.72, 0.72)


## The Take button, in the Steel Frame as the Spoils' Continue is, off unless [param is_live].
func _take_button(is_live: bool, width: int, height: int = BUTTON_HEIGHT, font_size: int = 26) -> Button:
	var button: Button = Button.new()
	button.text = TAKE
	button.custom_minimum_size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not is_live
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", UiText.bold())
	button.add_theme_font_size_override("font_size", font_size)
	SteelFrame.frame_roomy(button, BUTTON_FILL, height)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", ButtonShading.DISABLED_TEXT)
	if is_live:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_take)
	return button


## [param item] in a frame that draws only a drop shadow, from a box rounded by
## [param radius], dropped [param drop] pixels.
func _shadowed(item: Control, radius: int, drop: float) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_horizontal = item.size_flags_horizontal
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _flat(Color(0, 0, 0, 0), radius)
	style.shadow_color = SHADOW
	style.shadow_size = SHADOW_SIZE
	style.shadow_offset = Vector2(0, drop)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(item)
	return frame


## The flat, dark-edged ground of something set into the window.
func _set_in(radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = _flat(SLOT_GROUND, radius)
	style.set_border_width_all(2)
	style.border_color = SET_IN_EDGE
	return style


func _flat(fill: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style


func _gap(height: float) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _picture(texture: Texture2D) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _text(text: String, font_size: int, color: Color, is_bold: bool, is_centered: bool = false) -> Label:
	var made: Label = Label.new()
	made.text = text
	if is_centered:
		made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	return made


## [param label], wrapping at its width.
func _wrapping(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## A line of what an Item does, its mana symbols drawn as a card's are.
func _words(text: String, font_size: int) -> SymbolLabel:
	var made: SymbolLabel = SymbolLabel.new()
	made.set_font_size(font_size)
	made.write_in(text, INK)
	return made


# ---------------------------------------------------------------------------------------
# The prototype's own bar, which is no part of any layout.

func _add_prototype_bar() -> void:
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_screen.add_child(layer)
	var yellow: Color = Color(1, 0.85, 0.3)
	var dock: CenterContainer = CenterContainer.new()
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -64
	dock.offset_bottom = -12
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dock)
	var pill: PanelContainer = PanelContainer.new()
	var black: StyleBoxFlat = _flat(Color(0.04, 0.04, 0.06, 0.94), 24)
	black.set_border_width_all(2)
	black.border_color = yellow
	black.content_margin_left = 14
	black.content_margin_right = 14
	black.content_margin_top = 6
	black.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", black)
	dock.add_child(pill)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	row.add_child(_bar_button("<", func() -> void: _show_layout(posmod(_layout - 1, Layout.size()) as Layout)))
	var label: Label = _text("PROTOTYPE · %s · %d of %d" % [LAYOUT_NAMES[_layout], _layout + 1, Layout.size()], 20, yellow, true)
	row.add_child(label)
	row.add_child(_bar_button(">", func() -> void: _show_layout(posmod(_layout + 1, Layout.size()) as Layout)))
	var left: HBoxContainer = HBoxContainer.new()
	left.position = Vector2(16, 1080 - 52)
	left.add_theme_constant_override("separation", 8)
	layer.add_child(left)
	left.add_child(_bar_button("Items (I): %s" % OFFER_NAMES[_offer], func() -> void:
		_offer = posmod(_offer + 1, Offer.size()) as Offer
		_items = _items_of(_offer)
		_reset()))
	left.add_child(_bar_button("Reset (R)", _reset))
	left.add_child(_bar_button("Elite (L): %s" % ("lost" if _is_elite_lost else "won"), func() -> void:
		_is_elite_lost = not _is_elite_lost
		_reset()))
	var state: Label = _text(_state_text(), 18, yellow, false)
	_state_label = state
	var plate: PanelContainer = PanelContainer.new()
	var dark: StyleBoxFlat = _flat(Color(0.04, 0.04, 0.06, 0.94), 8)
	dark.content_margin_left = 10
	dark.content_margin_right = 10
	dark.content_margin_top = 4
	dark.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", dark)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.offset_right = -16
	plate.offset_bottom = -16
	plate.add_child(state)
	layer.add_child(plate)


func _bar_button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	return button


## What the prototype's state line says, kept up each frame.
func _state_text() -> String:
	if _layout != Layout.ARRIVING or _walk_run == null:
		return "Hero on: %s · selected: %s · taken: %s" % [
				StageMapScreen.KIND_NAMES[_run.stage_visit.node().kind], _name_of(_selected), _name_of(_taken)]
	var trove: String = "open" if _is_trove_open else ("closed, an Item taken" if _is_trove_done else "click its glowing Node")
	var put_on: String = "" if _put_on == -1 else ", put on"
	return "Hero on: %s · Trove: %s · taken: %s%s" % [
			StageMapScreen.KIND_NAMES[_walk_run.stage_visit.node().kind], trove, _name_of(_taken), put_on]


func _name_of(index: int) -> String:
	return "none" if index == -1 else _items[index].name
