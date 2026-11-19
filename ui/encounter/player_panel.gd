class_name PlayerPanel
extends Control
## One player's Player Panel in the sidebar: their name as it is written, their Portrait with their life total in
## its corner, a button for each color of mana in their pool, the Emblems button, and every
## step of the turn down the right side. Green steps have a stop; the step it is now has a
## pale Glow on the active player's panel, and the panel of the player with priority has
## one all round it (A477, A478). While the player can be chosen, their portrait alone
## glows and takes the click, never the whole panel. The Hero's panel has the Potions
## button under the Emblems button, which opens the Potions window, and under that Undo
## and Yield Turn; the Pass Button is not here but over the Info Panel (A489). The
## Villain's panel says when the Villain is thinking, under its Emblems button (A294),
## wrapped downward to as many lines as it takes. A name too long for its box glides from
## one end to the other and back (NameGlide), clipped to the box.
##
## It takes the Inspector's treatment, in the Inspector's colors (ADR 0033): an edged panel
## with Dither Shading, dithered buttons, and the Hero's controls on an entry's plate. The
## buttons' plates keep little room round their text, so that nothing grows past its box,
## and the Portrait lies on a flat square, so the dithering does not show through it.
##
## Unlike the board, a panel is not rebuilt from each snapshot. It is built once for its
## size, and each snapshot only changes what it shows differently: building its thirty-odd
## buttons took six to nine milliseconds a panel, most of it laying out the two symbols on
## them, which are characters from a fallback font. Whatever the screen draws on the
## portrait (a damage stepper, a Stack Mark) is cleared here on every snapshot.

## A mana button was pressed while paying: [param answer] spends one mana of that color.
signal mana_pressed(answer: int)
signal emblems_pressed
## The Hero's Potions button was pressed: open or close the Potions window.
signal potions_pressed
## The panel was clicked while its player could be chosen: [param answer] chooses them.
signal player_clicked(answer: int)
## A step button was pressed: toggle the stop there on this panel's row.
signal stop_toggled(step: MmTurn.Step)
## The Hero's controls, under their Potions button.
signal undo_pressed
signal yield_toggled

const STEP_NAMES: Array[String] = [
	"Untap", "Upkeep", "Draw", "Main 1", "Begin Combat", "Attackers", "Blockers", "Damage", "End Combat",
	"Main 2", "End", "Cleanup",
]
const GOLD: Color = Color("#c9a544")
const STOP_COLOR: Color = Color("#2f8f46")
const PLAIN_COLOR: Color = Color("#3a414d")
const NOW_COLOR: Color = Color("#f3e9a0")
## What the Villain's panel says while they think, with the Villain as they are named.
const THINKING_FORMAT: String = "%s is thinking…"
## The height the first line of it is centered on; more lines go on down the panel.
const THINKING_LINE: float = 34.0
const UNDO_FORMAT: String = "Undo [%s]"
const POTIONS_FORMAT: String = "⚗  Potions (%d)"
const POTION_COLOR: Color = Color("#9a63d8")
const NO_ITEMS_COLOR: Color = Color("#6b7280")
## How rounded the panel is.
const RADIUS: int = 8
## How much of its tint the Emblems or the Potions button takes over the panel's color.
const HELD_SHARE: float = 0.4
## The color a button is drawn in, kept on it.
const TINT: StringName = &"tint"
## The room a button's plate keeps at its sides: "Begin Combat" fits its step only with this.
const BUTTON_SIDE: int = 2
## How long a Glow takes to ease in or out, the priority Glow among them; the Encounter
## Screen sets it.
var glow_seconds: float = 0.0
## The player's own Portrait, drawn in place of PlayerPortraits' placeholder; set before the
## first snapshot. Screen sets it.
var portrait_override: Texture2D = null
## The Pain Portrait given with portrait_override; null for none, and then the player never
## winces. Unread without portrait_override. Screen sets it.
var pain_override: Texture2D = null
## How much longer the Pain Portrait shows; INF for a player who lost the encounter to it.
var _pain_left: float = 0.0
## The Portrait's Breath once start_breathing() is called; until then it stays at rest, as
## in tests and screenshots.
var _breath: Breath = null
## When the Blink Portrait shows, from start_breathing(); and the Blink Portrait, null for a
## Portrait that has none, which then never blinks.
var _blink: Blink = null
var _blink_texture: Texture2D = null
## The player's life now and on the first snapshot, which is what their Breath reads.
var _life_now: int = 0
var _starting_life: int = 0
var _player_id: int
var _title: String
var _is_hero: bool = false
var _built_for: Vector2 = Vector2.ZERO
## What holds the priority Glow, which is shown and hidden as a whole.
var _priority: Control = null
## The key that undoes, as the Undo button names it.
var _undo_key: String = "Z"
var _potions: Button = null
var _has_potions: Variant = null
var _picture: BreathingPortrait = null
var _life: Label = null
var _emblems: Button = null
var _is_emblems_gold: Variant = null
var _mana: Array[Button] = []
var _mana_counts: Array[Label] = []
## While paying: mana type → the answer that spends one unit of it.
var _pay_answers: Dictionary[MmMana.Type, int] = {}
## Mana types whose button glows without taking a press: what Auto-tap would spend, or is
## about to (the Tap Preview).
var _pool_marks: Array[MmMana.Type] = []
var _steps: Array[Button] = []
## How each step button is drawn now: 1 for a stop, plus 2 for the step it is.
var _step_looks: Array[int] = []
var _undo: Button = null
var _yield: Button = null
var _thinking: Label = null
## What the name is clipped to, and the name in it.
var _name_box: Control = null
var _name: Label = null
var _name_glide: NameGlide = NameGlide.new(0.0)
var _portrait: Panel = null
var _backing: Panel = null
var _controls: Panel = null
var _portrait_edge: Panel = null
var _portrait_back: Panel = null


