class_name StageMapGenerator
extends RefCounted
## Builds a Stage Map under ADR 0026: in stages, each rolling only from what is legal where
## it stands, then checked whole. A map that fails is thrown away and built again from the
## next numbers of the same stream, never repaired. Pure: no Nodes, no engine.

const Kind := StageMap.Kind

## After this many failed attempts generation stops with an error.
const MAX_ATTEMPTS: int = 1000
## Row -> [fewest, most] Nodes.
const ROW_SIZES: Dictionary[int, Array] = {3: [3, 3], 4: [3, 5], 5: [3, 5], 6: [3, 4], 7: [2, 3], 8: [2, 2]}
## Row -> [first, last] column a Node may stand in, which keeps the map a diamond.
const ROW_COLUMNS: Dictionary[int, Array] = {3: [3, 7], 4: [2, 8], 5: [1, 9], 6: [2, 8], 7: [3, 7], 8: [3, 7]}
## Chances (percent) of a Node having 1, 2 or 3 forward links.
const LINK_COUNT_WEIGHTS: Array[int] = [40, 45, 15]
const SKIP_CHANCE: float = 0.10
const SIDE_CHANCE: float = 0.15
## Chance that a Node of rows 3 to 6 tries to be an Elite Encounter.
const ELITE_CHANCE: float = 0.30
const KIND_WEIGHTS: Dictionary[StageMap.Kind, int] = {
	Kind.LESSER: 35, Kind.CHAOS: 30, Kind.STORE: 10, Kind.WORKSHOP: 10,
}
## Every path has this many Lesser and Elite Encounters, at fewest and at most.
const MIN_ENCOUNTERS: int = 2
const MAX_ENCOUNTERS: int = 4
const FIRST_ELITE_ROW: int = 3
const LAST_ELITE_ROW: int = 6
const FIRST_SHOP_ROW: int = 4
const LAST_SHOP_ROW: int = 7
## A Node tries this many sets of columns before its whole map is thrown away.
const PLACING_TRIES: int = 200


## The map for [param map_seed], the first of its attempts that keeps every rule; null,
## with an error, if none of MAX_ATTEMPTS does. Each attempt draws on from where the last
## left off (ADR 0026). [param failures_out], if given, receives why each attempt failed.
static func generate(map_seed: int, failures_out: Array[String] = []) -> StageMap:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = map_seed
	for attempt: int in MAX_ATTEMPTS:
		var map: StageMap = StageMap.new()
		var reason: String = _build(map, random)
		if reason == "":
			reason = validate(map)
		if reason == "":
			map.attempts = attempt + 1
			return map
		failures_out.append(reason)
	push_error("No valid Stage Map in %d attempts for map seed %d" % [MAX_ATTEMPTS, map_seed])
	return null


## "" if [param map] keeps every rule of ADR 0026, else the first rule it breaks.
static func validate(map: StageMap) -> String:
	for node: MapNode in map.nodes:
		if node.kind == Kind.NONE:
			return "a Node has no kind"
		if node.kind != Kind.BOSS and node.forward.is_empty():
			return "dead end"
		if node.kind != Kind.START and map.parents_of(node.id).is_empty():
			return "orphan"
		if node.kind == Kind.BOSS:
			for parent: MapNode in map.parents_of(node.id):
				if parent.row != StageMap.ROWS - 1:
					return "a path misses the final Store and Workshop"
		for id: int in node.forward:
			var ahead: MapNode = map.nodes[id]
			if ahead.row == node.row + 2 and _skip_runs_through(map, node, ahead) != null:
				return "skip link drawn over another link"
		for id: int in _linked(node):
			if node.kind == Kind.STORE and map.nodes[id].kind == Kind.STORE:
				return "Store linked to Store"
			if node.kind == Kind.WORKSHOP and map.nodes[id].kind == Kind.WORKSHOP:
				return "Workshop linked to Workshop"
		if node.kind == Kind.ELITE:
			if node.row < FIRST_ELITE_ROW or node.row > LAST_ELITE_ROW:
				return "Elite outside rows 3-6"
			if node.forward.size() != 1 or map.nodes[node.forward[0]].kind != Kind.TROVE:
				return "Elite without its Trove"
			for parent: MapNode in map.parents_of(node.id):
				if not _has_other_way(map, parent, node.id):
					return "forced Elite"
		if node.kind == Kind.TROVE:
			var parents: Array[MapNode] = map.parents_of(node.id)
			if parents.size() != 1 or parents[0].kind != Kind.ELITE or node.side != -1:
				return "Trove with another way in"
	var memo: Dictionary[int, int] = {}
	if _count(map, map.start().id, false, false, memo) < MIN_ENCOUNTERS:
		return "a path has fewer than %d encounters" % MIN_ENCOUNTERS
	if _count(map, map.start().id, false, true, memo) > MAX_ENCOUNTERS:
		return "a path has more than %d encounters" % MAX_ENCOUNTERS
	return ""


