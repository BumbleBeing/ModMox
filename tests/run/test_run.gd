extends GutTest
## The run's state (milestones 16 and 17): its Hearts and gold, the Active Deck and the
## encounter's setup built from it (ADRs 0025 and 0028), and the Stage the Run Seed rolls,
## with its map, its Boss and the Villains met on it (ADRs 0024 and 0026).

const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_a_debug_run_starts_with_three_hearts_and_no_gold() -> void:
	var run: Run = Run.debug(7)
	assert_eq(run.hearts, Run.STARTING_HEARTS)
	assert_eq(Run.STARTING_HEARTS, 3)
	assert_eq(run.gold, 0)
	assert_false(run.is_lost())


func test_a_debug_run_owns_four_of_every_nonland_card_or_as_many_as_a_villains_deck_has() -> void:
	var run: Run = Run.debug(7)
	var expected: Dictionary[MmCardDefinition, int] = {}
	for definition: MmCardDefinition in ContentCards.all():
		if not definition.supertypes.has(MmCardTypes.Supertype.BASIC):
			expected[definition] = Run.DEBUG_COPIES
	for villain: Villain in ContentStages.all_villains():
		for setup: MmPlayerSetup in villain.setups:
			var counted: Dictionary[MmCardDefinition, int] = {}
			for run_card: MmRunCard in setup.deck:
				counted[run_card.base] = counted.get(run_card.base, 0) + 1
			for definition: MmCardDefinition in counted:
				if expected.has(definition):
					expected[definition] = maxi(expected[definition], counted[definition])
	assert_eq(Run.DEBUG_COPIES, 4)
	var owned: Dictionary[MmCardDefinition, int] = {}
	for card: DeckbuilderCard in run.collection.cards():
		assert_false(card.is_basic_land(), card.card_name())
		owned[card.run_card.base] = owned.get(card.run_card.base, 0) + 1
	assert_eq(owned, expected)


func test_a_debug_run_has_a_legal_active_deck_built_from_red_green_first() -> void:
	var run: Run = Run.debug(7)
	var active: Deck = run.deckbox.active()
	assert_not_null(active)
	assert_eq(run.deckbox.decks()[0], active)
	assert_eq(active.name, "Red-Green")
	var red_green: MmPlayerSetup = ContentDecks.load_deck("red_green")
	assert_eq(_list_of(run, active), _list_of_setup(red_green))
	assert_true(run.deckbox.is_legal(active))


func test_a_debug_run_has_a_deck_for_each_villains_deck_named_after_it() -> void:
	var run: Run = Run.debug(7)
	var expected: Dictionary[String, Dictionary] = {}
	for villain: Villain in ContentStages.all_villains():
		expected[villain.name] = _list_of_setup(villain.setups[0])
	var built: Dictionary[String, Dictionary] = {}
	for deck: Deck in run.deckbox.decks():
		assert_false(built.has(deck.name), deck.name)
		built[deck.name] = _list_of(run, deck)
	assert_eq(built, expected)


func test_each_card_is_at_most_once_in_a_debug_deck() -> void:
	var run: Run = Run.debug(7)
	for deck: Deck in run.deckbox.decks():
		var seen: Dictionary[int, bool] = {}
		for id: int in deck.card_ids:
			assert_false(seen.has(id), deck.name)
			seen[id] = true


## T1: the same Run Seed gives the same Stage, map, Boss and Villains in order.
func test_the_same_run_seed_gives_the_same_stage_map_boss_and_villains() -> void:
	var first: Run = Run.debug(42)
	var second: Run = Run.debug(42)

	assert_eq(first.stage_visit.stage, second.stage_visit.stage)
	assert_eq(_describe(first.stage_visit.map), _describe(second.stage_visit.map))
	assert_eq(first.stage_visit.boss, second.stage_visit.boss)
	assert_eq(first.stage_visit.offsets, second.stage_visit.offsets)
	assert_eq(_walk(first), _walk(second))


func test_other_run_seeds_give_other_stages_and_maps() -> void:
	var stages: Dictionary[StageDefinition, bool] = {}
	var maps: Dictionary[String, bool] = {}
	for run_seed: int in 20:
		var run: Run = Run.debug(run_seed)
		stages[run.stage_visit.stage] = true
		maps[_describe(run.stage_visit.map)] = true

	assert_gt(stages.size(), 1)
	assert_gt(maps.size(), 1)


