class_name PlayerPanel
extends Control
## One player's panel in the sidebar: their name, a square portrait with their life total in
## its corner, a button for each color of mana in their pool, the Emblems button, and every
## step of the turn down the right side. Green steps have a stop; the step it is now has a
## pale border on the active player's panel. While the player can be chosen as a target the
## whole panel takes the click, behind its buttons, which keep working. The Villain's panel
## says when the Villain is thinking, under its Emblems button (A294).

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

var _player_id: int
var _title: String
var _life: Label = null
var _emblems: Button = null
var _mana: Array[Button] = []
var _mana_counts: Array[Label] = []
var _steps: Array[Button] = []
var _pass: Button = null
var _undo: Button = null
var _auto_pass: Button = null
var _thinking: Label = null


## [param title] is the player's name as the panel shows it.
func _init(player_id: int, title: String) -> void:
	_player_id = player_id
	_title = title
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draws the panel in [param panel_rect] from [param snapshot]. [param is_hero] says whose
## mana buttons can be pressed (only the Hero's, and only while paying) and whose panel has
## the controls: undo, pass and auto-pass, with [param is_auto_passing] for its box.
func show_snapshot(snapshot: EncounterSnapshot, clicks: DecisionClicks, stops: StepStops, panel_rect: Rect2, is_hero: bool,
		is_auto_passing: bool) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_mana.clear()
	_mana_counts.clear()
	_steps.clear()
	_pass = null
	_undo = null
	_auto_pass = null
	_thinking = null
	modulate = Color.WHITE
	position = panel_rect.position
	size = panel_rect.size
	var view: MmPlayerView = snapshot.view
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, panel_rect.size))
	add_child(CardShapes.rounded(panel_rect.size, 8, Color("#2c323c")))
	if view.priority_player_id == _player_id:
		add_child(CardShapes.outline(panel_rect.size, 8, 3, NOW_COLOR))
	if clicks.player_answers.has(_player_id):
		# Added before the buttons, so it lies behind them and they keep their clicks.
		var answer: int = clicks.player_answers[_player_id]
		ClickCatcher.add(self, panel_rect.size).clicked.connect(func() -> void: player_clicked.emit(answer))
	if clicks.players.has(_player_id):
		BorderEffects.add_glow(self, panel_rect.size, DecisionClicks.color_of(clicks.players[_player_id]))

	add_child(_label(_title, parts["name"], 22))
	var portrait: Panel = CardShapes.rounded(parts["portrait"].size, 8, Color("#444c5a"))
	portrait.position = parts["portrait"].position
	add_child(portrait)
	var life_box: Panel = CardShapes.rounded(parts["life"].size, 8, Color(0.05, 0.05, 0.07, 0.9))
	life_box.position = parts["life"].position
	add_child(life_box)
	_life = _label(str(view.life_totals.get(_player_id, 0)), parts["life"], 42)
	add_child(_life)

	var pool: Array = view.mana_pools.get(_player_id, [])
	for type: int in 6:
		var amount: int = 0
		for unit: MmMana in pool:
			if unit.type == type:
				amount += 1
		_add_mana_button(parts["mana_%d" % type], type, amount, is_hero and clicks.pool_answers.has(type),
				clicks.pool_answers.get(type, -1))

	var emblem_count: int = 0
	for emblem: MmObjectView in view.command:
		if emblem.controller_id == _player_id:
			emblem_count += 1
	_add_emblems_button(parts["emblems"], emblem_count)

	for step: int in STEP_NAMES.size():
		_add_step_button(parts["step_%d" % step], step, stops.has_stop(_player_id, step),
				view.active_player_id == _player_id and view.step == step)
	if is_hero:
		_add_controls(snapshot, parts, is_auto_passing)
	elif snapshot.is_villain_thinking:
		_thinking = _label(THINKING, Rect2(parts["controls"].position, Vector2(parts["controls"].size.x, 34)), 16)
		_thinking.modulate = Color(1, 0.85, 0.4)
		add_child(_thinking)


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
	return _thinking.text if _thinking != null else ""


## What takes a click on the panel while its player can be chosen, or null.
func click_catcher() -> ClickCatcher:
	return ClickCatcher.of(self)


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
func _add_controls(snapshot: EncounterSnapshot, parts: Dictionary[String, Rect2], is_auto_passing: bool) -> void:
	var section: Panel = CardShapes.rounded(parts["controls"].size, 6, Color("#22262e"))
	section.position = parts["controls"].position
	add_child(section)
	# Always there: grayed out when nothing can be undone (A245).
	_undo = _control("Undo [Z]", parts["undo"], 16, func() -> void: undo_pressed.emit())
	_undo.disabled = not snapshot.can_undo or snapshot.is_villain_thinking
	_pass = _control("Pass [SPACE]", parts["pass"], 19, func() -> void: pass_pressed.emit())
	_pass.disabled = not (snapshot.decision is PriorityDecision)
	_auto_pass = _control(("☑" if is_auto_passing else "☐") + "  Auto-pass", parts["auto_pass"], 17,
			func() -> void: auto_pass_toggled.emit())
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


func _add_mana_button(box: Rect2, type: int, amount: int, can_press: bool, pay_answer: int) -> void:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.disabled = not can_press
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PLAIN_COLOR.lightened(0.18) if state == "hover" else PLAIN_COLOR
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	button.modulate = Color(1, 1, 1, 1.0 if amount > 0 else 0.55)
	var pip: float = minf(box.size.x - 6.0, 24.0)
	button.add_child(CardShapes.image(ManaSymbols.texture((MmMana.SYMBOLS[type] as String).to_lower()),
			Rect2((box.size.x - pip) / 2.0, 5, pip, pip)))
	var count: Label = _label("(%d)" % amount, Rect2(0, 30, box.size.x, 22), 14)
	button.add_child(count)
	if can_press:
		BorderEffects.add_glow(button, box.size, DecisionClicks.color_of(DecisionClicks.Kind.MANA))
		button.pressed.connect(func() -> void: mana_pressed.emit(pay_answer))
	add_child(button)
	_mana.append(button)
	_mana_counts.append(count)


## Gold with Emblems to show, gray and unpressable with none.
func _add_emblems_button(box: Rect2, count: int) -> void:
	_emblems = Button.new()
	_emblems.text = "⛨  Emblems (%d)" % count
	_emblems.focus_mode = Control.FOCUS_NONE
	_emblems.position = box.position
	_emblems.size = box.size
	_emblems.disabled = count == 0
	var tint: Color = GOLD if count > 0 else Color("#6b7280")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(tint, 0.45 if state == "hover" else 0.25)
		style.border_color = tint
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		_emblems.add_theme_stylebox_override(state, style)
	_emblems.add_theme_color_override("font_color", Color("#f1dc9a"))
	_emblems.add_theme_color_override("font_hover_color", Color("#fff3c4"))
	_emblems.add_theme_color_override("font_disabled_color", Color("#9aa1ad"))
	_emblems.pressed.connect(func() -> void: emblems_pressed.emit())
	add_child(_emblems)


func _add_step_button(box: Rect2, step: int, has_stop: bool, is_now: bool) -> void:
	var button: Button = Button.new()
	button.text = STEP_NAMES[step]
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.position = box.position
	button.size = box.size
	button.add_theme_font_size_override("font_size", 13)
	# Untap and cleanup never hold a stop, so their buttons cannot be pressed.
	button.disabled = not StepStops.can_hold(step)
	button.set_meta("has_stop", has_stop)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
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
	button.pressed.connect(func() -> void: stop_toggled.emit(step))
	add_child(button)
	_steps.append(button)