static func _build(map: StageMap, random: RandomNumberGenerator) -> String:
	var start: MapNode = _add(map, 1, 5, Kind.START)
	var rows: Dictionary[int, Array] = {2: [_add(map, 2, 4, Kind.STORE), _add(map, 2, 6, Kind.WORKSHOP)]}
	for node: MapNode in rows[2]:
		start.forward.append(node.id)

	# Stage 1: row sizes, and a column for each Node.
	for row: int in range(3, 9):
		var placed: Array[MapNode] = _place_row(map, row, rows[row - 1], random)
		if placed.is_empty():
			return "no columns in reach of the row below"
		rows[row] = placed
	rows[9] = [_add(map, 9, 4, Kind.WORKSHOP), _add(map, 9, 6, Kind.STORE)]
	var boss: MapNode = _add(map, 10, 5, Kind.BOSS)

	# Stage 2: forward links. Rows 8 and 9 are fixed. Links into row 9 ignore the
	# one-column rule, or no Node of row 8 could reach both final Nodes (ADR 0026).
	for node: MapNode in rows[9]:
		node.forward.append(boss.id)
		for below: MapNode in rows[8]:
			below.forward.append(node.id)
	for row: int in range(2, 8):
		var reason: String = _link_row(map, rows[row], rows[row + 1], random)
		if reason != "":
			return reason

	# Stage 3: skip links.
	for row: int in range(2, 8):
		for node: MapNode in rows[row]:
			if random.randf() < SKIP_CHANCE:
				_try_skip(map, node, rows[row + 2], random)

	# Stage 4: horizontal links.
	for row: int in range(3, 9):
		var across: Array[MapNode] = map.in_row(row)
		for index: int in across.size() - 1:
			var left: MapNode = across[index]
			var right: MapNode = across[index + 1]
			if left.side == -1 and right.side == -1 and random.randf() < SIDE_CHANCE:
				left.side = right.id
				right.side = left.id

	# Stage 5: Elite Encounters and their Troves, placed first and making room for
	# themselves by cutting links.
	for row: int in range(FIRST_ELITE_ROW, LAST_ELITE_ROW + 1):
		for node: MapNode in map.in_row(row):
			if node.kind == Kind.NONE and random.randf() < ELITE_CHANCE:
				_try_elite(map, node, random)

	# Stage 6: the other kinds.
	for row: int in range(3, 9):
		for node: MapNode in map.in_row(row):
			if node.kind == Kind.NONE:
				_roll_kind(map, node, random)
	return ""


static func _add(map: StageMap, row: int, column: int, kind: StageMap.Kind = Kind.NONE) -> MapNode:
	var node: MapNode = MapNode.new()
	node.id = map.nodes.size()
	node.row = row
	node.column = column
	node.kind = kind
	map.nodes.append(node)
	return node


