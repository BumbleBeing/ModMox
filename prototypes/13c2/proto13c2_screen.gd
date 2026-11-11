extends EncounterScreen
## THROWAWAY PROTOTYPE for 13c-2 (A330): declaring attackers and blockers and dividing
## combat damage on the creatures themselves. A live encounter, plus buttons that load
## hand-built boards. Not held to the conventions or to tests; deleted when the build lands.
##
## Run: godot --path . -s res://prototypes/13c2/proto13c2_main.gd -- --hero=red_green --villain=white_black --seed=5

const CARDS: String = "res://content/cards/alpha/%s.tres"
const LINE_CHOSEN: Color = Color("#f3e9a0")
const LINE_DECLARED: Color = Color("#e8eaf0")
const BOARDS: Array[String] = ["Attack", "Block", "Crowded", "Divide", "Trample", "Villain blocked"]

var _lines_layer: Control
var _toggles: PanelContainer
var _is_fake: bool = false
var _fake_looks: Dictionary[int, CardLook] = {}
## The decision the selection below is for.
var _selection_for: MmPendingDecision = null
var _attackers: Array[int] = []
## [blocker ID, attacker ID] pairs.
var _pairs: Array = []
var _picked: int = -1
var _amounts: Array[int] = []
## What the selection was before each click, for Z.
var _history: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines_layer = Control.new()
	_lines_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggles = PanelContainer.new()
	navigate = func(_scene: String) -> void: get_tree().quit()
	super._ready()
	add_child(_lines_layer)
	move_child(_lines_layer, _board.get_index() + 1)
	_build_toggles()
	add_child(_toggles)
	move_child(_toggles, _lines_layer.get_index() + 1)
	_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _picked != -1 and not _is_paused:
		# A click on empty board puts the picked-up blocker down, unassigned (A314).
		_remember()
		_unassign(_picked)
		_picked = -1
		_redraw()
		return
	super._unhandled_input(event)


# ---------------------------------------------------------------- selection

func _show(snapshot: EncounterSnapshot) -> void:
	if snapshot.decision != _selection_for:
		_selection_for = snapshot.decision
		_attackers.clear()
		_pairs.clear()
		_picked = -1
		_history.clear()
		_amounts = _default_split(snapshot.decision as DivideCombatDamageDecision)
	super._show(snapshot)


func _is_combat_input() -> bool:
	var decision: MmPendingDecision = _snapshot.decision if _snapshot != null else null
	return decision is DeclareAttackersDecision or decision is DeclareBlockersDecision or decision is DivideCombatDamageDecision


## Kills as many recipients as possible in the order they stand; what is left goes to the
## first one still alive, or to the player with trample, or onto the first.
func _default_split(divide: DivideCombatDamageDecision) -> Array[int]:
	var amounts: Array[int] = []
	if divide == null:
		return amounts
	var left: int = divide.amount
	for index: int in divide.recipients.size():
		var lethal: int = divide.lethal_amounts[index] if index < divide.lethal_amounts.size() else 0
		var given: int = lethal if lethal > 0 and left >= lethal else 0
		amounts.append(given)
		left -= given
	if left > 0:
		var onto: int = amounts.size() - 1 if divide.includes_player() else 0
		if not divide.includes_player():
			for index: int in amounts.size():
				if amounts[index] == 0:
					onto = index
					break
		amounts[onto] += left
	return amounts


func _left_to_assign() -> int:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	var left: int = divide.amount
	for amount: int in _amounts:
		left -= amount
	return left


func _remember() -> void:
	_history.append([_attackers.duplicate(), _pairs.duplicate(true), _picked, _amounts.duplicate()])


func _unassign(blocker_id: int) -> void:
	_pairs = _pairs.filter(func(pair: Array) -> bool: return pair[0] != blocker_id)


func _blocks_of(blocker_id: int) -> Array[int]:
	var found: Array[int] = []
	for pair: Array in _pairs:
		if pair[0] == blocker_id:
			found.append(pair[1])
	return found


