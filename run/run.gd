class_name Run
extends RefCounted
## One run's state: its Run Seed, the Collection, the Deckbox and its Active Deck, the Mods
## held, Hearts and gold (milestone 16), the Stage being walked (milestone 17) and the
## Stages beaten before it (milestone 19). A run plays five Stages, Tiers 1 to 5 in order,
## each rolled on entering it among the colors not yet played; everything the Hero holds
## carries from one to the next, and Hearts never refill. The fifth Boss wins it and the
## last Heart, at any Tier, loses it. It knows nothing of screens; they change it only
## through its own methods. Gold is held but not yet spent.

const STARTING_HEARTS: int = 3
const DEBUG_DECK: String = "red_green"
const DEBUG_DECK_NAME: String = "Red-Green"
## How many copies of each nonland card in Content a debug run owns.
const DEBUG_COPIES: int = 4
const BASIC_LANDS: String = "res://content/cards/alpha/%s.tres"
const BASIC_LAND_FILES: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]
## The Emblem the Hero holds in every debug run, to end encounters quickly when playtesting.
const PLAYTEST_EMBLEM: String = "res://content/emblems/playtest_bolt.tres"
const FIRST_TIER: int = 1
## The Tier whose Boss wins the run.
const LAST_TIER: int = Villain.TIERS

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
## What the last encounter recorded paid (milestone 18, ADR 0039), which the Spoils screen
## shows; null after a loss, or before any win.
var last_spoils: Spoils = null
## The Villain that took the last Heart, once the run is lost; null until then.
var fell_to: Villain = null
## Where every choice made in the run is logged (milestone 21), or null for none; use_log()
## sets it.
var run_log: RunLog = null
## How the run began, as its Run Log's run_started line says: how, and what with.
var beginning: Dictionary = {}

var _random: RunRandom
## The Stages whose Bosses were beaten before the one being walked, in Tier order.
var _beaten: Array[StageVisit] = []


func _init(seed_of_run: int) -> void:
	run_seed = seed_of_run
	_random = RunRandom.new(seed_of_run)
	for land: String in BASIC_LAND_FILES:
		basic_lands.append(load(BASIC_LANDS % land) as MmCardDefinition)


## The run the main menu's Start Run (debug) begins, for playtesting: at least
## [constant DEBUG_COPIES] copies of every nonland card in Content, more of a card some
## Villain's deck has more of; a Deck built from each Villain's deck, named after it, with
## the one built from red_green first as the Active Deck; the Playtest Bolt; one of every
## Mod in Content that is not a Hex, to try them out; and a Tier 1
## Stage rolled from the Run Seed, entered; or [param stage], when given. Asked for at a
## later [param tier], it walks there, each Stage before it counted as won (its Boss beaten
## and nothing paid), for pictures and playtesting.
static func debug(seed_of_run: int, stage: StageDefinition = null, tier: int = FIRST_TIER) -> Run:
	var run: Run = Run.new(seed_of_run)
	run.beginning = {"how": "debug", "stage": stage.resource_path if stage != null else "", "tier": tier}
	var red_green: MmPlayerSetup = ContentDecks.load_deck(DEBUG_DECK)
	var lists: Array[MmPlayerSetup] = [red_green]
	var names: Array[String] = [DEBUG_DECK_NAME]
	for villain: Villain in ContentStages.all_villains():
		for setup: MmPlayerSetup in villain.setups:
			if not lists.has(setup):
				lists.append(setup)
				names.append(villain.name)
	var copies: Dictionary[MmCardDefinition, int] = {}
	for definition: MmCardDefinition in ContentCards.all():
		if not definition.supertypes.has(MmCardTypes.Supertype.BASIC):
			copies[definition] = DEBUG_COPIES
	for list: MmPlayerSetup in lists:
		var counted: Dictionary[MmCardDefinition, int] = {}
		for run_card: MmRunCard in list.deck:
			counted[run_card.base] = counted.get(run_card.base, 0) + 1
		for definition: MmCardDefinition in counted:
			if copies.has(definition):
				copies[definition] = maxi(copies[definition], counted[definition])
	var owned: Dictionary[MmCardDefinition, Array] = {}
	for definition: MmCardDefinition in copies:
		owned[definition] = []
		for copy: int in copies[definition]:
			var run_card: MmRunCard = MmRunCard.new()
			run_card.base = definition
			owned[definition].append(run.collection.add(run_card).id)
	for index: int in lists.size():
		var deck: Deck = Deck.new()
		deck.name = run.deckbox.free_name(names[index])
		var next: Dictionary[MmCardDefinition, int] = {}
		for run_card: MmRunCard in lists[index].deck:
			if run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC):
				deck.basic_lands[run_card.base.name] = deck.basic_lands.get(run_card.base.name, 0) + 1
			else:
				deck.card_ids.append(owned[run_card.base][next.get(run_card.base, 0)])
				next[run_card.base] = next.get(run_card.base, 0) + 1
		run.deckbox.put(deck)
	run.deckbox.set_active(run.deckbox.decks()[0])
	run.hero_emblems.append(load(PLAYTEST_EMBLEM) as MmCardDefinition)
	# For playtesting the Mods until a Workshop or the Spoils hand them out. A Hex is never
	# held (ADR 0029).
	for mod: Mod in ContentMods.all():
		if not mod.is_hex:
			run.held_mods.add(mod)
	run.enter_stage(stage if stage != null else run.roll_stage(FIRST_TIER))
	while run.stage_visit.stage.tier < clampi(tier, FIRST_TIER, LAST_TIER):
		run.stage_visit.is_won = true
		run.enter_next_stage()
	return run


