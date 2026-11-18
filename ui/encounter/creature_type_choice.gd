class_name CreatureTypeChoice
extends RefCounted
## What the Creature Type Window shows for a ChooseCreatureTypeDecision (game ADR 0053),
## worked out without Nodes: the chooser's own types, pinned first; every other type; which
## of them match what is typed, names starting with it first; the match Enter chooses and the
## one Up and Down move to; and what pointing at a type says and marks.
##
## The chooser's own types are those of the creatures they control, then of the creature
## cards they own in their hand, graveyard and library (they know their own deck list, which
## the Player View gives as library_contents). They are ordered by how many they control,
## then how many they own elsewhere, then alphabetically. Nobody else's types are pinned.

## The decision answered. Never changed.
var decision: ChooseCreatureTypeDecision

var _view: MmPlayerView
var _names: PlayerNames
## The chooser's own types, in pinned order.
var _yours: Array[String] = []
## Each of the chooser's creatures on the battlefield, by its types: object IDs in the
## order the view lists them.
var _controlled_ids: Dictionary[String, Array] = {}


func _init(asked: ChooseCreatureTypeDecision, view: MmPlayerView, names: PlayerNames = null) -> void:
	decision = asked
	_view = view
	_names = names
	_find_yours()


## Whether this choice is for [param asked]: the same decision, so a redraw keeps the window
## and what is typed in it.
func is_for(asked: MmPendingDecision) -> bool:
	return asked == decision


## The chooser's own types, in the order they are pinned.
func yours() -> Array[String]:
	return _yours.duplicate()


## How [param creature_type] matches [param query]: 0 if it starts with it (or nothing is
## typed), 1 if it has it elsewhere, -1 if not at all. Case is ignored.
static func rank(creature_type: String, query: String) -> int:
	if query == "":
		return 0
	var found: int = creature_type.to_lower().find(query.to_lower())
	if found < 0:
		return -1
	return 0 if found == 0 else 1


## The chooser's own types that match [param query], in pinned order.
func pinned(query: String) -> Array[String]:
	var matching: Array[String] = []
	for creature_type: String in _yours:
		if rank(creature_type, query) >= 0:
			matching.append(creature_type)
	return matching


## Every other type that matches [param query]: those starting with it first, then those
## having it elsewhere, each alphabetically.
func others(query: String) -> Array[String]:
	var starting: Array[String] = []
	var within: Array[String] = []
	for creature_type: String in decision.creature_types:
		if _yours.has(creature_type):
			continue
		match rank(creature_type, query):
			0:
				starting.append(creature_type)
			1:
				within.append(creature_type)
	starting.append_array(within)
	return starting


## Every match of [param query] in the order shown: pinned, then the others. Up and Down
## step through it.
func matches(query: String) -> Array[String]:
	var all: Array[String] = pinned(query)
	all.append_array(others(query))
	return all


## The match Enter chooses for [param query]: the first one shown, or "" when nothing is
## typed or nothing matches.
func top_match(query: String) -> String:
	if query == "":
		return ""
	var all: Array[String] = matches(query)
	return all[0] if not all.is_empty() else ""


## The match [param steps] away from [param current] among the matches of [param query],
## held at the first and the last; with no [param current] among them, the first.
func stepped(current: String, query: String, steps: int) -> String:
	var all: Array[String] = matches(query)
	if all.is_empty():
		return ""
	var at: int = all.find(current)
	if at == -1:
		return all[0]
	return all[clampi(at + steps, 0, all.size() - 1)]


## The answer that chooses [param creature_type], or -1.
func answer_of(creature_type: String) -> int:
	return decision.creature_types.find(creature_type)


## The chooser's creatures on the battlefield of [param creature_type], as the view lists
## them.
func controlled_of(creature_type: String) -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_controlled_ids.get(creature_type, []))
	return ids


## What the spell being resolved is called.
func spell_name() -> String:
	var spell: MmObjectView = _spell()
	return spell.name if spell != null else ""


func _spell() -> MmObjectView:
	for item: MmObjectView in _view.stack:
		if item.id == decision.stack_object_id:
			return item
	return null


func _find_yours() -> void:
	var controlled: Dictionary[String, int] = {}
	var elsewhere: Dictionary[String, int] = {}
	for permanent: MmObjectView in _view.battlefield:
		if permanent.controller_id != decision.player_id or not permanent.is_creature:
			continue
		for creature_type: String in _creature_types_of(permanent):
			controlled[creature_type] = controlled.get(creature_type, 0) + 1
			var ids: Array = _controlled_ids.get(creature_type, [])
			ids.append(permanent.id)
			_controlled_ids[creature_type] = ids
	var owned: Array[MmObjectView] = []
	owned.append_array(_view.hand)
	owned.append_array(_view.graveyards.get(decision.player_id, []))
	owned.append_array(_view.library_contents)
	for card: MmObjectView in owned:
		if not card.is_creature:
			continue
		for creature_type: String in _creature_types_of(card):
			elsewhere[creature_type] = elsewhere.get(creature_type, 0) + 1
	for creature_type: String in decision.creature_types:
		if controlled.has(creature_type) or elsewhere.has(creature_type):
			_yours.append(creature_type)
	# Stable from the alphabetical list: a tie keeps alphabetical order.
	var place: Dictionary[String, int] = {}
	for index: int in _yours.size():
		place[_yours[index]] = index
	_yours.sort_custom(func(a: String, b: String) -> bool:
		if controlled.get(a, 0) != controlled.get(b, 0):
			return controlled.get(a, 0) > controlled.get(b, 0)
		if elsewhere.get(a, 0) != elsewhere.get(b, 0):
			return elsewhere.get(a, 0) > elsewhere.get(b, 0)
		return place[a] < place[b])


## [param card]'s subtypes that are creature types.
func _creature_types_of(card: MmObjectView) -> Array[String]:
	var found: Array[String] = []
	for subtype: String in card.subtypes:
		if decision.creature_types.has(subtype) and not found.has(subtype):
			found.append(subtype)
	return found