func _is_clickable(object_id: int) -> bool:
	var decision: MmPendingDecision = _snapshot.decision
	if decision is DeclareAttackersDecision:
		return (decision as DeclareAttackersDecision).candidate_ids.has(object_id)
	if decision is DeclareBlockersDecision:
		var blocks: DeclareBlockersDecision = decision as DeclareBlockersDecision
		if blocks.candidate_blocker_ids.has(object_id):
			return true
		return _picked != -1 and (blocks.blockable_by_blocker.get(_picked, []) as Array).has(object_id)
	return false


## Clicks Game Object [param object_id] as the mouse would.
func combat_click(object_id: int) -> void:
	if _is_paused or not _is_clickable(object_id):
		return
	_remember()
	var decision: MmPendingDecision = _snapshot.decision
	if decision is DeclareAttackersDecision:
		if _attackers.has(object_id):
			_attackers.erase(object_id)
		else:
			_attackers.append(object_id)
	else:
		var blocks: DeclareBlockersDecision = decision as DeclareBlockersDecision
		if blocks.candidate_blocker_ids.has(object_id):
			if _picked == object_id:
				_unassign(object_id)
				_picked = -1
			else:
				_picked = object_id
		else:
			var limit: int = blocks.most_blocks_by_blocker.get(_picked, 1)
			var already: Array[int] = _blocks_of(_picked)
			if limit <= 1:
				_unassign(_picked)
				_pairs.append([_picked, object_id])
				_picked = -1
			elif already.has(object_id):
				_pairs = _pairs.filter(func(pair: Array) -> bool: return not (pair[0] == _picked and pair[1] == object_id))
			elif already.size() < limit:
				_pairs.append([_picked, object_id])
	_redraw()


func select_all_attackers() -> void:
	_remember()
	_attackers = (_snapshot.decision as DeclareAttackersDecision).candidate_ids.duplicate()
	_redraw()


## Gives recipient [param index] one more ([param change] 1) or one less (-1).
func change_amount(index: int, change: int) -> void:
	if _amounts[index] + change < 0 or (change > 0 and _left_to_assign() <= 0):
		return
	_remember()
	_amounts[index] += change
	_redraw()


func pass_priority() -> void:
	if not _is_combat_input():
		super.pass_priority()
		return
	var decision: MmPendingDecision = _snapshot.decision
	if decision is DeclareAttackersDecision:
		var ids: Array[int] = _attackers.duplicate()
		ids.sort()
		_answer(ids)
	elif decision is DeclareBlockersDecision:
		_answer(_pairs.duplicate(true))
	elif _left_to_assign() == 0:
		_answer(_amounts.duplicate())


func undo() -> void:
	if _history.is_empty():
		if not _is_fake:
			super.undo()
		return
	var before: Array = _history.pop_back()
	_attackers.assign(before[0])
	_pairs = before[1]
	_picked = before[2]
	_amounts.assign(before[3])
	_redraw()


func _answer(hero_answer: Variant) -> void:
	if _is_fake:
		_apply_fake(hero_answer)
	else:
		super._answer(hero_answer)


# ---------------------------------------------------------------- drawing

func _redraw() -> void:
	if _snapshot == null:
		return
	super._redraw()
	if _is_combat_input():
		_debug.visible = false
	_draw_combat_lines()
	_dress_controls()
	_dress_info()
	_add_player_stepper()
	_toggles.position = Vector2(_regions["battlefield"].position.x + 4.0, 2.0)


func _is_in_combat(permanent: MmObjectView) -> bool:
	return super._is_in_combat(permanent) or _attackers.has(permanent.id) or not _blocks_of(permanent.id).is_empty()


## Creatures in combat stand to the left of those that are not, in object ID order. Only
## once the engine says they are attacking or blocking: while the Hero is still choosing,
## nothing changes places under the cursor.
func _permanents(view: MmPlayerView, player_id: int, are_lands: bool) -> Array[MmObjectView]:
	var found: Array[MmObjectView] = super._permanents(view, player_id, are_lands)
	if are_lands:
		return found
	var fighting: Array[MmObjectView] = []
	var others: Array[MmObjectView] = []
	for permanent: MmObjectView in found:
		if super._is_in_combat(permanent):
			fighting.append(permanent)
		else:
			others.append(permanent)
	fighting.sort_custom(func(one: MmObjectView, other: MmObjectView) -> bool: return one.id < other.id)
	return fighting + others