## [param title] is what the panel calls its player until a snapshot names them.
func _init(player_id: int, title: String) -> void:
	_player_id = player_id
	_title = title
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param snapshot] in [param panel_rect]. [param is_hero] says whose mana buttons can
## be pressed (only the Hero's, and only while paying) and whose panel has the Potions
## button and the controls: undo and Yield Turn, with [param is_yielding] for its box.
func show_snapshot(snapshot: EncounterSnapshot, clicks: DecisionClicks, stops: StepStops, panel_rect: Rect2, is_hero: bool,
		is_yielding: bool) -> void:
	position = panel_rect.position
	size = panel_rect.size
	var is_new: bool = panel_rect.size != _built_for or is_hero != _is_hero
	if is_new:
		_build(panel_rect.size, is_hero)
	var view: MmPlayerView = snapshot.view
	# The priority Glow eases from one panel to the other; a panel just built shows it at once.
	var has_priority: bool = view.priority_player_id == _player_id
	if is_new:
		_priority.visible = has_priority
	elif has_priority:
		Easing.appear(_priority, glow_seconds)
	else:
		Easing.disappear(_priority, glow_seconds)
	_show_portrait(clicks)
	_set_text(_life, str(view.life_totals.get(_player_id, 0)))
	_read_life(view)

	var pool: Array = view.mana_pools.get(_player_id, [])
	_pay_answers = clicks.pool_answers.duplicate() if is_hero else ({} as Dictionary[MmMana.Type, int])
	_pool_marks = clicks.pool_marks.duplicate() if is_hero else ([] as Array[MmMana.Type])
	for type: int in 6:
		var amount: int = 0
		for unit: MmMana in pool:
			if unit.type == type:
				amount += 1
		_show_mana(type, amount)

	_show_name(snapshot.names.of(_player_id))
	var emblems: Array[MmObjectView] = snapshot.emblems_of(_player_id)
	_show_emblems(emblems.size(), HeldState.emblems_look(emblems, clicks))

	for step: int in STEP_NAMES.size():
		_show_step(step, stops.has_stop(_player_id, step), view.active_player_id == _player_id and view.step == step)
	if is_hero:
		var potions: Array[MmObjectView] = snapshot.potions_of(_player_id)
		_show_potions(potions.size(), HeldState.potions_look(potions, clicks))
		_undo.disabled = not snapshot.can_undo or snapshot.is_villain_thinking
		_set_text(_yield, ("☑" if is_yielding else "☐") + "  Yield Turn")
	else:
		_thinking.visible = snapshot.is_villain_thinking
		_show_thinking(THINKING_FORMAT % snapshot.names.starting(_player_id))


## Opens or closes the undo button, for a half-made choice whose clicks can be taken back
## while nothing else can.
func show_undo(is_open: bool) -> void:
	if _undo != null:
		_undo.disabled = not is_open


