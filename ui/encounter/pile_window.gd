class_name PileWindow
extends ZoneWindow
## The Zone Window of a pile: a graveyard, an exile or a library. A graveyard or exile is a
## grid of Card Faces that wraps to the window's width, the newest card first. A library
## is one row scrolled sideways, its top card on the left, showing a card back for each
## card the Hero does not know and its face for one they do, such as a card they put on
## the bottom, or the top card they may look at (game ADR 0055). A card that answers the
## decision glows and is clicked here (ADR 0032). While the Hero searches their library
## (game ADR 0058) it is a grid of every card face up, the cards the search may find first
## and then the rest, each by name; a card selected glows white, the others that may be
## selected green, and none once as many are selected as may be.

signal card_clicked(object_id: int)
## The cursor came onto ([param is_over]) or left a card that answers the decision.
signal card_hovered(object_id: int, is_over: bool)

enum Arrangement { GRID, ROW }

const CARD_HEIGHT: float = EncounterLayout.HAND_CARD_HEIGHT
const GAP: int = 8
## The Glow of a card selected in a search, white as a card chosen to discard is (A401).
const PICKED_GLOW: Color = Color.WHITE
## What entries() gives for a card the Hero does not know.
const UNKNOWN: int = 0
## The room left around the cards, so that a Glow, which reaches 7 pixels past its card, is
## not cut off where the window stops drawing.
const GLOW_ROOM: int = 8
## Room for four cards across and one row, as a window first opens.
const OPENING_SIZE: Vector2 = Vector2(4.0 * (CARD_HEIGHT * CardGeometry.ASPECT + GAP) + 24.0 + 2.0 * GLOW_ROOM,
	CARD_HEIGHT + 78.0 + 2.0 * GLOW_ROOM)

## How long a Glow takes to come up; the Encounter Screen sets it.
var glow_seconds: float = 0.0

var _arrangement: Arrangement
var _holders: Array[Control] = []
var _entries: Array[int] = []
var _faces: Dictionary[int, CardFace] = {}
## What was last shown, so that a snapshot that changes nothing here rebuilds nothing.
var _shown: String = ""
## The arrangement it was made with, kept while a search lays it out as a grid.
var _usual: Arrangement
## The cards being selected in a search shown here, or null when it shows no search.
var _picks: CardPicks = null
## Whether it is a graveyard's, whose cards show their flashback chips.
var _is_graveyard: bool


func _init(arrangement: Arrangement, tint: Color, is_graveyard: bool = false) -> void:
	super("", true, tint)
	_is_graveyard = is_graveyard
	_arrangement = arrangement
	_usual = arrangement
	size = OPENING_SIZE
	if arrangement == Arrangement.ROW:
		# One row: it never scrolls down, only sideways.
		scroll().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


## Shows [param cards] under [param title], such as "Jackson's Graveyard": each an
## MmObjectView in the zone's own order, or null for a card the Hero does not know.
## [param snapshot] has each card's look, and a card [param clicks] has an answer on glows
## and takes a click.
## With [param picks] for a search, it shows the search instead (game ADR 0058).
func show_cards(title: String, cards: Array, snapshot: EncounterSnapshot, clicks: DecisionClicks,
		picks: CardPicks = null) -> void:
	show_title("%s (%d)" % [title, cards.size()])
	_picks = picks if picks != null and picks.is_searching() else null
	_set_arrangement(Arrangement.GRID if _picks != null else _usual)
	var ordered: Array = cards.duplicate()
	if _picks != null:
		ordered = searched_order(cards, _picks)
	elif _arrangement == Arrangement.GRID:
		ordered.reverse()
	var signature: String = _signature(ordered, clicks)
	if signature == _shown:
		return
	_shown = signature
	clear()
	_holders.clear()
	_entries.clear()
	_faces.clear()
	var box: Container = HFlowContainer.new() if _arrangement == Arrangement.GRID else HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for constant: String in ["h_separation", "v_separation", "separation"]:
		box.add_theme_constant_override(constant, GAP)
	var room: MarginContainer = MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		room.add_theme_constant_override(side, GLOW_ROOM)
	room.add_child(box)
	body().add_child(room)
	for entry: Variant in ordered:
		var seen: MmObjectView = entry as MmObjectView
		var holder: Control = _holder(seen, snapshot, clicks)
		box.add_child(holder)
		_holders.append(holder)
		_entries.append(seen.id if seen != null else UNKNOWN)


## [param cards] as a search shows them: the cards [param picks] may find first, then the
## rest, each by name, and in library order for one name (game ADR 0058).
static func searched_order(cards: Array, picks: CardPicks) -> Array:
	var order: Dictionary[int, int] = {}
	var shown: Array = []
	for index: int in cards.size():
		var seen: MmObjectView = cards[index] as MmObjectView
		if seen != null:
			order[seen.id] = index
			shown.append(seen)
	shown.sort_custom(func(a: MmObjectView, b: MmObjectView) -> bool:
		var a_found: bool = picks.is_candidate(a.id)
		if a_found != picks.is_candidate(b.id):
			return a_found
		if a.name != b.name:
			return a.name < b.name
		return order[a.id] < order[b.id])
	return shown


## The object ID of each card shown, in the order shown, or UNKNOWN for a card back.
func entries() -> Array[int]:
	return _entries


