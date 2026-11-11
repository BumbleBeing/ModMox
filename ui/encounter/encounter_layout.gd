class_name EncounterLayout
extends RefCounted
## Where every Region (game glossary) of the Encounter Screen sits, worked out from the
## screen's size alone so it can be tested without a window. Designed at 1920 × 1080 (A205):
## rows keep their share of the height, the sidebar and the pile column keep their width,
## and extra width goes to the battlefield.

const DESIGN_HEIGHT: float = 1080.0
const SIDEBAR_WIDTH: float = 340.0
const PILES_WIDTH: float = 170.0
const GUTTER: float = 12.0
## A pile's card is this tall, with its label under it.
const PILE_HEIGHT: float = 140.0
const PILE_LABEL: float = 22.0
## A card in the Hero's hand, and a card back in the Villain's.
const HAND_CARD_HEIGHT: float = 250.0
const VILLAIN_CARD_HEIGHT: float = 150.0
## How much of a card in the Hero's hand is below the bottom of the screen, of its height:
## enough to cut it off a little under its type line.
const HAND_HIDDEN: float = 0.25
## How much of each card in the Hero's hand shows at rest, of its width.
const HAND_SHOWN: float = 0.42
const VILLAIN_HAND_SHOWN: float = 0.55
## A card near the cursor rises by at most this much of its height.
const HAND_RISE: float = 1.0 / 8.0
## How far a fanned card turns for each place away from the middle, in radians, and how
## far it drops for the square of that.
const FAN_ANGLE: float = 0.025
const FAN_DROP: float = 2.5
const ROW_GAP: float = 8.0
## Noncreature permanents are drawn this much smaller than creatures, and take at most this
## share of their row (A276, A277).
const OTHERS_SCALE: float = 0.85
const OTHERS_SHARE: float = 1.0 / 3.0
## Room at each end of a line of permanents, so a Glow at the end is not cut off.
const LINE_PAD: float = 8.0
## Once attackers are declared, creatures not in combat are drawn this much smaller, and
## those in it step this far toward the middle of the board (A279).
const BYSTANDER_SCALE: float = 0.8
const COMBAT_STEP: float = 40.0
## The step buttons' column in a player's panel.
const STEP_WIDTH: float = 112.0
const STEP_GAP: float = 4.0
const PANEL_PAD: float = 10.0
const CONTROLS_PAD: float = 6.0
const CONTROLS_GAP: float = 6.0
## Pass is this many times as tall as Undo and Auto-pass.
const PASS_TALLER: float = 1.3

## The Info Panel, at the left end of the hand's strip (A293).
const INFO_WIDTH: float = 300.0
const INFO_PAD: float = 6.0
## The Option Menu: how wide it is, how tall a row is, the gap between rows, the room around
## them, and how many rows show before it scrolls (A286).
const MENU_WIDTH: float = 330.0
const MENU_ROW: float = 38.0
const MENU_GAP: float = 4.0
const MENU_PAD: float = 5.0
const MENU_ROWS_SHOWN: int = 3
## The Pause Menu's window, and the height each of its buttons takes.
const PAUSE_WIDTH: float = 420.0
const PAUSE_HEADING: float = 94.0
const PAUSE_ROW: float = 58.0

## The Regions no two of which may overlap.
const LEAVES: Array[String] = [
	"villain_panel", "hero_panel",
	"villain_hand", "villain_lands", "villain_nonlands", "hero_nonlands", "hero_lands", "hero_hand",
	"info", "villain_library", "villain_graveyard", "villain_exile", "hero_library", "hero_graveyard", "hero_exile",
]


