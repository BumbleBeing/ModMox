extends GutTest
## Milestone 21: a run is saved as a snapshot (ADR 0074). It loads as the same run, every
## part of it, and each of its random streams goes on as if it had never been saved. It
## names Content by path, and carries its format and the build that wrote it.

const FOLDER: String = "user://test_saved_run/"
const PATH: String = FOLDER + "run.json"
const MOD_PATH: String = FOLDER + "ember.tres"
const HEX_PATH: String = FOLDER + "burden.tres"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"
const HELM_PATH: String = FOLDER + "test_helm.tres"
const CUIRASS_PATH: String = FOLDER + "test_cuirass.tres"
const ArmorSample := preload("res://tests/support/armor_sample.gd")


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)


func after_each() -> void:
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER + file)
	DirAccess.remove_absolute(FOLDER)


## S1: a saved run loads with everything it held: the Run Seed, the Collection with each
## card's identity and Mods, the Deckbox in its order with its Active Deck, the Mods held,
## Hearts, gold, Emblems, the Stage being walked and the Stages beaten.
func test_a_saved_run_loads_as_the_same_run() -> void:
	var run: Run = _walked_run()

	var loaded: Run = _round_trip(run).run

	assert_eq(loaded.run_seed, run.run_seed)
	assert_eq(loaded.hearts, run.hearts)
	assert_eq(loaded.gold, run.gold)
	assert_eq(_paths(loaded.hero_emblems), _paths(run.hero_emblems))
	assert_eq(_cards_of(loaded.collection), _cards_of(run.collection))
	assert_eq(loaded.collection.next_id(), run.collection.next_id())
	assert_eq(_decks_of(loaded), _decks_of(run))
	assert_eq(loaded.deckbox.decks().find(loaded.deckbox.active()), run.deckbox.decks().find(run.deckbox.active()))
	assert_eq(_held_of(loaded.held_mods), _held_of(run.held_mods))
	assert_eq(_visit_of(loaded.stage_visit), _visit_of(run.stage_visit))
	assert_eq(loaded.stages_beaten().size(), 1)
	assert_eq(_visit_of(loaded.stages_beaten()[0]), _visit_of(run.stages_beaten()[0]))
	assert_eq(SavedRun.data_of(loaded, RunFlow.Screen.STAGE_MAP, RunFlow.Screen.STAGE_MAP),
		SavedRun.data_of(run, RunFlow.Screen.STAGE_MAP, RunFlow.Screen.STAGE_MAP))


## A9 (milestone 23): the Armor held, each as often as held, and what is Worn in each Armor
## Slot load as they were, by path.
func test_the_armor_held_and_worn_loads_as_it_was() -> void:
	var run: Run = _walked_run()
	var helm: Armor = _saved_armor(ArmorSample.armor("Test Helm", Armor.Slot.HELM, [ArmorSample.life(3)]), HELM_PATH)
	var cuirass: Armor = _saved_armor(
		ArmorSample.armor("Test Cuirass", Armor.Slot.CUIRASS, [ArmorSample.emblem(ArmorSample.DIVINERS_BOON)]), CUIRASS_PATH)
	run.held_armor.add(helm)
	run.held_armor.add(cuirass)
	run.held_armor.add(helm)
	run.held_armor.put_on(cuirass)

	var loaded: Run = _round_trip(run).run

	var test_armor: Array[String] = []
	for armor: Armor in loaded.held_armor.kinds():
		if armor.resource_path.begins_with(FOLDER):
			test_armor.append(armor.resource_path)
	assert_eq(test_armor, [HELM_PATH, CUIRASS_PATH] as Array[String])
	assert_eq(loaded.held_armor.count_of(load(HELM_PATH) as Armor), 2)
	assert_eq(loaded.held_armor.worn_in(Armor.Slot.CUIRASS).resource_path, CUIRASS_PATH)
	assert_null(loaded.held_armor.worn_in(Armor.Slot.HELM))
	assert_eq(loaded.hero_setup().emblems.back().name, "Diviner's Boon", "The Worn Armor still brings its Emblem.")


## P3 (milestone 24): the Potions held, each as often as held and in the order held, load as
## they were, by path.
func test_the_potions_held_load_as_they_were() -> void:
	var run: Run = _walked_run()
	run.held_potions.use_up([0])
	run.held_potions.add(load("res://content/potions/big_gulp.tres") as MmCardDefinition)

	var loaded: Run = _round_trip(run).run

	assert_eq(_paths(loaded.held_potions.all()), _paths(run.held_potions.all()))
	assert_eq(loaded.held_potions.all().size(), 2)
	assert_eq(loaded.hero_setup().potions.size(), 2, "They are still the Hero's in an encounter.")


## S1: a card's Mods are the same Mods, in the same order, and do to the card what they did.
func test_a_loaded_cards_mods_do_what_they_did() -> void:
	var run: Run = _walked_run()
	var modded: DeckbuilderCard = _first_with_mods(run.collection)

	var loaded: DeckbuilderCard = _round_trip(run).run.collection.card(modded.id)

	assert_eq(loaded.card_name(), modded.card_name())
	assert_eq(_paths(loaded.mods), _paths(modded.mods))
	assert_eq(loaded.run_card.flatten().mana_cost.symbols, modded.run_card.flatten().mana_cost.symbols)