func test_a_debug_run_starts_on_the_start_node_of_a_tier_one_stage() -> void:
	var run: Run = Run.debug(7)

	assert_eq(run.stage_visit.stage.tier, 1)
	assert_eq(run.stage_visit.node().kind, StageMap.Kind.START)
	assert_true(run.stage_visit.stage.bosses.has(run.stage_visit.boss))
	assert_false(run.is_won())


func test_every_node_is_given_a_place_in_its_cell() -> void:
	var run: Run = Run.debug(7)

	for node: MapNode in run.stage_visit.map.nodes:
		var offset: Vector2 = run.stage_visit.offsets[node.id]
		assert_between(offset.x, -1.0, 1.0)
		assert_between(offset.y, -1.0, 1.0)


## The Boss's Node is always drawn at the center of its cell, the same spot on every map,
## so a Map Backdrop can be painted round it (ADR 0038).
func test_the_bosss_node_is_always_at_the_center_of_its_cell() -> void:
	for run_seed: int in [1, 7, 42]:
		var run: Run = Run.debug(run_seed)
		var boss: MapNode = run.stage_visit.map.boss()

		assert_eq(run.stage_visit.offsets[boss.id], Vector2.ZERO)
		assert_eq(StageMapLayout.node_spot(boss, run.stage_visit.offsets[boss.id], 8.0),
				StageMapLayout.cell_center(StageMap.ROWS, 5, 8.0))


## ADR 0038: entering a Stage draws its Scenery's seed from a stream of its own, so the
## same Run Seed places the same Scenery and Stages differ.
func test_entering_a_stage_draws_its_scenery_seed() -> void:
	assert_eq(Run.debug(7).stage_visit.scenery_seed, Run.debug(7).stage_visit.scenery_seed)
	assert_ne(Run.debug(7).stage_visit.scenery_seed, Run.debug(8).stage_visit.scenery_seed)


func test_a_debug_run_holds_the_playtest_bolt_in_every_encounter() -> void:
	var run: Run = Run.debug(7)

	assert_eq(run.hero_setup().emblems.size(), 1)
	assert_eq(run.hero_setup().emblems[0].name, "Playtest Bolt")


func test_a_debug_run_holds_one_of_every_mod_in_content_and_no_hex() -> void:
	var run: Run = Run.debug(1)

	var mods: Array[Mod] = ContentMods.all()
	assert_false(mods.is_empty(), "Content has Mods.")
	for mod: Mod in mods:
		assert_eq(run.held_mods.count_of(mod), 0 if mod.is_hex else 1, mod.name)
	assert_eq(run.held_mods.kinds().size(), mods.filter(func(mod: Mod) -> bool: return not mod.is_hex).size())


## Milestone 23: a debug run holds one of every Armor in Content, to try them out, and wears
## none of it.
func test_a_debug_run_holds_one_of_every_armor_in_content_and_wears_none() -> void:
	var run: Run = Run.debug(1)

	var armor: Array[Armor] = ContentArmor.all()
	for each: Armor in armor:
		assert_eq(run.held_armor.count_of(each), 1, each.name)
	assert_eq(run.held_armor.kinds().size(), armor.size())
	assert_eq(run.held_armor.worn(), [] as Array[Armor])


## T8 (milestone 17): beating the Boss beats the Stage; only the fifth wins the run
## (milestone 19).
func test_beating_the_boss_beats_the_stage() -> void:
	var run: Run = Run.debug(5)

	_walk(run)

	assert_true(run.is_stage_beaten())
	assert_false(run.is_won(), "A Tier 1 Boss does not win the run.")
	assert_eq(run.hearts, Run.STARTING_HEARTS)


func test_losing_to_the_boss_costs_a_heart_and_meets_it_again() -> void:
	var run: Run = Run.debug(5)
	while run.stage_visit.node().kind != StageMap.Kind.BOSS:
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])

	run.record_encounter(false)

	assert_eq(run.hearts, Run.STARTING_HEARTS - 1)
	assert_eq(run.stage_visit.meeting, run.stage_visit.boss)
	assert_false(run.is_won())


