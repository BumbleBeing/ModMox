extends GutTest
## Every kind of Pending Decision the engine can ask has an input on the Encounter Screen
## (13e-2): with the Debug Decision Panel gone, one that had none would leave the Hero
## asked something with nothing to click.

const DECISIONS: String = "res://addons/modmox_rules/src/decisions/"
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID


func test_every_decision_kind_in_the_engine_has_an_input() -> void:
	var asked: Array[Script] = _engine_kinds()

	assert_gt(asked.size(), 10, "The scan found the engine's decisions.")
	for kind: Script in asked:
		assert_true(DecisionInputs.kinds().has(kind), "%s has an input." % kind.get_global_name())


func test_no_input_is_listed_for_a_kind_the_engine_does_not_have() -> void:
	var asked: Array[Script] = _engine_kinds()

	for kind: Script in DecisionInputs.kinds():
		assert_true(asked.has(kind), "%s is a decision of the engine's." % kind.get_global_name())
		assert_ne(DecisionInputs.kinds()[kind], "")


func test_it_covers_a_decision_of_a_listed_kind_and_nothing_else() -> void:
	assert_true(DecisionInputs.covers(KeepOrMulliganDecision.new(HERO, 0, 0)))
	assert_true(DecisionInputs.covers(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])))
	assert_true(DecisionInputs.covers(PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])))
	assert_false(DecisionInputs.covers(MmPendingDecision.new(HERO)), "The bare base class is no kind at all.")
	assert_false(DecisionInputs.covers(null))


## Every decision class the engine defines, apart from their base class.
func _engine_kinds() -> Array[Script]:
	var kinds: Array[Script] = []
	for file: String in DirAccess.get_files_at(DECISIONS):
		if not file.ends_with(".gd"):
			continue
		var script: Script = load(DECISIONS + file) as Script
		if script != MmPendingDecision:
			kinds.append(script)
	return kinds
