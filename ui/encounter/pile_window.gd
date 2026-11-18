class_name PileWindow
extends ZoneWindow
## The Zone Window of a pile: a graveyard, an exile or a library. A graveyard or exile is a
## grid of Card Faces that wraps to the window's width, the newest card first. A library
## is one row scrolled sideways, its top card on the left, showing a card back for each
## card the Hero does not know and its face for one they do, such as a card they put on
## the bottom. A card that answers the decision glows and is clicked here (ADR 0032). The
## Hero's library while they may look at its top card holds only that card, with a caption
## (game ADR 0055).

signal card_clicked(object_id: int)
## The cursor came onto ([param is_over]) or left a card that answers the decision.
signal card_hovered(object_id: int, is_over: bool)

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

## What a top card shown alone says under it (game ADR 0055).
const TOP_CARD_CAPTION: String = "Top card · only you see it"
const CAPTION_COLOR: Color = Color("#9aa3af")

## How long a Glow takes to come up; the Encounter Screen sets it.
var glow_seconds: float = 0.0

var _arrangement: Arrangement
var _holders: Array[Control] = []
var _entries: Array[int] = []
var _faces: Dictionary[int, CardFace] = {}
## What was last shown, so that a snapshot that changes nothing here rebuilds nothing.
var _shown: String = ""
var _caption: Label = null


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
	_caption = null
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


## Shows only [param top], the top card of a library of [param count] cards that the Hero
## may look at (game ADR 0055), under [param title] and above a caption saying so. A card
## [param clicks] has an answer on glows and takes a click, as in show_cards().
func show_top_card(title: String, count: int, top: MmObjectView, snapshot: EncounterSnapshot, clicks: DecisionClicks) -> void:
	show_title("%s (%d)" % [title, count])
	var signature: String = "top " + _signature([top], clicks)
	if signature == _shown:
		return
	_shown = signature
	clear()
	_holders.clear()
	_entries.clear()
	_faces.clear()
	var room: MarginContainer = MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		room.add_theme_constant_override(side, GLOW_ROOM)
	body().add_child(room)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	room.add_child(column)
	var holder: Control = _holder(top, snapshot, clicks)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(holder)
	_holders.append(holder)
	_entries.append(top.id)
	var note: Label = Label.new()
	note.text = TOP_CARD_CAPTION
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", CAPTION_COLOR)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(note)
	_caption = note


## The caption under a top card shown alone, or null.
func caption() -> Label:
	return _caption if is_instance_valid(_caption) and _caption.is_inside_tree() else null


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
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)
	_faces[seen.id] = face
	if not clicks.options_of(seen.id).is_empty():
		BorderEffects.add_glow_of(face, card, clicks.colors_of(seen.id), glow_seconds)
		var catcher: ClickCatcher = ClickCatcher.add(face, card)
		catcher.clicked.connect(func() -> void: card_clicked.emit(seen.id))
		catcher.mouse_entered.connect(func() -> void: card_hovered.emit(seen.id, true))
		catcher.mouse_exited.connect(func() -> void: card_hovered.emit(seen.id, false))
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
