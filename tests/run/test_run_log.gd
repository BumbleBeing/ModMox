extends GutTest
## Milestone 21: the Run Log (game glossary, ADR 0074) records every choice made in a run,
## each with the options it was chosen from, a line at a time, its first line naming its
## format and the build that wrote it.

const FOLDER: String = "user://test_run_log/"
const SAVE: String = FOLDER + "run.json"
const LOGS: String = FOLDER + "logs/"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"
const MOD_PATH: String = FOLDER + "ember.tres"
const ARMOR_PATH: String = FOLDER + "test_helm.tres"
const ArmorSample := preload("res://tests/support/armor_sample.gd")


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	RunFlow.clear()
	RunFlow.use_storage(SAVE, LOGS)


func after_each() -> void:
	RunFlow.clear()
	RunFlow.use_storage("", "")
	for folder: String in [LOGS, FOLDER]:
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


## S7: the log is a file of its own in the Run Logs folder, named for its time and Run Seed,
## and its first line names its format, the build and the Run Seed; the next says how the
## run began.
func test_the_first_lines_name_the_format_the_build_and_how_the_run_began() -> void:
	RunFlow.start(_run())

	var lines: Array[Dictionary] = _lines()

	assert_eq(DirAccess.get_files_at(LOGS).size(), 1)
	assert_string_ends_with(DirAccess.get_files_at(LOGS)[0], "-5.jsonl")
	assert_eq(lines[0]["kind"], "run_log")
	assert_eq(int(lines[0]["format"]), RunLog.FORMAT)
	assert_eq(lines[0]["build"], ProjectSettings.get_setting("application/config/version"))
	assert_eq(int(lines[0]["run_seed"]), 5)
	assert_eq(lines[1]["kind"], "run_started")
	assert_eq(lines[1]["how"], "debug")
	assert_eq(lines[1]["stage"], KITTY_KEEP)


## S7: each Node walked to is logged with the Nodes it was chosen from.
func test_each_node_chosen_is_logged_with_its_options() -> void:
	var run: Run = _on_the_map()
	var options: Array[int] = run.stage_visit.choices()

	run.move_to(options[1])

	var line: Dictionary = _last("node_chosen")
	assert_eq(int(line["node"]), options[1])
	assert_eq(_ints(line["options"]), options)


## S7: each Deck saved is logged with its place, name, cards and basic lands; so are a Deck
## duplicated, a Deck deleted, and the Active Deck chosen.
func test_deck_changes_are_logged() -> void:
	var run: Run = _on_the_map()
	var deck: Deck = run.deckbox.decks()[1]
	deck.name = "Bears"
	deck.card_ids.remove_at(0)

	run.deckbox.put(deck)
	var copy: Deck = run.deckbox.duplicate_deck(deck)
	run.deckbox.set_active(copy)
	run.deckbox.delete(run.deckbox.decks()[0])

	var saved: Dictionary = _last("deck_saved")
	assert_eq(int(saved["deck"]), 1)
	assert_eq(saved["name"], "Bears")
	assert_eq(_ints(saved["card_ids"]), deck.card_ids)
	assert_eq(int(saved["basic_lands"].get("Forest", 0)), deck.basic_lands.get("Forest", 0))
	assert_eq(int(_last("deck_duplicated")["deck"]), 1)
	assert_eq(int(_last("active_deck")["deck"]), 2)
	assert_eq(int(_last("deck_deleted")["deck"]), 0)


## S7: each Mod applied is logged with the card it went on.
func test_each_mod_applied_is_logged() -> void:
	var run: Run = _on_the_map()
	assert_eq(ResourceSaver.save(DeckbuilderSample.cycling_mod("Ember", MmMana.Type.RED), MOD_PATH), OK)
	var ember: Mod = load(MOD_PATH) as Mod
	run.held_mods.add(ember)
	var card: DeckbuilderCard = run.collection.cards()[3]

	run.held_mods.apply(ember, card, run.collection)

	var line: Dictionary = _last("mod_applied")
	assert_eq(line["mod"], MOD_PATH)
	assert_eq(int(line["card"]), card.id)
	assert_eq(line["base"], card.run_card.base.resource_path)


## A9 (milestone 23): each Armor put on is logged with its Armor Slot, and each taken off
## with its slot and what was Worn there.
func test_armor_put_on_and_taken_off_is_logged() -> void:
	var run: Run = _on_the_map()
	assert_eq(ResourceSaver.save(ArmorSample.armor("Test Helm", Armor.Slot.HELM, [ArmorSample.life(3)]), ARMOR_PATH), OK)
	var helm: Armor = load(ARMOR_PATH) as Armor
	run.held_armor.add(helm)

	run.held_armor.put_on(helm)
	run.held_armor.take_off(Armor.Slot.HELM)

	var put_on: Dictionary = _last("armor_put_on")
	assert_eq(put_on["armor"], ARMOR_PATH)
	assert_eq(put_on["slot"], "HELM")
	var taken_off: Dictionary = _last("armor_taken_off")
	assert_eq(taken_off["slot"], "HELM")
	assert_eq(taken_off["armor"], ARMOR_PATH)