## No more "ATTACKING" and "BLOCKING" tags (A316).
func _add_combat_tag(_face: Control, _permanent: MmObjectView, _footprint: Vector2) -> void:
	pass


func _draw_line(key: String, permanents: Array[MmObjectView], heights: Array[float], line_rect: Rect2,
		band_height: float, band_top: float, glow: DecisionClicks, is_hero: bool) -> void:
	super._draw_line(key, permanents, heights, line_rect, band_height, band_top, glow, is_hero)
	_lines[key].scrolled.connect(func(_offset: float) -> void: _draw_combat_lines())


func _remember_face(object_id: int, face: Control, face_size: Vector2, glow: DecisionClicks) -> void:
	var blocks: DeclareBlockersDecision = _snapshot.decision as DeclareBlockersDecision
	if blocks != null and _picked != -1 and (blocks.blockable_by_blocker.get(_picked, []) as Array).has(object_id):
		# While a blocker is picked up, the attackers it can block glow as targets (A313).
		glow.objects[object_id] = DecisionClicks.Kind.TARGET
	super._remember_face(object_id, face, face_size, glow)
	if _is_combat_input() and _is_clickable(object_id) and ClickCatcher.of(face) == null:
		ClickCatcher.add(face, face_size).clicked.connect(combat_click.bind(object_id))
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	if object_id == _picked or (divide != null and divide.source_id == object_id):
		BorderEffects.add_pointer(face, face_size)
	if divide == null:
		return
	if divide.source_id == object_id:
		var left: int = _left_to_assign()
		var chip: Panel = CardShapes.rounded(Vector2(96, 30), 6, Color(0, 0, 0, 0.82))
		chip.position = Vector2((face_size.x - 96.0) / 2.0, face_size.y * 0.36)
		face.add_child(chip)
		var text: Label = _stepper_label("%d left" % left, Rect2(0, 0, 96, 30), Color("#f3e9a0") if left > 0 else Color(1, 1, 1, 0.6))
		chip.add_child(text)
	for index: int in divide.recipients.size():
		if divide.recipients[index].is_object() and divide.recipients[index].id == object_id:
			face.add_child(_stepper(index, Vector2((face_size.x - 112.0) / 2.0, face_size.y * 0.36)))


## "− 3 +" for recipient [param index]: red once the amount is lethal (A319).
func _stepper(index: int, at: Vector2) -> Control:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	var box: Panel = CardShapes.rounded(Vector2(112, 36), 7, Color(0, 0, 0, 0.82))
	box.position = at
	var lethal: int = divide.lethal_amounts[index] if index < divide.lethal_amounts.size() else -1
	var is_lethal: bool = lethal > 0 and _amounts[index] >= lethal
	var number: Label = _stepper_label(str(_amounts[index]), Rect2(34, 0, 44, 36), Color("#ff5648") if is_lethal else Color.WHITE)
	number.add_theme_font_size_override("font_size", 24)
	box.add_child(number)
	var minus: Button = _button("−", change_amount.bind(index, -1), 20)
	minus.position = Vector2(3, 3)
	minus.size = Vector2(30, 30)
	minus.disabled = _amounts[index] <= 0
	box.add_child(minus)
	var plus: Button = _button("+", change_amount.bind(index, 1), 20)
	plus.position = Vector2(79, 3)
	plus.size = Vector2(30, 30)
	plus.disabled = _left_to_assign() <= 0 or (divide.recipients[index].is_player() and not _are_blockers_dead())
	box.add_child(plus)
	for button: Button in [minus, plus]:
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var flat: StyleBoxFlat = StyleBoxFlat.new()
			flat.bg_color = Color("#4a5362").lightened(0.25) if state in ["hover", "pressed"] else Color("#4a5362")
			if state == "disabled":
				flat.bg_color = Color("#22262e")
			flat.set_corner_radius_all(5)
			button.add_theme_stylebox_override(state, flat)
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	return box


