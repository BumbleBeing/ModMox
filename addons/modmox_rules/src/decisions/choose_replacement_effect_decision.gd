class_name ChooseReplacementEffectDecision
extends MmPendingDecision
## CR 616.1: several replacement or prevention effects would apply to [member event], and the
## affected player chooses which applies first. The others are offered again afterwards if
## they still apply. Answer: the index of the chosen entry in [member options], which lists
## created effects in the order they were created, then those of static abilities.

## The event about to be performed, so the GUI can say what is being replaced.
var event: MmEvent
var options: Array[ActiveReplacementEffect]


func _init(deciding_player_id: int, proposed: MmEvent, choices: Array[ActiveReplacementEffect]) -> void:
	super(deciding_player_id)
	event = proposed
	options = choices.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, options.size())


func describe() -> String:
	var keys: PackedStringArray = PackedStringArray()
	for active: ActiveReplacementEffect in options:
		keys.append(active.key())
	return "player %d: choose which of [%s] applies to %s" % [player_id, ", ".join(keys), event.describe()]
