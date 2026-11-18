extends GutTest
## What the Creature Type Window shows (game ADR 0053), worked out without Nodes: the
## chooser's own types pinned first, every other type, what matches the search, what Enter
## chooses, where Up and Down go, and what pointing at a type says.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const RALLY: int = 90


func test_the_choosers_types_are_ordered_by_how_many_they_control_then_own_elsewhere_then_alphabetically() -> void:
	var view: MmPlayerView = _view()
	view.battlefield = [_creature(1, "Lion", ["Cat"]), _creature(2, "Tabby", ["Cat"]), _creature(3, "Elf", ["Elf", "Warrior"])]
	view.hand = [_creature(4, "Bat", ["Bat"]), _creature(5, "Hawk", ["Bird"])]
	view.graveyards[HERO] = [_creature(6, "Rook", ["Bird"])]
	view.library_contents = [_creature(0, "Ape", ["Ape"])]

	var choice: CreatureTypeChoice = CreatureTypeChoice.new(_decision(), view)

	assert_eq(choice.yours(), ["Cat", "Elf", "Warrior", "Bird", "Ape", "Bat"])


func test_the_library_counts_from_what_the_view_says_is_in_it() -> void:
	var view: MmPlayerView = _view()
	view.library_contents = [_creature(0, "Lion", ["Cat"])]

	assert_eq(CreatureTypeChoice.new(_decision(), view).yours(), ["Cat"], "A player knows their own deck list.")


func test_the_opponents_creatures_and_what_is_not_a_creature_are_not_pinned() -> void:
	var view: MmPlayerView = _view()
	var theirs: MmObjectView = _creature(1, "Goblin", ["Goblin"])
	theirs.controller_id = VILLAIN
	var aura: MmObjectView = _creature(2, "Aura", ["Aura"])
	aura.is_creature = false
	view.battlefield = [theirs, aura]
	view.graveyards[VILLAIN] = [_creature(3, "Orc", ["Orc"])]

	assert_eq(CreatureTypeChoice.new(_decision(), view).yours(), [])


func test_with_nothing_typed_every_type_is_shown_pinned_first() -> void:
	var choice: CreatureTypeChoice = _cats_and_elves()

	var shown: Array[String] = choice.matches("")

	assert_eq(shown.size(), 377)
	assert_eq(shown.slice(0, 2), ["Cat", "Elf"])
	assert_eq(shown[2], "Advisor")
	assert_eq(choice.others("").count("Cat"), 0, "A pinned type is shown once.")


func test_types_starting_with_what_is_typed_come_before_those_having_it_elsewhere() -> void:
	var choice: CreatureTypeChoice = _cats_and_elves()

	var others: Array[String] = choice.others("ca")

	assert_eq(others.slice(0, 3), ["Caitian", "Camarid", "Camel"])
	assert_true(others.has("Scarecrow"))
	assert_gt(others.find("Scarecrow"), others.find("Capybara"))
	assert_eq(choice.pinned("ca"), ["Cat"])
	assert_eq(choice.pinned("CA"), ["Cat"], "Case is ignored.")


func test_enter_chooses_the_top_match_only_once_something_is_typed() -> void:
	var choice: CreatureTypeChoice = _cats_and_elves()

	assert_eq(choice.top_match(""), "")
	assert_eq(choice.top_match("e"), "Elf", "The chooser's own first.")
	assert_eq(choice.top_match("wiz"), "Wizard")
	assert_eq(choice.top_match("zzz"), "")


func test_up_and_down_step_through_the_matches_and_stop_at_the_ends() -> void:
	var choice: CreatureTypeChoice = _cats_and_elves()

	assert_eq(choice.stepped("", "ca", 1), "Cat", "From nothing lit, the first.")
	assert_eq(choice.stepped("Cat", "ca", 1), "Caitian")
	assert_eq(choice.stepped("Caitian", "ca", -1), "Cat")
	assert_eq(choice.stepped("Cat", "ca", -1), "Cat")
	var all: Array[String] = choice.matches("ca")
	assert_eq(choice.stepped(all[-1], "ca", 1), all[-1])


func test_a_type_is_answered_by_its_place_in_the_decisions_list() -> void:
	var choice: CreatureTypeChoice = _cats_and_elves()

	assert_eq(choice.answer_of("Cat"), CreatureTypes.ALL.find("Cat"))
	assert_eq(choice.answer_of("Forest"), -1)


func test_pointing_at_a_type_finds_the_creatures_of_it_you_control() -> void:
	var view: MmPlayerView = _view()
	var token: MmObjectView = _creature(3, "Cat Token", ["Cat"])
	token.is_token = true
	view.battlefield = [_creature(1, "Savannah Lions", ["Cat"]), _creature(2, "Llanowar Elves", ["Elf"]), token]
	var choice: CreatureTypeChoice = CreatureTypeChoice.new(_decision(), view)

	assert_eq(choice.controlled_of("Cat"), [1, 3])
	assert_eq(choice.controlled_of("Elf"), [2])
	assert_eq(choice.controlled_of("Angel"), [])


func test_it_is_for_its_own_decision_only() -> void:
	var decision: ChooseCreatureTypeDecision = _decision()
	var choice: CreatureTypeChoice = CreatureTypeChoice.new(decision, _view())

	assert_true(choice.is_for(decision))
	assert_false(choice.is_for(_decision()))
	assert_eq(choice.spell_name(), "Rally the Ranks")


func _cats_and_elves() -> CreatureTypeChoice:
	var view: MmPlayerView = _view()
	view.battlefield = [_creature(1, "Lion", ["Cat"]), _creature(2, "Tabby", ["Cat"]), _creature(3, "Elf", ["Elf"])]
	return CreatureTypeChoice.new(_decision(), view)


func _decision() -> ChooseCreatureTypeDecision:
	return ChooseCreatureTypeDecision.new(HERO, RALLY)


## The Hero's view with Rally the Ranks resolving.
func _view() -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var rally: MmCardDefinition = Scenario.rally("Rally the Ranks")
	var spell: MmObjectView = MmObjectView.new()
	spell.id = RALLY
	spell.name = rally.name
	spell.card_types = rally.card_types
	spell.abilities = rally.abilities
	spell.controller_id = HERO
	view.stack = [spell]
	return view


func _creature(id: int, card_name: String, subtypes: Array[String]) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = card_name
	seen.is_creature = true
	seen.card_types = [MmCardTypes.CardType.CREATURE]
	seen.subtypes = subtypes
	seen.owner_id = HERO
	seen.controller_id = HERO
	return seen
