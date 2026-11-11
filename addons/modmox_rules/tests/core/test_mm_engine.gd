extends GutTest
## The engine facade's own facts: its version, and finding a card's Run Card for presentation.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_version_is_semantic() -> void:
	var regex: RegEx = RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_not_null(regex.search(MmEngine.VERSION), "VERSION must look like MAJOR.MINOR.PATCH, got '%s'." % MmEngine.VERSION)


func test_a_card_identity_from_a_view_leads_back_to_its_run_card() -> void:
	var bear: MmCardDefinition = Scenario.vanilla("Bear")
	var wolf: MmCardDefinition = Scenario.vanilla("Wolf")
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(bear, 40), Scenario.copies(wolf, 40))
	var engine: MmEngine = MmEngine.start(setup)

	var seen: MmObjectView = engine.view_for(engine.hero()).hand[0]
	var villain_card: MmObjectView = engine.view_for(engine.villain()).hand[0]

	assert_true(setup.hero.deck.has(engine.run_card(seen.card_id)), "The Hero's card is one of the Hero's Run Cards.")
	assert_eq(engine.run_card(villain_card.card_id).base.name, "Wolf")
	assert_null(engine.run_card(MmGameObject.NO_CARD), "An ability or Emblem is not a card.")
