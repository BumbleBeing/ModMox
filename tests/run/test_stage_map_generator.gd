extends GutTest
## A Stage's map (ADR 0026): built in stages, checked whole and rerolled until it keeps
## every rule. Each rule is checked here on its own, over a few dozen map seeds, by a check
## written apart from the generator's own; and the generator's check is shown to refuse a
## map that breaks a rule. The slow check over thousands of seeds is test_stage_map_soak.

const SEEDS: int = 40


func _maps() -> Array[StageMap]:
	var made: Array[StageMap] = []
	for map_seed: int in range(1, SEEDS + 1):
		made.append(StageMapGenerator.generate(map_seed))
	return made


func test_the_same_seed_builds_the_same_map() -> void:
	var first: StageMap = StageMapGenerator.generate(7)
	var second: StageMap = StageMapGenerator.generate(7)

	assert_eq(_describe(first), _describe(second))


func test_another_seed_builds_another_map() -> void:
	var shapes: Dictionary[String, bool] = {}
	for map_seed: int in range(1, 6):
		shapes[_describe(StageMapGenerator.generate(map_seed))] = true

	assert_gt(shapes.size(), 1)


func test_every_seed_gets_a_valid_map() -> void:
	for map: StageMap in _maps():
		assert_not_null(map)
		assert_eq(StageMapGenerator.validate(map), "")


func test_the_fixed_rows_are_always_the_same() -> void:
	for map: StageMap in _maps():
		assert_eq(_row_of(map, 1), [[5, StageMap.Kind.START]])
		assert_eq(_row_of(map, 2), [[4, StageMap.Kind.STORE], [6, StageMap.Kind.WORKSHOP]])
		assert_eq(_row_of(map, 9), [[4, StageMap.Kind.WORKSHOP], [6, StageMap.Kind.STORE]])
		assert_eq(_row_of(map, 10), [[5, StageMap.Kind.BOSS]])


func test_each_generated_row_has_its_number_of_nodes() -> void:
	var sizes: Dictionary[int, Array] = {3: [3, 3], 4: [3, 5], 5: [3, 5], 6: [3, 4], 7: [2, 3], 8: [2, 2]}
	for map: StageMap in _maps():
		for row: int in sizes:
			var count: int = map.in_row(row).size()
			assert_between(count, sizes[row][0], sizes[row][1], "row %d" % row)


func test_every_node_can_be_reached_from_the_start_and_can_reach_the_boss() -> void:
	for map: StageMap in _maps():
		var reached: Dictionary[int, bool] = _reachable(map, map.start().id, false)
		var reaching: Dictionary[int, bool] = _reachable(map, map.boss().id, true)
		for node: MapNode in map.nodes:
			assert_true(reached.has(node.id), "Node %d is reached" % node.id)
			assert_true(reaching.has(node.id), "Node %d reaches the Boss" % node.id)


func test_every_path_has_two_to_four_lesser_and_elite_encounters() -> void:
	for map: StageMap in _maps():
		var counts: Array[int] = []
		_walk(map, map.start().id, {}, 0, counts)
		assert_gte(counts.min(), StageMapGenerator.MIN_ENCOUNTERS)
		assert_lte(counts.max(), StageMapGenerator.MAX_ENCOUNTERS)


func test_no_store_links_to_a_store_and_no_workshop_to_a_workshop() -> void:
	for map: StageMap in _maps():
		for node: MapNode in map.nodes:
			if node.kind != StageMap.Kind.STORE and node.kind != StageMap.Kind.WORKSHOP:
				continue
			for id: int in _linked(node):
				assert_ne(map.nodes[id].kind, node.kind, "Node %d" % node.id)


func test_elite_encounters_are_only_in_rows_three_to_six() -> void:
	for map: StageMap in _maps():
		for node: MapNode in map.nodes:
			if node.kind == StageMap.Kind.ELITE:
				assert_between(node.row, 3, 6)


func test_an_elite_leads_only_to_its_trove_and_a_trove_is_reached_only_from_its_elite() -> void:
	for map: StageMap in _maps():
		for node: MapNode in map.nodes:
			if node.kind == StageMap.Kind.ELITE:
				assert_eq(node.forward.size(), 1)
				assert_eq(map.nodes[node.forward[0]].kind, StageMap.Kind.TROVE)
			if node.kind == StageMap.Kind.TROVE:
				var parents: Array[MapNode] = map.parents_of(node.id)
				assert_eq(parents.size(), 1)
				assert_eq(parents[0].kind, StageMap.Kind.ELITE)
				assert_eq(node.side, -1)