## With trample: whether every blocker has been assigned lethal damage (CR 702.19b).
func _are_blockers_dead() -> bool:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	for index: int in divide.lethal_amounts.size():
		if _amounts[index] < divide.lethal_amounts[index]:
			return false
	return true


func _stepper_label(text: String, box: Rect2, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = box.position
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## With trample the attacked player is a recipient: their stepper sits on their portrait.
func _add_player_stepper() -> void:
	var divide: DivideCombatDamageDecision = _snapshot.decision as DivideCombatDamageDecision
	if divide == null or not divide.includes_player():
		return
	var index: int = divide.recipients.size() - 1
	var panel: PlayerPanel = _panels[divide.recipients[index].id]
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, panel.size))
	panel.add_child(_stepper(index, parts["portrait"].position + Vector2((parts["portrait"].size.x - 112.0) / 2.0, 20)))


## The pairs to draw: those the engine says are blocking, and those chosen so far.
func _shown_pairs() -> Array:
	var pairs: Array = []
	for permanent: MmObjectView in _snapshot.view.battlefield:
		for attacker_id: int in permanent.blocking_ids:
			pairs.append([permanent.id, attacker_id, false])
	for pair: Array in _pairs:
		pairs.append([pair[0], pair[1], true])
	return pairs


## Blockers stand opposite their attackers, side by side when several block one (A315).
## A line that overflows is left as it is: the lines carry the meaning there (A327).
func _arrange_blocks() -> void:
	var pairs: Array = _shown_pairs()
	for key: String in ["hero_creatures", "villain_creatures"]:
		var line: ScrollRow = _lines.get(key, null) as ScrollRow
		if line == null or line.can_scroll():
			continue
		var ids: Array = _line_ids.get(key, [])
		var origin: float = line.content().global_position.x
		var wanted: Dictionary[int, float] = {}
		var groups: Dictionary[int, Array] = {}
		for pair: Array in pairs:
			if ids.has(pair[0]) and _faces.has(pair[1]) and not wanted.has(pair[0]):
				wanted[pair[0]] = 0.0
				if not groups.has(pair[1]):
					groups[pair[1]] = []
				(groups[pair[1]] as Array).append(pair[0])
		if wanted.is_empty():
			continue
		for attacker_id: int in groups:
			var group: Array = groups[attacker_id]
			var total: float = -EncounterLayout.ROW_GAP
			for blocker_id: int in group:
				total += _face_sizes[blocker_id].x + EncounterLayout.ROW_GAP
			var x: float = _faces[attacker_id].get_global_rect().get_center().x - origin - total / 2.0
			for blocker_id: int in group:
				wanted[blocker_id] = x
				x += _face_sizes[blocker_id].x + EncounterLayout.ROW_GAP
		var blockers: Array = wanted.keys()
		blockers.sort_custom(func(one: int, other: int) -> bool: return wanted[one] < wanted[other])
		# A line that fits is centered in its view, so the room it has runs past both ends
		# of its own contents.
		var least: float = EncounterLayout.LINE_PAD - line.content().position.x
		var most: float = line.size.x - EncounterLayout.LINE_PAD - line.content().position.x
		var taken: Array[Rect2] = []
		var edge: float = least
		for blocker_id: int in blockers:
			wanted[blocker_id] = maxf(wanted[blocker_id], edge)
			edge = wanted[blocker_id] + _face_sizes[blocker_id].x + EncounterLayout.ROW_GAP
		edge = most
		for place: int in range(blockers.size() - 1, -1, -1):
			var blocker_id: int = blockers[place]
			wanted[blocker_id] = minf(wanted[blocker_id], edge - _face_sizes[blocker_id].x)
			edge = wanted[blocker_id] - EncounterLayout.ROW_GAP
			_faces[blocker_id].position.x = wanted[blocker_id]
			taken.append(Rect2(wanted[blocker_id], 0, _face_sizes[blocker_id].x, 1))
		for object_id: int in ids:
			if wanted.has(object_id):
				continue
			var width: float = _face_sizes[object_id].x
			var start: float = _faces[object_id].position.x
			var found: float = start
			for step: int in 200:
				var offset: float = (step / 2 + 1) * 12.0 * (1.0 if step % 2 == 0 else -1.0) if step > 0 else 0.0
				var tried: float = start + offset
				if tried < least or tried + width > most:
					continue
				var spot: Rect2 = Rect2(tried - EncounterLayout.ROW_GAP, 0, width + EncounterLayout.ROW_GAP * 2.0, 1)
				if not taken.any(func(used: Rect2) -> bool: return used.intersects(spot)):
					found = tried
					break
			_faces[object_id].position.x = found
			taken.append(Rect2(found, 0, width, 1))


