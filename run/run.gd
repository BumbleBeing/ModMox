class_name Run
extends RefCounted
## One run's state: its Run Seed, the Collection, the Deckbox and its Active Deck, the Mods
## held, Hearts and gold (milestone 16), and the Stage being walked (milestone 17). It
## knows nothing of screens; they change it only through its own methods. Gold is held but
## not yet spent.

const STARTING_HEARTS: int = 3
const DEBUG_DECK: String = "red_green"
const DEBUG_DECK_NAME: String = "Red-Green"
const BASIC_LANDS: String = "res://content/cards/alpha/%s.tres"
const BASIC_LAND_FILES: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]
## The Emblem the Hero holds in every debug run, to end encounters quickly when playtesting.
const PLAYTEST_EMBLEM: String = "res://content/emblems/playtest_bolt.tres"
## Later (milestone 19): the run's Stages come one Tier after another.
const FIRST_TIER: int = 1

var run_seed: int
var collection: Collection = Collection.new()
var deckbox: Deckbox = Deckbox.new()
var held_mods: HeldMods = HeldMods.new()
## The basic lands a Deck may count, free and unlimited (ADR 0028).
var basic_lands: Array[MmCardDefinition] = []
var hearts: int = STARTING_HEARTS
var gold: int = 0
## The Emblems the Hero holds in every encounter.
var hero_emblems: Array[MmCardDefinition] = []
## The Stage being walked, or null before one is entered.
var stage_visit: StageVisit = null

var _random: RunRandom


func _init(seed_of_run: int) -> void:
	run_seed = seed_of_run
	_random = RunRandom.new(seed_of_run)
	for land: String in BASIC_LAND_FILES:
		basic_lands.append(load(BASIC_LANDS % land) as MmCardDefinition)


## The run the main menu's Start Run (debug) begins: every nonland card of the Content
## decks, one Deck built from red_green as the Active Deck, the Playtest Bolt, and a Tier 1
## Stage rolled from the Run Seed, entered; or [param stage], when given.
static func debug(seed_of_run: int, stage: StageDefinition = null) -> Run:
	var run: Run = Run.new(seed_of_run)
	var active: Deck = null
	for deck_name: String in EncounterRequest.deck_names():
		var setup: MmPlayerSetup = load(EncounterRequest.DECKS + deck_name + ".tres") as MmPlayerSetup
		var deck: Deck = Deck.new()
		for run_card: MmRunCard in setup.deck:
			if run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC):
				deck.basic_lands[run_card.base.name] = deck.basic_lands.get(run_card.base.name, 0) + 1
				continue
			var copy: MmRunCard = MmRunCard.new()
			copy.base = run_card.base
			copy.modifications = run_card.modifications.duplicate()
			deck.card_ids.append(run.collection.add(copy).id)
		if deck_name == DEBUG_DECK:
			deck.name = DEBUG_DECK_NAME
			active = deck
	run.deckbox.put(active)
	run.deckbox.set_active(active)
	run.hero_emblems.append(load(PLAYTEST_EMBLEM) as MmCardDefinition)
	run.enter_stage(stage if stage != null else run.roll_stage(FIRST_TIER))
	return run


## A Stage of [param tier] from Content, rolled from the Run Seed among every color.
## Later (milestone 19): only among the colors not yet played.
func roll_stage(tier: int) -> StageDefinition:
	var stages: Array[StageDefinition] = []
	for stage: StageDefinition in StageDefinition.all():
		if stage.tier == tier:
			stages.append(stage)
	return stages[_random.pick(RunRandom.STAGES, stages.size())]


## Enters [param stage]: its map is built, its Boss picked and where each Node is drawn
## chosen, each from a stream of its own of the Run Seed (ADR 0025), and the Hero stands
## on its Start Node.
func enter_stage(stage: StageDefinition) -> void:
	var map: StageMap = StageMapGenerator.generate(_random.next_seed(RunRandom.STAGE_MAPS))
	var boss: Villain = stage.bosses[_random.pick(RunRandom.BOSSES, stage.bosses.size())]
	stage_visit = StageVisit.new(stage, map, boss)
	for node: MapNode in map.nodes:
		stage_visit.offsets[node.id] = Vector2(
			_random.fraction(RunRandom.MAP_LAYOUT) * 2.0 - 1.0, _random.fraction(RunRandom.MAP_LAYOUT) * 2.0 - 1.0)


## Moves the Hero to the Node [param id] of the Stage, meeting its Villain if it is an
## encounter. Says why not, changing nothing, if a Path does not allow it.
func move_to(id: int) -> String:
	return stage_visit.move_to(id, _random)


## A new Encounter Seed, so that each attempt at an encounter is a new game (ADR 0025).
func next_encounter_seed() -> int:
	return _random.next_seed(RunRandom.ENCOUNTER_SEEDS)


## Counts an encounter's end: a loss (or a draw) costs a Heart. The Node it was at is
## passed, unless it is the Boss Encounter and was lost.
func record_encounter(won: bool) -> void:
	if not won:
		hearts = maxi(0, hearts - 1)
	if stage_visit != null:
		stage_visit.record(won)


## Whether the Boss has been beaten. Later (milestone 19): a run is won after the fifth.
func is_won() -> bool:
	return stage_visit != null and stage_visit.is_won


func is_lost() -> bool:
	return hearts <= 0


## The Hero's setup for an encounter: the Active Deck's Run Cards with their Mods, a fresh
## Run Card for each basic land it counts (ADR 0028), and the Emblems the Hero holds.
func hero_setup() -> MmPlayerSetup:
	var setup: MmPlayerSetup = MmPlayerSetup.new()
	setup.emblems = hero_emblems.duplicate()
	var active: Deck = deckbox.active()
	for id: int in active.card_ids:
		setup.deck.append(collection.card(id).run_card)
	for land: MmCardDefinition in basic_lands:
		for index: int in active.basic_lands.get(land.name, 0):
			var fresh: MmRunCard = MmRunCard.new()
			fresh.base = land
			setup.deck.append(fresh)
	return setup


## The encounter against the Villain the Hero is meeting, with the Hero playing the Active
## Deck, in front of the Stage's Backdrop (ADR 0035).
func encounter_request() -> EncounterRequest:
	var request: EncounterRequest = EncounterRequest.new()
	var villain: Villain = stage_visit.meeting
	request.villain_setup = villain.setup_for_tier(stage_visit.stage.tier)
	request.villain_name = villain.name
	request.backdrop = stage_visit.stage.backdrop()
	request.hero_setup = hero_setup()
	request.encounter_seed = next_encounter_seed()
	request.run = self
	return request