## Names [param key_label] on the Undo button as the key that undoes: "Undo [Z]".
func show_undo_key(key_label: String) -> void:
	_undo_key = key_label
	if _undo != null:
		_set_text(_undo, UNDO_FORMAT % key_label)


## The undo and Yield Turn buttons: null on the Villain's panel.
func undo_button() -> Button:
	return _undo


## The Potions button: null on the Villain's panel.
func potions_button() -> Button:
	return _potions


## What holds the Glow that says the panel's player has priority: shown while they have it.
func priority_glow() -> Control:
	return _priority


## The Portrait the panel shows, its Pain Portrait while the player winces, or null for a
## player who has none.
func portrait_texture() -> Texture2D:
	return _picture.texture() if _picture != null else null


## The Portrait in its square, as it breathes: null for a player who has none.
func breathing_portrait() -> BreathingPortrait:
	return _picture


## The Portrait's Breath, or null until start_breathing().
func breath() -> Breath:
	return _breath


## The Portrait starts to breathe, at its character's Breath Rate and Breath Intensity, and
## to blink, both from where [param encounter_seed] says. The Encounter Screen calls it in a
## real encounter.
func start_breathing(encounter_seed: int, values: BreathValues = null) -> void:
	if values == null:
		values = BreathValues.load_from()
	var key: String = BreathValues.key_of(_portrait_texture())
	_breath = Breath.new(values.rate_of(key), values.intensity_of(key))
	_breath.phase = Breath.start_phase(encounter_seed, _player_id)
	_blink = Blink.new(encounter_seed, _player_id)
	_blink_texture = blink_of(_portrait_texture())
	_show_breath()
	set_process(true)


## The player was hurt: their Pain Portrait shows for [param seconds], or for as long as
## it already had left if that is longer, or for good when [param stays] (they lost the
## encounter). A player with no Pain Portrait does not wince.
func wince(seconds: float, stays: bool = false) -> void:
	if _pain_texture() == null:
		return
	_pain_left = INF if stays else maxf(_pain_left, seconds)
	if _breath != null:
		_breath.wind()
	_show_picture()
	set_process(true)


## Whether the Pain Portrait is showing.
func is_wincing() -> bool:
	return _pain_left > 0.0


## Lets [param seconds] of a wince and of a breath pass; the Portrait comes back when the
## wince is over, and breathes again.
func advance(seconds: float) -> void:
	_glide_name(seconds)
	var breathed: float = seconds
	if _pain_left > 0.0:
		var pain_was: float = _pain_left
		_pain_left = maxf(_pain_left - seconds, 0.0)
		if _pain_left == 0.0:
			_show_picture()
			if _breath != null:
				_breath.catch_breath()
				# Only what is left after the wince is breathed.
				breathed = seconds - pain_was
	if _breath != null:
		_breath.advance(breathed, _life_now, _starting_life)
		_show_breath()
		var was_shut: bool = _is_blinking()
		_blink.advance(seconds)
		if _is_blinking() != was_shut:
			_show_picture()
	elif _pain_left == 0.0 and not _name_glide.is_gliding():
		set_process(false)


## The life the Breath reads, and whether the player has lost, from [param view].
func _read_life(view: MmPlayerView) -> void:
	_life_now = view.life_totals.get(_player_id, 0)
	if _starting_life == 0:
		_starting_life = _life_now
	var has_lost: bool = view.is_over and view.winner_id != _player_id and view.life_totals.has(view.winner_id)
	if has_lost and _breath != null:
		_breath.stop()
		_show_breath()


func _show_breath() -> void:
	if _picture != null and _breath != null:
		_picture.show_growth(_breath.growth())


func _process(delta: float) -> void:
	advance(delta)


func _portrait_texture() -> Texture2D:
	return portrait_override if portrait_override != null else PlayerPortraits.texture_of(_player_id)


func _pain_texture() -> Texture2D:
	return pain_override if portrait_override != null else PlayerPortraits.pain_of(_player_id)


func _shown_portrait() -> Texture2D:
	if is_wincing():
		return _pain_texture()
	return _blink_texture if _is_blinking() else _portrait_texture()


## Whether the Blink Portrait shows: the eyes are shut, and the player has one and has not
## lost.
func _is_blinking() -> bool:
	return _blink != null and _blink_texture != null and _blink.is_shut() and not _breath.is_stopped()


