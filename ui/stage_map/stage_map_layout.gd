class_name StageMapLayout
extends RefCounted
## Where the Stage Map draws things (milestone 17, signed off as prototypes/stage_map_screen):
## the map split into even cells, a row 320 pixels tall and a column 192 wide, each Node
## somewhere in its own cell; and the view, which frames the Hero's row near the bottom and
## the two rows ahead under the Run Bar, scrolling only up and down. Pure: no Nodes.

const SCREEN: Vector2 = Vector2(1920, 1080)
const BAR_HEIGHT: float = 96.0
const ROW_PITCH: float = 320.0
const COLUMN_PITCH: float = 192.0
## The framed row's centers stand this far down the screen.
const FRAMED_ROW_Y: float = SCREEN.y - 170.0
## A Node is drawn up to this far from the center of its cell, sideways and up or down.
const NODE_LEEWAY: Vector2 = Vector2(40.0, 80.0)
## A Node's 32 × 32 icon is drawn at twice its size; the Boss's Node is a larger disc.
const ICON_SCALE: int = 2
const ICON_RADIUS: float = 32.0
const BOSS_RADIUS: float = 52.0
## How far beyond a Node's edge a click still picks it.
const CLICK_SLACK: float = 4.0
## A glide along one row's length takes this long at Fast; longer links take longer, and
## none takes less than the shortest.
const GLIDE_SECONDS: float = 0.8
const SHORTEST_GLIDE: float = 0.6


## The row framed at the bottom while the Hero is at [param hero_row], never past either
## end of the map.
static func framed_row(hero_row: float) -> float:
	return clampf(hero_row, 1.0, StageMap.ROWS - 2)


## The center of the cell at [param row] and [param column] with the view at
## [param scroll_row]. Row 1 is at the bottom.
static func cell_center(row: int, column: int, scroll_row: float) -> Vector2:
	return Vector2(
		SCREEN.x / 2.0 + (column - 5) * COLUMN_PITCH,
		FRAMED_ROW_Y - (row - scroll_row) * ROW_PITCH)


## Where [param node] is drawn with the view at [param scroll_row]: its cell's center moved
## by [param offset], a share (-1 to 1 each way) of NODE_LEEWAY.
static func node_spot(node: MapNode, offset: Vector2, scroll_row: float) -> Vector2:
	return (cell_center(node.row, node.column, scroll_row) + offset * NODE_LEEWAY).round()


## How far a Node of [param kind] reaches from its center.
static func radius_of(kind: StageMap.Kind) -> float:
	return BOSS_RADIUS if kind == StageMap.Kind.BOSS else ICON_RADIUS


## The id of the Node of [param visit] drawn under [param point] with the view at
## [param scroll_row], or -1.
static func node_at(point: Vector2, visit: StageVisit, scroll_row: float) -> int:
	for node: MapNode in visit.map.nodes:
		var spot: Vector2 = node_spot(node, visit.offsets.get(node.id, Vector2.ZERO), scroll_row)
		if spot.distance_to(point) <= radius_of(node.kind) + CLICK_SLACK:
			return node.id
	return -1


## How long the glide from [param from] to [param to] takes at [param speed].
static func glide_seconds(from: MapNode, to: MapNode, speed: GameSpeed.Speed) -> float:
	var rows: float = Vector2((to.column - from.column) * COLUMN_PITCH, (to.row - from.row) * ROW_PITCH).length() / ROW_PITCH
	return GameSpeed.seconds(maxf(SHORTEST_GLIDE, GLIDE_SECONDS * rows), speed)


## The glide's easing, slow at both ends: [param t] from 0 to 1.
static func eased(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
