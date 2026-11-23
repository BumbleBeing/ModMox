class_name ChooseTargetsDecision
extends MmPendingDecision
## The caster chooses the targets of an "up to" requirement [member target_index] of the
## spell or ability being put on the stack, "up to two target creatures" (CR 601.2c): any
## number of different objects from none to [member most] (CR 115.3). With nothing to
## choose it is asked only as a spell is cast or an ability activated, so that choosing none
## is confirmed or the cast canceled; a trigger then chooses none unasked (ADR 0014).
## Answer: an Array of distinct
## indexes into [member candidates], from none up to [member most] of them (ADR 0016).

var stack_object_id: int
## The requirement's index among the spell or ability's target requirements.
var target_index: int
## Every legal choice, in the order TargetRequirement.legal_targets() gives. Only
## permanents, until a card can choose up to some number of players or spells.
var candidates: Array[MmReference]
## The most targets that may be chosen.
var most: int


func _init(deciding_player_id: int, object_id: int, requirement_index: int, legal: Array[MmReference], at_most: int) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	target_index = requirement_index
	candidates = legal.duplicate()
	most = at_most
	for candidate: MmReference in candidates:
		assert(candidate.is_object(), "Later: \"up to\" target players, when a card needs them.")


func validate(answer: Variant) -> String:
	if typeof(answer) != TYPE_ARRAY:
		return "Expected a list of choices, got %s." % type_string(typeof(answer))
	var chosen: Array = answer
	if chosen.size() > most:
		return "Choose at most %d targets, not %d." % [most, chosen.size()]
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in chosen:
		if typeof(entry) != TYPE_INT:
			return "%s is not a choice number." % [entry]
		var index: int = entry
		if index < 0 or index >= candidates.size():
			return "Choice %d is not one of the options." % index
		if seen.has(index):
			return "CR 115.3: choice %d was chosen twice." % index
		seen[index] = true
	return ""


func describe() -> String:
	return "player %d: choose up to %d targets for requirement %d of object %d (%d candidates)" % [
		player_id, most, target_index, stack_object_id, candidates.size()]