## The Blink Portrait drawn beside [param portrait], named after it, or null for none.
static func blink_of(portrait: Texture2D) -> Texture2D:
	if portrait == null or portrait.resource_path == "":
		return null
	var path: String = portrait.resource_path.get_basename() + "_blink.png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _show_picture() -> void:
	if _picture != null:
		_picture.set_texture(_shown_portrait())


func yield_button() -> Button:
	return _yield


## The panel's Dither Shaded panel, behind everything on it.
func backing() -> Panel:
	return _backing


## The entry plate the Hero's controls sit on: null on the Villain's panel.
func controls_plate() -> Panel:
	return _controls


## The flat square the Portrait lies on: null for a player who has none.
func portrait_back() -> Panel:
	return _portrait_back


## The edge round the Portrait: null for a player who has none.
func portrait_edge() -> Panel:
	return _portrait_edge


func name_label() -> Label:
	return _name


## The box the name is clipped to.
func name_box() -> Control:
	return _name_box


## Whether the name is too long for its box, and so glides.
func is_name_gliding() -> bool:
	return _name_glide.is_gliding()


func thinking_label() -> Label:
	return _thinking


## The color [param button], a step or the Emblems, Potions or Undo button, is drawn in.
static func tint_of(button: Button) -> Color:
	return button.get_meta(TINT)


## What the Emblems or the Potions button is filled with when drawn in [param tint].
static func held_fill(tint: Color) -> Color:
	return Inspector.palette().panel.lerp(tint, HELD_SHARE)


## The player's name as the panel shows it.
func name_text() -> String:
	return _name.text


## What the panel says about its player thinking: that they are, by name, on the Villain's
## while they think, and "" otherwise.
func thinking_text() -> String:
	return _thinking.text if _thinking != null and _thinking.visible else ""


## The player's picture: what glows and is clicked while the player can be chosen. What is
## drawn on it from outside lasts until the next snapshot is shown.
func portrait() -> Panel:
	return _portrait


## What takes a click on the portrait while its player can be chosen, or null.
func click_catcher() -> ClickCatcher:
	return ClickCatcher.of(_portrait)


func life_text() -> String:
	return _life.text


func emblems_button() -> Button:
	return _emblems

## Whether the Emblems or the Potions button glows.
func is_glowing(button: Button) -> bool:
	return BorderEffects.glow_color(button) != null


## Makes the buttons for [param types] of mana glow, and only those, without any of them
## taking a press: the pool mana the Tap Preview says would be spent. Nothing is rebuilt.
## The next snapshot shown puts the Glows back to what it says.
func mark_pool(types: Array[MmMana.Type]) -> void:
	_pool_marks = types.duplicate()
	for type: int in _mana.size():
		_glow_mana(type)


## The button for mana of [param type], in WUBRGC order.
func mana_button(type: MmMana.Type) -> Button:
	return _mana[type]


func mana_count_text(type: MmMana.Type) -> String:
	return _mana_counts[type].text


func step_button(step: MmTurn.Step) -> Button:
	return _steps[step]


## Whether the button for [param step] is drawn as having a stop.
func shows_stop(step: MmTurn.Step) -> bool:
	return _steps[step].get_meta("has_stop")


## Whether the button for [param step] has the Glow of the step it is now.
func shows_now(step: MmTurn.Step) -> bool:
	return _step_looks[step] >= 2


