class_name StageVisit
extends RefCounted
## The Hero's walk through one Stage: its Stage Map, its Boss, the Node they stand on,
## where they have been, and the Villain they are meeting there (milestone 17). Held by the
## Run, which hands it the run's randomness; it knows nothing of screens.
##
## The Hero moves one link at a time along a Path: forward and skip links onward,
## horizontal links either way, never to a visited Node. An encounter must be played
## before moving on; a lost one counts as passed, except the Boss Encounter, which is
## played again until it is won (ADR 0026).

var stage: StageDefinition
var map: StageMap
## Picked once on entering the Stage, and the same through every rematch (ADR 0024).
var boss: Villain
## The id of the Node the Hero stands on.
var current: int = 0
## The Villain of the encounter the Hero stands at and has not yet beaten or lost to, or
## null when there is none.
var meeting: Villain = null
## Whether the Boss has been beaten.
var is_won: bool = false
## Where each Node is drawn in its cell, by id: x and y each from -1 to 1, as a share of
## how far a Node may stray from its cell's center. Picked from the Run Seed, so the same
## run always draws its map alike.
var offsets: Dictionary[int, Vector2] = {}
## The seed the Stage Map places the Stage's Scenery from, drawn from the Run Seed
## (ADR 0038).
var scenery_seed: int = 0

var _visited: Dictionary[int, bool] = {}
## Each link walked, as [lower id, higher id].
var _walked: Dictionary[Vector2i, bool] = {}


func _init(stage_entered: StageDefinition, stage_map: StageMap, stage_boss: Villain) -> void:
	stage = stage_entered
	map = stage_map
	boss = stage_boss
	current = map.start().id
	_visited[current] = true


## The Node the Hero stands on.
func node() -> MapNode:
	return map.nodes[current]


## The ids of the Nodes the Hero may move to now, forward links first: none while an
## encounter here is still to be played.
func choices() -> Array[int]:
	var found: Array[int] = []
	if must_play():
		return found
	var here: MapNode = node()
	for id: int in here.forward:
		if not _visited.has(id):
			found.append(id)
	if here.side != -1 and not _visited.has(here.side):
		found.append(here.side)
	return found


## Whether the Hero stands at an encounter they have not yet played (or, at the Boss, not
## yet won).
func must_play() -> bool:
	return meeting != null


## Moves the Hero to the Node [param id], meeting its Villain if it is an encounter, drawn
## from [param random]. Says why not, changing nothing, if a Path does not allow it.
func move_to(id: int, random: RunRandom) -> String:
	if not choices().has(id):
		return "The Hero cannot move from Node %d to Node %d." % [current, id]
	_walked[_link(current, id)] = true
	current = id
	_visited[id] = true
	var arrived: MapNode = node()
	if arrived.kind == StageMap.Kind.BOSS:
		meeting = boss
	elif StageMap.is_encounter(arrived):
		var villains: Array[Villain] = stage.villains_for(arrived.kind)
		meeting = villains[random.pick(RunRandom.VILLAINS, villains.size())]
	return ""


## Counts the end of the encounter here: [param won] or not, it is passed, except a lost
## Boss Encounter, which is met again.
func record(won: bool) -> void:
	if meeting == null:
		return
	if node().kind == StageMap.Kind.BOSS:
		is_won = won
		if not won:
			return
	meeting = null


## The walk as plain data, for a saved run (ADR 0074): its Stage, Boss and the Villain being
## met by their Content paths.
func to_data() -> Dictionary:
	var saved_offsets: Dictionary = {}
	for id: int in offsets:
		saved_offsets[str(id)] = [offsets[id].x, offsets[id].y]
	var walked: Array = []
	for link: Vector2i in _walked:
		walked.append([link.x, link.y])
	return {
		"stage": SavedRun.path_of(stage), "map": map.to_data(), "boss": SavedRun.path_of(boss),
		"current": current, "meeting": SavedRun.path_of(meeting) if meeting != null else "", "is_won": is_won,
		"offsets": saved_offsets, "scenery_seed": scenery_seed, "visited": _visited.keys(), "walked": walked,
	}


## The walk [param data] holds, as to_data() made it.
static func from_data(data: Dictionary) -> StageVisit:
	var visit: StageVisit = StageVisit.new(
		load(str(data["stage"])) as StageDefinition, StageMap.from_data(data["map"]), load(str(data["boss"])) as Villain)
	visit.current = int(data["current"])
	visit.meeting = null if str(data["meeting"]) == "" else load(str(data["meeting"])) as Villain
	visit.is_won = bool(data["is_won"])
	visit.scenery_seed = int(data["scenery_seed"])
	var saved_offsets: Dictionary = data["offsets"]
	for id: String in saved_offsets:
		visit.offsets[int(id)] = Vector2(float(saved_offsets[id][0]), float(saved_offsets[id][1]))
	visit._visited.clear()
	for id: Variant in data["visited"]:
		visit._visited[int(id)] = true
	for link: Array in data["walked"]:
		visit._walked[Vector2i(int(link[0]), int(link[1]))] = true
	return visit


func is_visited(id: int) -> bool:
	return _visited.has(id)


## Whether the link between Nodes [param a] and [param b] has been walked, either way.
func is_walked(a: int, b: int) -> bool:
	return _walked.has(_link(a, b))


static func _link(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))
