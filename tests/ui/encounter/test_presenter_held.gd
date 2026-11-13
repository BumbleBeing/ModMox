extends GutTest
## What a snapshot carries for an Emblem and a Potion (ADR 0033 and engine ADR 0036): a look
## that says which it is, in its own words, with the art it was authored with, and for a
## Potion its Rarity. The engine's views carry no file names, so the presenter finds each
## in the setup.

const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_an_authored_emblem_has_an_emblems_look_with_its_own_art_key() -> void:
	var snapshot: EncounterSnapshot = _snapshot()
	var boon: MmObjectView = snapshot.emblems_of(HERO)[2]

	var look: CardLook = snapshot.look_of(boon.id)

	assert_eq(look.kind, CardLook.Kind.EMBLEM)
	assert_eq(look.name, "Electromancer's Boon")
	assert_eq(look.held_type_line(), "Emblem")
	assert_eq(look.art_key, "emblems/electromancers_boon")
	assert_eq(look.rules_lines, ["{R}: This emblem deals 3 damage to any target. Activate only once each game."] as Array[String])
	assert_eq(look.rules_text, look.rules_lines[0])
	assert_false(look.is_ability_spent(0))
	assert_false(snapshot.has_rarity(boon.id), "An Emblem is not an Item (A535).")


func test_a_sample_emblem_borrows_the_art_of_the_card_it_was_made_from() -> void:
	var snapshot: EncounterSnapshot = _snapshot()

	assert_eq(snapshot.look_of(snapshot.emblems_of(HERO)[0].id).art_key, "howling_mine")
	assert_eq(snapshot.look_of(snapshot.emblems_of(VILLAIN)[0].id).art_key, "ankh_of_mishra")
	assert_eq(snapshot.look_of(snapshot.emblems_of(VILLAIN)[1].id).art_key, "emblems/electromancers_boon",
		"Each player's Emblems are found in that player's setup.")


func test_a_sample_emblem_calls_itself_this_emblem() -> void:
	var snapshot: EncounterSnapshot = _snapshot()

	var look: CardLook = snapshot.look_of(snapshot.emblems_of(VILLAIN)[0].id)

	assert_eq(look.rules_text, "Whenever a land enters, this emblem deals 2 damage to that land's controller.")


func test_a_potion_has_a_potions_look_its_icons_key_and_its_rarity() -> void:
	var snapshot: EncounterSnapshot = _snapshot()
	var potion: MmObjectView = snapshot.potions_of(HERO)[0]

	var look: CardLook = snapshot.look_of(potion.id)

	assert_eq(look.kind, CardLook.Kind.POTION)
	assert_eq(look.name, "Big Gulp")
	assert_eq(look.held_type_line(), "Potion")
	assert_eq(look.art_key, "big_gulp")
	assert_eq(look.rules_text, "Target creature gets +2/+2 until end of turn.")
	assert_true(snapshot.has_rarity(potion.id))
	assert_eq(snapshot.rarity_of(potion.id), MmCardDefinition.Rarity.COMMON)
	assert_eq(snapshot.potions_of(VILLAIN).size(), 0)


func test_a_card_keeps_a_cards_look() -> void:
	var snapshot: EncounterSnapshot = _snapshot()

	var look: CardLook = snapshot.look_of(snapshot.view.hand[0].id)

	assert_eq(look.kind, CardLook.Kind.CARD)
	assert_eq(look.held_type_line(), "")
	assert_eq(look.rules_lines.size(), 0)


func _snapshot() -> EncounterSnapshot:
	var request: EncounterRequest = EncounterRequest.new()
	request.has_sample_emblems = true
	request.has_sample_potions = true
	var presenter: EncounterPresenter = EncounterPresenter.new(request.setup(), DefaultAnswerAgent.new())
	presenter.start()
	presenter.wait_until_idle()
	return presenter.snapshot()