## S7: an encounter's start is logged with its Villain, its Encounter Seed and the Deck the
## Hero plays; its answers, each with its words, and its end follow it.
func test_an_encounter_is_logged_from_its_start_to_its_end() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()
	var villain: String = run.stage_visit.meeting.resource_path
	RunFlow.begin_encounter()
	var encounter_seed: int = run.next_encounter_seed()

	RunFlow.finish_encounter(true, _record())

	var started: Dictionary = _last("encounter_started")
	assert_eq(started["villain"], villain)
	assert_eq(int(started["encounter_seed"]), encounter_seed)
	assert_eq(_ints(started["card_ids"]), run.deckbox.active().card_ids)
	assert_eq(int(started["deck"]), run.deckbox.decks().find(run.deckbox.active()))
	var answers: Array[Dictionary] = _all("answer")
	assert_eq(answers.size(), 2)
	assert_eq(answers[0]["by"], "hero")
	assert_eq(answers[0]["chosen"], "Play Forest")
	assert_eq(int(answers[1]["answer"]), 0)
	var ended: Dictionary = _last("encounter_ended")
	assert_eq(ended["won"], true)
	assert_eq(ended["winner"], "hero")
	assert_eq(int(ended["turns"]), 7)
	assert_eq(int(ended["hero_life"]), 12)
	assert_eq(int(ended["villain_life"]), 0)
	assert_eq(_ints(ended["potions_used"]), [1] as Array[int], "P2 (milestone 24): the Potions used, by place.")
	assert_eq(_kinds().slice(-4), ["encounter_started", "answer", "answer", "encounter_ended"])


## S7: an encounter quit logs its answers so far, that it was quit, and where; Continue logs
## where the run was taken up, in the same file.
func test_a_quit_and_a_continue_are_logged() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()
	RunFlow.begin_encounter()
	run.next_encounter_seed()

	RunFlow.quit(_record())
	RunFlow.continue_run(SavedRun.read(SAVE))

	assert_eq(DirAccess.get_files_at(LOGS).size(), 1, "Continue writes on in the same log.")
	assert_eq(_kinds().slice(-6), ["encounter_started", "answer", "answer", "encounter_quit", "quit", "continued"])
	assert_eq(_last("quit")["screen"], "ENCOUNTER")
	assert_eq(_last("continued")["screen"], "DECKBOX")


## S7: the run's end is logged: won, lost or abandoned.
func test_the_runs_end_is_logged() -> void:
	var run: Run = _on_the_map()
	run.hearts = 1
	_move_to_an_encounter(run)
	RunFlow.arrive()
	RunFlow.begin_encounter()

	RunFlow.finish_encounter(false)

	assert_eq(_last("run_ended")["how"], "lost")
	RunFlow.clear()
	RunFlow.start(Run.debug(6, load(KITTY_KEEP) as StageDefinition))
	RunFlow.abandon()
	assert_eq(_last("run_ended")["how"], "abandoned")


## The record an encounter screen hands RunFlow: two answers and how it ended.
func _record() -> Dictionary:
	return {
		"answers": [
			{"by": "hero", "decision": "priority for player 1", "answer": 1, "options": 3, "chosen": "Play Forest"},
			{"by": "villain", "decision": "priority for player 2", "answer": 0, "options": 1, "chosen": "Pass"},
		],
		"winner": "hero", "turns": 7, "hero_life": 12, "villain_life": 0, "potions_used": [1],
	}


func _run() -> Run:
	return Run.debug(5, load(KITTY_KEEP) as StageDefinition)


func _on_the_map() -> Run:
	var run: Run = _run()
	RunFlow.start(run)
	RunFlow.finish_intro()
	return run


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])


## The lines of the newest log in the Run Logs folder.
func _lines() -> Array[Dictionary]:
	var files: PackedStringArray = DirAccess.get_files_at(LOGS)
	files.sort()
	return RunLog.read(LOGS + files[files.size() - 1])


func _kinds() -> Array[String]:
	var found: Array[String] = []
	for line: Dictionary in _lines():
		found.append(str(line["kind"]))
	return found


func _all(kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line: Dictionary in _lines():
		if line["kind"] == kind:
			found.append(line)
	return found


func _last(kind: String) -> Dictionary:
	var found: Array[Dictionary] = _all(kind)
	assert_false(found.is_empty(), "A %s line." % kind)
	return found[found.size() - 1] if not found.is_empty() else {}


func _ints(values: Array) -> Array[int]:
	var found: Array[int] = []
	for value: Variant in values:
		found.append(int(value))
	return found
