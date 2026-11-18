extends GutTest
## Breath (game glossary): a Portrait's slow grow and shrink, at its character's Breath Rate
## and Breath Intensity, faster at low life, Winded when hurt, and still once its player has
## lost.

const EPSILON: float = 0.0001


func test_at_rate_one_a_breath_takes_four_seconds_and_rate_scales_it() -> void:
	assert_almost_eq(Breath.seconds_per_breath(1.0, 20, 20), 4.0, EPSILON)
	assert_almost_eq(Breath.seconds_per_breath(2.0, 20, 20), 2.0, EPSILON)
	assert_almost_eq(Breath.seconds_per_breath(0.5, 20, 20), 8.0, EPSILON)


func test_above_half_life_the_rate_is_the_characters_own() -> void:
	assert_almost_eq(Breath.life_factor(20, 20), 1.0, EPSILON)
	assert_almost_eq(Breath.life_factor(10, 20), 1.0, EPSILON)


func test_below_half_life_the_rate_climbs_to_twice_at_one_life() -> void:
	assert_almost_eq(Breath.life_factor(1, 20), 2.0, EPSILON)
	assert_almost_eq(Breath.life_factor(0, 20), 2.0, EPSILON, "No faster than at 1 life.")
	assert_almost_eq(Breath.life_factor(-3, 20), 2.0, EPSILON)
	# Half of 20 is 10, so 5.5 life is halfway from 10 down to 1.
	var halfway: float = Breath.life_factor(5, 20)
	assert_gt(halfway, 1.5)
	assert_lt(halfway, 1.6)
	assert_almost_eq(Breath.seconds_per_breath(1.0, 1, 20), 2.0, EPSILON)


func test_a_breath_eases_in_to_the_top_halfway_and_eases_out_to_the_bottom() -> void:
	assert_almost_eq(Breath.fullness_at(0.0), 0.0, EPSILON)
	assert_almost_eq(Breath.fullness_at(0.5), 1.0, EPSILON, "The top is halfway through.")
	assert_almost_eq(Breath.fullness_at(1.0), 0.0, EPSILON)
	assert_almost_eq(Breath.fullness_at(0.25), 0.5, EPSILON)
	assert_almost_eq(Breath.fullness_at(0.2), Breath.fullness_at(0.8), EPSILON, "Out as it went in.")
	# Eased: it moves least at the top and bottom and most in between.
	var near_bottom: float = Breath.fullness_at(0.05) - Breath.fullness_at(0.0)
	var middle: float = Breath.fullness_at(0.3) - Breath.fullness_at(0.25)
	var near_top: float = Breath.fullness_at(0.5) - Breath.fullness_at(0.45)
	assert_lt(near_bottom, middle / 4.0)
	assert_lt(near_top, middle / 4.0)


func test_intensity_is_how_many_art_pixels_it_grows_at_the_top() -> void:
	var breath: Breath = Breath.new(1.0, 2.0)
	breath.advance(2.0, 20, 20)

	assert_almost_eq(breath.growth(), 2.0, EPSILON)


func test_breathing_goes_round_and_round() -> void:
	var breath: Breath = Breath.new(1.0, 1.0)
	breath.advance(2.0, 20, 20)
	var halfway: float = breath.growth()
	breath.advance(4.0, 20, 20)

	assert_almost_eq(breath.growth(), halfway, EPSILON)


func test_at_low_life_it_breathes_faster() -> void:
	var calm: Breath = Breath.new(1.0, 1.0)
	var panting: Breath = Breath.new(1.0, 1.0)
	calm.advance(0.4, 20, 20)
	panting.advance(0.4, 1, 20)

	assert_gt(panting.growth(), calm.growth())


func test_winded_it_sinks_quickly_to_the_bottom_and_stays() -> void:
	var breath: Breath = Breath.new(1.0, 1.0)
	breath.advance(2.0, 20, 20)
	var top: float = breath.growth()

	breath.wind()
	assert_true(breath.is_winded())
	breath.advance(Breath.WINDED_SECONDS / 2.0, 20, 20)
	var sinking: float = breath.growth()
	assert_lt(sinking, top)
	assert_gt(sinking, 0.0)
	breath.advance(Breath.WINDED_SECONDS, 20, 20)
	assert_almost_eq(breath.growth(), 0.0, EPSILON)
	breath.advance(10.0, 20, 20)
	assert_almost_eq(breath.growth(), 0.0, EPSILON, "It stays at the bottom until it catches its breath.")


func test_hurt_again_while_winded_it_stays_at_the_bottom() -> void:
	var breath: Breath = Breath.new(1.0, 1.0)
	breath.advance(1.0, 20, 20)
	breath.wind()
	breath.advance(1.0, 20, 20)
	breath.wind()
	breath.advance(0.01, 20, 20)

	assert_almost_eq(breath.growth(), 0.0, EPSILON)


func test_catching_its_breath_it_starts_a_new_breath_from_the_bottom() -> void:
	var breath: Breath = Breath.new(1.0, 1.0)
	breath.advance(1.0, 20, 20)
	breath.wind()
	breath.advance(1.0, 20, 20)

	breath.catch_breath()
	assert_false(breath.is_winded())
	assert_almost_eq(breath.phase, 0.0, EPSILON)
	breath.advance(1.0, 20, 20)
	assert_gt(breath.growth(), 0.0, "It breathes in.")


func test_a_player_who_lost_sinks_and_never_breathes_again() -> void:
	var breath: Breath = Breath.new(1.0, 1.0)
	breath.advance(1.0, 20, 20)

	breath.stop()
	breath.advance(1.0, 20, 20)
	breath.catch_breath()
	breath.advance(1.0, 20, 20)

	assert_true(breath.is_stopped())
	assert_almost_eq(breath.growth(), 0.0, EPSILON)


func test_where_each_player_starts_comes_from_the_seed() -> void:
	var start: float = Breath.start_phase(7, 0)

	assert_eq(Breath.start_phase(7, 0), start, "The same seed starts the same.")
	assert_ne(Breath.start_phase(7, 1), start, "The two players do not breathe in step.")
	assert_true(start >= 0.0 and start < 1.0)
