class_name ChooseCreatureTypeDecision
extends MmPendingDecision
## The controller of a resolving permanent spell with "As this enters, choose a creature
## type" chooses one, before it enters (CR 614.12, ADR 0052). Answer: the index of the
## chosen type in [member creature_types].

var stack_object_id: int
## Every creature type (CR 205.3m): CreatureTypes.ALL, shared rather than copied.
var creature_types: Array[String]


func _init(deciding_player_id: int, object_id: int) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	creature_types = CreatureTypes.ALL


func validate(answer: Variant) -> String:
	return _check_choice(answer, creature_types.size())


func describe() -> String:
	return "player %d: choose a creature type for object %d" % [player_id, stack_object_id]
