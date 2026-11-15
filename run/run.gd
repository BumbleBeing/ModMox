class_name Run
extends RefCounted
## One run's state: its Run Seed, the Collection, the Deckbox and its Active Deck, the Mods
## held, Hearts and gold (milestone 16). It knows nothing of screens; they change it only
## through its own methods. Gold is held but not yet spent.

const STARTING_HEARTS: int = 3
const DEBUG_DECK: String = "red_green"
const DEBUG_DECK_NAME: String = "Red-Green"
const BASIC_LANDS: String = "res://content/cards/alpha/%s.tres"
const BASIC_LAND_FILES: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]

var run_seed: int
var collection: Collection = Collection.new()
var deckbox: Deckbox = Deckbox.new()
var held_mods: HeldMods = HeldMods.new()
## The basic lands a Deck may count, free and unlimited (ADR 0028).
var basic_lands: Array[MmCardDefinition] = []
var hearts: int = STARTING_HEARTS
var gold: int = 0

var _random: RunRandom


func _init(seed_of_run: int) -> void:
	run_seed = seed_of_run
	_random = RunRandom.new(seed_of_run)
	for land: String in BASIC_LAND_FILES:
		basic_lands.append(load(BASIC_LANDS % land) as MmCardDefinition)


## The run the main menu's Start Run (debug) begins: every nonland card of the Content
## decks, and one Deck built from red_green as the Active Deck.
static func debug(seed_of_run: int) -> Run:
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
	return run


## The Villain the next encounter is against: the name of a deck in content/decks/,
## drawn by the Run Seed.
func next_villain() -> String:
	var names: Array[String] = EncounterRequest.deck_names()
	return names[_random.pick(RunRandom.VILLAINS, names.size())]


## A new Encounter Seed, so that each attempt at an encounter is a new game (ADR 0025).
func next_encounter_seed() -> int:
	return _random.next_seed(RunRandom.ENCOUNTER_SEEDS)


## Counts an encounter's end: a loss (or a draw) costs a Heart.
func record_encounter(won: bool) -> void:
	if not won:
		hearts = maxi(0, hearts - 1)


func is_lost() -> bool:
	return hearts <= 0


## The Hero's setup for an encounter: the Active Deck's Run Cards with their Mods, and a
## fresh Run Card for each basic land it counts (ADR 0028).
func hero_setup() -> MmPlayerSetup:
	var setup: MmPlayerSetup = MmPlayerSetup.new()
	var active: Deck = deckbox.active()
	for id: int in active.card_ids:
		setup.deck.append(collection.card(id).run_card)
	for land: MmCardDefinition in basic_lands:
		for index: int in active.basic_lands.get(land.name, 0):
			var fresh: MmRunCard = MmRunCard.new()
			fresh.base = land
			setup.deck.append(fresh)
	return setup


## The encounter against [param villain_deck], with the Hero playing the Active Deck.
func encounter_request(villain_deck: String) -> EncounterRequest:
	var request: EncounterRequest = EncounterRequest.new()
	request.villain_deck = villain_deck
	request.hero_setup = hero_setup()
	request.encounter_seed = next_encounter_seed()
	request.run = self
	return request