## Where a line to Game Object [param object_id] ends: on its face, at the edge toward the
## lane, or on the scroll arrow that points toward it when it is out of sight (A327).
func _line_end(object_id: int) -> Vector2:
	var face: Control = _faces[object_id]
	var rect: Rect2 = face.get_global_rect()
	var is_hero: bool = false
	for key: String in _lines:
		var ids: Array = _line_ids.get(key, [])
		if not ids.has(object_id):
			continue
		is_hero = key.begins_with("hero")
		var line: ScrollRow = _lines[key]
		var middle: float = face.position.x + line.content().position.x + _face_sizes[object_id].x / 2.0
		var side: int = EncounterLayout.hidden_past(middle, line.size.x, ScrollRow.ARROW_WIDTH)
		if side != 0:
			var arrow: Button = line.left_arrow() if side < 0 else line.right_arrow()
			return Vector2(arrow.get_global_rect().get_center().x, rect.position.y if is_hero else rect.end.y)
	return Vector2(rect.get_center().x, rect.position.y - 2.0 if is_hero else rect.end.y + 2.0)


func _draw_combat_lines() -> void:
	for child: Node in _lines_layer.get_children():
		_lines_layer.remove_child(child)
		child.queue_free()
	if _snapshot == null:
		return
	for pair: Array in _shown_pairs():
		if not _faces.has(pair[0]) or not _faces.has(pair[1]):
			continue
		var from: Vector2 = _line_end(pair[0])
		var to: Vector2 = _line_end(pair[1])
		var color: Color = LINE_CHOSEN if pair[2] else LINE_DECLARED
		var line: Line2D = Line2D.new()
		line.points = PackedVector2Array([from, to])
		line.width = 4.0
		line.default_color = color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_lines_layer.add_child(line)
		var along: Vector2 = (to - from).normalized()
		var across: Vector2 = Vector2(-along.y, along.x)
		var head: Polygon2D = Polygon2D.new()
		head.polygon = PackedVector2Array([to + along * 2.0, to - along * 14.0 + across * 8.0, to - along * 14.0 - across * 8.0])
		head.color = color
		_lines_layer.add_child(head)


func _dress_controls() -> void:
	var button: Button = pass_button()
	var decision: MmPendingDecision = _snapshot.decision
	if button == null or not _is_combat_input():
		return
	button.disabled = false
	if decision is DeclareAttackersDecision:
		button.text = "Attack with %d" % _attackers.size() if not _attackers.is_empty() else "No attacks"
	elif decision is DeclareBlockersDecision:
		button.text = "Confirm blocks" if not _pairs.is_empty() else "No blocks"
	else:
		button.text = "Assign damage"
		button.disabled = _left_to_assign() != 0
	button.add_theme_font_size_override("font_size", 17)
	var undo_button: Button = undo_button()
	if undo_button != null and not _history.is_empty():
		undo_button.disabled = false


func _dress_info() -> void:
	var decision: MmPendingDecision = _snapshot.decision
	if not _is_combat_input():
		return
	var prompt: String = "Declare attackers"
	var hint: String = ""
	if decision is DeclareBlockersDecision:
		prompt = "Declare blockers"
		hint = "Click a creature, then the attacker it blocks." if _pairs.is_empty() else ""
	elif decision is DivideCombatDamageDecision:
		var divide: DivideCombatDamageDecision = decision as DivideCombatDamageDecision
		prompt = "Divide %d damage from %s" % [divide.amount, DebugDecisionForm.name_of(_snapshot.view, divide.source_id)]
	_info._prompt.text = prompt
	if hint != "":
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		label.text = hint
		label.position = Vector2(12, 40)
		label.size = Vector2(_info.size.x - 24, 40)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info.add_child(label)
	if decision is DeclareAttackersDecision:
		var all: Button = _button("All attack", select_all_attackers, 16)
		all.position = Vector2(_info.size.x - 122, _info.size.y - 40)
		all.size = Vector2(110, 32)
		_info.add_child(all)


