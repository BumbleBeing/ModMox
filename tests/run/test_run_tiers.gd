extends GutTest
## A whole run (milestone 19): five Stages, Tiers 1 to 5 in order, each rolled on entering
## it among the colors not yet played; Hearts, gold, the Collection, the Deckbox and the Mods
## held carry from Stage to Stage; the fifth Boss wins the run, and the last Heart, at any
## Tier, loses it.

const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"


## T1: the same Run Seed and choices give the same five Stages in order.
func test_the_same_run_seed_and_choices_give_the_same_five_stages() -> void:
	var first: Run = _won_run(11)
	var again: Run = _won_run(11)

	assert_eq(_stage_names(again), _stage_names(first))
	assert_eq(_boss_names(again), _boss_names(first))


func test_other_run_seeds_roll_the_stages_in_other_orders() -> void:
	var orders: Dictionary[String, bool] = {}
	for run_seed: int in range(1, 9):
		orders[", ".join(_stage_names(_won_run(run_seed)))] = true

	assert_gt(orders.size(), 1, "Eight Run Seeds give more than one order of colors.")


## T2: a run's five Stages are at Tiers 1 to 5 in order, and of five different colors.
func test_a_runs_five_stages_are_tiers_one_to_five_of_five_colors() -> void:
	for run_seed: int in range(1, 6):
		var run: Run = _won_run(run_seed)
		var colors: Dictionary[MmCardTypes.CardColor, bool] = {}
		var played: Array[StageVisit] = run.stages_played()

		assert_eq(played.size(), Villain.TIERS)
		for index: int in played.size():
			assert_eq(played[index].stage.tier, index + 1)
			colors[played[index].stage.color] = true
		assert_eq(colors.size(), Villain.TIERS, "Run Seed %d plays every color once." % run_seed)


func test_a_debug_run_begun_in_kitty_keep_rolls_the_other_four_colors() -> void:
	var run: Run = Run.debug(3, load(KITTY_KEEP) as StageDefinition)
	_beat_the_stage(run)
	run.enter_next_stage()

	assert_eq(run.stages_played()[0].stage.resource_path, KITTY_KEEP)
	assert_eq(run.stage_visit.stage.tier, 2)
	assert_ne(run.stage_visit.stage.color, MmCardTypes.CardColor.WHITE)


## T3: beating a Boss at Tiers 1 to 4 pays its Spoils and enters the next Tier's Stage on
## its Start Node.
func test_beating_a_boss_before_tier_five_enters_the_next_tiers_stage() -> void:
	var run: Run = Run.debug(5)
	for tier: int in range(1, Villain.TIERS):
		_beat_the_stage(run)
		assert_not_null(run.last_spoils, "The Tier %d Boss pays its Spoils." % tier)
		assert_true(run.is_stage_beaten())

		run.enter_next_stage()

		assert_eq(run.stage_visit.stage.tier, tier + 1)
		assert_eq(run.stage_visit.current, run.stage_visit.map.start().id)
		assert_eq(run.stage_visit.node().kind, StageMap.Kind.START)
		assert_false(run.is_stage_beaten())


## T4: beating the fifth Boss wins the run, and no earlier Boss does.
func test_only_the_fifth_boss_wins_the_run() -> void:
	var run: Run = Run.debug(5)
	for tier: int in range(1, Villain.TIERS):
		_beat_the_stage(run)
		assert_false(run.is_won(), "Beating the Tier %d Boss does not win the run." % tier)
		run.enter_next_stage()

	_beat_the_stage(run)

	assert_true(run.is_won())


## T5: Hearts, gold, the Collection, the Deckbox and the Mods held carry across Stages
## unchanged, and Hearts never refill.
func test_what_the_hero_holds_carries_into_the_next_stage() -> void:
	var run: Run = Run.debug(5)
	run.record_encounter(false)
	_beat_the_stage(run)
	var hearts: int = run.hearts
	var gold: int = run.gold
	var collection: Collection = run.collection
	var owned: int = run.collection.cards().size()
	var deckbox: Deckbox = run.deckbox
	var active: Deck = run.deckbox.active()
	var held_mods: HeldMods = run.held_mods

	run.enter_next_stage()

	assert_eq(run.hearts, hearts)
	assert_eq(run.hearts, Run.STARTING_HEARTS - 1, "A Heart lost in Tier 1 stays lost.")
	assert_eq(run.gold, gold)
	assert_eq(run.collection, collection)
	assert_eq(run.collection.cards().size(), owned)
	assert_eq(run.deckbox, deckbox)
	assert_eq(run.deckbox.active(), active)
	assert_eq(run.held_mods, held_mods)


