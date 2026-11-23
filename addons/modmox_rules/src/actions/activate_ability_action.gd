class_name ActivateAbilityAction
extends MmAction
## Activate ability number [member ability_index] of [member object_id], counting in the
## order of its current characteristics' abilities (CR 602).

var object_id: int
var ability_index: int
## The color of mana this activation makes, for an ability that adds one mana of any color:
## an MmMana.Type, chosen as it is activated (CR 605.3a, ADR 0072). MmMana.NO_TYPE for
## every other ability.
var mana_type: int = MmMana.NO_TYPE


func _init(source_object_id: int, index: int, chosen_mana_type: int = MmMana.NO_TYPE) -> void:
	object_id = source_object_id
	ability_index = index
	mana_type = chosen_mana_type


## The actions that activate [param ability], ability number [param index] of
## [param source_object_id]: one, or for a mana ability that adds mana of any color one for
## each color, in WUBRG order (ADR 0012, 0072).
static func each_for(source_object_id: int, index: int, ability: ActivatedAbility) -> Array[MmAction]:
	var actions: Array[MmAction] = []
	var colors: Array[MmMana.Type] = ability.mana_types_to_choose()
	if colors.is_empty():
		actions.append(new(source_object_id, index))
	for color: MmMana.Type in colors:
		actions.append(new(source_object_id, index, color))
	return actions


func describe() -> String:
	var activating: String = "activate ability %d of object %d" % [ability_index, object_id]
	if mana_type == MmMana.NO_TYPE:
		return activating
	return "%s for %s" % [activating, MmMana.Type.find_key(mana_type)]