# ---------------------------------------------------------------- hand-built boards

func _build_toggles() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(3)
	_toggles.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	_toggles.add_child(row)
	var note: Label = Label.new()
	note.text = "13c-2 prototype:"
	note.add_theme_font_size_override("font_size", 12)
	row.add_child(note)
	row.add_child(_button("Live game", go_live, 12))
	for board: String in BOARDS:
		row.add_child(_button(board, load_board.bind(board), 12))


func go_live() -> void:
	_is_fake = false
	_presenter.set_paused(false)
	_show(_presenter.snapshot())


## Loads the hand-built board named [param board] in place of the live game.
func load_board(board: String) -> void:
	_is_fake = true
	_presenter.set_paused(true)
	_fake_looks.clear()
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	view.life_totals = {HERO: 20, VILLAIN: 20}
	view.hand_sizes = {HERO: 0, VILLAIN: 4}
	view.library_sizes = {HERO: 30, VILLAIN: 30}
	view.active_player_id = VILLAIN if board in ["Block", "Crowded", "Villain blocked"] else HERO
	view.priority_player_id = HERO
	view.step = MmTurn.Step.DECLARE_ATTACKERS
	var decision: MmPendingDecision = null
	for index: int in 5:
		view.battlefield.append(_fake(900 + index, "forest" if index < 3 else "mountain", HERO, {}))
		view.battlefield.append(_fake(950 + index, "plains" if index < 3 else "swamp", VILLAIN, {}))
	if board == "Attack":
		var cards: Array[String] = ["grizzly_bears", "hill_giant", "craw_wurm", "elvish_archers", "llanowar_elves", "gray_ogre"]
		var ids: Array[int] = []
		for index: int in cards.size():
			var is_spent: bool = index == 4
			view.battlefield.append(_fake(1 + index, cards[index], HERO, {"tapped": is_spent}))
			if not is_spent:
				ids.append(1 + index)
		for index: int in 3:
			view.battlefield.append(_fake(20 + index, ["savannah_lions", "white_knight", "serra_angel"][index], VILLAIN, {}))
		decision = DeclareAttackersDecision.new(HERO, ids)
	elif board == "Block" or board == "Villain blocked":
		view.step = MmTurn.Step.DECLARE_BLOCKERS
		var attackers: Array[String] = ["savannah_lions", "serra_angel", "scathe_zombies"]
		for index: int in attackers.size():
			view.battlefield.append(_fake(20 + index, attackers[index], VILLAIN,
				{"tapped": index != 1, "attacking": true, "blocked": board == "Villain blocked" and index == 2}))
		view.battlefield.append(_fake(23, "black_knight", VILLAIN, {}))
		var blockers: Array[String] = ["grizzly_bears", "giant_spider", "hill_giant", "llanowar_elves"]
		for index: int in blockers.size():
			var blocking: Array[int] = []
			if board == "Villain blocked" and index in [0, 2]:
				blocking.append(22)
			view.battlefield.append(_fake(1 + index, blockers[index], HERO, {"blocking": blocking}))
		if board == "Block":
			# Only the Spider, with reach, can block the Angel.
			decision = DeclareBlockersDecision.new(HERO, [1, 2, 3, 4] as Array[int], [20, 21, 22] as Array[int],
				{1: [20, 22], 2: [20, 21, 22], 3: [20, 22], 4: [20, 22]} as Dictionary[int, Array],
				{1: 1, 2: 1, 3: 1, 4: 1} as Dictionary[int, int])
		else:
			decision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])
	elif board == "Crowded":
		view.step = MmTurn.Step.DECLARE_BLOCKERS
		var theirs: Array[String] = ["savannah_lions", "scathe_zombies", "black_knight", "white_knight", "pearled_unicorn",
			"drudge_skeletons", "frozen_shade", "savannah_lions", "scathe_zombies"]
		var ours: Array[String] = ["grizzly_bears", "hill_giant", "craw_wurm", "elvish_archers", "gray_ogre", "giant_spider",
			"hurloon_minotaur", "ironroot_treefolk", "uthden_troll"]
		var blockable: Dictionary[int, Array] = {}
		var most: Dictionary[int, int] = {}
		var attacker_ids: Array[int] = []
		var blocker_ids: Array[int] = []
		for index: int in theirs.size():
			view.battlefield.append(_fake(20 + index, theirs[index], VILLAIN, {"tapped": true, "attacking": true}))
			attacker_ids.append(20 + index)
		for index: int in ours.size():
			view.battlefield.append(_fake(1 + index, ours[index], HERO, {}))
			blocker_ids.append(1 + index)
		for blocker_id: int in blocker_ids:
			blockable[blocker_id] = attacker_ids.duplicate()
			most[blocker_id] = 1
		decision = DeclareBlockersDecision.new(HERO, blocker_ids, attacker_ids, blockable, most)
	else:
		view.step = MmTurn.Step.COMBAT_DAMAGE
		var is_trample: bool = board == "Trample"
		view.battlefield.append(_fake(1, "craw_wurm", HERO, {"tapped": true, "attacking": true, "blocked": true}))
		view.battlefield.append(_fake(2, "grizzly_bears", HERO, {}))
		var blockers: Array[String] = ["savannah_lions", "scathe_zombies"]
		if not is_trample:
			blockers.append("pearled_unicorn")
		var recipients: Array[MmReference] = []
		var lethal: Array[int] = []
		for index: int in blockers.size():
			var seen: MmObjectView = _fake(20 + index, blockers[index], VILLAIN, {"blocking": [1] as Array[int]})
			view.battlefield.append(seen)
			recipients.append(MmReference.to_object(seen.id))
			lethal.append(seen.toughness)
		if is_trample:
			recipients.append(MmReference.to_player(VILLAIN))
		decision = DivideCombatDamageDecision.new(HERO, 1, 6, recipients, lethal)
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = view
	snapshot.decision = decision
	snapshot.looks = _fake_looks.duplicate()
	_show(snapshot)


