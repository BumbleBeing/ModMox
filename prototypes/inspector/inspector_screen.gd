extends EncounterScreen
## THROWAWAY prototype of 13h: the Inspector. It takes the sidebar's place while the cursor
## is over a card; a right-click pins the card, and a second one, a right-click on empty
## space, a left-click outside the Inspector, Escape or its close button lets it go.
## Nothing is inspected while a card or a trigger is being dragged. Everything is done
## beside the real screen, which finds the card under the cursor from where the faces are,
## so ui/ is untouched and no face takes the mouse for it.

const InspectorPanel := preload("res://prototypes/inspector/inspector_panel.gd")
const Notes := preload("res://prototypes/inspector/inspector_notes.gd")
const ProtoPresenter := preload("res://prototypes/inspector/inspector_presenter.gd")
## No card: object IDs start above this.
const NOTHING: int = 0
## How long the Inspector stays after the cursor leaves a card, in seconds, so that
## crossing the gap between two cards never shows the sidebar.
const LINGER: float = 0.15
const RING: Color = Color("#e6e9ef")

## The encounter to play, set before the screen is put in the tree.
var proto_request: EncounterRequest = null

## For the picture-taking script: where to take the cursor to be, or null for the mouse.
var pretend_cursor: Variant = null

var _inspector: InspectorPanel
var _ring: Panel
## The ring while it is on a card: a child of that card's face, remade when the face is.
var _card_ring: Panel = null
var _pinned: int = NOTHING
var _lingering: int = NOTHING
var _linger_left: float = 0.0
var _inspected: int = NOTHING
var _was_pinned: bool = false
var _is_stale: bool = true


func _ready() -> void:
	super()
	_inspector = InspectorPanel.new()
	_inspector.hide()
	_inspector.close_pressed.connect(func() -> void: _pinned = NOTHING)
	add_child(_inspector)
	# Over the player panels, under every window.
	move_child(_inspector, _stack_window.get_index())
	_ring = _new_ring()
	_ring.z_index = 1
	_ring.hide()
	add_child(_ring)
	move_child(_ring, _drag_layer.get_index())
	if proto_request == null:
		return
	var presenter: ProtoPresenter = ProtoPresenter.new(proto_request.setup(), proto_request.villain_agent())
	presenter.names = proto_request.names()
	settings_path = GameSettings.PATH
	load_settings()
	use_settings(presenter)
	use_game_pace(presenter)
	begin(presenter)


func _redraw() -> void:
	super()
	_is_stale = true


func _process(delta: float) -> void:
	super(delta)
	if _snapshot != null and _inspector != null:
		_follow_inspector(delta)


func _input(event: InputEvent) -> void:
	var click: InputEventMouseButton = make_input_local(event) as InputEventMouseButton
	if click != null and click.pressed and _snapshot != null and not _is_paused:
		if click.button_index == MOUSE_BUTTON_RIGHT and not _is_dragging():
			if not _is_over_inspector(click.position):
				var under: int = _card_under(click.position)
				_pinned = NOTHING if under == _pinned else under
		elif click.button_index == MOUSE_BUTTON_LEFT and not _is_over_inspector(click.position):
			# The click goes on to do whatever it does.
			_pinned = NOTHING
	super(event)


func press_key(keycode: Key) -> void:
	if keycode == KEY_ESCAPE and _pinned != NOTHING and not _is_paused:
		_pinned = NOTHING
		return
	super(keycode)


func _is_dragging() -> bool:
	return _drag.is_holding() or (_is_trigger_pressed() and _trigger_list.is_holding())


func _is_over_inspector(cursor: Vector2) -> bool:
	return Easing.is_shown(_inspector) and Rect2(_inspector.position, _inspector.size).has_point(cursor)