## Logs every choice made in the run from here on in [param log_to]: the Nodes walked to, the
## encounters begun, and what the Deckbox and the Mods held log of their own.
func use_log(log_to: RunLog) -> void:
	run_log = log_to
	deckbox.run_log = log_to
	held_mods.run_log = log_to


## A Stage of [param tier] from Content, rolled from the Run Seed among the colors not yet
## played in this run.
func roll_stage(tier: int) -> StageDefinition:
	var played: Dictionary[MmCardTypes.CardColor, bool] = {}
	for visit: StageVisit in stages_played():
		played[visit.stage.color] = true
	var stages: Array[StageDefinition] = []
	for stage: StageDefinition in ContentStages.all():
		if stage.tier == tier and not played.has(stage.color):
			stages.append(stage)
	return stages[_random.pick(RunRandom.STAGES, stages.size())]


## Enters the next Tier's Stage, rolled among the colors not yet played, once the Boss of
## the Stage being walked is beaten. Everything the Hero holds goes with them.
func enter_next_stage() -> void:
	assert(is_stage_beaten() and not is_won(), "The next Stage is entered once a Boss before the last is beaten.")
	var tier: int = stage_visit.stage.tier + 1
	_beaten.append(stage_visit)
	enter_stage(roll_stage(tier))


## The Stages whose Bosses were beaten before the one being walked, in Tier order.
func stages_beaten() -> Array[StageVisit]:
	return _beaten.duplicate()


## Every Stage entered, in Tier order: those beaten, then the one being walked.
func stages_played() -> Array[StageVisit]:
	var played: Array[StageVisit] = stages_beaten()
	if stage_visit != null:
		played.append(stage_visit)
	return played


## Whether the Boss of the Stage being walked has been beaten.
func is_stage_beaten() -> bool:
	return stage_visit != null and stage_visit.is_won


## Enters [param stage]: its map is built, its Boss picked and where each Node is drawn
## chosen, each from a stream of its own of the Run Seed (ADR 0025), and the Hero stands
## on its Start Node. The Boss's Node is always at its cell's center, so a Map Backdrop can
## be painted round it (ADR 0038); its place is drawn all the same, so the rest are not
## moved. The seed its Scenery is placed from comes last, from a stream of its own.
func enter_stage(stage: StageDefinition) -> void:
	var map: StageMap = StageMapGenerator.generate(_random.next_seed(RunRandom.STAGE_MAPS))
	var boss: Villain = stage.bosses[_random.pick(RunRandom.BOSSES, stage.bosses.size())]
	stage_visit = StageVisit.new(stage, map, boss)
	for node: MapNode in map.nodes:
		var offset: Vector2 = Vector2(
			_random.fraction(RunRandom.MAP_LAYOUT) * 2.0 - 1.0, _random.fraction(RunRandom.MAP_LAYOUT) * 2.0 - 1.0)
		stage_visit.offsets[node.id] = Vector2.ZERO if node.kind == StageMap.Kind.BOSS else offset
	stage_visit.scenery_seed = _random.next_seed(RunRandom.SCENERY)


## Moves the Hero to the Node [param id] of the Stage, meeting its Villain if it is an
## encounter. Says why not, changing nothing, if a Path does not allow it.
func move_to(id: int) -> String:
	var options: Array[int] = stage_visit.choices()
	var refusal: String = stage_visit.move_to(id, _random)
	if refusal == "" and run_log != null:
		run_log.record("node_chosen", {"node": id, "options": options})
	return refusal


## A new Encounter Seed, so that each attempt at an encounter is a new game (ADR 0025).
## Drawing it begins the encounter, which the Run Log records with the Villain met and the
## Deck the Hero plays.
func next_encounter_seed() -> int:
	var encounter_seed: int = _random.next_seed(RunRandom.ENCOUNTER_SEEDS)
	if run_log != null:
		var active: Deck = deckbox.active()
		run_log.record("encounter_started", {
			"villain": stage_visit.meeting.resource_path if stage_visit != null and stage_visit.meeting != null else "",
			"encounter_seed": encounter_seed,
			"deck": deckbox.decks().find(active),
			"card_ids": active.card_ids.duplicate() if active != null else [],
			"basic_lands": active.basic_lands.duplicate() if active != null else {},
		})
	return encounter_seed