## Picks how many Nodes [param row] has and which columns, so that every Node of the row
## below has one within a column of it, and the other way round. Tried a few times over,
## which costs no whole-map attempt.
static func _place_row(map: StageMap, row: int, below: Array, random: RandomNumberGenerator) -> Array[MapNode]:
	var sizes: Array = ROW_SIZES[row]
	var span: Array = ROW_COLUMNS[row]
	for _try: int in PLACING_TRIES:
		var columns: Array[int] = []
		for column: int in range(span[0], span[1] + 1):
			columns.append(column)
		_shuffle(columns, random)
		columns.resize(random.randi_range(sizes[0], sizes[1]))
		var fits: bool = true
		for node: MapNode in below:
			if not (columns.has(node.column - 1) or columns.has(node.column) or columns.has(node.column + 1)):
				fits = false
		for column: int in columns:
			var has_parent: bool = false
			for node: MapNode in below:
				if absi(node.column - column) <= 1:
					has_parent = true
			if not has_parent:
				fits = false
		if fits:
			var placed: Array[MapNode] = []
			columns.sort()
			for column: int in columns:
				placed.append(_add(map, row, column))
			return placed
	return []


static func _link_row(map: StageMap, from: Array, to: Array, random: RandomNumberGenerator) -> String:
	for node: MapNode in from:
		var reach: Array[int] = []
		for ahead: MapNode in to:
			if absi(ahead.column - node.column) <= 1:
				reach.append(ahead.id)
		_shuffle(reach, random)
		reach.resize(mini(reach.size(), _roll_link_count(random)))
		node.forward.append_array(reach)
	# Give every Node ahead a parent.
	for ahead: MapNode in to:
		if not map.parents_of(ahead.id).is_empty():
			continue
		var best: MapNode = null
		for node: MapNode in from:
			if absi(ahead.column - node.column) > 1:
				continue
			if best == null or node.forward.size() < best.forward.size():
				best = node
		best.forward.append(ahead.id)
		if best.forward.size() > 3:
			var dropped: bool = false
			for id: int in best.forward:
				if id != ahead.id and map.parents_of(id).size() > 1:
					best.forward.erase(id)
					dropped = true
					break
			if not dropped:
				return "a Node would need a fourth forward link"
	return ""


static func _roll_link_count(random: RandomNumberGenerator) -> int:
	var roll: int = random.randi_range(1, 100)
	for index: int in LINK_COUNT_WEIGHTS.size():
		roll -= LINK_COUNT_WEIGHTS[index]
		if roll <= 0:
			return index + 1
	return 1


## Turns one of [param node]'s forward links into a skip link, or adds one if it has room.
static func _try_skip(map: StageMap, node: MapNode, two_ahead: Array, random: RandomNumberGenerator) -> void:
	var reach: Array[int] = []
	for ahead: MapNode in two_ahead:
		if absi(ahead.column - node.column) > 2 or node.forward.has(ahead.id):
			continue
		if _skip_runs_through(map, node, ahead) == null:
			reach.append(ahead.id)
	if reach.is_empty():
		return
	var target: int = reach[random.randi_range(0, reach.size() - 1)]
	var spare: Array[int] = []
	for id: int in node.forward:
		if map.parents_of(id).size() > 1:
			spare.append(id)
	if not spare.is_empty():
		node.forward.erase(spare[random.randi_range(0, spare.size() - 1)])
		node.forward.append(target)
	elif node.forward.size() < 3:
		node.forward.append(target)


## The Node a skip link from [param from] to [param to] would be drawn straight through,
## or null. Such a link would lie on top of that Node's own links. A skip link that moves
## one column passes between two columns and can lie on nothing.
static func _skip_runs_through(map: StageMap, from: MapNode, to: MapNode) -> MapNode:
	if (to.column - from.column) % 2 != 0:
		return null
	for node: MapNode in map.nodes:
		if node.row == from.row + 1 and node.column * 2 == from.column + to.column:
			return node
	return null