## Works out which card the Inspector shows: the one under the cursor, or the one the
## cursor has just left, or else the pinned one. None while anything is dragged.
func _follow_inspector(delta: float) -> void:
	if _pinned != NOTHING and _seen(_pinned) == null:
		_pinned = NOTHING
	var cursor: Vector2 = get_local_mouse_position() if pretend_cursor == null else pretend_cursor as Vector2
	var hovered: int = NOTHING
	if not _is_dragging() and not _is_paused and not _is_over_inspector(cursor):
		hovered = _card_under(cursor)
	if hovered != NOTHING:
		_lingering = hovered
		_linger_left = LINGER
	else:
		_linger_left -= delta
		if _linger_left <= 0.0 or _is_dragging() or _seen(_lingering) == null:
			_lingering = NOTHING
	var wanted: int = NOTHING
	if not _is_dragging():
		wanted = _lingering if _lingering != NOTHING else _pinned
	var is_pinned: bool = wanted != NOTHING and wanted == _pinned
	if wanted != _inspected or is_pinned != _was_pinned or _is_stale:
		_inspected = wanted
		_was_pinned = is_pinned
		_is_stale = false
		_show_inspected()
	_place_ring()


func _show_inspected() -> void:
	if _inspected == NOTHING:
		Easing.disappear(_inspector, _ease_seconds)
		return
	Easing.appear(_inspector, _ease_seconds)
	var sidebar: Rect2 = _regions["sidebar"]
	_inspector.position = sidebar.position
	_inspector.size = sidebar.size
	var seen: MmObjectView = _seen(_inspected)
	var subject: MmObjectView = seen
	var card_id: int = seen.card_id
	if seen.ability != null:
		# An ability on the stack is read as the card it came from.
		card_id = seen.source_card_id
		var source: MmObjectView = _seen(seen.source_object_id)
		if source != null:
			subject = source
	var originals: Dictionary[int, CardLook] = (_presenter as ProtoPresenter).originals
	var original: CardLook = originals.get(card_id, null) as CardLook
	var look: CardLook = _snapshot.look_of(subject.id)
	if subject == seen and seen.ability != null and original != null:
		# Its source is gone: all that is known of it is what it was.
		look = original
	var states: Array[Array] = []
	if _snapshot.view.battlefield.has(subject):
		states = Notes.state_entries(subject, _snapshot.view, _snapshot.names)
	var rarity: Notes.Rarity = Notes.rarity_of(look.art_key) if original != null else Notes.Rarity.NONE
	var glow: Variant = Notes.RARITY_COLORS[rarity] if rarity != Notes.Rarity.NONE else null
	_inspector.show_card(_inspected, look, original, glow, states, _inspected == _pinned, _ease_seconds)


## The card drawn under [param cursor] that can be inspected, as an object ID, or NOTHING:
## an entry of a window first, then a card of the opening hand through the pregame, or
## else a card of the hand, then a permanent. Nothing under a window or the Option Menu.
func _card_under(cursor: Vector2) -> int:
	var at: Vector2 = get_global_transform() * cursor
	var entries: Dictionary[int, Control] = _window_entries()
	for object_id: int in entries:
		if entries[object_id].is_visible_in_tree() and entries[object_id].get_global_rect().has_point(at):
			return object_id
	if _overlay.is_open() and not _overlay.is_closing():
		return _opening_card_under(cursor)
	if _is_covered(cursor):
		return NOTHING
	var in_hand: MmObjectView = _hand_view(hand_card_under(cursor)) if not _hand_faces.is_empty() else null
	if in_hand != null:
		return in_hand.id
	for object_id: int in _faces:
		var face: Control = _faces[object_id]
		if face != null and is_instance_valid(face) and face.is_visible_in_tree() and _seen(object_id) != null \
				and Rect2(Vector2.ZERO, _face_sizes[object_id]).has_point(face.get_global_transform().affine_inverse() * at):
			return object_id
	return NOTHING