## Makes everything the panel has, for a panel of [param panel_size]. What each thing shows
## is filled in by show_snapshot().
func _build(panel_size: Vector2, is_hero: bool) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_built_for = panel_size
	_is_hero = is_hero
	_mana.clear()
	_mana_counts.clear()
	_steps.clear()
	_step_looks.clear()
	_is_emblems_gold = null
	_undo = null
	_yield = null
	_thinking = null
	_potions = null
	_has_potions = null
	_picture = null
	_controls = null
	_portrait_edge = null
	_portrait_back = null
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, panel_size))
	var palette: InspectorParts.Palette = Inspector.palette()
	_backing = Panel.new()
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.size = panel_size
	add_child(_backing)
	InspectorParts.shade_background(_backing, null, palette.panel, palette.edge, palette.edge_width, RADIUS)
	_priority = Control.new()
	_priority.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_priority.size = panel_size
	BorderEffects.add_glow(_priority, panel_size, NOW_COLOR)
	add_child(_priority)
	_name_box = Control.new()
	_name_box.clip_contents = true
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_box.position = parts["name"].position
	_name_box.size = parts["name"].size
	add_child(_name_box)
	_name = _label("", Rect2(Vector2.ZERO, parts["name"].size), 22)
	_name_box.add_child(_name)
	_show_name(_title)
	_add_portrait(parts["portrait"])
	var life_box: Panel = CardShapes.rounded(parts["life"].size, 8, Color(0.05, 0.05, 0.07, 0.6))
	life_box.position = parts["life"].position
	add_child(life_box)
	_life = _label("", parts["life"], 42)
	add_child(_life)
	for type: int in 6:
		_add_mana_button(parts["mana_%d" % type], type)
	_emblems = Button.new()
	_emblems.focus_mode = Control.FOCUS_NONE
	_emblems.position = parts["emblems"].position
	_emblems.size = parts["emblems"].size
	_emblems.add_theme_color_override("font_color", Color("#f1dc9a"))
	_emblems.add_theme_color_override("font_hover_color", Color("#fff3c4"))
	_emblems.add_theme_color_override("font_disabled_color", Color("#9aa1ad"))
	_emblems.pressed.connect(func() -> void: emblems_pressed.emit())
	add_child(_emblems)
	for step: int in STEP_NAMES.size():
		_add_step_button(parts["step_%d" % step], step)
	if is_hero:
		_add_potions(parts["potions"])
		_add_controls(parts)
	else:
		var thinking_top: float = parts["potions"].position.y
		_thinking = _label("", Rect2(parts["potions"].position.x, thinking_top, parts["potions"].size.x,
			panel_size.y - thinking_top - EncounterLayout.PANEL_PAD), 16)
		_thinking.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_thinking.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_thinking.modulate = Color(1, 0.85, 0.4)
		add_child(_thinking)
		# One line sits where it always has, centered on THINKING_LINE. Measured in the tree,
		# where the label has the game's font.
		var shift: float = (THINKING_LINE - _thinking.get_line_height()) / 2.0
		_thinking.position.y += shift
		_thinking.size.y -= shift


## A player's Portrait is drawn pixel for pixel, six screen pixels to each of its own, and
## grows a little as it breathes, cropped to its square (BreathingPortrait); what glows and
## is clicked lies over it and draws nothing. A player with no Portrait has
## a plain gray square.
func _add_portrait(box: Rect2) -> void:
	var texture: Texture2D = _shown_portrait()
	if texture == null:
		_portrait = CardShapes.rounded(box.size, 8, Color("#444c5a"))
	else:
		# Flat, so the dithering does not show through the picture's empty pixels.
		_portrait_back = CardShapes.rounded(box.size, 0, Inspector.palette().panel)
		_portrait_back.position = box.position
		_portrait_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_portrait_back)
		_picture = BreathingPortrait.new(box)
		_picture.set_texture(texture)
		add_child(_picture)
		_show_breath()
		_portrait_edge = CardShapes.outline(box.size, 0, 2, Inspector.palette().edge)
		_portrait_edge.position = box.position
		add_child(_portrait_edge)
		_portrait = Panel.new()
		_portrait.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait.size = box.size
	_portrait.position = box.position
	add_child(_portrait)


## The portrait glows and takes a click while its player can be chosen. Whatever else was
## drawn on it since the last snapshot is taken off; a Glow that has not changed is kept as
## it is, and one that has eases.
func _show_portrait(clicks: DecisionClicks) -> void:
	for child: Node in _portrait.get_children():
		if child.name == BorderEffects.GLOW or String(child.name).begins_with(BorderEffects.LEAVING):
			continue
		_portrait.remove_child(child)
		child.queue_free()
	_portrait.modulate = Color.WHITE
	if clicks.players.has(_player_id):
		BorderEffects.set_glow(_portrait, _portrait.size, DecisionClicks.color_of(clicks.players[_player_id]), glow_seconds)
	else:
		BorderEffects.remove_glow(_portrait, glow_seconds)
	if clicks.player_answers.has(_player_id):
		var answer: int = clicks.player_answers[_player_id]
		ClickCatcher.add(_portrait, _portrait.size).clicked.connect(func() -> void: player_clicked.emit(answer))