func test_each_encounter_gets_its_own_encounter_seed() -> void:
	var run: Run = Run.debug(5)
	var first: int = run.next_encounter_seed()
	var second: int = run.next_encounter_seed()
	assert_ne(first, second)
	var again: Run = Run.debug(5)
	assert_eq(again.next_encounter_seed(), first)


func test_walking_the_stage_does_not_change_the_encounter_seeds() -> void:
	var plain: Run = Run.debug(9)
	var busy: Run = Run.debug(9)

	_walk(busy)

	assert_eq(busy.next_encounter_seed(), plain.next_encounter_seed())


func test_a_win_keeps_the_hearts() -> void:
	var run: Run = Run.debug(1)
	run.record_encounter(true)
	assert_eq(run.hearts, Run.STARTING_HEARTS)


func test_a_loss_costs_a_heart_and_the_last_one_ends_the_run() -> void:
	var run: Run = Run.debug(1)
	run.record_encounter(false)
	assert_eq(run.hearts, Run.STARTING_HEARTS - 1)
	assert_false(run.is_lost())
	run.record_encounter(false)
	run.record_encounter(false)
	assert_eq(run.hearts, 0)
	assert_true(run.is_lost())
	run.record_encounter(false)
	assert_eq(run.hearts, 0)


func test_the_heros_setup_is_exactly_the_active_deck_with_fresh_basic_lands() -> void:
	var run: Run = Run.debug(3)
	var active: Deck = run.deckbox.active()
	var setup: MmPlayerSetup = run.hero_setup()
	assert_eq(setup.deck.size(), active.size())
	var owned: Array[MmRunCard] = []
	for id: int in active.card_ids:
		owned.append(run.collection.card(id).run_card)
	var lands: Dictionary[String, int] = {}
	for run_card: MmRunCard in setup.deck:
		if owned.has(run_card):
			owned.erase(run_card)
		else:
			assert_true(run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC), run_card.base.name)
			lands[run_card.base.name] = lands.get(run_card.base.name, 0) + 1
	assert_true(owned.is_empty(), "every Run Card of the Deck is in the setup itself")
	assert_eq(lands, active.basic_lands)


func test_each_setup_gets_new_basic_lands() -> void:
	var run: Run = Run.debug(3)
	var first: MmPlayerSetup = run.hero_setup()
	var second: MmPlayerSetup = run.hero_setup()
	for run_card: MmRunCard in first.deck:
		if run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC):
			assert_false(second.deck.has(run_card))


func test_a_modded_card_keeps_its_mods_in_the_setup() -> void:
	var run: Run = Run.debug(3)
	var card: DeckbuilderCard = run.collection.card(run.deckbox.active().card_ids[0])
	var mod: Mod = Mod.new()
	mod.name = "Ember"
	var symbol: AddManaCostModification = AddManaCostModification.new()
	symbol.cost = MmManaCost.new()
	symbol.cost.symbols = [MmMana.Type.RED] as Array[MmMana.Type]
	mod.mod_cost = symbol
	card.attach(mod)
	assert_true(run.hero_setup().deck.has(card.run_card))
	assert_true(card.run_card.modifications.has(symbol))


## Walks the Stage to its Boss and beats it: the first choice at every Node, every
## encounter won. Says which Villains were met, in order.
func _walk(run: Run) -> Array[String]:
	var met: Array[String] = []
	while not run.is_stage_beaten():
		if run.stage_visit.must_play():
			met.append(run.stage_visit.meeting.name)
			run.record_encounter(true)
		else:
			assert_eq(run.move_to(run.stage_visit.choices()[0]), "")
	return met


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])


## Card name to how many of it in [param deck], its basic lands counted.
func _list_of(run: Run, deck: Deck) -> Dictionary:
	var list: Dictionary = deck.basic_lands.duplicate()
	for id: int in deck.card_ids:
		var name: String = run.collection.card(id).run_card.base.name
		list[name] = list.get(name, 0) + 1
	return list


func _list_of_setup(setup: MmPlayerSetup) -> Dictionary:
	var list: Dictionary = {}
	for run_card: MmRunCard in setup.deck:
		list[run_card.base.name] = list.get(run_card.base.name, 0) + 1
	return list


func _describe(map: StageMap) -> String:
	var lines: PackedStringArray = []
	for node: MapNode in map.nodes:
		lines.append("%d %d %d %s %d" % [node.row, node.column, node.kind, node.forward, node.side])
	return "\n".join(lines)
