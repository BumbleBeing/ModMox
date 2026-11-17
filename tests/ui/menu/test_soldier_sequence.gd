extends GutTest
## The order the Menu Soldier plays his animations in, one straight after another: a
## Transition Animation first, chosen at random, then an Effect Animation, and so on in turn,
## never the same one of either kind twice running; and the hook that tells what brings him
## the next effect which one it is and when he flashes its color.

const SEEDS: int = 40
## Enough animations that every one turns up, whatever the seed.
const ANIMATIONS: int = 60


func test_the_first_animation_starts_at_once_on_the_neutral_frame() -> void:
	var sequence: SoldierSequence = _sequence(1)

	assert_true(SoldierAnimations.TRANSITIONS.has(sequence.animation()))
	assert_eq(sequence.frame(), SoldierAnimations.NEUTRAL)


func test_the_first_animation_is_a_transition_chosen_at_random() -> void:
	var firsts: Dictionary[String, bool] = {}

	for random_seed: int in SEEDS:
		var sequence: SoldierSequence = _sequence(random_seed)
		firsts[sequence.animation()] = true

	assert_eq_deep(_sorted(firsts.keys()), _sorted(SoldierAnimations.TRANSITIONS.keys()))


func test_transitions_and_effects_take_turns() -> void:
	var played: Array[String] = _played(_sequence(2), ANIMATIONS)

	for index: int in played.size():
		var kind: Dictionary = SoldierAnimations.TRANSITIONS if index % 2 == 0 else SoldierAnimations.EFFECTS
		assert_true(kind.has(played[index]), "%s is animation %d." % [played[index], index])


## Transitions go w, x, y, z, never x, y, x, z: each differs from the one before it.
func test_the_same_transition_never_plays_twice_in_a_row() -> void:
	for random_seed: int in SEEDS:
		var transitions: Array[String] = _every_other(_played(_sequence(random_seed), ANIMATIONS), 0)

		for index: int in range(1, transitions.size()):
			assert_ne(transitions[index], transitions[index - 1], "seed %d, transition %d" % [random_seed, index])


## Effects go w, x, y, z, never x, y, z, y: each differs from the one before it.
func test_the_same_effect_never_plays_twice_in_a_row() -> void:
	for random_seed: int in SEEDS:
		var effects: Array[String] = _every_other(_played(_sequence(random_seed), ANIMATIONS), 1)

		for index: int in range(1, effects.size()):
			assert_ne(effects[index], effects[index - 1], "seed %d, effect %d" % [random_seed, index])


func test_every_transition_and_every_effect_turns_up() -> void:
	var played: Array[String] = _played(_sequence(3), ANIMATIONS * 4)

	for animation: String in SoldierAnimations.TRANSITIONS.keys() + SoldierAnimations.EFFECTS.keys():
		assert_has(played, animation)


func test_each_animation_starts_as_the_last_one_ends() -> void:
	var sequence: SoldierSequence = _sequence(4)
	var first: String = sequence.animation()

	sequence.advance(SoldierAnimations.SECONDS - 0.01)
	assert_eq(sequence.animation(), first)
	sequence.advance(0.02)

	assert_true(SoldierAnimations.EFFECTS.has(sequence.animation()), "no gap between them")
	assert_eq(sequence.frame(), SoldierAnimations.NEUTRAL)


func test_the_next_effect_is_known_from_the_start_and_is_the_one_that_plays() -> void:
	var sequence: SoldierSequence = _sequence(5)
	var told: String = sequence.next_effect()

	assert_true(SoldierAnimations.EFFECTS.has(told))
	assert_eq(_played(sequence, 2)[1], told)


func test_the_soldier_flashes_the_next_effects_color_as_the_countdown_ends() -> void:
	for random_seed: int in SEEDS:
		var sequence: SoldierSequence = _sequence(random_seed)
		var effect: String = sequence.next_effect()
		var color: Color = sequence.next_color()

		sequence.advance(sequence.seconds_until_flash() - 0.001)
		var before: String = sequence.frame()
		sequence.advance(0.002)

		assert_ne(before, SoldierAnimations.flash_of(effect), "seed %d: not a moment early" % random_seed)
		assert_eq(sequence.frame(), SoldierAnimations.flash_of(effect), "seed %d" % random_seed)
		assert_eq(color, SoldierAnimations.color_of(effect))


func test_the_next_effect_changes_on_the_frame_of_the_flash() -> void:
	var sequence: SoldierSequence = _sequence(6)
	watch_signals(sequence)
	var flashing: String = sequence.next_effect()

	sequence.advance(sequence.seconds_until_flash() - 0.001)
	assert_signal_not_emitted(sequence, "next_effect_changed")
	sequence.advance(0.002)

	assert_signal_emit_count(sequence, "next_effect_changed", 1)
	assert_signal_emitted_with_parameters(sequence, "next_effect_changed", [sequence.next_effect()])
	assert_ne(sequence.next_effect(), flashing, "never the same effect twice in a row")
	assert_eq(sequence.animation(), flashing, "the one flashing is the one playing")
	var expected: float = 2 * SoldierAnimations.SECONDS - SoldierAnimations.seconds_to_flash(flashing) \
			+ SoldierAnimations.seconds_to_flash(sequence.next_effect()) - 0.001
	assert_almost_eq(sequence.seconds_until_flash(), expected, 0.0001,
			"the next flash is two animations on: a transition between")


func test_a_long_frame_that_skips_flashes_tells_of_each_and_keeps_the_rules() -> void:
	var sequence: SoldierSequence = _sequence(7)
	watch_signals(sequence)
	sequence.advance(6 * SoldierAnimations.SECONDS + 1.0)

	assert_signal_emit_count(sequence, "next_effect_changed", 3, "three effects flashed")
	assert_gt(sequence.seconds_until_flash(), 0.0)
	var played: Array[String] = _played(sequence, 10)
	for index: int in range(2, played.size()):
		assert_ne(played[index], played[index - 2])


## A sequence that chooses with [param random_seed].
func _sequence(random_seed: int) -> SoldierSequence:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = random_seed
	return SoldierSequence.new(random)


## The next [param count] animations [param sequence] plays, the one playing now first.
func _played(sequence: SoldierSequence, count: int) -> Array[String]:
	var played: Array[String] = [sequence.animation()]
	while played.size() < count:
		sequence.advance(0.25)
		if sequence.animation() != played.back():
			played.append(sequence.animation())
	return played


## Every other one of [param played], from [param first]: 0 for the transitions, 1 for the
## effects, since the two take turns from a transition.
func _every_other(played: Array[String], first: int) -> Array[String]:
	var picked: Array[String] = []
	for index: int in range(first, played.size(), 2):
		picked.append(played[index])
	return picked


func _sorted(names: Array) -> Array:
	var sorted: Array = names.duplicate()
	sorted.sort()
	return sorted
