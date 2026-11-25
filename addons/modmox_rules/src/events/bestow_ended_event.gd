class_name BestowEndedEvent
extends MmEvent
## A bestowed Aura spell whose target is gone ceases to be bestowed, and is an enchantment
## creature spell from then on (CR 702.103e, engine ADR 0089).

var object_id: int


func _init(spell_id: int) -> void:
	object_id = spell_id


func apply(state: MmGameState) -> void:
	state.object(object_id).end_bestowed()


func describe() -> String:
	return "BESTOW ENDED: object %d" % object_id
