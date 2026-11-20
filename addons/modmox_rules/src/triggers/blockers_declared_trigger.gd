class_name BlockersDeclaredTrigger
extends MmTrigger
## "Whenever [filter] blocks a creature" (CR 509.3b): triggers as blockers are declared, once
## for each attacking creature a creature that matches is declared blocking, so one that
## blocks two attackers triggers it twice (ADR 0017's addendum). "That creature" is the
## attacker it blocks, and "that player" the attacking player. A creature put onto the
## battlefield blocking was never declared as a blocker, so it never triggers it.
# Later: "Whenever [filter] blocks" (CR 509.3a), once however many it blocks and with no
# "that creature", as a field here; and "becomes blocked (by a creature)" (CR 509.3c-d).
# Once a card has one.

## Which blockers count. Null matches any creature.
@export var filter: MmFilter = null


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	return not triggering_object_ids(state, event, context).is_empty()


## The attacker of each block declared by a creature that matches, by blocker ID and then
## attacker ID, whatever order the blocks were declared in.
func triggering_object_ids(state: MmGameState, event: MmEvent, context: MmEffectContext) -> Array[int]:
	var found: Array[int] = []
	var declared: BlockersDeclaredEvent = event as BlockersDeclaredEvent
	if declared == null:
		return found
	# Each block as (blocker ID, attacker ID), which sorts by blocker and then attacker.
	var blocks: Array[Vector2i] = []
	for index: int in declared.blocker_ids.size():
		var blocker_id: int = declared.blocker_ids[index]
		if filter == null or filter.matches(state, MmReference.to_object(blocker_id), context):
			blocks.append(Vector2i(blocker_id, declared.attacker_ids[index]))
	blocks.sort()
	for block: Vector2i in blocks:
		found.append(block.y)
	return found


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	return state.opponent_of((event as BlockersDeclaredEvent).defending_player_id).id