## Every Region's rectangle on a screen of [param screen] pixels. The six piles fill the
## right column with equal spacing, the Villain's above the Hero's, each running library,
## graveyard, exile from the top (A294). Besides LEAVES it has
## "sidebar", "piles" and "battlefield" (both players' rows), which contain others.
static func regions(screen: Vector2) -> Dictionary[String, Rect2]:
	var found: Dictionary[String, Rect2] = {}
	var scale: float = screen.y / DESIGN_HEIGHT
	var left: float = SIDEBAR_WIDTH + GUTTER
	var width: float = screen.x - PILES_WIDTH - GUTTER - left
	found["sidebar"] = Rect2(0, 0, SIDEBAR_WIDTH, screen.y)
	var panel_height: float = (screen.y - PANEL_PAD * 3.0) / 2.0
	found["villain_panel"] = Rect2(PANEL_PAD, PANEL_PAD, SIDEBAR_WIDTH - PANEL_PAD * 2.0, panel_height)
	found["hero_panel"] = Rect2(PANEL_PAD, panel_height + PANEL_PAD * 2.0, SIDEBAR_WIDTH - PANEL_PAD * 2.0, panel_height)

	found["villain_hand"] = Rect2(left, 0, width, 80.0 * scale)
	# The Hero's hand sits low, cut off below its type lines. The Hero's rows sit low with
	# it, which opens a lane across the middle for creatures in combat to step into.
	var drop: float = HAND_CARD_HEIGHT * HAND_HIDDEN
	found["villain_lands"] = Rect2(left, 92.0 * scale, width, 140.0 * scale)
	found["villain_nonlands"] = Rect2(left, 244.0 * scale, width, 200.0 * scale)
	found["hero_nonlands"] = Rect2(left, (472.0 + drop) * scale, width, 200.0 * scale)
	found["hero_lands"] = Rect2(left, (684.0 + drop) * scale, width, 140.0 * scale)
	var strip: Rect2 = Rect2(left, (836.0 + drop) * scale, width, screen.y - (836.0 + drop) * scale)
	found["info"] = Rect2(strip.position.x, strip.position.y + INFO_PAD, INFO_WIDTH, strip.size.y - INFO_PAD * 2.0)
	# The hand keeps to the middle of the battlefield between strict bounds: the Info
	# Panel's side, and as far in from the other side, so it can never overlap the panel.
	var inset: float = INFO_WIDTH + GUTTER
	found["hero_hand"] = Rect2(strip.position.x + inset, strip.position.y, strip.size.x - inset * 2.0, strip.size.y)
	found["battlefield"] = Rect2(left, 86.0 * scale, width, (744.0 + drop) * scale)

	var piles_left: float = screen.x - PILES_WIDTH
	found["piles"] = Rect2(piles_left, 0, PILES_WIDTH, screen.y)
	var pile: Vector2 = Vector2(PILES_WIDTH, PILE_HEIGHT + PILE_LABEL)
	var gap: float = (screen.y - pile.y * 6.0) / 7.0
	var keys: Array[String] = [
		"villain_library", "villain_graveyard", "villain_exile", "hero_library", "hero_graveyard", "hero_exile",
	]
	for index: int in keys.size():
		found[keys[index]] = Rect2(Vector2(piles_left, gap + (pile.y + gap) * index), pile)
	return found