## S1: each random stream goes on as if the run had never been saved: the next Encounter
## Seed, the next Villain met, the next Spoils and the next Stage all come out the same.
func test_each_random_stream_goes_on_as_if_never_saved() -> void:
	var run: Run = _walked_run()
	var loaded: Run = _round_trip(run).run

	assert_eq(loaded.next_encounter_seed(), run.next_encounter_seed())
	for walked: Run in [run, loaded]:
		_move_to_an_encounter(walked)
		walked.record_encounter(true)
	assert_eq(loaded.stage_visit.current, run.stage_visit.current)
	assert_eq(_villain_paths(loaded), _villain_paths(run))
	assert_eq(loaded.last_spoils.gold, run.last_spoils.gold)
	assert_eq(_bases_of(loaded.last_spoils.cards), _bases_of(run.last_spoils.cards))
	for walked: Run in [run, loaded]:
		walked.stage_visit.is_won = true
		walked.enter_next_stage()
	assert_eq(loaded.stage_visit.stage.resource_path, run.stage_visit.stage.resource_path)
	assert_eq(_visit_of(loaded.stage_visit), _visit_of(run.stage_visit))


## S1: the Spoils a win paid load as the same cards of the Collection, for the Spoils screen.
func test_the_last_spoils_load_as_cards_of_the_collection() -> void:
	var run: Run = _walked_run()
	_move_to_an_encounter(run)
	run.record_encounter(true)

	var loaded: Run = _round_trip(run).run

	assert_eq(loaded.last_spoils.gold, run.last_spoils.gold)
	assert_eq(_bases_of(loaded.last_spoils.cards), _bases_of(run.last_spoils.cards))
	for card: MmRunCard in loaded.last_spoils.cards:
		assert_true(loaded.collection.cards().any(
			func(owned: DeckbuilderCard) -> bool: return owned.run_card == card), "A card paid is the Collection's.")


## S1: the snapshot keeps the Screen it was saved on, and where the Deckbox's Close leads.
func test_a_snapshot_keeps_its_screens() -> void:
	var saved: SavedRun = _round_trip(_walked_run(), RunFlow.Screen.DECKBOX, RunFlow.Screen.STAGE_INTRO)

	assert_eq(saved.screen, RunFlow.Screen.DECKBOX)
	assert_eq(saved.back_from_deckbox, RunFlow.Screen.STAGE_INTRO)


## S4: a change to Content applies to a loaded run: cards, Mods, Emblems, Stages and
## Villains are saved by their path and loaded from it.
func test_content_is_saved_by_path_and_loaded_from_it() -> void:
	var run: Run = _walked_run()
	var data: Dictionary = SavedRun.data_of(run, RunFlow.Screen.STAGE_MAP, RunFlow.Screen.STAGE_MAP)

	var loaded: Run = _round_trip(run).run

	var text: String = JSON.stringify(data)
	assert_string_contains(text, "\"res://content/cards/")
	assert_string_contains(text, "\"%s\"" % KITTY_KEEP)
	assert_string_contains(text, "\"res://content/villains/")
	assert_string_contains(text, "\"%s\"" % MOD_PATH)
	var first: DeckbuilderCard = loaded.collection.cards()[0]
	assert_same(first.run_card.base, load(first.run_card.base.resource_path), "The card is Content's own.")
	assert_same(loaded.stages_beaten()[0].stage, load(KITTY_KEEP))
	assert_same(loaded.stage_visit.stage, load(run.stage_visit.stage.resource_path))


## S4: a snapshot names its format and the build that wrote it, and one of another format
## is not current.
func test_a_snapshot_names_its_format_and_build() -> void:
	var data: Dictionary = SavedRun.data_of(_walked_run(), RunFlow.Screen.STAGE_MAP, RunFlow.Screen.STAGE_MAP)
	SavedRun.write(data, PATH)

	var read: Dictionary = SavedRun.read(PATH)

	assert_true(SavedRun.is_current(read))
	assert_eq(SavedRun.build_of(read), ProjectSettings.get_setting("application/config/version"))
	read["format"] = SavedRun.FORMAT + 1
	assert_false(SavedRun.is_current(read))
	read["format"] = SavedRun.FORMAT - 1
	assert_false(SavedRun.is_current(read))


## S4: a file that is missing, or is not a snapshot, reads as nothing.
func test_a_missing_or_broken_file_reads_as_nothing() -> void:
	var broken: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("{ not a snapshot")
	broken.close()

	assert_eq(SavedRun.read(FOLDER + "missing.json"), {})
	assert_eq(SavedRun.read(PATH), {})
	assert_false(SavedRun.is_current({}))


func test_writing_and_deleting_a_snapshot() -> void:
	var data: Dictionary = SavedRun.data_of(_walked_run(), RunFlow.Screen.STAGE_MAP, RunFlow.Screen.STAGE_MAP)

	assert_true(SavedRun.write(data, PATH))
	assert_true(SavedRun.exists(PATH))
	SavedRun.delete(PATH)
	assert_false(SavedRun.exists(PATH))


