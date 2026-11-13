extends GutTest
## AI against AI with the authored decks, played to the end (A168): no answer is ever
## rejected, every encounter ends within the cap, and replaying the decision log gives the
## same final state. By default it plays one seed at Easy to keep the suite fast (A185);
## for all 100, at any AI Difficulty (easy, normal or hard), run:
##   MODMOX_SOAK_SEEDS=100 MODMOX_SOAK_DIFFICULTY=normal tools/test.sh -gselect=test_soak
## A second test plays with both Boons for each player and a Big Gulp for the Hero (ADR
## 0036), and checks that no once-each-game ability is activated twice and no Potion used
## twice. It plays one seed too, or all of MODMOX_SOAK_SEEDS with MODMOX_SOAK_HELD=1.

const DECKS: Array[String] = ["red_green", "white_black", "blue_red"]
const DEFAULT_SEEDS: int = 1
## No real encounter comes near this many answers; reaching it means the AIs are stuck.
const DECISION_CAP: int = 6000


func test_ai_against_ai_encounters_end_cleanly_and_replay_exactly() -> void:
	_soak(maxi(OS.get_environment("MODMOX_SOAK_SEEDS").to_int(), DEFAULT_SEEDS), false)


func test_ai_against_ai_encounters_with_boons_and_a_potion_end_cleanly_and_replay_exactly() -> void:
	var is_asked_for: bool = OS.get_environment("MODMOX_SOAK_HELD") == "1"
	_soak(maxi(OS.get_environment("MODMOX_SOAK_SEEDS").to_int(), DEFAULT_SEEDS) if is_asked_for else DEFAULT_SEEDS, true)


## Plays seeds 1 to [param seed_count]; with [param is_holding], with Boons and a Potion.
func _soak(seed_count: int, is_holding: bool) -> void:
	var outcomes: Array[String] = []
	var level: String = OS.get_environment("MODMOX_SOAK_DIFFICULTY")
	var difficulty: AiDifficulty = AiDifficulty.easy()
	if level == "normal":
		difficulty = AiDifficulty.normal()
	elif level == "hard":
		difficulty = AiDifficulty.hard()
	else:
		assert_true(level in ["", "easy"], "Unknown difficulty %s" % level)
	for encounter_seed: int in range(1, seed_count + 1):
		var setup: MmEncounterSetup = soak_setup(encounter_seed)
		if is_holding:
			_give_held(setup)
		var engine: MmEngine = MmEngine.start(setup)
		var agents: Dictionary[int, MmAgent] = {}
		agents[MmEncounterSetup.HERO_PLAYER_ID] = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)
		agents[MmEncounterSetup.VILLAIN_PLAYER_ID] = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)
		var driver: MmEncounterDriver = MmEncounterDriver.new(engine, agents)
		driver.decision_cap = DECISION_CAP
		driver.builds_views = false

		var status: MmEncounterDriver.Status = driver.run()

		assert_eq(status, MmEncounterDriver.Status.OVER, "Seed %d: %s %s" % [encounter_seed, status, driver.rejection])
		var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())
		assert_eq(replayed.fingerprint(), engine.fingerprint(), "Seed %d replays exactly." % encounter_seed)
		var used: String = ""
		if is_holding:
			var spent: int = _count_events(engine, AbilitySpentEvent)
			var potions_used: int = _count_events(engine, PotionUsedEvent)
			assert_lte(spent, 4, "Seed %d: two Boons each, each once." % encounter_seed)
			assert_lte(potions_used, 1, "Seed %d: the Hero's one Potion." % encounter_seed)
			used = ", %d Boon abilities and %d Potions used" % [spent, potions_used]
		outcomes.append("seed %d: %s on Game Turn %d after %d decisions%s" % [encounter_seed,
			MmEngine.Outcome.find_key(engine.outcome()), engine.game_state().game_turn, engine.decision_count(), used])
	print("\n".join(outcomes))


## Seed n pits two of the three decks against each other, in turn.
static func soak_setup(encounter_seed: int) -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = _deck(DECKS[encounter_seed % DECKS.size()])
	setup.villain = _deck(DECKS[(encounter_seed + 1) % DECKS.size()])
	setup.encounter_seed = encounter_seed
	return setup


## Gives each player both Boons, and the Hero a Big Gulp as the game does (A523), on copies
## of the loaded decks.
static func _give_held(setup: MmEncounterSetup) -> void:
	setup.hero = setup.hero.duplicate() as MmPlayerSetup
	setup.villain = setup.villain.duplicate() as MmPlayerSetup
	for player: MmPlayerSetup in [setup.hero, setup.villain]:
		player.emblems = [load("res://content/emblems/diviners_boon.tres"), load("res://content/emblems/electromancers_boon.tres")] as Array[MmCardDefinition]
	setup.hero.potions = [load("res://content/potions/big_gulp.tres")] as Array[MmCardDefinition]


## How many events of [param kind] the encounter logged.
static func _count_events(engine: MmEngine, kind: Script) -> int:
	var count: int = 0
	for event: MmEvent in engine.event_log():
		if event.get_script() == kind:
			count += 1
	return count


static func _deck(deck_name: String) -> MmPlayerSetup:
	return load("res://content/decks/%s.tres" % deck_name) as MmPlayerSetup
