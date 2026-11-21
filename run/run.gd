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
## the one built from red_green first as the Active Deck; the Playtest Bolt, and a Tier 1
## Stage rolled from the Run Seed, entered; or [param stage], when given. Asked for at a
## later [param tier], it walks there, each Stage before it counted as won (its Boss beaten
## and nothing paid), for pictures and playtesting.
static func debug(seed_of_run: int, stage: StageDefinition = null, tier: int = FIRST_TIER) -> Run:
	var run: Run = Run.new(seed_of_run)
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
	run.enter_stage(stage if stage != null else run.roll_stage(FIRST_TIER))
	while run.stage_visit.stage.tier < clampi(tier, FIRST_TIER, LAST_TIER):
		run.stage_visit.is_won = true
		run.enter_next_stage()
	return run


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
	return stage_visit.move_to(id, _random)


## A new Encounter Seed, so that each attempt at an encounter is a new game (ADR 0025).
func next_encounter_seed() -> int:
	return _random.next_seed(RunRandom.ENCOUNTER_SEEDS)


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
