class_name AssignsCombatDamageByToughnessAbility
extends StaticAbility
## "[affected] assigns combat damage equal to its toughness rather than its power" (CR
## 510.1a), as Bark of Doran's "As long as equipped creature's toughness is greater than its
## power, it assigns combat damage equal to its toughness rather than its power". It changes a
## rule, not characteristics: what it reaches keeps its power for everything else, fighting
## included, and gains no ability, so a creature that loses all its abilities still assigns by
## toughness (ADR 0018). Combat damage assignment asks it, through
## CombatProcedure.combat_damage_amount(), once every layer has applied.

## What assigns by toughness, found with this ability's controller as "you" and its object as
## the source: AttachedToSelection for "equipped creature", SourceSelection for "this
## creature".
@export var affected: MmSelection
## "As long as [condition]": asked as combat damage is assigned, with every layer applied, and
## with the same controller and source as [member affected]. Null for always.
@export var condition: MmCondition = null


## Whether this ability of [param source] makes [param creature] assign combat damage by its
## toughness right now.
func applies_to(state: MmGameState, source: MmGameObject, creature: MmGameObject) -> bool:
	assert(affected != null, "An AssignsCombatDamageByToughnessAbility needs a Selection.")
	var context: MmEffectContext = MmEffectContext.new(source.controller_id, source.id)
	if condition != null and not condition.is_true(state, context):
		return false
	for found: MmReference in affected.select(state, context):
		if found.is_object() and found.id == creature.id:
			return true
	return false


func describe() -> String:
	return "assigns combat damage equal to toughness"
