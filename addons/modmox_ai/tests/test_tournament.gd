extends GutTest
## AI against AI tournaments (A197, A198, A199). By default one seed pair of Easy against
## itself checks the harness. For a real run, on its own:
##   MODMOX_TOURNAMENT_SEEDS=100 tools/test.sh -gselect=test_tournament
## with optional settings:
##   MODMOX_TOURNAMENT_FIRST_SEED  the first seed (default 1), to split a run across processes
##   MODMOX_TOURNAMENT_A, _B       each contender's difficulty: easy, normal or hard
##                                 (defaults normal and easy: the milestone 12 gate)
##   MODMOX_TOURNAMENT_TRIAL       AI Profile settings for contender A only, for tuning,
##                                 such as "land_value=12,summoning_sick_percent=80"

const AiTournament := preload("res://addons/modmox_ai/tests/support/ai_tournament.gd")


func test_a_seed_pair_swaps_the_seats_and_every_game_replays() -> void:
	var tournament: AiTournament = AiTournament.new("easy A", AiProfile.new(), AiDifficulty.easy(),
		"easy B", AiProfile.new(), AiDifficulty.easy())

	tournament.play_seed_pair(1)

	assert_eq(tournament.failures, [] as Array[String])
	assert_eq(tournament.games, 2)
	assert_eq(tournament.seats_played, [[1, 1], [1, 1]])
	assert_eq(tournament.wins[0] + tournament.wins[1] + tournament.draws, 2)
	# The same AI on both seats of the same seed: whichever seat won once wins again.
	assert_eq(tournament.wins[0], tournament.wins[1], "Self-play splits a seed pair.")
	assert_almost_eq(tournament.first_score(), 0.5, 0.0001)
	gut.p(tournament.report())


func test_the_interval_narrows_with_more_games() -> void:
	var small: AiTournament = AiTournament.new("a", AiProfile.new(), AiDifficulty.easy(), "b", AiProfile.new(), AiDifficulty.easy())
	small.games = 20
	small.wins = [12, 8]
	var large: AiTournament = AiTournament.new("a", AiProfile.new(), AiDifficulty.easy(), "b", AiProfile.new(), AiDifficulty.easy())
	large.games = 200
	large.wins = [120, 80]

	assert_almost_eq(small.first_score(), 0.6, 0.0001)
	assert_true(small.first_interval()[0] < 0.5, "12-8 is not clearly better.")
	assert_true(large.first_interval()[0] > 0.5, "120-80 is.")


func test_a_requested_tournament() -> void:
	var seeds: int = OS.get_environment("MODMOX_TOURNAMENT_SEEDS").to_int()
	if seeds <= 0:
		pass_test("Run with MODMOX_TOURNAMENT_SEEDS=n to play one.")
		return
	var first_seed: int = maxi(OS.get_environment("MODMOX_TOURNAMENT_FIRST_SEED").to_int(), 1)
	var first_level: String = _env_or("MODMOX_TOURNAMENT_A", "normal")
	var second_level: String = _env_or("MODMOX_TOURNAMENT_B", "easy")
	var trial: String = OS.get_environment("MODMOX_TOURNAMENT_TRIAL")
	var first_profile: AiProfile = AiProfile.new()
	for setting: String in trial.split(",", false):
		var parts: PackedStringArray = setting.split("=")
		assert_true(parts.size() == 2 and parts[0] in first_profile, "Unknown setting %s" % setting)
		first_profile.set(parts[0], parts[1].to_int())
	var first_name: String = first_level if trial == "" else "%s [%s]" % [first_level, trial]
	var tournament: AiTournament = AiTournament.new(first_name, first_profile, _difficulty(first_level),
		second_level, AiProfile.new(), _difficulty(second_level))

	for encounter_seed: int in range(first_seed, first_seed + seeds):
		tournament.play_seed_pair(encounter_seed)

	assert_eq(tournament.failures, [] as Array[String])
	print("\n=== ModMox tournament, seeds %d-%d ===\n%s" % [first_seed, first_seed + seeds - 1, tournament.report()])


func _difficulty(level: String) -> AiDifficulty:
	match level:
		"easy":
			return AiDifficulty.easy()
		"hard":
			return AiDifficulty.hard()
	return AiDifficulty.normal()


func _env_or(name: String, fallback: String) -> String:
	var value: String = OS.get_environment(name)
	return fallback if value == "" else value
