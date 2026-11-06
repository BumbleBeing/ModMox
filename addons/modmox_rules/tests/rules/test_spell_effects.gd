extends GutTest
## CR 120: damage to a player causes that much life loss. CR 121: drawing.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Type := MmMana.Type


func test_damage_to_a_player_is_life_loss_from_the_spell() -> void:
	var engine: MmEngine = _hero_holding(Scenario.bolt(), "Bolt", "Mountain")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])
	var bolt_on_stack: int = engine.game_state().stack.object_ids()[0]

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.villain().life, 17)
	var damage: DamageEvent = null
	for event: MmEvent in engine.event_log():
		if event is DamageEvent:
			damage = event as DamageEvent
	assert_not_null(damage)
	assert_eq(damage.source_object_id, bolt_on_stack, "The spell is the source of the damage.")
	assert_eq(damage.amount, 3)


func test_target_player_draws_cards() -> void:
	var recall: MmCardDefinition = Scenario.instant("Recall", Scenario.mana_cost(0, [Type.BLUE]),
		[Scenario.target_player()], [Scenario.draw_cards(3, Scenario.targeted(0))])
	var engine: MmEngine = _hero_holding(recall, "Recall", "Island")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Recall"), [MmReference.to_player(engine.hero().id)])
	var hand_before: int = engine.hero().hand.size()

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.hero().hand.size(), hand_before + 3)


func test_gaining_life() -> void:
	var salve: MmCardDefinition = Scenario.instant("Salve", Scenario.mana_cost(0, [Type.WHITE]),
		[Scenario.target_player()], [Scenario.gain_life(3, Scenario.targeted(0))])
	var engine: MmEngine = _hero_holding(salve, "Salve", "Plains")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Salve"), [MmReference.to_player(engine.villain().id)])

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.villain().life, 23)


func _hero_holding(card: MmCardDefinition, card_name: String, land_type: String) -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land(land_type), 20, card, 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, card_name))
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
