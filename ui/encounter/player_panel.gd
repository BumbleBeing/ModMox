class_name PlayerPanel
extends Control
## One player's panel in the sidebar: their name, a square portrait with their life total in
## its corner, a button for each color of mana in their pool, the Emblems button, and every
## step of the turn down the right side. Green steps have a stop; the step it is now has a
## pale border on the active player's panel. While the player can be chosen, their portrait
## alone glows and takes the click, never the whole panel. The Villain's panel
## says when the Villain is thinking, under its Emblems button (A294).
##
## Unlike the board, a panel is not rebuilt from each snapshot. It is built once for its
## size, and each snapshot only changes what it shows differently: building its thirty-odd
## buttons took six to nine milliseconds a panel, most of it laying out the two symbols on
## them, which are characters from a fallback font. Whatever the screen draws on the
## portrait (a damage stepper, a Stack Mark) is cleared here on every snapshot.

## A mana button was pressed while paying: [param answer] spends one mana of that color.
signal mana_pressed(answer: int)
signal emblems_pressed
## The panel was clicked while its player could be chosen: [param answer] chooses them.
signal player_clicked(answer: int)
## A step button was pressed: toggle the stop there on this panel's row.
signal stop_toggled(step: MmTurn.Step)
## The Hero's controls, under their Emblems button.
signal pass_pressed
signal undo_pressed
signal auto_pass_toggled

const STEP_NAMES: Array[String] = [
	"Untap", "Upkeep", "Draw", "Main 1", "Begin Combat", "Attackers", "Blockers", "Damage", "End Combat",
	"Main 2", "End", "Cleanup",
]
const GOLD: Color = Color("#c9a544")
const STOP_COLOR: Color = Color("#2f8f46")
const PLAIN_COLOR: Color = Color("#3a414d")
const NOW_COLOR: Color = Color("#f3e9a0")
const THINKING: String = "The Villain is thinking…"
const PASS: String = "Pass [SPACE]"

var _player_id: int
var _title: String
var _is_hero: bool = false
var _built_for: Vector2 = Vector2.ZERO
var _outline: Panel = null
var _life: Label = null
var _emblems: Button = null
var _has_emblems: Variant = null
var _mana: Array[Button] = []
var _mana_counts: Array[Label] = []
## While paying: mana type → the answer that spends one unit of it.
var _pay_answers: Dictionary[MmMana.Type, int] = {}
var _steps: Array[Button] = []
## How each step button is drawn now: 1 for a stop, plus 2 for the step it is.
var _step_looks: Array[int] = []
var _pass: Button = null
var _undo: Button = null
var _auto_pass: Button = null
var _thinking: Label = null
var _portrait: Panel = null


## [param title] is the player's name as the panel shows it.
func _init(player_id: int, title: String) -> void:
	_player_id = player_id
	_title = title
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param snapshot] in [param panel_rect]. [param is_hero] says whose mana buttons can
## be pressed (only the Hero's, and only while paying) and whose panel has the controls:
## undo, pass and auto-pass, with [param is_auto_passing] for its box.
func show_snapshot(snapshot: EncounterSnapshot, clicks: DecisionClicks, stops: StepStops, panel_rect: Rect2, is_hero: bool,
		is_auto_passing: bool) -> void:
	position = panel_rect.position
	size = panel_rect.size
	if panel_rect.size != _built_for or is_hero != _is_hero:
		_build(panel_rect.size, is_hero)
	var view: MmPlayerView = snapshot.view
	_outline.visible = view.priority_player_id == _player_id
	_show_portrait(clicks)
	_set_text(_life, str(view.life_totals.get(_player_id, 0)))

	var pool: Array = view.mana_pools.get(_player_id, [])
	_pay_answers = clicks.pool_answers.duplicate() if is_hero else ({} as Dictionary[MmMana.Type, int])
	for type: int in 6:
		var amount: int = 0
		for unit: MmMana in pool:
			if unit.type == type:
				amount += 1
		_show_mana(type, amount)

	var emblem_count: int = 0
	for emblem: MmObjectView in view.command:
		if emblem.controller_id == _player_id:
			emblem_count += 1
	_show_emblems(emblem_count)

	for step: int in STEP_NAMES.size():
		_show_step(step, stops.has_stop(_player_id, step), view.active_player_id == _player_id and view.step == step)
	if is_hero:
		_undo.disabled = not snapshot.can_undo or snapshot.is_villain_thinking
		_pass.disabled = not (snapshot.decision is PriorityDecision)
		if _pass.text != PASS:
			# It was the confirm button of a combat decision (show_confirm).
			_pass.text = PASS
			_pass.add_theme_font_size_override("font_size", 19)
		_set_text(_auto_pass, ("☑" if is_auto_passing else "☐") + "  Auto-pass")
	else:
		_thinking.visible = snapshot.is_villain_thinking


