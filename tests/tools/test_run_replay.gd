extends GutTest
## Milestone 21: a Run Log replays its run exactly (ADR 0074), the Villain's answers fed back
## so the AI never runs, and a log that has been tampered with is caught at the first line
## that does not hold.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const FOLDER: String = "user://test_run_replay/"
const SAVE: String = FOLDER + "run.json"
const LOGS: String = FOLDER + "logs/"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	RunFlow.clear()
	RunFlow.use_storage(SAVE, LOGS)


func after_each() -> void:
	RunFlow.clear()
	RunFlow.use_storage("", "")
	RunFlow.remembers_saves = false
	for folder: String in [LOGS, FOLDER]:
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


## S8: a short run (Nodes walked, a Deck saved and made Active, Armor put on, taken off and put
## on again (A9, milestone 23), an encounter won, one quit and continued, then lost) replays
## from its Run Log to the same run.
func test_a_run_log_replays_to_the_same_run() -> void:
	var played: Run = _play_a_short_run()

	var replay: RunReplay = RunReplay.replay(_log())

	assert_false(played.held_armor.worn().is_empty(), "The run ended with Armor Worn.")
	assert_eq(replay.reason, "", "The replay holds at every line.")
	assert_eq(replay.line, -1)
	assert_eq(_state_of(replay.run), _state_of(played))


## S8: a log whose Encounter Seed was changed is caught at that line.
func test_a_changed_encounter_seed_is_caught_at_its_line() -> void:
	_play_a_short_run()
	var lines: Array[Dictionary] = _log()
	var index: int = _first(lines, "encounter_started")
	lines[index]["encounter_seed"] = int(lines[index]["encounter_seed"]) + 1

	var replay: RunReplay = RunReplay.replay(lines)

	assert_eq(replay.line, index)
	assert_string_contains(replay.reason, "Encounter Seed")


## S8: a log whose Node's options were changed is caught at that line.
func test_changed_options_are_caught_at_their_line() -> void:
	_play_a_short_run()
	var lines: Array[Dictionary] = _log()
	var index: int = _first(lines, "node_chosen")
	lines[index]["options"] = [99]

	var replay: RunReplay = RunReplay.replay(lines)

	assert_eq(replay.line, index)


## S8: a log whose encounter ended otherwise than its answers say is caught at its end.
func test_a_changed_ending_is_caught_at_its_line() -> void:
	_play_a_short_run()
	var lines: Array[Dictionary] = _log()
	var index: int = _first(lines, "encounter_ended")
	lines[index]["turns"] = int(lines[index]["turns"]) + 5

	var replay: RunReplay = RunReplay.replay(lines)

	assert_eq(replay.line, index)


## P2 (milestone 24): a log whose encounter used other Potions than its answers say is caught
## at its end, since the Potions held would then differ.
func test_changed_potions_used_are_caught_at_their_line() -> void:
	_play_a_short_run()
	var lines: Array[Dictionary] = _log()
	var index: int = _first(lines, "encounter_ended")
	lines[index]["potions_used"] = [0]

	var replay: RunReplay = RunReplay.replay(lines)

	assert_eq(replay.line, index)
	assert_string_contains(replay.reason, "potions_used")


## SR8 (milestone 24): a run that sells cards and buys at a Store, opens the Deckbox there,
## quits and continues at the Store, and then plays on, replays to the same run.
func test_buying_and_selling_at_a_store_replays() -> void:
	var played: Run = _shop_and_play_on()

	var replay: RunReplay = RunReplay.replay(_log())

	assert_eq(replay.reason, "", "The replay holds at every line.")
	assert_eq(replay.line, -1)
	assert_eq(_state_of(replay.run), _state_of(played))


## SR8: a purchase logged at another price than the good's is caught at its line.
func test_a_changed_price_is_caught_at_its_line() -> void:
	_shop_and_play_on()
	var lines: Array[Dictionary] = _log()
	var index: int = _first(lines, "store_bought")
	lines[index]["price"] = int(lines[index]["price"]) + 5

	var replay: RunReplay = RunReplay.replay(lines)

	assert_eq(replay.line, index)
	assert_string_contains(replay.reason, "price")


## SR8: a sale of a card the Collection does not hold is caught at its line.
func test_a_sale_of_a_card_not_held_is_caught_at_its_line() -> void:
	_shop_and_play_on()
	var lines: Array[Dictionary] = _log()
	var index: int = _first(lines, "card_sold")
	lines[index]["card"] = 99999

	var replay: RunReplay = RunReplay.replay(lines)

	assert_eq(replay.line, index)


