class_name HeldArmor
extends RefCounted
## The Armor the Hero holds, and what is Worn in each Armor Slot (game ADR 0106). The same
## Armor held twice is one kind with a count of two. A Worn Armor is still held; held but not
## Worn, an Armor does nothing.

## Where each Armor put on or taken off is logged (milestone 21), or null for none.
var run_log: RunLog = null

var _armor: Array[Armor] = []
var _worn: Dictionary[Armor.Slot, Armor] = {}


func add(armor: Armor) -> void:
	_armor.append(armor)


## The Armor held as plain data, for a saved run (ADR 0074): their paths, each as often as it
## is held, in the order held, and the path Worn in each Armor Slot, by its name.
func to_data() -> Dictionary:
	var worn_paths: Dictionary = {}
	for armor: Armor in worn():
		worn_paths[Armor.Slot.keys()[armor.slot]] = SavedRun.path_of(armor)
	return {"armor": SavedRun.paths_of(_armor), "worn": worn_paths}


## The Armor [param data] holds, as to_data() made it.
static func from_data(data: Dictionary) -> HeldArmor:
	var held: HeldArmor = HeldArmor.new()
	for path: Variant in data["armor"]:
		held._armor.append(load(str(path)) as Armor)
	var worn_paths: Dictionary = data["worn"]
	for armor_slot: Variant in worn_paths:
		held._worn[Armor.Slot[str(armor_slot)]] = load(str(worn_paths[armor_slot])) as Armor
	return held


## Each kind of Armor held, once, in the order first held.
func kinds() -> Array[Armor]:
	var result: Array[Armor] = []
	for armor: Armor in _armor:
		if not result.has(armor):
			result.append(armor)
	return result


func count_of(armor: Armor) -> int:
	return _armor.count(armor)


## The Armor Worn in [param armor_slot], or null for none.
func worn_in(armor_slot: Armor.Slot) -> Armor:
	return _worn.get(armor_slot, null) as Armor


func is_worn(armor: Armor) -> bool:
	return _worn.get(armor.slot, null) == armor


## The Armor Worn, Helm, then Cuirass, then Greaves.
func worn() -> Array[Armor]:
	var result: Array[Armor] = []
	for armor_slot: Armor.Slot in Armor.Slot.values():
		if _worn.has(armor_slot):
			result.append(_worn[armor_slot])
	return result


## The Starting Conditions of the Armor Worn, in the order they apply: Helm, Cuirass, then
## Greaves, each Armor's in the order authored.
func starting_conditions() -> Array[StartingCondition]:
	var result: Array[StartingCondition] = []
	for armor: Armor in worn():
		result.append_array(armor.starting_conditions)
	return result


## Puts on a held [param armor]: it fills its own Armor Slot, in place of whatever was Worn
## there, which stays held. False if it is not held.
func put_on(armor: Armor) -> bool:
	if not _armor.has(armor):
		return false
	_worn[armor.slot] = armor
	if run_log != null:
		run_log.record("armor_put_on", {"armor": armor.resource_path, "slot": Armor.Slot.keys()[armor.slot]})
	return true


## Takes off whatever is Worn in [param armor_slot], which stays held. False if nothing is.
func take_off(armor_slot: Armor.Slot) -> bool:
	if not _worn.has(armor_slot):
		return false
	var armor: Armor = _worn[armor_slot]
	_worn.erase(armor_slot)
	if run_log != null:
		run_log.record("armor_taken_off", {"slot": Armor.Slot.keys()[armor_slot], "armor": armor.resource_path})
	return true
