class_name PlayerPanel
extends Control
## One player's panel in the sidebar: their name, their Portrait with their life total in
## its corner, a button for each color of mana in their pool, the Emblems button, and every
## step of the turn down the right side. Green steps have a stop; the step it is now has a
## pale Glow on the active player's panel, and the panel of the player with priority has
## one all round it (A477, A478). While the player can be chosen, their portrait alone
## glows and takes the click, never the whole panel. The Hero's panel has the Potions
## button under the Emblems button, which opens the Potions window, and under that Undo
## and Yield Turn; the Pass Button is not here but over the Info Panel (A489). The
## Villain's panel says when the Villain is thinking, under its Emblems button (A294).
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
const THINKING: String = "The Villain is thinking…"
## The same for a Villain with a name of their own.
const THINKING_FORMAT: String = "%s is thinking…"
const UNDO_FORMAT: String = "Undo [%s]"
const POTIONS_FORMAT: String = "⚗  Potions (%d)"
const POTION_COLOR: Color = Color("#9a63d8")
const NO_ITEMS_COLOR: Color = Color("#6b7280")

## How long a Glow takes to ease in or out, the priority Glow among them; the Encounter
## Screen sets it.
var glow_seconds: float = 0.0
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
var _picture: TextureRect = null
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
var _name: Label = null
var _portrait: Panel = null


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

	var pool: Array = view.mana_pools.get(_player_id, [])
	_pay_answers = clicks.pool_answers.duplicate() if is_hero else ({} as Dictionary[MmMana.Type, int])
	_pool_marks = clicks.pool_marks.duplicate() if is_hero else ([] as Array[MmMana.Type])
	for type: int in 6:
		var amount: int = 0
		for unit: MmMana in pool:
			if unit.type == type:
				amount += 1
		_show_mana(type, amount)

	_set_label(_name, snapshot.names.of(_player_id).to_upper())
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
		_set_label(_thinking, THINKING_FORMAT % snapshot.names.starting(_player_id))


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


## The Portrait the panel shows, or null for a player who has none.
func portrait_texture() -> Texture2D:
	return _picture.texture if _picture != null else null


func yield_button() -> Button:
	return _yield


## The player's name as the panel shows it, in capitals.
func name_text() -> String:
	return _name.text


## What the panel says about its player thinking: THINKING on the Villain's while they
## think, and "" otherwise.
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
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, panel_size))
	add_child(CardShapes.rounded(panel_size, 8, Color("#2c323c")))
	_priority = Control.new()
	_priority.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_priority.size = panel_size
	BorderEffects.add_glow(_priority, panel_size, NOW_COLOR)
	add_child(_priority)
	_name = _label(_title, parts["name"], 22)
	add_child(_name)
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
		_thinking = _label(THINKING, Rect2(parts["potions"].position, Vector2(parts["potions"].size.x, 34)), 16)
		_thinking.modulate = Color(1, 0.85, 0.4)
		add_child(_thinking)


## A player's Portrait is drawn pixel for pixel, six screen pixels to each of its own, and
## what glows and is clicked lies over it and draws nothing. A player with no Portrait has
## a plain gray square.
func _add_portrait(box: Rect2) -> void:
	var texture: Texture2D = PlayerPortraits.texture_of(_player_id)
	if texture == null:
		_portrait = CardShapes.rounded(box.size, 8, Color("#444c5a"))
	else:
		_picture = CardShapes.image(texture, box)
		_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_picture.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_picture)
		var edge: Panel = CardShapes.outline(box.size, 0, 2, Color("#14161a"))
		edge.position = box.position
		add_child(edge)
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
	_tint(_emblems, GOLD if is_gold else Color("#6b7280"))


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


## Draws [param button], the Emblems or the Potions button, in [param tint]: see-through,
## lighter under the cursor, with a thin border.
static func _tint(button: Button, tint: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(tint, 0.45 if state == "hover" else 0.25)
		style.border_color = tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)


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
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = STOP_COLOR if has_stop else PLAIN_COLOR
		if state == "hover":
			style.bg_color = style.bg_color.lightened(0.18)
		if state == "disabled":
			style.bg_color = Color("#2c323c")
		style.set_corner_radius_all(5)
		# "Begin Combat" fits the column only with thin margins.
		style.content_margin_left = 2
		style.content_margin_right = 2
		button.add_theme_stylebox_override(state, style)
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
	var section: Panel = CardShapes.rounded(parts["controls"].size, 6, Color("#22262e"))
	section.position = parts["controls"].position
	add_child(section)
	# Always there: grayed out when nothing can be undone (A245).
	_undo = _control(UNDO_FORMAT % _undo_key, parts["undo"], 16, func() -> void: undo_pressed.emit())
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
static func _set_label(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