## The parts of a player's panel of [param panel]: "name", "portrait" (square), "life" (in
## the portrait's bottom right corner), "mana_0" to "mana_5" (WUBRGC, spanning the
## portrait's width), "emblems", and "step_0" to "step_11" down the right side. Under the
## Emblems button is "controls", a section of its own filled by "undo", "pass" and
## "auto_pass" from the top, which only the Hero's panel has.
static func panel(panel_rect: Rect2) -> Dictionary[String, Rect2]:
	var parts: Dictionary[String, Rect2] = {}
	var left: float = panel_rect.position.x + PANEL_PAD
	var column: float = panel_rect.size.x - STEP_WIDTH - PANEL_PAD * 3.0
	parts["name"] = Rect2(left, panel_rect.position.y + 6, column, 30)
	var portrait: Rect2 = Rect2(left, panel_rect.position.y + 40, column, column)
	parts["portrait"] = portrait
	var life: Vector2 = Vector2(86, 62)
	parts["life"] = Rect2(portrait.end - life - Vector2(5, 5), life)
	var mana_width: float = (column - STEP_GAP * 5.0) / 6.0
	for type: int in 6:
		parts["mana_%d" % type] = Rect2(left + (mana_width + STEP_GAP) * type, portrait.end.y + 8, mana_width, 54)
	parts["emblems"] = Rect2(left, portrait.end.y + 70, column, 36)
	var controls: Rect2 = Rect2(left, parts["emblems"].end.y + 10, column, panel_rect.end.y - PANEL_PAD - parts["emblems"].end.y - 10)
	parts["controls"] = controls
	var inside: float = column - CONTROLS_PAD * 2.0
	var inner_left: float = left + CONTROLS_PAD
	# The three buttons share the whole section, evenly spaced, Pass the tallest.
	var room: float = controls.size.y - CONTROLS_PAD * 2.0 - CONTROLS_GAP * 2.0
	var button: float = room / (2.0 + PASS_TALLER)
	parts["undo"] = Rect2(inner_left, controls.position.y + CONTROLS_PAD, inside, button)
	parts["pass"] = Rect2(inner_left, parts["undo"].end.y + CONTROLS_GAP, inside, button * PASS_TALLER)
	parts["auto_pass"] = Rect2(inner_left, parts["pass"].end.y + CONTROLS_GAP, inside, button)
	var step_height: float = (panel_rect.size.y - PANEL_PAD * 2.0 - STEP_GAP * 11.0) / 12.0
	for step: int in 12:
		parts["step_%d" % step] = Rect2(panel_rect.end.x - PANEL_PAD - STEP_WIDTH,
				panel_rect.position.y + PANEL_PAD + (step_height + STEP_GAP) * step, STEP_WIDTH, step_height)
	return parts


## How tall the Battlefield Faces in a row of [param row_rect] are: as tall as lets a tapped
## one, which stands taller sideways, still fit, and shorter when the row would overflow.
static func row_face_height(is_tapped: Array[bool], row_rect: Rect2) -> float:
	var height: float = floorf(row_rect.size.y / CardGeometry.FIELD_ASPECT)
	var total: float = _row_width(is_tapped, height)
	if total > row_rect.size.x:
		# The gaps do not shrink, so only the faces' share of the width is scaled.
		var gaps: float = ROW_GAP * (is_tapped.size() - 1)
		height = floorf(height * (row_rect.size.x - gaps) / (total - gaps))
		while height > 1.0 and _row_width(is_tapped, height) > row_rect.size.x:
			height -= 1.0
	return height


## Where each permanent in a row stands: its footprint, sideways if tapped, centered in
## [param row_rect] on one line.
static func row(is_tapped: Array[bool], row_rect: Rect2) -> Array[Rect2]:
	var height: float = row_face_height(is_tapped, row_rect)
	var x: float = row_rect.position.x + (row_rect.size.x - _row_width(is_tapped, height)) / 2.0
	var footprints: Array[Rect2] = []
	for tapped: bool in is_tapped:
		var footprint: Vector2 = _footprint(tapped, height)
		footprints.append(Rect2(Vector2(x, row_rect.position.y + (row_rect.size.y - footprint.y) / 2.0), footprint))
		x += footprint.x + ROW_GAP
	return footprints


## How tall a creature's Battlefield Face is in the nonland row [param row_rect]: as tall as
## lets a tapped one, which stands taller sideways, still fit.
static func creature_height(row_rect: Rect2) -> float:
	return floorf(row_rect.size.y / CardGeometry.FIELD_ASPECT)


