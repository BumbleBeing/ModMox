extends GutTest
## Spoils paid by the run (milestone 18, ADR 0039): a win at an encounter pays its gold and
## its cards the moment it is recorded, and the run keeps what it paid for the Spoils
## screen to show; a loss pays nothing.


## T3: a win at a Lesser or Elite Encounter of a Tier 1 Stage pays 15 to 55 gold and 1 to 3
## cards into the Collection, and the run keeps them as its last Spoils.
func test_a_win_pays_gold_and_cards_into_the_run() -> void:
	var run: Run = Run.debug(5)
	_move_to_an_encounter(run)
	var gold_before: int = run.gold
	var owned_before: int = run.collection.cards().size()

	run.record_encounter(true)

	var paid: Spoils = run.last_spoils
	assert_not_null(paid)
	assert_between(paid.gold, 15, 55)
	assert_eq(run.gold, gold_before + paid.gold)
	assert_between(paid.cards.size(), 1, 3)
	var owned: Array[DeckbuilderCard] = run.collection.cards()
	assert_eq(owned.size(), owned_before + paid.cards.size())
	for index: int in paid.cards.size():
		assert_eq(owned[owned_before + index].run_card, paid.cards[index], "the Collection holds the card paid")


## T3: the cards paid come from the beaten Villain's own deck.
func test_the_cards_paid_come_from_the_villains_deck() -> void:
	var run: Run = Run.debug(5)
	_move_to_an_encounter(run)
	var in_deck: Dictionary[String, bool] = {}
	for run_card: MmRunCard in run.stage_visit.meeting.setup_for_tier(run.stage_visit.stage.tier).deck:
		in_deck[run_card.base.name] = true

	run.record_encounter(true)

	for card: MmRunCard in run.last_spoils.cards:
		assert_true(in_deck.has(card.base.name), card.base.name)


## T2: a loss pays nothing: the gold and the Collection are as they were, and there are no
## Spoils to show.
func test_a_loss_pays_nothing() -> void:
	var run: Run = Run.debug(5)
	_move_to_an_encounter(run)
	var owned_before: int = run.collection.cards().size()

	run.record_encounter(false)

	assert_eq(run.gold, 0)
	assert_eq(run.collection.cards().size(), owned_before)
	assert_null(run.last_spoils)


## T2: a win with no Villain being met (away from any encounter) pays nothing either.
func test_a_win_away_from_an_encounter_pays_nothing() -> void:
	var run: Run = Run.debug(5)
	run.record_encounter(true)
	assert_eq(run.gold, 0)
	assert_null(run.last_spoils)


## A beaten Boss pays 85 to 130 gold and 2 or 3 cards at Tier 1 (retuned in milestone 24).
func test_beating_the_boss_pays_a_bosss_spoils() -> void:
	var run: Run = Run.debug(5)
	while run.stage_visit.node().kind != StageMap.Kind.BOSS:
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])
	var gold_before: int = run.gold

	run.record_encounter(true)

	assert_true(run.is_stage_beaten())
	assert_between(run.last_spoils.gold, 85, 130)
	assert_between(run.last_spoils.cards.size(), 2, 3)
	assert_eq(run.gold, gold_before + run.last_spoils.gold)


## T1: the same Run Seed, walked the same way, pays the same Spoils at every win.
func test_the_same_run_seed_pays_the_same_spoils() -> void:
	assert_eq(_spoils_of_a_walk(Run.debug(11)), _spoils_of_a_walk(Run.debug(11)))
	assert_ne(_spoils_of_a_walk(Run.debug(11)), _spoils_of_a_walk(Run.debug(12)))


## Walks the Stage to its Boss and beats it, the first choice at every Node; says what each
## win paid, in order.
func _spoils_of_a_walk(run: Run) -> Array[String]:
	var paid: Array[String] = []
	while not run.is_stage_beaten():
		if run.stage_visit.must_play():
			run.record_encounter(true)
			var names: PackedStringArray = []
			for card: MmRunCard in run.last_spoils.cards:
				names.append(card.base.name)
			paid.append("%d: %s" % [run.last_spoils.gold, ", ".join(names)])
		else:
			run.move_to(run.stage_visit.choices()[0])
	return paid


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])