## A run walked onto its first Store, where the Hero sells six Rare cards and buys the
## cheapest good, opens and closes the Deckbox, quits and continues, sells one more card and
## buys again if it can; then on to the first encounter, won.
func _shop_and_play_on() -> Run:
	var run: Run = Run.debug(21, load(KITTY_KEEP) as StageDefinition)
	RunFlow.start(run)
	RunFlow.close_deckbox()
	RunFlow.finish_intro()
	for id: int in run.stage_visit.choices():
		if run.stage_visit.map.nodes[id].kind == StageMap.Kind.STORE:
			run.move_to(id)
	assert_eq(RunFlow.arrive(), RunFlow.Screen.STORE)
	for count: int in 6:
		assert_eq(run.sell(_a_rare(run)), "")
	assert_eq(run.buy(_cheapest(run)), "")
	RunFlow.open_deckbox(RunFlow.Screen.STORE)
	RunFlow.close_deckbox()
	RunFlow.quit()
	assert_eq(RunFlow.continue_run(SavedRun.read(SAVE)), RunFlow.Screen.STORE)
	run = RunFlow.run
	assert_eq(run.sell(_a_rare(run)), "")
	if _cheapest(run) != null and _cheapest(run).price() <= run.gold:
		run.buy(_cheapest(run))
	RunFlow.leave_store()
	_walk_to_an_encounter(run)
	_play(run, true)
	return RunFlow.run


## The first Rare card in [param run]'s Collection.
func _a_rare(run: Run) -> DeckbuilderCard:
	for card: DeckbuilderCard in run.collection.cards():
		if card.run_card.base.rarity == MmCardDefinition.Rarity.RARE:
			return card
	return null


## The cheapest good the Store has not sold.
func _cheapest(run: Run) -> StoreGood:
	var found: StoreGood = null
	for good: StoreGood in run.store_stock().goods():
		if not good.is_sold and (found == null or good.price() < found.price()):
			found = good
	return found


## A run walked to its first encounter, which the Hero wins when the Villain concedes on Game
## Turn 3, with a Deck saved and made Active and the first Armor held put on on the way; then
## on to the next with the Armor taken off and put on again, quit partway and continued, and
## lost when the Hero concedes.
func _play_a_short_run() -> Run:
	var run: Run = Run.debug(21, load(KITTY_KEEP) as StageDefinition)
	RunFlow.start(run)
	RunFlow.close_deckbox()
	RunFlow.finish_intro()
	var deck: Deck = run.deckbox.decks()[0]
	deck.basic_lands["Forest"] = deck.basic_lands.get("Forest", 0) + 1
	run.deckbox.put(deck)
	run.deckbox.set_active(deck)
	assert_false(run.held_armor.kinds().is_empty(), "A debug run holds the Armor in Content.")
	var armor: Armor = run.held_armor.kinds()[0]
	run.held_armor.put_on(armor)
	_walk_to_an_encounter(run)
	_play(run, true)
	RunFlow.finish_spoils()
	run.held_armor.take_off(armor.slot)
	run.held_armor.put_on(armor)
	_walk_to_an_encounter(run)
	RunFlow.begin_encounter()
	var request: EncounterRequest = EncounterRequest.for_run(run)
	var engine: MmEngine = MmEngine.start(request.setup())
	Scenario.play_until_game_turn(engine, 2, true)
	RunFlow.quit(EncounterPresenter.record_of(request.setup(), engine.decision_log()))
	RunFlow.continue_run(SavedRun.read(SAVE))
	_play(RunFlow.run, false)
	return RunFlow.run


## Plays the encounter the run's Hero is meeting to Game Turn 3, when [param won] has the
## Villain concede, and otherwise the Hero.
func _play(run: Run, won: bool) -> void:
	RunFlow.begin_encounter()
	var request: EncounterRequest = EncounterRequest.for_run(run)
	var setup: MmEncounterSetup = request.setup()
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_game_turn(engine, 3, true)
	engine.concede(engine.villain() if won else engine.hero())
	RunFlow.finish_encounter(won, EncounterPresenter.record_of(setup, engine.decision_log()))


func _walk_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])
		RunFlow.arrive()


func _log() -> Array[Dictionary]:
	var files: PackedStringArray = DirAccess.get_files_at(LOGS)
	assert_eq(files.size(), 1)
	return RunLog.read(LOGS + files[0])


func _first(lines: Array[Dictionary], kind: String) -> int:
	for index: int in lines.size():
		if lines[index]["kind"] == kind:
			return index
	return -1


## Everything [param run] holds but where its log is written.
func _state_of(run: Run) -> Dictionary:
	var data: Dictionary = run.to_data()
	data.erase("run_log")
	return data