## While a combat decision is being answered the pass button confirms it instead: it reads
## [param text] and can be pressed only when [param is_complete]. Undo is open whenever
## there is a click to take back ([param can_undo]).
func show_confirm(text: String, is_complete: bool, can_undo: bool) -> void:
	if _pass == null:
		return
	_pass.text = text
	_pass.disabled = not is_complete
	_pass.add_theme_font_size_override("font_size", 17)
	if can_undo:
		_undo.disabled = false


## The pass, undo and auto-pass buttons: null on the Villain's panel.
func pass_button() -> Button:
	return _pass


func undo_button() -> Button:
	return _undo


func auto_pass_button() -> Button:
	return _auto_pass


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


## Whether the button for [param step] has the border of the step it is now.
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
	_has_emblems = null
	_pass = null
	_undo = null
	_auto_pass = null
	_thinking = null
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, panel_size))
	add_child(CardShapes.rounded(panel_size, 8, Color("#2c323c")))
	_outline = CardShapes.outline(panel_size, 8, 3, NOW_COLOR)
	add_child(_outline)
	add_child(_label(_title, parts["name"], 22))
	_portrait = CardShapes.rounded(parts["portrait"].size, 8, Color("#444c5a"))
	_portrait.position = parts["portrait"].position
	add_child(_portrait)
	var life_box: Panel = CardShapes.rounded(parts["life"].size, 8, Color(0.05, 0.05, 0.07, 0.9))
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
		_add_controls(parts)
	else:
		_thinking = _label(THINKING, Rect2(parts["controls"].position, Vector2(parts["controls"].size.x, 34)), 16)
		_thinking.modulate = Color(1, 0.85, 0.4)
		add_child(_thinking)


## The portrait glows and takes a click while its player can be chosen. Whatever else was
## drawn on it since the last snapshot is taken off.
func _show_portrait(clicks: DecisionClicks) -> void:
	for child: Node in _portrait.get_children():
		_portrait.remove_child(child)
		child.queue_free()
	_portrait.modulate = Color.WHITE
	if clicks.players.has(_player_id):
		BorderEffects.add_glow(_portrait, _portrait.size, DecisionClicks.color_of(clicks.players[_player_id]))
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
	if can_press != (BorderEffects.glow_color(button) != null):
		if can_press:
			BorderEffects.add_glow(button, button.size, DecisionClicks.color_of(DecisionClicks.Kind.MANA))
		else:
			BorderEffects.remove_glow(button)


## Gold with Emblems to show, gray and unpressable with none.
func _show_emblems(count: int) -> void:
	_set_text(_emblems, "⛨  Emblems (%d)" % count)
	_emblems.disabled = count == 0
	if _has_emblems is bool and _has_emblems == (count > 0):
		return
	_has_emblems = count > 0
	var tint: Color = GOLD if count > 0 else Color("#6b7280")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(tint, 0.45 if state == "hover" else 0.25)
		style.border_color = tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		_emblems.add_theme_stylebox_override(state, style)


## A step with a stop is green, and the step it is now has a pale border.
func _show_step(step: int, has_stop: bool, is_now: bool) -> void:
	var look: int = (1 if has_stop else 0) + (2 if is_now else 0)
	if _step_looks[step] == look:
		return
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
		if is_now:
			style.border_color = NOW_COLOR
			style.set_border_width_all(3)
		button.add_theme_stylebox_override(state, style)


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
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The Hero's controls, in a section of their own under the Emblems button.
func _add_controls(parts: Dictionary[String, Rect2]) -> void:
	var section: Panel = CardShapes.rounded(parts["controls"].size, 6, Color("#22262e"))
	section.position = parts["controls"].position
	add_child(section)
	# Always there: grayed out when nothing can be undone (A245).
	_undo = _control("Undo [Z]", parts["undo"], 16, func() -> void: undo_pressed.emit())
	_pass = _control(PASS, parts["pass"], 19, func() -> void: pass_pressed.emit())
	_auto_pass = _control("", parts["auto_pass"], 17, func() -> void: auto_pass_toggled.emit())
	_auto_pass.flat = true
	_auto_pass.tooltip_text = "Pass for me except on steps with a stop (green) where I can cast or activate something, or when the Villain puts something on the stack."


func _control(text: String, box: Rect2, font_size: int, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.add_theme_font_size_override("font_size", font_size)
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
	button.add_theme_font_size_override("font_size", 13)
	# Untap and cleanup never hold a stop, so their buttons cannot be pressed.
	button.disabled = not StepStops.can_hold(step)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	button.pressed.connect(func() -> void: stop_toggled.emit(step))
	add_child(button)
	_steps.append(button)
	# No look yet: show_snapshot() gives it its first.
	_step_looks.append(-1)
