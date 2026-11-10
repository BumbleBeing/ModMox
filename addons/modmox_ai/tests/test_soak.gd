extends GutTest
## AI against AI with the authored decks, played to the end (A168): no answer is ever
## rejected, every encounter ends within the cap, and replaying the decision log gives the
## same final state. By default it plays one seed at Easy to keep the suite fast (A185);
## for all 100, at any AI Difficulty (easy, normal or hard), run:
##   MODMOX_SOAK_SEEDS=100 MODMOX_SOAK_DIFFICULTY=normal tools/test.sh -gselect=test_soak

const DECKS: Array[String] = ["red_green", "white_black", "blue_red"]
const DEFAULT_SEEDS: int = 1
## No real encounter comes near this many answers; reaching it means the AIs are stuck.
const DECISION_CAP: int = 6000


func test_ai_against_ai_encounters_end_cleanly_and_replay_exactly() -> void:
	var seed_count: int = maxi(OS.get_environment("MODMOX_SOAK_SEEDS").to_int(), DEFAULT_SEEDS)
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
		outcomes.append("seed %d: %s on Game Turn %d after %d decisions" % [encounter_seed,
			MmEngine.Outcome.find_key(engine.outcome()), engine.game_state().game_turn, engine.decision_count()])
	print("\n".join(outcomes))


## Seed n pits two of the three decks against each other, in turn.
static func soak_setup(encounter_seed: int) -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = _deck(DECKS[encounter_seed % DECKS.size()])
	setup.villain = _deck(DECKS[(encounter_seed + 1) % DECKS.size()])
	setup.encounter_seed = encounter_seed
	return setup


static func _deck(deck_name: String) -> MmPlayerSetup:
	return load("res://content/decks/%s.tres" % deck_name) as MmPlayerSetup