## T6: losing the last Heart at any Tier loses the run, and the run knows who took it and
## where.
func test_losing_the_last_heart_at_any_tier_loses_the_run() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		var run: Run = Run.debug(5, null, tier)
		run.hearts = 1
		_move_to_an_encounter(run)
		var villain: Villain = run.stage_visit.meeting

		run.record_encounter(false)

		assert_true(run.is_lost(), "Tier %d" % tier)
		assert_false(run.is_won())
		assert_eq(run.fell_to, villain)
		assert_eq(run.stage_visit.stage.tier, tier)
		assert_eq(run.stages_beaten().size(), tier - 1)


func test_a_heart_lost_before_the_last_names_no_one() -> void:
	var run: Run = Run.debug(5)
	_move_to_an_encounter(run)

	run.record_encounter(false)

	assert_false(run.is_lost())
	assert_null(run.fell_to)


## T7: a Spoils at a Tier N Stage is rolled for Tier N.
func test_spoils_at_a_tier_n_stage_are_rolled_for_tier_n() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		var run: Run = Run.debug(8, null, tier)
		_move_to_an_encounter(run)
		var rank: StageMap.Kind = run.stage_visit.node().kind
		var scale: float = 1.0 + SpoilsRoll.GOLD_PER_TIER * (tier - 1)

		run.record_encounter(true)

		assert_between(run.last_spoils.gold, roundi(SpoilsRoll.GOLD[rank].x * scale),
				roundi(SpoilsRoll.GOLD[rank].y * scale), "Tier %d" % tier)


## T8: Content holds a valid Stage of every color at every Tier.
func test_content_holds_a_valid_stage_of_every_color_at_every_tier() -> void:
	var found: Dictionary[String, String] = {}
	for stage: StageDefinition in ContentStages.all():
		assert_eq(stage.validate(), "", stage.name)
		found["%d/%s" % [stage.tier, stage.backdrop()]] = stage.name

	for tier: int in range(1, Villain.TIERS + 1):
		for color: String in StageDefinition.BACKDROPS.values():
			assert_true(found.has("%d/%s" % [tier, color]), "A %s Stage at Tier %d." % [color, tier])


func test_the_placeholder_stages_are_named_by_their_color_alone() -> void:
	for stage: StageDefinition in ContentStages.all():
		if stage.resource_path.get_file().begins_with("placeholder_"):
			assert_eq(stage.name, "Placeholder %s" % stage.backdrop().capitalize())


## A debug run asked for at a later Tier walks there, its earlier Stages counted as won.
func test_a_debug_run_at_a_later_tier_counts_its_earlier_stages_as_won() -> void:
	var run: Run = Run.debug(6, null, 4)

	assert_eq(run.stage_visit.stage.tier, 4)
	assert_eq(run.stages_beaten().size(), 3)
	for visit: StageVisit in run.stages_beaten():
		assert_true(visit.is_won)
	assert_eq(run.stage_visit.node().kind, StageMap.Kind.START)
	assert_eq(run.hearts, Run.STARTING_HEARTS)


## A run that has beaten all five Bosses, every encounter on the way won.
func _won_run(run_seed: int) -> Run:
	var run: Run = Run.debug(run_seed)
	_beat_the_stage(run)
	while not run.is_won():
		run.enter_next_stage()
		_beat_the_stage(run)
	return run


## Walks the Stage being walked to its Boss and beats it, winning every encounter on the way.
func _beat_the_stage(run: Run) -> void:
	while not run.is_stage_beaten():
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])


func _stage_names(run: Run) -> Array[String]:
	var names: Array[String] = []
	for visit: StageVisit in run.stages_played():
		names.append(visit.stage.name + " " + str(visit.stage.tier))
	return names


func _boss_names(run: Run) -> Array[String]:
	var names: Array[String] = []
	for visit: StageVisit in run.stages_played():
		names.append(visit.boss.name)
	return names
