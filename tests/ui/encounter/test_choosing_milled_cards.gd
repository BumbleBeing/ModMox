extends GutTest
## Choosing "an instant or sorcery card from among them" as a spell resolves (engine ADR
## 0080): the cards are in the Hero's graveyard, so its pile glows and its window takes the
## click, as for a target there (game ADR 0032), and the Info Panel asks for a card.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_milled_candidates_are_clicked_in_the_graveyard_window() -> void:
	var engine: MmEngine = _choice_asked()
	var choice: ChooseObjectDecision = engine.pending_decision() as ChooseObjectDecision
	assert_not_null(choice)
	if choice == null:
		return
	var view: MmPlayerView = engine.view_for(engine.hero())

	var clicks: DecisionClicks = DecisionClicks.of(choice, view)
	var prompt: InfoPrompt = InfoPrompt.of(choice, view)

	assert_eq(clicks.piles(), ["hero_graveyard"] as Array[String])
	for candidate: MmReference in choice.candidates:
		assert_eq(clicks.options_of(candidate.id).size(), 1)
	assert_eq(prompt.text, "Choose an instant or sorcery card for Secrets")


## The Hero resolving Secrets (Scenario.free_secrets()) on Game Turn 3, asked which milled
## instant or sorcery card to put into their hand.
func _choice_asked() -> MmEngine:
	var ping: MmCardDefinition = Scenario.instant("Ping", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var extras: Array[MmCardDefinition] = [Scenario.free_secrets(), ping, ping, Scenario.basic_land("Plains")]
	var no_cards: Array[MmCardDefinition] = []
	var held: Array[MmCardDefinition] = [extras[0]]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, no_cards, extras), no_cards, no_cards,
		held, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Secrets")), "")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	return engine