static func _roll_kind(map: StageMap, node: MapNode, random: RandomNumberGenerator) -> void:
	var legal: Dictionary[StageMap.Kind, int] = {Kind.LESSER: KIND_WEIGHTS[Kind.LESSER], Kind.CHAOS: KIND_WEIGHTS[Kind.CHAOS]}
	if node.row >= FIRST_SHOP_ROW and node.row <= LAST_SHOP_ROW:
		for kind: StageMap.Kind in [Kind.STORE, Kind.WORKSHOP]:
			if not _touches(map, node, kind):
				legal[kind] = KIND_WEIGHTS[kind]
	var total: int = 0
	for kind: StageMap.Kind in legal:
		total += legal[kind]
	var roll: int = random.randi_range(1, total)
	for kind: StageMap.Kind in legal:
		roll -= legal[kind]
		if roll <= 0:
			node.kind = kind
			break


## Makes [param node] an Elite Encounter and one Node ahead its Trove, if links can be cut
## to allow it: the Trove loses its other parents and its horizontal link, and the Elite
## Encounter its other forward links. Nothing is cut that would leave a Node without a
## parent or a forward link, or force an Elite Encounter.
static func _try_elite(map: StageMap, node: MapNode, random: RandomNumberGenerator) -> void:
	for parent: MapNode in map.parents_of(node.id):
		if not _has_other_way(map, parent, node.id):
			return
	var choices: Array[int] = []
	for id: int in node.forward:
		var ahead: MapNode = map.nodes[id]
		if ahead.row != node.row + 1 or ahead.kind != Kind.NONE:
			continue
		var fits: bool = true
		for other: int in node.forward:
			if other != id and map.parents_of(other).size() < 2:
				fits = false
		for parent: MapNode in map.parents_of(id):
			if parent != node and not _has_other_way(map, parent, id):
				fits = false
		if fits:
			choices.append(id)
	if choices.is_empty():
		return
	var trove: MapNode = map.nodes[choices[random.randi_range(0, choices.size() - 1)]]
	for parent: MapNode in map.parents_of(trove.id):
		parent.forward.erase(trove.id)
	if trove.side != -1:
		map.nodes[trove.side].side = -1
		trove.side = -1
	trove.kind = Kind.TROVE
	node.forward.assign([trove.id])
	node.kind = Kind.ELITE


## Whether [param node] is linked, any way, to a Node already of [param kind].
static func _touches(map: StageMap, node: MapNode, kind: StageMap.Kind) -> bool:
	var linked: Array[int] = _linked(node)
	for parent: MapNode in map.parents_of(node.id):
		linked.append(parent.id)
	for id: int in linked:
		if map.nodes[id].kind == kind:
			return true
	return false


## The ids of the Nodes [param node] links to: forward, and its horizontal link.
static func _linked(node: MapNode) -> Array[int]:
	var linked: Array[int] = node.forward.duplicate()
	if node.side != -1:
		linked.append(node.side)
	return linked


## Whether [param parent] has a forward link to something that is neither [param elite_id]
## nor another Elite Encounter.
static func _has_other_way(map: StageMap, parent: MapNode, elite_id: int) -> bool:
	for id: int in parent.forward:
		if id != elite_id and map.nodes[id].kind != Kind.ELITE:
			return true
	return false


## The fewest or (with [param is_most]) most encounters on any walk from [param id] to the
## Boss Encounter. A walk goes forward, or once sideways and then forward.
static func _count(map: StageMap, id: int, came_sideways: bool, is_most: bool, memo: Dictionary[int, int]) -> int:
	var key: int = id * 4 + (2 if came_sideways else 0) + (1 if is_most else 0)
	if memo.has(key):
		return memo[key]
	var node: MapNode = map.nodes[id]
	var here: int = 1 if node.kind == Kind.LESSER or node.kind == Kind.ELITE else 0
	var onward: Array[int] = []
	for ahead: int in node.forward:
		onward.append(_count(map, ahead, false, is_most, memo))
	if node.side != -1 and not came_sideways:
		onward.append(_count(map, node.side, true, is_most, memo))
	var best: int = 0
	if not onward.is_empty():
		best = onward.max() if is_most else onward.min()
	memo[key] = here + best
	return here + best


static func _shuffle(items: Array[int], random: RandomNumberGenerator) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var held: int = items[index]
		items[index] = items[other]
		items[other] = held
