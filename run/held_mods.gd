class_name HeldMods
extends RefCounted
## The Mods the Hero holds and has not applied. The same Mod held twice is one kind with a
## count of two.

## Where each Mod applied is logged (milestone 21), or null for none.
var run_log: RunLog = null

var _mods: Array[Mod] = []


func add(mod: Mod) -> void:
	_mods.append(mod)


## The Mods held as plain data, for a saved run (ADR 0074): their paths, each as often as
## it is held, in the order held.
func to_data() -> Dictionary:
	return {"mods": SavedRun.paths_of(_mods)}


## The Mods [param data] holds, as to_data() made it.
static func from_data(data: Dictionary) -> HeldMods:
	var held: HeldMods = HeldMods.new()
	for path: Variant in data["mods"]:
		held._mods.append(load(str(path)) as Mod)
	return held


## Each kind of Mod held, once, in the order first held.
func kinds() -> Array[Mod]:
	var result: Array[Mod] = []
	for mod: Mod in _mods:
		if not result.has(mod):
			result.append(mod)
	return result


func count_of(mod: Mod) -> int:
	return _mods.count(mod)


## Whether any held Mod is applicable to [param card].
func has_applicable(card: DeckbuilderCard) -> bool:
	for mod: Mod in kinds():
		if mod.is_applicable_to(card):
			return true
	return false


## Applies one held [param mod] to [param card] and uses it up. This is final: it changes
## the card in [param collection], not the Working Deck. A free basic land becomes the
## Collection's with its first Mod (A558). False if the Mod is not held or not applicable.
func apply(mod: Mod, card: DeckbuilderCard, collection: Collection) -> bool:
	if not _mods.has(mod) or not mod.is_applicable_to(card):
		return false
	_mods.erase(mod)
	card.attach(mod)
	collection.adopt(card)
	if run_log != null:
		run_log.record("mod_applied", {
			"mod": mod.resource_path, "card": card.id, "base": card.run_card.base.resource_path,
		})
	return true
