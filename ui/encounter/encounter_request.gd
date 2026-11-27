class_name EncounterRequest
extends RefCounted
## What encounter to play: both decks, the Encounter Seed and how hard the Villain plays.
## Filled in on the start form or from the command line (A246), or made by for_run() for
## the encounter a run's Stage Map has led to.

const EMBLEMS: String = "res://content/emblems/"
const POTIONS: String = "res://content/potions/"
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

var hero_deck: String = "red_green"
var villain_deck: String = "white_black"
var encounter_seed: int = 1
var difficulty: String = "easy"
## What each player is called; "" for a player who goes by their part.
var hero_name: String = ""
var villain_name: String = ""
## The Villain's own Portrait, from a run's Villain; null for the placeholder (PlayerPortraits).
var villain_portrait: Texture2D = null
## Its Pain Portrait, given with its Portrait; null for none.
var villain_pain_portrait: Texture2D = null
## The Backdrop (game glossary) behind the encounter, one of Backdrops.NAMES: in a run, the
## color of the Stage it is met on (ADR 0035).
var backdrop: String = Backdrops.PLAIN
## Gives each player sample Emblems, so the Emblems windows have something to show and to
## activate: the Hero Howling Winds and both Boons, the Villain Ankh's Curse and
## Electromancer's Boon (A527).
var has_sample_emblems: bool = false
## Gives the Hero one Big Gulp in a debug encounter outside a run (A523); in a run the Hero has
## the Potions held in the Satchel (milestone 24).
var has_sample_potions: bool = false
## The file names of Armor in Content the Hero wears, "seers_cuirass", so an Armor can be
## seen in play before the Satchel puts one on (game ADR 0106).
var worn_armor: Array[String] = []
## The Hero's setup when it comes from a run's Active Deck rather than a deck in Content;
## hero_deck is then not read (milestone 16).
var hero_setup: MmPlayerSetup = null
## The Villain's setup when it comes from a run's Villain rather than a deck in Content;
## villain_deck is then not read (milestone 17).
var villain_setup: MmPlayerSetup = null
## The run this encounter is part of, or null.
var run: Run = null
## The Modded Name of each of the Hero's Run Cards that has one (ADR 0029), from a run's
## Active Deck. Empty outside a run.
var card_names: Dictionary[MmRunCard, String] = {}


## The encounter against the Villain the Hero of [param run] is meeting, with the Hero
## playing the Active Deck, in front of the Stage's Backdrop (ADR 0035).
static func for_run(run: Run) -> EncounterRequest:
	var request: EncounterRequest = EncounterRequest.new()
	var villain: Villain = run.stage_visit.meeting
	request.villain_setup = villain.setup_for_tier(run.stage_visit.stage.tier)
	request.villain_name = villain.name
	request.villain_portrait = villain.sprite
	request.villain_pain_portrait = villain.pain_sprite
	request.backdrop = run.stage_visit.stage.backdrop()
	request.hero_setup = run.hero_setup()
	request.card_names = run.modded_names()
	request.encounter_seed = run.next_encounter_seed()
	request.run = run
	return request


## The request in [param arguments], as passed after "--" on the command line, such as
## --hero=red_green --villain=white_black --seed=7 --difficulty=normal --emblems --potions
## --hero-name=Jackson --villain-name=Mishra --backdrop=red --armor=seers_cuirass. Null when
## they name no deck and no seed, which means "show the start form".
static func from_arguments(arguments: PackedStringArray) -> EncounterRequest:
	var request: EncounterRequest = EncounterRequest.new()
	var is_asked_for: bool = false
	for argument: String in arguments:
		if argument.begins_with("--hero="):
			request.hero_deck = argument.trim_prefix("--hero=")
			is_asked_for = true
		elif argument.begins_with("--villain="):
			request.villain_deck = argument.trim_prefix("--villain=")
			is_asked_for = true
		elif argument.begins_with("--seed="):
			request.encounter_seed = int(argument.trim_prefix("--seed="))
			is_asked_for = true
		elif argument.begins_with("--difficulty="):
			request.difficulty = argument.trim_prefix("--difficulty=")
		elif argument.begins_with("--hero-name="):
			request.hero_name = argument.trim_prefix("--hero-name=")
		elif argument.begins_with("--villain-name="):
			request.villain_name = argument.trim_prefix("--villain-name=")
		elif argument.begins_with("--backdrop="):
			request.backdrop = argument.trim_prefix("--backdrop=")
		elif argument == "--emblems":
			request.has_sample_emblems = true
		elif argument == "--potions":
			request.has_sample_potions = true
		elif argument.begins_with("--armor="):
			for armor: String in argument.trim_prefix("--armor=").split(",", false):
				request.worn_armor.append(armor)
	return request if is_asked_for else null