## How a player's nonland row is shared (A276, A277): "creatures" toward the left and
## middle, and "others" (noncreature permanents) to their right, smaller and set back toward
## that player's own edge of the board. The others take only the width their faces need,
## [param others_tapped] saying which are tapped, and never more than OTHERS_SHARE of the
## row. With no others, the creatures have the whole row and "others" is empty.
static func nonland_groups(row_rect: Rect2, others_tapped: Array[bool], is_hero: bool) -> Dictionary[String, Rect2]:
	var groups: Dictionary[String, Rect2] = {}
	var others_width: float = 0.0
	if not others_tapped.is_empty():
		var needed: float = line_width(others_tapped, _same_heights(others_tapped.size(), others_height(row_rect)))
		others_width = minf(needed, row_rect.size.x * OTHERS_SHARE)
	groups["creatures"] = Rect2(row_rect.position, Vector2(row_rect.size.x - others_width, row_rect.size.y))
	var set_back: float = row_rect.size.y * OTHERS_SCALE
	var top: float = row_rect.end.y - set_back if is_hero else row_rect.position.y
	groups["others"] = Rect2(row_rect.end.x - others_width, top, others_width, set_back if others_width > 0.0 else 0.0)
	return groups


## How tall a noncreature permanent's face is in the nonland row [param row_rect].
static func others_height(row_rect: Rect2) -> float:
	return floorf(creature_height(row_rect) * OTHERS_SCALE)


## How much smaller a creature is drawn for not being in combat: BYSTANDER_SCALE while there
## is a combat it is not part of, and 1 otherwise.
static func bystander_scale(is_combat_on: bool, is_in_combat: bool) -> float:
	return BYSTANDER_SCALE if is_combat_on and not is_in_combat else 1.0


## How far a creature in combat steps toward the middle of the board: up for the Hero's,
## down for the Villain's.
static func combat_step(is_hero: bool) -> float:
	return -COMBAT_STEP if is_hero else COMBAT_STEP


## The width of a line of permanents, each [param heights] tall and sideways if tapped, with
## LINE_PAD at each end. A line keeps its faces' size and scrolls when it is wider than its
## group (A278).
static func line_width(is_tapped: Array[bool], heights: Array[float]) -> float:
	if is_tapped.is_empty():
		return 0.0
	var total: float = LINE_PAD * 2.0 - ROW_GAP
	for index: int in is_tapped.size():
		total += _footprint(is_tapped[index], heights[index]).x + ROW_GAP
	return total


## Where each permanent of a line stands inside its group, [param box_height] tall, before
## any scrolling: from LINE_PAD at the left, each centered from top to bottom.
static func line(is_tapped: Array[bool], heights: Array[float], box_height: float) -> Array[Rect2]:
	var footprints: Array[Rect2] = []
	var x: float = LINE_PAD
	for index: int in is_tapped.size():
		var footprint: Vector2 = _footprint(is_tapped[index], heights[index])
		footprints.append(Rect2(Vector2(x, (box_height - footprint.y) / 2.0), footprint))
		x += footprint.x + ROW_GAP
	return footprints


## How far a line [param content_width] wide can scroll in a group [param view_width] wide.
static func max_scroll(content_width: float, view_width: float) -> float:
	return maxf(0.0, content_width - view_width)


## Where a line starts in its group: centered when it fits, and at the left edge, moved by
## [param scroll], when it does not.
static func line_start(content_width: float, view_width: float, scroll: float) -> float:
	if content_width <= view_width:
		return (view_width - content_width) / 2.0
	return -clampf(scroll, 0.0, max_scroll(content_width, view_width))


## How far apart the cards of a hand of [param count] start, each [param card_width] wide
## and showing [param shown] of that unless the hand has to squeeze into [param width].
static func hand_step(count: int, width: float, card_width: float, shown: float) -> float:
	return minf(card_width * shown, (width - card_width) / maxf(count - 1, 1))


