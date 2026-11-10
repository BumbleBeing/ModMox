class_name AiMonteCarlo
extends RefCounted
## Flat Monte Carlo (glossary "Rollout", A188–A193): compares a few candidate answers by
## rolling each out on the same re-dealt worlds and summing the Board Evaluator's scores.
## The one-step pick is the default; another candidate replaces it only by beating it
## clearly (A192).


## The answers worth rolling out: [param pick] first, then [param passing], then the rest
## of [param options] by one-step score, best first, ties in action order, up to
## [param count] in all (A189).
static func candidates(options: Array[int], one_step_scores: Array[int], pick: int, passing: int, count: int) -> Array[int]:
	var rest: Array[int] = []
	for index: int in options.size():
		if options[index] != pick and options[index] != passing:
			rest.append(index)
	rest.sort_custom(func(first: int, second: int) -> bool:
		if one_step_scores[first] != one_step_scores[second]:
			return one_step_scores[first] > one_step_scores[second]
		return options[first] < options[second])
	var chosen: Array[int] = [pick]
	if passing != pick:
		chosen.append(passing)
	for index: int in rest:
		chosen.append(options[index])
	return chosen.slice(0, maxi(count, 1))


## [param player_id]'s score of each of [param answers] in each of [param samples]
## re-dealt worlds, as one row per sample. Every answer in a row is played on the same
## world, Game RNG and CHEAP Agents' AI RNGs, so they differ only by the answer (A193).
static func sample_scores(source: MmSimulationSource, rng: MmRng, answers: Array[int], samples: int,
		player_id: int, profile: AiProfile) -> Array:
	var rows: Array = []
	for _sample: int in samples:
		var world_seed: int = rng.next_seed()
		var row: Array[int] = []
		for answer: int in answers:
			var copy: MmEngine = source.simulation_copy(MmRng.new(world_seed))
			row.append(AiSimulation.score_rollout(copy, answer, player_id, profile))
		rows.append(row)
	return rows


## The total of each of [param count] answers over [param rows]. A won or lost game is
## worth so much that the totals rank by wins minus losses first (A191).
static func totals(rows: Array, count: int) -> Array[int]:
	var sums: Array[int] = []
	sums.resize(count)
	sums.fill(0)
	for row: Variant in rows:
		for index: int in count:
			sums[index] += (row as Array)[index] as int
	return sums


## The switch margin over [param samples] samples (A192).
static func margin(profile: AiProfile, samples: int) -> int:
	return profile.rollout_switch_margin * samples


## The chosen answer: [param candidate_answers][0], the default, unless another's total
## beats it by at least [param switch_margin] (and at least 1, so a tie keeps it). Of
## those that do, the best; equal bests are broken with [param rng].
static func choose(candidate_answers: Array[int], candidate_totals: Array[int], switch_margin: int, rng: MmRng) -> int:
	var needed: int = candidate_totals[0] + maxi(switch_margin, 1)
	var best: Array[int] = []
	var best_total: int = 0
	for index: int in range(1, candidate_answers.size()):
		if candidate_totals[index] < needed:
			continue
		if best.is_empty() or candidate_totals[index] > best_total:
			best = [candidate_answers[index]]
			best_total = candidate_totals[index]
		elif candidate_totals[index] == best_total:
			best.append(candidate_answers[index])
	if best.is_empty():
		return candidate_answers[0]
	return best[0] if best.size() == 1 else best[rng.next_int(best.size())]


## "answer: total (wins W, losses L)" for each candidate, for explain_detail().
static func describe(candidate_answers: Array[int], rows: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var sums: Array[int] = totals(rows, candidate_answers.size())
	for index: int in candidate_answers.size():
		var won: int = 0
		var lost: int = 0
		for row: Variant in rows:
			var score: int = (row as Array)[index]
			if score >= AiBoardEvaluator.WIN:
				won += 1
			elif score <= -AiBoardEvaluator.WIN:
				lost += 1
		parts.append("%d: %d (%dW %dL)" % [candidate_answers[index], sums[index], won, lost])
	return ", ".join(parts)