## A run that has beaten Tier 1 and walked into Tier 2, with Mods held and applied, a Hex,
## a Deck duplicated and made Active, gold, a Heart lost and a win's Spoils.
func _walked_run() -> Run:
	var run: Run = Run.debug(7, load(KITTY_KEEP) as StageDefinition)
	_move_to_an_encounter(run)
	run.record_encounter(true)
	run.stage_visit.is_won = true
	run.enter_next_stage()
	_move_to_an_encounter(run)
	run.record_encounter(false)
	run.move_to(run.stage_visit.choices()[0])
	run.gold += 7
	var ember: Mod = _saved_mod(DeckbuilderSample.cycling_mod("Ember", MmMana.Type.RED), MOD_PATH)
	var burden: Mod = _saved_mod(DeckbuilderSample.burden(), HEX_PATH)
	run.held_mods.add(ember)
	run.held_mods.add(ember)
	run.held_mods.add(ember)
	var bolt: DeckbuilderCard = _first_named(run.collection, "Lightning Bolt")
	run.held_mods.apply(ember, bolt, run.collection)
	var bear: MmRunCard = MmRunCard.new()
	bear.base = _first_named(run.collection, "Grizzly Bears").run_card.base
	run.collection.add(bear, [burden] as Array[Mod])
	var copy: Deck = run.deckbox.duplicate_deck(run.deckbox.decks()[1])
	copy.card_ids.remove_at(0)
	copy.basic_lands["Forest"] = copy.basic_lands.get("Forest", 0) + 2
	run.deckbox.set_active(copy)
	return run


func _saved_armor(armor: Armor, path: String) -> Armor:
	assert_eq(ResourceSaver.save(armor, path), OK)
	return load(path) as Armor


func _round_trip(run: Run, screen: RunFlow.Screen = RunFlow.Screen.STAGE_MAP,
		back: RunFlow.Screen = RunFlow.Screen.STAGE_MAP) -> SavedRun:
	assert_true(SavedRun.write(SavedRun.data_of(run, screen, back), PATH))
	var read: Dictionary = SavedRun.read(PATH)
	assert_true(SavedRun.is_current(read))
	return SavedRun.from_data(read)


func _saved_mod(mod: Mod, path: String) -> Mod:
	assert_eq(ResourceSaver.save(mod, path), OK)
	return load(path) as Mod


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])


func _first_named(collection: Collection, card_name: String) -> DeckbuilderCard:
	for card: DeckbuilderCard in collection.cards():
		if card.run_card.base.name == card_name:
			return card
	return null


func _first_with_mods(collection: Collection) -> DeckbuilderCard:
	for card: DeckbuilderCard in collection.cards():
		if card.is_modified():
			return card
	return null


func _paths(resources: Array) -> Array[String]:
	var found: Array[String] = []
	for resource: Resource in resources:
		found.append(resource.resource_path)
	return found


func _bases_of(cards: Array[MmRunCard]) -> Array[String]:
	var found: Array[String] = []
	for card: MmRunCard in cards:
		found.append(card.base.resource_path)
	return found


func _cards_of(collection: Collection) -> Array[String]:
	var found: Array[String] = []
	for card: DeckbuilderCard in collection.cards():
		found.append("%d %s %s %d" % [card.id, card.run_card.base.resource_path, _paths(card.mods), card.run_card.modifications.size()])
	return found


func _decks_of(run: Run) -> Array[String]:
	var found: Array[String] = []
	for deck: Deck in run.deckbox.decks():
		found.append("%s %s %s" % [deck.name, deck.card_ids, deck.basic_lands])
	return found


func _held_of(held: HeldMods) -> Array[String]:
	var found: Array[String] = []
	for mod: Mod in held.kinds():
		found.append("%s x%d" % [mod.resource_path, held.count_of(mod)])
	return found


func _villain_paths(run: Run) -> Array[String]:
	var visit: StageVisit = run.stage_visit
	return [visit.boss.resource_path, visit.meeting.resource_path if visit.meeting != null else ""]


## Everything a Stage being walked holds, as words.
func _visit_of(visit: StageVisit) -> Array[String]:
	var found: Array[String] = [
		visit.stage.resource_path, visit.boss.resource_path, str(visit.current), str(visit.is_won),
		visit.meeting.resource_path if visit.meeting != null else "", str(visit.scenery_seed),
		str(visit.map.attempts),
	]
	for node: MapNode in visit.map.nodes:
		found.append("%d %d %d %d %s %d %s %s %s" % [node.id, node.row, node.column, node.kind, node.forward, node.side,
			visit.offsets[node.id], visit.is_visited(node.id), _walked_from(visit, node)])
	return found


func _walked_from(visit: StageVisit, node: MapNode) -> Array[int]:
	var found: Array[int] = []
	for other: MapNode in visit.map.nodes:
		if visit.is_walked(node.id, other.id):
			found.append(other.id)
	return found
