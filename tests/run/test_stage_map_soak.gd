extends GutTest
## The slow check of ADR 0026: maps for thousands of map seeds, every one valid, with how
## many attempts they took. By default it builds a handful to keep the suite fast; for
## more, run:
##   MODMOX_MAP_SEEDS=2000 tools/test.sh -gselect=test_stage_map_soak

const DEFAULT_SEEDS: int = 5


func test_every_map_seed_gets_a_valid_map() -> void:
	var seeds: int = maxi(OS.get_environment("MODMOX_MAP_SEEDS").to_int(), DEFAULT_SEEDS)
	var attempts: Array[int] = []
	var reasons: Dictionary[String, int] = {}

	for map_seed: int in range(1, seeds + 1):
		var failures: Array[String] = []
		var map: StageMap = StageMapGenerator.generate(map_seed, failures)
		assert_not_null(map, "map seed %d" % map_seed)
		if map == null:
			continue
		assert_eq(StageMapGenerator.validate(map), "", "map seed %d" % map_seed)
		attempts.append(map.attempts)
		for reason: String in failures:
			reasons[reason] = reasons.get(reason, 0) + 1

	attempts.sort()
	var total: int = 0
	for count: int in attempts:
		total += count
	gut.p("Map seeds: %d. Attempts per map: mean %.1f, median %d, worst %d." % [
		seeds, float(total) / attempts.size(), attempts[attempts.size() / 2], attempts[-1]])
	for reason: String in reasons:
		gut.p("  thrown away %d times: %s" % [reasons[reason], reason])