## A mana button is dim with none of its color, and glows and can be pressed while that
## color can pay.
func _show_mana(type: int, amount: int) -> void:
	var button: Button = _mana[type]
	var can_press: bool = _pay_answers.has(type)
	button.disabled = not can_press
	button.modulate = Color(1, 1, 1, 1.0 if amount > 0 else 0.55)
	_set_text(_mana_counts[type], "(%d)" % amount)
	_glow_mana(type)


## A mana button glows while its color can pay, or is marked as about to be spent.
func _glow_mana(type: int) -> void:
	var button: Button = _mana[type]
	var glows: bool = _pay_answers.has(type) or _pool_marks.has(type)
	if glows != (BorderEffects.glow_color(button) != null):
		if glows:
			BorderEffects.add_glow(button, button.size, DecisionClicks.color_of(DecisionClicks.Kind.MANA), glow_seconds)
		else:
			BorderEffects.remove_glow(button, glow_seconds)


## Gold while any Emblem has something left to give, and gray with none or once every one
## is used up; unpressable only with none, since a used-up Emblem can still be read. It
## glows green while one could be activated now (A520, A526, A537).
func _show_emblems(count: int, look: HeldState.Look) -> void:
	_set_text(_emblems, "⛨  Emblems (%d)" % count)
	_emblems.disabled = count == 0
	_show_usable(_emblems, look == HeldState.Look.GLOWING)
	var is_gold: bool = look != HeldState.Look.GRAY
	if _is_emblems_gold is bool and _is_emblems_gold == is_gold:
		return
	_is_emblems_gold = is_gold
	_tint(_emblems, GOLD if is_gold else NO_ITEMS_COLOR)


## Purple with Potions held and gray with none, as the Emblems button is gold or gray; it
## opens the Potions window, so it takes no press with none. It glows green while one
## could be used now (A526, A537).
func _show_potions(count: int, look: HeldState.Look) -> void:
	_set_text(_potions, POTIONS_FORMAT % count)
	_potions.disabled = count == 0
	# With none it does not even light up under the cursor.
	_potions.mouse_filter = Control.MOUSE_FILTER_IGNORE if count == 0 else Control.MOUSE_FILTER_STOP
	_show_usable(_potions, look == HeldState.Look.GLOWING)
	if _has_potions is bool and _has_potions == (count > 0):
		return
	_has_potions = count > 0
	var tint: Color = POTION_COLOR if count > 0 else NO_ITEMS_COLOR
	_potions.add_theme_color_override("font_color", Color("#dcc6f7"))
	_potions.add_theme_color_override("font_hover_color", Color("#f0e4ff"))
	_potions.add_theme_color_override("font_disabled_color", Color("#9aa1ad"))
	_tint(_potions, tint)


## Draws [param button], the Emblems or the Potions button, in [param tint]: Dither
## Shaded in the panel's color tinted toward it, flat while it cannot be pressed.
static func _tint(button: Button, tint: Color) -> void:
	# Its symbol comes from a taller fallback font, which leaves no room to lift the text
	# above the lip without the button growing.
	_shade(button, held_fill(tint), held_fill(tint), false)
	button.set_meta(TINT, tint)


## Gives [param button] Dither Shading in [param fill], and [param disabled_fill] while it
## cannot be pressed, with no more room round its text than "Begin Combat" fits its step
## with; without [param lifts_text] its text is centered on the whole plate.
static func _shade(button: Button, fill: Color, disabled_fill: Color, lifts_text: bool = true) -> void:
	ButtonShading.shade(button, fill, disabled_fill, BUTTON_SIDE, lifts_text)
	button.set_meta(TINT, fill)


## Gives [param button] the green Glow of something that can be used now, or takes it
## away. The Glow is an outline round the button, so it never tints what is inside.
func _show_usable(button: Button, is_usable: bool) -> void:
	if is_usable:
		BorderEffects.set_glow(button, button.size, DecisionClicks.color_of(DecisionClicks.Kind.PLAY), glow_seconds)
	else:
		BorderEffects.remove_glow(button, glow_seconds)



## A step with a stop is green, and the step it is now glows; a step just built shows its
## Glow at once.
func _show_step(step: int, has_stop: bool, is_now: bool) -> void:
	var look: int = (1 if has_stop else 0) + (2 if is_now else 0)
	if _step_looks[step] == look:
		return
	var seconds: float = 0.0 if _step_looks[step] == -1 else glow_seconds
	var was_now: bool = _step_looks[step] >= 2
	_step_looks[step] = look
	var button: Button = _steps[step]
	button.set_meta("has_stop", has_stop)
	var palette: InspectorParts.Palette = Inspector.palette()
	_shade(button, STOP_COLOR if has_stop else palette.button, palette.button_disabled)
	if is_now and not was_now:
		BorderEffects.add_glow(button, button.size, NOW_COLOR, seconds)
	elif was_now and not is_now:
		BorderEffects.remove_glow(button, seconds)