func test_no_elite_is_forced() -> void:
	for map: StageMap in _maps():
		for node: MapNode in map.nodes:
			if node.kind != StageMap.Kind.ELITE:
				continue
			for parent: MapNode in map.parents_of(node.id):
				var others: int = 0
				for id: int in parent.forward:
					if id != node.id:
						others += 1
				assert_gt(others, 0, "a parent of Elite %d has another way on" % node.id)


func test_every_path_passes_the_store_or_workshop_of_row_nine() -> void:
	for map: StageMap in _maps():
		for parent: MapNode in map.parents_of(map.boss().id):
			assert_eq(parent.row, 9)


func test_no_skip_link_is_drawn_through_a_node() -> void:
	for map: StageMap in _maps():
		for node: MapNode in map.nodes:
			for id: int in node.forward:
				var ahead: MapNode = map.nodes[id]
				if ahead.row != node.row + 2:
					continue
				for middle: MapNode in map.in_row(node.row + 1):
					assert_ne(middle.column * 2, node.column + ahead.column, "skip from %d" % node.id)


func test_validate_refuses_a_store_linked_to_a_store() -> void:
	var map: StageMap = StageMapGenerator.generate(7)
	var store: MapNode = map.in_row(2)[0]

	store.forward.append(map.in_row(9)[1].id)

	assert_eq(StageMapGenerator.validate(map), "Store linked to Store")


func test_validate_refuses_an_elite_outside_rows_three_to_six() -> void:
	var map: StageMap = StageMapGenerator.generate(7)
	var node: MapNode = map.in_row(8)[0]

	node.kind = StageMap.Kind.ELITE

	assert_eq(StageMapGenerator.validate(map), "Elite outside rows 3-6")


func test_validate_refuses_a_node_nothing_leads_to() -> void:
	var map: StageMap = StageMapGenerator.generate(7)
	var node: MapNode = _cuttable(map)

	for parent: MapNode in map.parents_of(node.id):
		parent.forward.erase(node.id)
	if node.side != -1:
		map.nodes[node.side].side = -1
		node.side = -1

	assert_eq(StageMapGenerator.validate(map), "orphan")


## The map as text: every Node's row, column, kind and links, in order.
func _describe(map: StageMap) -> String:
	var lines: PackedStringArray = []
	for node: MapNode in map.nodes:
		lines.append("%d %d %d %d %s %d" % [node.id, node.row, node.column, node.kind, node.forward, node.side])
	return "\n".join(lines)


## A generated Node whose parents all lead somewhere else too, so cutting it off leaves no
## other Node broken.
func _cuttable(map: StageMap) -> MapNode:
	for node: MapNode in map.nodes:
		if node.row < 3 or node.row > 8 or node.kind == StageMap.Kind.TROVE:
			continue
		var is_spare: bool = true
		for parent: MapNode in map.parents_of(node.id):
			if parent.forward.size() < 2:
				is_spare = false
		if is_spare:
			return node
	return null


func _row_of(map: StageMap, row: int) -> Array:
	var found: Array = []
	for node: MapNode in map.in_row(row):
		found.append([node.column, node.kind])
	return found


func _linked(node: MapNode) -> Array[int]:
	var linked: Array[int] = node.forward.duplicate()
	if node.side != -1:
		linked.append(node.side)
	return linked


## Every Node reachable from [param from]: forward, sideways either way, or (with
## [param is_backward]) along links the other way.
func _reachable(map: StageMap, from: int, is_backward: bool) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {from: true}
	var waiting: Array[int] = [from]
	while not waiting.is_empty():
		var node: MapNode = map.nodes[waiting.pop_back()]
		var next: Array[int] = []
		if is_backward:
			for parent: MapNode in map.parents_of(node.id):
				next.append(parent.id)
		else:
			next.append_array(node.forward)
		if node.side != -1:
			next.append(node.side)
		for id: int in next:
			if not found.has(id):
				found[id] = true
				waiting.append(id)
	return found


## Every walk the Hero could take from [param id] to the Boss, never back to a visited
## Node, adding each walk's count of Lesser and Elite Encounters to [param counts].
func _walk(map: StageMap, id: int, visited: Dictionary, so_far: int, counts: Array[int]) -> void:
	var node: MapNode = map.nodes[id]
	var count: int = so_far + (1 if node.kind == StageMap.Kind.LESSER or node.kind == StageMap.Kind.ELITE else 0)
	if node.kind == StageMap.Kind.BOSS:
		counts.append(count)
		return
	var here: Dictionary = visited.duplicate()
	here[id] = true
	for next: int in _linked(node):
		if not here.has(next):
			_walk(map, next, here, count, counts)
