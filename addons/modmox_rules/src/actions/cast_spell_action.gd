class_name CastSpellAction
extends MmAction
## Cast the card [member object_id] (CR 601), as its Adventure when [member as_adventure]
## (CR 715.3, engine ADR 0078), bestowed when [member is_bestowed] (CR 702.103a), or for
## its alternative cost when [member is_for_alternative_cost] (CR 118.9, engine ADR 0093).

var object_id: int
var as_adventure: bool = false
## Cast for its bestow cost as an Aura spell (CR 702.103a, engine ADR 0089).
var is_bestowed: bool = false
## Cast from the hand for its AlternativeCostAbility's cost (CR 118.9, engine ADR 0093).
var is_for_alternative_cost: bool = false


func _init(card_object_id: int, is_adventure: bool = false, bestowed: bool = false,
		for_alternative_cost: bool = false) -> void:
	object_id = card_object_id
	as_adventure = is_adventure
	is_bestowed = bestowed
	is_for_alternative_cost = for_alternative_cost


func describe() -> String:
	return "cast %d%s%s%s" % [object_id, " as an Adventure" if as_adventure else "", " bestowed" if is_bestowed else "",
		" for its alternative cost" if is_for_alternative_cost else ""]
