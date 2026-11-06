extends GutTest
## The stack is public (CR 400.2): every view shows each item, its controller and targets.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_both_players_see_the_stack_with_its_targets() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Bolt"))
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_eq(view.stack.size(), 1)
		var item: MmObjectView = view.stack[0]
		assert_eq(item.name, "Bolt")
		assert_eq(item.controller_id, engine.hero().id)
		assert_eq(item.targets.size(), 1)
		assert_true(item.targets[0].equals(MmReference.to_player(engine.villain().id)))
