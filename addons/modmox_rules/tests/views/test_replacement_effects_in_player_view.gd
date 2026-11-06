extends GutTest
## Shields and other replacement effects are public, so the GUI can show what will
## prevent or replace an event and which card it came from (A140).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_view_lists_the_shield_on_it_with_its_source_card() -> void:
	var engine: MmEngine = _main_ready([Scenario.creature("Giant", 5, 5)], [Scenario.free_shield("Ward", 2)])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	var ward: int = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Ward")).card_id
	Scenario.cast_and_resolve(engine, "Ward", [MmReference.to_object(giant)])

	var seen: MmObjectView = engine.view_for(engine.villain()).battlefield[0]

	assert_eq(seen.replacement_effects.size(), 1)
	var shield: ActiveReplacementEffect = seen.replacement_effects[0]
	assert_eq(shield.source_card_id, ward)
	assert_eq(shield.remaining, 2)
	assert_true(shield.effect is PreventDamageReplacementEffect)


func test_a_player_view_lists_shields_on_each_player() -> void:
	var engine: MmEngine = _main_ready([], [Scenario.free_shield("Ward", 2)])
	Scenario.cast_and_resolve(engine, "Ward", [MmReference.to_player(engine.villain().id)])

	var view: MmPlayerView = engine.view_for(engine.hero())

	assert_eq(view.player_replacement_effects[engine.villain().id].size(), 1)
	assert_eq(view.player_replacement_effects[engine.hero().id].size(), 0)


func test_an_effect_on_no_particular_player_or_object_is_listed_for_the_whole_game() -> void:
	var engine: MmEngine = _main_ready([Scenario.creature("Giant", 5, 5)], [Scenario.free_fog("Fog")])
	Scenario.cast_and_resolve(engine, "Fog")

	var view: MmPlayerView = engine.view_for(engine.villain())

	assert_eq(view.game_replacement_effects.size(), 1)
	assert_eq(view.battlefield[0].replacement_effects, [])


func test_a_regeneration_shield_is_shown_as_regeneration() -> void:
	var engine: MmEngine = _main_ready([Scenario.creature("Giant", 5, 5)], [Scenario.free_regenerate("Mend")])
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Giant"))])

	var seen: MmObjectView = engine.view_for(engine.hero()).battlefield[0]

	assert_true(seen.replacement_effects[0].effect is RegenerationReplacementEffect)


func _main_ready(hero_creatures: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, no_cards, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
