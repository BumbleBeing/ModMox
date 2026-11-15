class_name HeldMods
extends RefCounted
## The Mods the Hero holds and has not applied. The same Mod held twice is one kind with a
## count of two.

var _mods: Array[Mod] = []


func add(mod: Mod) -> void:
	_mods.append(mod)


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
	return true
