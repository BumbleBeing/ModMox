class_name HeldPotions
extends RefCounted
## The Potions the Hero holds between encounters (milestone 24), in the Satchel. Every one
## held is the Hero's in each encounter, in the order held; one used there is used up and gone
## afterwards, whether the encounter was won or lost. The same Potion held twice is one kind
## with a count of two.

var _potions: Array[MmCardDefinition] = []


func add(potion: MmCardDefinition) -> void:
	_potions.append(potion)


## Every Potion held, each as often as it is held, in the order held: what an encounter
## hands the Hero, whose places in it name the ones used (MmEngine.used_potion_indexes()).
func all() -> Array[MmCardDefinition]:
	return _potions.duplicate()


## Each kind of Potion held, once, in the order first held.
func kinds() -> Array[MmCardDefinition]:
	var result: Array[MmCardDefinition] = []
	for potion: MmCardDefinition in _potions:
		if not result.has(potion):
			result.append(potion)
	return result


func count_of(potion: MmCardDefinition) -> int:
	return _potions.count(potion)


## Uses up the Potions at [param places] in all(), as an encounter was handed them.
func use_up(places: Array) -> void:
	var used: Array[int] = []
	for place: Variant in places:
		used.append(int(place))
	var kept: Array[MmCardDefinition] = []
	for index: int in _potions.size():
		if not used.has(index):
			kept.append(_potions[index])
	_potions = kept


## The Potions held as plain data, for a saved run (ADR 0074): their paths, each as often as
## it is held, in the order held.
func to_data() -> Dictionary:
	return {"potions": SavedRun.paths_of(_potions)}


## The Potions [param data] holds, as to_data() made it.
static func from_data(data: Dictionary) -> HeldPotions:
	var held: HeldPotions = HeldPotions.new()
	for path: Variant in data["potions"]:
		held._potions.append(load(str(path)) as MmCardDefinition)
	return held