## Counts an encounter's end: a loss (or a draw) costs a Heart, and a win pays its Spoils
## at once (ADR 0039). The Node it was at is passed, unless it is the Boss Encounter and
## was lost.
func record_encounter(won: bool) -> void:
	last_spoils = null
	if not won:
		hearts = maxi(0, hearts - 1)
		if hearts == 0 and fell_to == null and stage_visit != null:
			fell_to = stage_visit.meeting
	if stage_visit == null:
		return
	if won and stage_visit.meeting != null:
		_pay(SpoilsRoll.roll(stage_visit.node().kind, stage_visit.stage.tier, stage_visit.meeting, _random))
	stage_visit.record(won)


## The run as plain data, for a saved run (ADR 0074): everything it holds, with Content by
## its path, and where each of its random streams has reached. The Spoils last paid are
## named by the identities their cards have in the Collection.
func to_data() -> Dictionary:
	var beaten: Array = []
	for visit: StageVisit in _beaten:
		beaten.append(visit.to_data())
	var spoils: Variant = null
	if last_spoils != null:
		var ids: Array[int] = []
		for card: MmRunCard in last_spoils.cards:
			for owned: DeckbuilderCard in collection.cards():
				if owned.run_card == card:
					ids.append(owned.id)
		spoils = {"gold": last_spoils.gold, "cards": ids}
	return {
		"run_seed": run_seed,
		"random": _random.to_data(),
		"collection": collection.to_data(),
		"deckbox": deckbox.to_data(),
		"held_mods": held_mods.to_data(),
		"hearts": hearts,
		"gold": gold,
		"emblems": SavedRun.paths_of(hero_emblems),
		"stage_visit": stage_visit.to_data() if stage_visit != null else null,
		"beaten": beaten,
		"last_spoils": spoils,
		"fell_to": SavedRun.path_of(fell_to) if fell_to != null else "",
		"run_log": run_log.path if run_log != null else "",
	}


## The run [param data] holds, as to_data() made it, its random streams each where it had
## reached.
static func from_data(data: Dictionary) -> Run:
	var run: Run = Run.new(int(data["run_seed"]))
	run._random.restore(data["random"])
	run.collection = Collection.from_data(data["collection"])
	run.deckbox = Deckbox.from_data(data["deckbox"])
	run.held_mods = HeldMods.from_data(data["held_mods"])
	run.hearts = int(data["hearts"])
	run.gold = int(data["gold"])
	for path: Variant in data["emblems"]:
		run.hero_emblems.append(load(str(path)) as MmCardDefinition)
	if data["stage_visit"] != null:
		run.stage_visit = StageVisit.from_data(data["stage_visit"])
	for visit: Dictionary in data["beaten"]:
		run._beaten.append(StageVisit.from_data(visit))
	if data["last_spoils"] != null:
		run.last_spoils = Spoils.new()
		run.last_spoils.gold = int(data["last_spoils"]["gold"])
		for id: Variant in data["last_spoils"]["cards"]:
			var owned: DeckbuilderCard = run.collection.card(int(id))
			if owned != null:
				run.last_spoils.cards.append(owned.run_card)
	if str(data["fell_to"]) != "":
		run.fell_to = load(str(data["fell_to"])) as Villain
	return run


## The file of the Run Log the run in [param data] was writing, or "" for none.
static func log_path_of(data: Dictionary) -> String:
	return str(data.get("run_log", ""))


## Pays [param spoils]: its gold to the run's and its cards into the Collection, and keeps
## it as the last Spoils.
func _pay(spoils: Spoils) -> void:
	gold += spoils.gold
	for card: MmRunCard in spoils.cards:
		collection.add(card)
	last_spoils = spoils


## Whether the run is won: the fifth Boss, the last Tier's, has been beaten.
func is_won() -> bool:
	return is_stage_beaten() and stage_visit.stage.tier == LAST_TIER


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


## The Modded Name of each Run Card in the Active Deck that has a Mod or a Hex (ADR 0029),
## for the encounter to call it by: the engine never learns a Mod was involved, so it names
## each card after its Original.
func modded_names() -> Dictionary[MmRunCard, String]:
	var names: Dictionary[MmRunCard, String] = {}
	for id: int in deckbox.active().card_ids:
		var card: DeckbuilderCard = collection.card(id)
		if card.is_modified():
			names[card.run_card] = card.card_name()
	return names