## The card of the opening hand drawn under [param cursor], or NOTHING: none while cards
## are in the air, when they may be face down, and none under an Emblems window.
func _opening_card_under(cursor: Vector2) -> int:
	if _overlay.motion().is_moving():
		return NOTHING
	for window: ZoneWindow in _emblem_windows.values():
		if Easing.is_shown(window) and Rect2(window.position, window.size).has_point(cursor):
			return NOTHING
	var object_id: int = _overlay.card_at(cursor - _overlay.position)
	return object_id if object_id != OpeningHandOverlay.NONE and _seen(object_id) != null else NOTHING


## Every card shown in an open window, by object ID: the stack's entries, each Emblem and
## the face-up cards of the piles.
func _window_entries() -> Dictionary[int, Control]:
	var entries: Dictionary[int, Control] = {}
	if Easing.is_shown(_stack_window):
		for object_id: int in _stack_items:
			var entry: StackEntry = stack_entry_of(object_id)
			if entry != null and is_instance_valid(entry):
				entries[object_id] = entry
	for player_id: int in _emblem_windows:
		var window: ZoneWindow = _emblem_windows[player_id]
		if not Easing.is_shown(window):
			continue
		var emblems: Array[MmObjectView] = []
		for emblem: MmObjectView in _snapshot.view.command:
			if emblem.controller_id == player_id:
				emblems.append(emblem)
		var rows: Array[Node] = window.body().get_children()
		if rows.size() != emblems.size():
			continue
		for index: int in rows.size():
			entries[emblems[index].id] = rows[index] as Control
	for key: String in _pile_windows:
		var pile: PileWindow = _pile_windows[key]
		if not Easing.is_shown(pile):
			continue
		for object_id: int in pile.entries():
			var face: CardFace = pile.face_of(object_id)
			if object_id != PileWindow.UNKNOWN and face != null:
				entries[object_id] = face
	return entries


## Puts the ring round the pinned card where it is drawn, turned as it is.
func _place_ring() -> void:
	var host: Control = null
	var host_size: Vector2 = Vector2.ZERO
	if _pinned != NOTHING and not _is_dragging():
		var entries: Dictionary[int, Control] = _window_entries()
		var seen: MmObjectView = _seen(_pinned)
		if entries.has(_pinned):
			host = entries[_pinned]
			host_size = host.size
		elif _overlay.is_open():
			host = _overlay.face_of(_pinned)
			host_size = host.size if host != null else Vector2.ZERO
		elif _hand_cards.has(seen.card_id) and _snapshot.view.hand.has(seen):
			host = _hand_faces[_hand_cards.find(seen.card_id)]
			host_size = host.size
		elif _faces.has(_pinned) and is_instance_valid(_faces[_pinned]):
			host = _faces[_pinned]
			host_size = _face_sizes[_pinned]
	# On a card the ring is part of the card, so whatever lies over the card lies over its
	# ring too. An entry of a list has nothing over it, and its ring is drawn over the screen.
	var is_on_card: bool = host != null and not host is Container
	if _card_ring != null and (not is_instance_valid(_card_ring) or not is_on_card or _card_ring.get_parent() != host):
		if is_instance_valid(_card_ring):
			_card_ring.queue_free()
		_card_ring = null
	if is_on_card and _card_ring == null:
		_card_ring = _new_ring()
		host.add_child(_card_ring)
	if is_on_card:
		_card_ring.size = host_size
	_ring.visible = host != null and not is_on_card and host.is_visible_in_tree()
	if not _ring.visible:
		return
	var placed: Transform2D = get_global_transform().affine_inverse() * host.get_global_transform()
	_ring.position = placed.origin
	_ring.rotation = placed.get_rotation()
	_ring.scale = placed.get_scale()
	_ring.size = host_size


static func _new_ring() -> Panel:
	var ring: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = RING
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	style.set_expand_margin_all(4)
	ring.add_theme_stylebox_override("panel", style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ring


## For the picture-taking script: pins or lets go as a right-click at [param cursor] would.
func pretend_right_click(cursor: Vector2) -> void:
	var under: int = _card_under(cursor)
	_pinned = NOTHING if under == _pinned else under


func pinned() -> int:
	return _pinned