## Where each card of the Hero's hand rests, fanned along the bottom of [param hand_rect].
static func hand_rest(count: int, hand_rect: Rect2, card_size: Vector2) -> Array[Vector2]:
	var step: float = hand_step(count, hand_rect.size.x, card_size.x, HAND_SHOWN)
	var x: float = hand_rect.position.x + (hand_rect.size.x - (step * (count - 1) + card_size.x)) / 2.0
	var places: Array[Vector2] = []
	for index: int in count:
		var away: float = index - (count - 1) / 2.0
		places.append(Vector2(x + step * index, hand_rect.position.y + away * away * FAN_DROP))
	return places


## Where each card back of the Villain's hand hangs, fanned from the top edge.
static func villain_hand(count: int, hand_rect: Rect2, card_size: Vector2) -> Array[Vector2]:
	var step: float = hand_step(count, hand_rect.size.x, card_size.x, VILLAIN_HAND_SHOWN)
	var x: float = hand_rect.position.x + (hand_rect.size.x - (step * (count - 1) + card_size.x)) / 2.0
	var places: Array[Vector2] = []
	for index: int in count:
		var away: float = index - (count - 1) / 2.0
		places.append(Vector2(x + step * index, hand_rect.end.y - card_size.y - away * away * FAN_DROP))
	return places


## How far card [param index] of [param count] is turned in a fan.
static func fan_angle(index: int, count: int) -> float:
	return (index - (count - 1) / 2.0) * FAN_ANGLE


## Whether [param cursor] is close enough to a hand resting at [param rest] to part it.
static func is_cursor_over_hand(rest: Array[Vector2], card_size: Vector2, cursor: Vector2) -> bool:
	if rest.is_empty():
		return false
	var top: float = rest[0].y
	for place: Vector2 in rest:
		top = minf(top, place.y)
	return cursor.y > top - card_size.y * HAND_RISE - 10.0 and cursor.x > rest[0].x - 30.0 \
		and cursor.x < rest[rest.size() - 1].x + card_size.x + 30.0


## Which card of a hand resting at [param rest] the cursor is over, as a place between
## cards (2.5 is halfway between the third and fourth). It is worked out from where the
## cards rest, never from where they have moved to, so parting them cannot make it jitter.
static func hand_cursor_place(rest: Array[Vector2], card_size: Vector2, cursor: Vector2) -> float:
	if rest.size() < 2:
		return 0.0
	var step: float = rest[1].x - rest[0].x
	return clampf((cursor.x - rest[0].x) / step - 0.5, 0.0, rest.size() - 1.0)


## Where the cards of a hand resting at [param rest] go while [param cursor] is over it:
## they part sideways so the card under the cursor shows whole, and those nearest rise a
## little, never more than HAND_RISE of their height.
static func hand_spread(rest: Array[Vector2], card_size: Vector2, cursor: Vector2) -> Array[Vector2]:
	if not is_cursor_over_hand(rest, card_size, cursor):
		return rest.duplicate()
	var place: float = hand_cursor_place(rest, card_size, cursor)
	var hidden: float = card_size.x - (rest[1].x - rest[0].x if rest.size() > 1 else card_size.x)
	var places: Array[Vector2] = []
	for index: int in rest.size():
		var away: float = index - place
		var side: float = clampf(away, -1.0, 1.0)
		var moved: Vector2 = rest[index]
		# A card to the right covers the one under the cursor, so it moves clear; those to
		# the left only make a little room.
		moved.x += side * hidden * (0.95 if side > 0.0 else 0.35)
		moved.y -= card_size.y * HAND_RISE * clampf(1.0 - absf(away) / 1.5, 0.0, 1.0)
		places.append(moved)
	return places