## Sets the text of [param node], a Button or a Label, only if it says something else:
## setting it lays it out again.
func _set_text(node: Control, text: String) -> void:
	if node.get("text") != text:
		node.set("text", text)


func _label(text: String, box: Rect2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = box.position
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The Potions button, in the Emblems button's style. It takes no press and does not
## light up under the cursor until the Hero holds a Potion.
func _add_potions(box: Rect2) -> void:
	_potions = Button.new()
	_potions.focus_mode = Control.FOCUS_NONE
	_potions.disabled = true
	_potions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_potions.position = box.position
	_potions.size = box.size
	_potions.pressed.connect(func() -> void: potions_pressed.emit())
	add_child(_potions)


## The Hero's controls, in a section of their own under the Potions button.
func _add_controls(parts: Dictionary[String, Rect2]) -> void:
	_controls = Panel.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_theme_stylebox_override("panel", InspectorParts.plate_style(Inspector.palette()))
	_controls.position = parts["controls"].position
	_controls.size = parts["controls"].size
	add_child(_controls)
	# Always there: grayed out when nothing can be undone (A245).
	_undo = _control(UNDO_FORMAT % _undo_key, parts["undo"], 16, func() -> void: undo_pressed.emit())
	_shade(_undo, Inspector.palette().button, Inspector.palette().button_disabled)
	_yield = _control("", parts["yield"], 17, func() -> void: yield_toggled.emit())
	_yield.flat = true


func _control(text: String, box: Rect2, font_size: int, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	button.pressed.connect(on_press)
	add_child(button)
	return button


func _add_mana_button(box: Rect2, type: int) -> void:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PLAIN_COLOR.lightened(0.18) if state == "hover" else PLAIN_COLOR
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	var pip: float = minf(box.size.x - 6.0, 24.0)
	button.add_child(CardShapes.image(ManaSymbols.texture((MmMana.SYMBOLS[type] as String).to_lower()),
			Rect2((box.size.x - pip) / 2.0, 5, pip, pip)))
	var count: Label = _label("", Rect2(0, 30, box.size.x, 22), 14)
	button.add_child(count)
	button.pressed.connect(func() -> void:
		if _pay_answers.has(type):
			mana_pressed.emit(_pay_answers[type]))
	add_child(button)
	_mana.append(button)
	_mana_counts.append(count)


func _add_step_button(box: Rect2, step: int) -> void:
	var button: Button = Button.new()
	button.text = STEP_NAMES[step]
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.position = box.position
	button.size = box.size
	button.add_theme_font_size_override("font_size", 14)
	# Untap and cleanup never hold a stop, so their buttons cannot be pressed.
	button.disabled = not StepStops.can_hold(step)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	button.pressed.connect(func() -> void: stop_toggled.emit(step))
	add_child(button)
	_steps.append(button)
	# No look yet: show_snapshot() gives it its first.
	_step_looks.append(-1)


## Changes a label's text only when it differs, since laying text out is not free.
## Heads the panel with [param player_name]: centered and still if it fits its box, and
## otherwise as wide as its words, gliding from its start. The same name keeps gliding
## where it was; another starts over.
func _show_name(player_name: String) -> void:
	if _name.text == player_name and _name.get_meta(&"box_width", -1.0) == _name_box.size.x:
		return
	_name.text = player_name
	_name.set_meta(&"box_width", _name_box.size.x)
	# As the label shapes it, kerning and all.
	var width: float = _name.get_minimum_size().x
	_name_glide = NameGlide.new(width - _name_box.size.x)
	if _name_glide.is_gliding():
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_name.size = Vector2(ceilf(width), _name_box.size.y)
		set_process(true)
	else:
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.size = _name_box.size
	_name.position = Vector2.ZERO


func _glide_name(seconds: float) -> void:
	if _name_glide.is_gliding():
		_name_glide.advance(seconds)
		_name.position.x = _name_glide.offset()


func _show_thinking(text: String) -> void:
	_set_label(_thinking, text)


static func _set_label(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
