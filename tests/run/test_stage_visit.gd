extends GutTest
## The Hero's walk through a Stage (milestone 17): moving one link at a time along a Path,
## the encounters that must be played before moving on, the Villain met at each, and the
## Boss that is played again until beaten. On a small map made by hand:
##
##   row 5            5 Boss
##   row 4            4 Trove
##   row 3            3 Elite
##   row 2   1 Lesser ---- 2 Chaos
##   row 1        0 Start

const STAGES: String = "res://content/stages/"

var _stage: StageDefinition
var _random: RunRandom


func before_each() -> void:
	_stage = load(STAGES + "placeholder_green.tres")
	_random = RunRandom.new(3)


func _visit() -> StageVisit:
	var map: StageMap = StageMap.new()
	_add(map, 1, 5, StageMap.Kind.START, [1, 2])
	_add(map, 2, 4, StageMap.Kind.LESSER, [3])
	_add(map, 2, 6, StageMap.Kind.CHAOS, [3])
	_add(map, 3, 5, StageMap.Kind.ELITE, [4])
	_add(map, 4, 5, StageMap.Kind.TROVE, [5])
	_add(map, 5, 5, StageMap.Kind.BOSS, [])
	map.nodes[1].side = 2
	map.nodes[2].side = 1
	return StageVisit.new(_stage, map, _stage.bosses[0])


func _add(map: StageMap, row: int, column: int, kind: StageMap.Kind, forward: Array[int]) -> void:
	var node: MapNode = MapNode.new()
	node.id = map.nodes.size()
	node.row = row
	node.column = column
	node.kind = kind
	node.forward = forward
	map.nodes.append(node)


func test_the_hero_starts_on_the_start_node_with_nothing_to_play() -> void:
	var visit: StageVisit = _visit()

	assert_eq(visit.current, 0)
	assert_true(visit.is_visited(0))
	assert_false(visit.must_play())
	assert_null(visit.meeting)


## T2: the Hero moves only where a Path allows from where they stand.
func test_the_hero_can_move_along_a_forward_link_and_nowhere_else() -> void:
	var visit: StageVisit = _visit()

	assert_eq(visit.choices(), [1, 2] as Array[int])
	assert_ne(visit.move_to(3, _random), "", "Node 3 is not linked to the Start Node.")
	assert_eq(visit.current, 0)


func test_a_horizontal_link_can_be_walked_either_way() -> void:
	var visit: StageVisit = _visit()
	visit.move_to(2, _random)

	assert_true(visit.choices().has(1))


## T2: never to a visited Node.
func test_the_hero_never_moves_back_to_a_visited_node() -> void:
	var visit: StageVisit = _visit()
	visit.move_to(2, _random)

	assert_eq(visit.move_to(1, _random), "")

	visit.record(false)
	assert_eq(visit.choices(), [3] as Array[int], "Node 2 was visited, so its side link is closed.")
	assert_ne(visit.move_to(2, _random), "")


## T3: an encounter Node cannot be left before it is played.
func test_an_encounter_must_be_played_before_moving_on() -> void:
	var visit: StageVisit = _visit()
	visit.move_to(1, _random)

	assert_true(visit.must_play())
	assert_true(visit.choices().is_empty())
	assert_ne(visit.move_to(3, _random), "")
	assert_eq(visit.current, 1)


## T4: arriving at a Node that is not an encounter meets no one and asks nothing.
func test_arriving_anywhere_else_meets_no_one() -> void:
	var visit: StageVisit = _visit()

	visit.move_to(2, _random)

	assert_null(visit.meeting)
	assert_false(visit.must_play())
	assert_eq(visit.choices(), [3, 1] as Array[int])


## T5: a Lesser or Elite Encounter's Villain comes from the Stage's list for its Rank.
func test_the_villain_met_comes_from_the_stages_list_for_the_nodes_rank() -> void:
	var visit: StageVisit = _visit()

	visit.move_to(1, _random)
	assert_true(_stage.lesser_villains.has(visit.meeting))
	visit.record(true)
	visit.move_to(3, _random)

	assert_true(_stage.elite_villains.has(visit.meeting))


## T6: a lost encounter counts as passed, and an Elite still leads to its Trove.
func test_a_lost_elite_still_leads_to_its_trove() -> void:
	var visit: StageVisit = _visit()
	visit.move_to(2, _random)
	visit.move_to(3, _random)

	visit.record(false)

	assert_false(visit.must_play())
	assert_null(visit.meeting)
	assert_eq(visit.choices(), [4] as Array[int])


## T7: a lost Boss is played again, the same Boss.
func test_a_lost_boss_must_be_played_again() -> void:
	var visit: StageVisit = _visit()
	_walk_to_boss(visit)

	visit.record(false)

	assert_true(visit.must_play())
	assert_eq(visit.meeting, _stage.bosses[0])
	assert_false(visit.is_won)


## T8: beating the Boss wins the Stage.
func test_beating_the_boss_wins() -> void:
	var visit: StageVisit = _visit()
	_walk_to_boss(visit)

	visit.record(true)

	assert_true(visit.is_won)
	assert_false(visit.must_play())


func test_the_walked_links_are_remembered() -> void:
	var visit: StageVisit = _visit()
	visit.move_to(2, _random)
	visit.move_to(1, _random)

	assert_true(visit.is_walked(0, 2))
	assert_true(visit.is_walked(1, 2), "Either way round.")
	assert_false(visit.is_walked(0, 1))


func test_the_boss_is_known_from_the_start_and_met_on_arriving() -> void:
	var visit: StageVisit = _visit()

	assert_eq(visit.boss, _stage.bosses[0])
	_walk_to_boss(visit)
	assert_eq(visit.meeting, visit.boss)


func _walk_to_boss(visit: StageVisit) -> void:
	visit.move_to(2, _random)
	visit.move_to(3, _random)
	visit.record(true)
	visit.move_to(4, _random)
	visit.move_to(5, _random)
