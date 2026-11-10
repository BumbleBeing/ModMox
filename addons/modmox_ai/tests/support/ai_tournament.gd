extends RefCounted
## AI against AI tournaments (A197): two contenders, each an AI Profile and a difficulty,
## play the soak's encounters. Each seed is played twice with the seats swapped, so seat,
## deck and playing first even out. Every encounter must end cleanly and replay exactly.

const Soak := preload("res://addons/modmox_ai/tests/test_soak.gd")
## No real encounter comes near this many answers; reaching it means the AIs are stuck.
const DECISION_CAP: int = 6000
## z for a 95% confidence interval.
const Z: float = 1.96

var names: Array[String] = []
var profiles: Array[AiProfile] = []
var difficulties: Array[AiDifficulty] = []
## Encounters won by each contender, and drawn.
var wins: Array[int] = [0, 0]
var draws: int = 0
var games: int = 0
## Games each contender played in each seat: [as Hero, as Villain].
var seats_played: Array = [[0, 0], [0, 0]]
## A line for every encounter that did not end cleanly or did not replay exactly.
var failures: Array[String] = []
var _lines: Array[String] = []


func _init(first_name: String, first_profile: AiProfile, first_difficulty: AiDifficulty,
		second_name: String, second_profile: AiProfile, second_difficulty: AiDifficulty) -> void:
	names = [first_name, second_name]
	profiles = [first_profile, second_profile]
	difficulties = [first_difficulty, second_difficulty]


## Plays seed [param encounter_seed] twice: the first contender as Hero, then as Villain.
func play_seed_pair(encounter_seed: int) -> void:
	for first_seat: int in [MmEncounterSetup.HERO_PLAYER_ID, MmEncounterSetup.VILLAIN_PLAYER_ID]:
		_play(encounter_seed, first_seat)


## The first contender's score: wins plus half the draws, over games played.
func first_score() -> float:
	return 0.0 if games == 0 else (wins[0] + 0.5 * draws) / games


## The 95% Wilson interval of the first contender's score, as [low, high].
func first_interval() -> Array[float]:
	var interval: Array[float] = [0.0, 1.0]
	if games == 0:
		return interval
	var p: float = first_score()
	var z2: float = Z * Z
	var center: float = (p + z2 / (2.0 * games)) / (1.0 + z2 / games)
	var spread: float = Z * sqrt(p * (1.0 - p) / games + z2 / (4.0 * games * games)) / (1.0 + z2 / games)
	interval[0] = center - spread
	interval[1] = center + spread
	return interval


func report() -> String:
	var interval: Array[float] = first_interval()
	var summary: String = "%s vs %s: %d games, %d-%d, %d drawn; %s scores %.1f%% (95%% interval %.1f%%-%.1f%%)" % [
		names[0], names[1], games, wins[0], wins[1], draws, names[0], first_score() * 100.0,
		interval[0] * 100.0, interval[1] * 100.0]
	return "\n".join(_lines + [summary] + failures)


func _play(encounter_seed: int, first_seat: int) -> void:
	var setup: MmEncounterSetup = Soak.soak_setup(encounter_seed)
	var engine: MmEngine = MmEngine.start(setup)
	var agents: Dictionary[int, MmAgent] = {}
	agents[first_seat] = AiAgent.new(profiles[0], AiAgent.Mode.FULL, difficulties[0])
	agents[1 - first_seat] = AiAgent.new(profiles[1], AiAgent.Mode.FULL, difficulties[1])
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, agents)
	driver.decision_cap = DECISION_CAP
	driver.builds_views = false
	var status: MmEncounterDriver.Status = driver.run()
	var label: String = "seed %d, %s as %s" % [encounter_seed, names[0],
		"Hero" if first_seat == MmEncounterSetup.HERO_PLAYER_ID else "Villain"]
	if status != MmEncounterDriver.Status.OVER:
		failures.append("%s: %s %s" % [label, MmEncounterDriver.Status.find_key(status), driver.rejection])
		return
	if MmEngine.replay(setup, engine.decision_log()).fingerprint() != engine.fingerprint():
		failures.append("%s: the replay differs." % label)
	games += 1
	(seats_played[0] as Array)[first_seat] += 1
	(seats_played[1] as Array)[1 - first_seat] += 1
	var winner: int = engine.game_state().winner_id
	if winner == MmGameState.NO_PLAYER:
		draws += 1
	else:
		wins[0 if winner == first_seat else 1] += 1
	_lines.append("%s: %s won on Game Turn %d" % [label,
		"nobody" if winner == MmGameState.NO_PLAYER else names[0 if winner == first_seat else 1], engine.game_state().game_turn])
