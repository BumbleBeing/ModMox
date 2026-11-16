class_name SceneryLayout
extends RefCounted
## Where a Stage's Scenery is placed on its Stage Map (ADR 0038), from the seed its visit
## drew from the Run Seed. Each Kind in turn draws how many to place, then tries spots at
## random: a piece is kept only if it lies wholly on the Map Backdrop and on its Stage's
## Scenery Ground, if it has one, NODE_CLEARANCE or
## more from every Node's drawn edge, LINK_CLEARANCE or more from every link, and clear of
## the pieces already placed. A spot that breaks a rule is thrown away and another tried, up
## to TRIES, so a crowded map has fewer pieces. Places are with the view at the Start. Pure:
## no Nodes.

const NODE_CLEARANCE: float = 40.0
const LINK_CLEARANCE: float = 16.0
const TRIES: int = 30


## The pieces of [param visit]'s Scenery, the higher first, so the lower is drawn in front.
static func place(visit: StageVisit) -> Array[SceneryPiece]:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = visit.scenery_seed
	var bounds: Rect2 = StageMapLayout.map_backdrop_rect(1.0)
	var links_drawn: Array[PackedVector2Array] = links(visit)
	var ground: Image = visit.stage.scenery_ground
	var placed: Array[SceneryPiece] = []
	for kind: SceneryKind in visit.stage.scenery:
		var extent: Vector2 = kind.frames[0].get_size() * kind.scale
		var count: int = random.randi_range(kind.least, kind.most)
		for piece: int in count:
			for attempt: int in TRIES:
				var at: Vector2 = Vector2(
					random.randi_range(int(bounds.position.x), int(bounds.end.x - extent.x)),
					random.randi_range(int(bounds.position.y), int(bounds.end.y - extent.y)))
				var flipped: bool = random.randf() < 0.5
				var ahead: float = random.randf()
				var rect: Rect2 = Rect2(at, extent)
				if is_on_ground(rect, ground) and _fits(rect, visit, links_drawn, placed):
					placed.append(SceneryPiece.new(kind, rect, flipped, ahead))
					break
	placed.sort_custom(func(a: SceneryPiece, b: SceneryPiece) -> bool:
		if a.rect.end.y != b.rect.end.y:
			return a.rect.end.y < b.rect.end.y
		return a.rect.position.x < b.rect.position.x)
	return placed


## Where [param piece] is drawn with the view at [param scroll_row].
static func screen_rect(piece: SceneryPiece, scroll_row: float) -> Rect2:
	return Rect2(piece.rect.position + Vector2(0.0, (scroll_row - 1.0) * StageMapLayout.ROW_PITCH), piece.rect.size)


## Every link of [param visit]'s map, from one Node's center to the other's, with the view
## at the Start.
static func links(visit: StageVisit) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	for node: MapNode in visit.map.nodes:
		var others: Array[int] = node.forward.duplicate()
		if node.side > node.id:
			others.append(node.side)
		for id: int in others:
			found.append(PackedVector2Array([_spot(visit, node.id), _spot(visit, id)]))
	return found


## Whether [param rect] lies wholly on [param ground], a picture the Map Backdrop's size
## that is opaque where Scenery may stand; any rect does when there is none.
static func is_on_ground(rect: Rect2, ground: Image) -> bool:
	if ground == null:
		return true
	var pixel: float = StageMapLayout.BACKDROP_PIXEL
	var from: Vector2 = (rect.position - StageMapLayout.map_backdrop_rect(1.0).position) / pixel
	var to: Vector2 = from + rect.size / pixel
	for y: int in range(maxi(0, floori(from.y)), mini(ground.get_height(), ceili(to.y))):
		for x: int in range(maxi(0, floori(from.x)), mini(ground.get_width(), ceili(to.x))):
			if ground.get_pixel(x, y).a < 0.5:
				return false
	return true


## How far [param point] is from [param rect]: 0 inside it.
static func distance_to_point(rect: Rect2, point: Vector2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy: float = maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()


## How far the segment from [param a] to [param b] is from [param rect]: 0 if it crosses it.
static func distance_to_segment(rect: Rect2, a: Vector2, b: Vector2) -> float:
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for index: int in corners.size():
		if Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % 4]) != null:
			return 0.0
	var nearest: float = minf(distance_to_point(rect, a), distance_to_point(rect, b))
	for corner: Vector2 in corners:
		nearest = minf(nearest, corner.distance_to(Geometry2D.get_closest_point_to_segment(corner, a, b)))
	return nearest


static func _fits(rect: Rect2, visit: StageVisit, links_drawn: Array[PackedVector2Array],
		placed: Array[SceneryPiece]) -> bool:
	for node: MapNode in visit.map.nodes:
		if distance_to_point(rect, _spot(visit, node.id)) - StageMapLayout.radius_of(node.kind) < NODE_CLEARANCE:
			return false
	for link: PackedVector2Array in links_drawn:
		if distance_to_segment(rect, link[0], link[1]) < LINK_CLEARANCE:
			return false
	for piece: SceneryPiece in placed:
		if rect.intersects(piece.rect):
			return false
	return true


static func _spot(visit: StageVisit, id: int) -> Vector2:
	return StageMapLayout.node_spot(visit.map.nodes[id], visit.offsets.get(id, Vector2.ZERO), 1.0)