## As hand_spread(), but no card leaves [param bounds]. The card under the cursor still shows
## whole: it moves in from the right end if it must, so the card after it can clear it. The
## cards on each side of those two keep their spacing when there is room, and are squeezed
## evenly toward their end of the bounds when there is not, so none is ever hidden behind
## another at the edge.
static func hand_spread_within(rest: Array[Vector2], card_size: Vector2, cursor: Vector2, bounds: Rect2) -> Array[Vector2]:
	var places: Array[Vector2] = hand_spread(rest, card_size, cursor)
	if places.size() < 2:
		return places
	var most_left: float = bounds.position.x
	var most_right: float = maxf(most_left, bounds.end.x - card_size.x)
	var last: int = places.size() - 1
	var under: int = roundi(hand_cursor_place(rest, card_size, cursor))
	var after: int = mini(under + 1, last)
	var gap: float = places[after].x - places[under].x
	var anchor: float = clampf(minf(places[under].x, most_right - gap), most_left, most_right)
	var held: Array[Vector2] = places.duplicate()
	var left_span: float = places[under].x - places[0].x
	var left_scale: float = minf(1.0, (anchor - most_left) / left_span) if left_span > 0.0 else 1.0
	for index: int in under + 1:
		held[index].x = anchor - (places[under].x - places[index].x) * left_scale
	var after_x: float = minf(anchor + gap, most_right)
	var right_span: float = places[last].x - places[after].x
	var right_scale: float = minf(1.0, (most_right - after_x) / right_span) if right_span > 0.0 else 1.0
	for index: int in range(after, last + 1):
		held[index].x = after_x + (places[index].x - places[after].x) * right_scale
	return held


## The order to draw lands named [param names] in, as indexes into it: lands of one name
## stand together, so a new land goes just right of the rightmost land with its name, and a
## land with a new name starts a group at the right end.
static func land_order(names: Array[String]) -> Array[int]:
	var groups: Array[String] = []
	for land_name: String in names:
		if not groups.has(land_name):
			groups.append(land_name)
	var order: Array[int] = []
	for group: String in groups:
		for index: int in names.size():
			if names[index] == group:
				order.append(index)
	return order


## Where an Option Menu of [param row_count] rows opens when a card is clicked at
## [param at]: there, moved as little as keeps it inside [param field]. It shows at most
## MENU_ROWS_SHOWN rows and scrolls for the rest.
static func menu_rect(at: Vector2, row_count: int, field: Rect2) -> Rect2:
	var shown: int = clampi(row_count, 1, MENU_ROWS_SHOWN)
	var menu: Vector2 = Vector2(MENU_WIDTH, shown * MENU_ROW + (shown - 1) * MENU_GAP + MENU_PAD * 2.0)
	return Rect2(Vector2(
		clampf(at.x, field.position.x, field.end.x - menu.x),
		clampf(at.y, field.position.y, field.end.y - menu.y)), menu)


## Which end of a scrolling line a face is hidden past: -1 for the left, 1 for the right
## and 0 if it is in view. [param middle] is the face's middle measured from the line's left
## edge, and a face behind an arrow, [param arrow_width] wide, counts as hidden.
static func hidden_past(middle: float, view_width: float, arrow_width: float) -> int:
	if middle < arrow_width:
		return -1
	if middle > view_width - arrow_width:
		return 1
	return 0


## The Pause Menu's window with [param button_count] buttons, centered on [param field].
static func pause_rect(button_count: int, field: Rect2) -> Rect2:
	var window: Vector2 = Vector2(PAUSE_WIDTH, PAUSE_HEADING + button_count * PAUSE_ROW + 16.0)
	return Rect2(field.position + (field.size - window) / 2.0, window)


static func _same_heights(count: int, height: float) -> Array[float]:
	var heights: Array[float] = []
	for index: int in count:
		heights.append(height)
	return heights


static func _footprint(is_tapped: bool, height: float) -> Vector2:
	var upright: Vector2 = BattlefieldFace.size_for(height)
	return Vector2(upright.y, upright.x) if is_tapped else upright


static func _row_width(is_tapped: Array[bool], height: float) -> float:
	if is_tapped.is_empty():
		return 0.0
	var total: float = 0.0
	for tapped: bool in is_tapped:
		total += _footprint(tapped, height).x + ROW_GAP
	return total - ROW_GAP
