class_name PileWindow
extends ZoneWindow
## The Zone Window of a pile: a graveyard, an exile or a library. A graveyard or exile is a
## grid of Card Faces that wraps to the window's width, the newest card first. A library
## is one row scrolled sideways, its top card on the left, showing a card back for each
## card the Hero does not know and its face for one they do, such as a card they put on
## the bottom. A card that answers the decision glows and is clicked here (ADR 0032).

signal card_clicked(object_id: int)

enum Arrangement { GRID, ROW }

const CARD_HEIGHT: float = EncounterLayout.HAND_CARD_HEIGHT
const GAP: int = 8
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


func _init(arrangement: Arrangement, tint: Color) -> void:
	super("", true, tint)
	_arrangement = arrangement
	size = OPENING_SIZE
	if arrangement == Arrangement.ROW:
		# One row: it never scrolls down, only sideways.
		scroll().vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


## Shows [param cards] under [param title], such as "Jackson's Graveyard": each an
## MmObjectView in the zone's own order, or null for a card the Hero does not know.
## [param snapshot] has each card's look, and a card [param clicks] has an answer on glows
## and takes a click.
func show_cards(title: String, cards: Array, snapshot: EncounterSnapshot, clicks: DecisionClicks) -> void:
	show_title("%s (%d)" % [title, cards.size()])
	var ordered: Array = cards.duplicate()
	if _arrangement == Arrangement.GRID:
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
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	_faces[seen.id] = face
	if not clicks.options_of(seen.id).is_empty():
		BorderEffects.add_glow_of(face, card, clicks.colors_of(seen.id), glow_seconds)
		ClickCatcher.add(face, card).clicked.connect(func() -> void: card_clicked.emit(seen.id))
	return holder


## Everything that decides what is drawn: which cards, in what order, and which answer.
func _signature(ordered: Array, clicks: DecisionClicks) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in ordered:
		var seen: MmObjectView = entry as MmObjectView
		if seen == null:
			parts.append("?")
		else:
			parts.append("%d%s" % [seen.id, "" if clicks.options_of(seen.id).is_empty() else "!"])
	return ",".join(parts)