func _fake(id: int, card: String, controller: int, flags: Dictionary) -> MmObjectView:
	var definition: MmCardDefinition = load(CARDS % card) as MmCardDefinition
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.card_id = id
	seen.name = definition.name
	seen.owner_id = controller
	seen.controller_id = controller
	seen.card_types = definition.card_types.duplicate()
	seen.is_creature = definition.card_types.has(MmCardTypes.CardType.CREATURE)
	seen.power = definition.power
	seen.toughness = definition.toughness
	seen.base_power = definition.power
	seen.base_toughness = definition.toughness
	seen.abilities = definition.abilities.duplicate()
	seen.is_tapped = flags.get("tapped", false)
	seen.is_attacking = flags.get("attacking", false)
	seen.is_blocked = flags.get("blocked", false)
	seen.blocking_ids.assign(flags.get("blocking", []))
	var look: CardLook = CardLook.of_definition(definition)
	look.art_key = card
	look.is_tapped = seen.is_tapped
	_fake_looks[id] = look
	return seen


## On a hand-built board an answer only shows what it would have done.
func _apply_fake(hero_answer: Variant) -> void:
	var decision: MmPendingDecision = _snapshot.decision
	for seen: MmObjectView in _snapshot.view.battlefield:
		if decision is DeclareAttackersDecision and (hero_answer as Array).has(seen.id):
			seen.is_attacking = true
			seen.is_tapped = true
			_snapshot.looks[seen.id].is_tapped = true
		elif decision is DeclareBlockersDecision:
			for pair: Array in hero_answer:
				if pair[0] == seen.id:
					seen.blocking_ids.append(pair[1])
	_snapshot.decision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])
	_show(_snapshot)
	_error = "Prototype board: answered %s" % str(hero_answer)
	_redraw()