## Where each card shown is, in the order shown, in the window's own coordinates. The
## cards find their places a frame after they are shown.
func card_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for holder: Control in _holders:
		rects.append(Rect2(holder.global_position - global_position, holder.size))
	return rects


## The face of the card [param object_id], or null if it is not shown face up.
func face_of(object_id: int) -> CardFace:
	return _faces.get(object_id, null) as CardFace


## Which way the card [param object_id] is scrolled out of sight: -1 above what the window
## shows, 1 below it, 0 if its middle is in sight or it is not shown at all.
func hidden_past(object_id: int) -> int:
	var face: CardFace = face_of(object_id)
	if face == null:
		return 0
	var seen: Rect2 = scroll().get_global_rect()
	var middle: float = face.get_global_rect().get_center().y
	if middle < seen.position.y:
		return -1
	return 1 if middle > seen.end.y else 0


## Where a card flying to or from the card [param object_id] is drawn, in the window's own
## coordinates, as its middle and its height: on the card, or, for one scrolled out of
## sight, small on the nearest edge of what the window shows, above or below (game ADR
## 0043). The middle of the window for a card it does not show.
func flight_place(object_id: int) -> Rect2:
	var face: CardFace = face_of(object_id)
	if face == null:
		return Rect2(size / 2.0, Vector2(0.0, CARD_HEIGHT))
	var seen: Rect2 = scroll().get_global_rect()
	var middle: Vector2 = face.get_global_rect().get_center() - global_position
	var hidden: int = hidden_past(object_id)
	if hidden == 0:
		return Rect2(middle, Vector2(0.0, CARD_HEIGHT))
	var edge: float = (seen.position.y if hidden < 0 else seen.end.y) - global_position.y
	return Rect2(Vector2(middle.x, edge), Vector2(0.0, CARD_HEIGHT * EncounterLayout.UNSEEN_FLIGHT_SCALE))


## Shows the card [param object_id] or, while its card is in the air, nothing of it.
func show_face(object_id: int, is_shown: bool) -> void:
	var face: CardFace = face_of(object_id)
	if face != null:
		face.modulate.a = 1.0 if is_shown else 0.0


## What takes a click on the card [param object_id], or null if a click answers nothing.
func catcher_of(object_id: int) -> ClickCatcher:
	var face: CardFace = face_of(object_id)
	return ClickCatcher.of(face) if face != null else null


func _holder(seen: MmObjectView, snapshot: EncounterSnapshot, clicks: DecisionClicks) -> Control:
	var card: Vector2 = Vector2(CARD_HEIGHT * CardGeometry.ASPECT, CARD_HEIGHT)
	var holder: Control = Control.new()
	holder.custom_minimum_size = card
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if seen == null:
		holder.add_child(CardBack.make(CARD_HEIGHT))
		return holder
	var face: CardFace = CardFace.new()
	face.setup(snapshot.look_of(seen.id), CARD_HEIGHT)
	if _is_graveyard:
		face.show_graveyard_chips()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	_faces[seen.id] = face
	if _picks != null:
		_add_search_answer(seen.id, face, card)
		return holder
	if not clicks.options_of(seen.id).is_empty():
		BorderEffects.add_glow_of(face, card, clicks.colors_of(seen.id), glow_seconds)
		var catcher: ClickCatcher = ClickCatcher.add(face, card)
		catcher.clicked.connect(func() -> void: card_clicked.emit(seen.id))
		catcher.mouse_entered.connect(func() -> void: card_hovered.emit(seen.id, true))
		catcher.mouse_exited.connect(func() -> void: card_hovered.emit(seen.id, false))
	return holder


## A card a search may find: white while selected, green while it may be selected, and
## nothing once as many are selected as may be; a click selects it or lets it go.
func _add_search_answer(object_id: int, face: CardFace, card: Vector2) -> void:
	var color: Color = Color.TRANSPARENT
	if _picks.is_picked(object_id):
		color = PICKED_GLOW
	elif _picks.can_pick(object_id):
		color = DecisionClicks.color_of(DecisionClicks.Kind.OTHER)
	if color == Color.TRANSPARENT:
		return
	BorderEffects.add_glow_of(face, card, [color], glow_seconds)
	var catcher: ClickCatcher = ClickCatcher.add(face, card)
	catcher.clicked.connect(func() -> void: card_clicked.emit(object_id))
	catcher.mouse_entered.connect(func() -> void: card_hovered.emit(object_id, true))
	catcher.mouse_exited.connect(func() -> void: card_hovered.emit(object_id, false))


## Lays the cards out as [param arrangement]: a row never scrolls down.
func _set_arrangement(arrangement: Arrangement) -> void:
	_arrangement = arrangement
	var is_row: bool = arrangement == Arrangement.ROW
	scroll().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if is_row else ScrollContainer.SCROLL_MODE_AUTO


## Everything that decides what is drawn: which cards, in what order, and which answer.
func _signature(ordered: Array, clicks: DecisionClicks) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if _picks != null:
		parts.append("search %s" % [_picks.picked()])
	for entry: Variant in ordered:
		var seen: MmObjectView = entry as MmObjectView
		if seen == null:
			parts.append("?")
		else:
			parts.append("%d%s" % [seen.id, "" if clicks.options_of(seen.id).is_empty() else "!"])
	return ",".join(parts)