## Why this request cannot be played, or "" if it can.
func validate() -> String:
	var decks: Array[String] = []
	if hero_setup == null:
		decks.append(hero_deck)
	if villain_setup == null:
		decks.append(villain_deck)
	for deck: String in decks:
		if not ContentDecks.has(deck):
			return "There is no deck named \"%s\"." % deck
	if not DIFFICULTIES.has(difficulty):
		return "There is no difficulty named \"%s\"." % difficulty
	if not Backdrops.has(backdrop):
		return "There is no backdrop named \"%s\"." % backdrop
	for armor: String in worn_armor:
		if ContentArmor.named(armor) == null:
			return "There is no Armor named \"%s\"." % armor
	return ""


## The Encounter Setup this request describes. Loaded decks are never changed: sample
## Emblems and the Armor worn go on copies.
func setup() -> MmEncounterSetup:
	var encounter: MmEncounterSetup = MmEncounterSetup.new()
	encounter.hero = hero_setup if hero_setup != null else ContentDecks.load_deck(hero_deck)
	encounter.villain = villain_setup if villain_setup != null else ContentDecks.load_deck(villain_deck)
	encounter.encounter_seed = encounter_seed
	if has_sample_emblems or has_sample_potions or not worn_armor.is_empty():
		encounter.hero = encounter.hero.duplicate() as MmPlayerSetup
		encounter.hero.emblems = encounter.hero.emblems.duplicate()
		encounter.villain = encounter.villain.duplicate() as MmPlayerSetup
	if has_sample_emblems:
		encounter.hero.emblems = [_sample_emblem("Sample Boon: Howling Winds", "howling_mine"),
			_emblem("diviners_boon"), _emblem("electromancers_boon")] as Array[MmCardDefinition]
		encounter.villain.emblems = [_sample_emblem("Sample Hex: Ankh's Curse", "ankh_of_mishra"),
			_emblem("electromancers_boon")] as Array[MmCardDefinition]
	if has_sample_potions:
		encounter.hero.potions = [load(POTIONS + "big_gulp.tres") as MmCardDefinition] as Array[MmCardDefinition]
	if not worn_armor.is_empty():
		StartingCondition.apply_all(_wearing().starting_conditions(), encounter.hero)
	return encounter


## What each player is called on the screen.
func names() -> PlayerNames:
	return PlayerNames.new(hero_name, villain_name)


## The Agent that plays the Villain, at this request's difficulty. Given a [param log_folder],
## it writes an AI Log of its answers there, a file for this encounter (AiLoggingAgent).
func villain_agent(log_folder: String = "") -> MmAgent:
	var level: AiDifficulty = load("res://content/ai/difficulty_%s.tres" % difficulty) as AiDifficulty
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, level)
	if log_folder == "":
		return agent
	return AiLoggingAgent.begin(log_folder, encounter_seed, agent, Time.get_datetime_string_from_system())


## An Emblem with the abilities of a card in Content, and nothing else (ADR 0011).
static func _sample_emblem(emblem_name: String, card: String) -> MmCardDefinition:
	var source: MmCardDefinition = load("res://content/cards/alpha/%s.tres" % card) as MmCardDefinition
	var emblem: MmCardDefinition = MmCardDefinition.new()
	emblem.name = emblem_name
	emblem.abilities = source.abilities.duplicate()
	# It has no file of its own, so it says which card's art and credit it borrows.
	emblem.set_meta(EncounterPresenter.ART_KEY_META, card)
	return emblem


## The Armor named in worn_armor, each put on in turn, a later one in place of an earlier one
## for the same Armor Slot, as the Satchel puts Armor on.
func _wearing() -> HeldArmor:
	var held: HeldArmor = HeldArmor.new()
	for file_name: String in worn_armor:
		var armor: Armor = ContentArmor.named(file_name)
		if armor == null:
			continue  # validate() names it.
		held.add(armor)
		held.put_on(armor)
	return held


static func _emblem(file_name: String) -> MmCardDefinition:
	return load(EMBLEMS + file_name + ".tres") as MmCardDefinition
