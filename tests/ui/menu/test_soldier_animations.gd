extends GutTest
## The Menu Soldier's animations: each lasts seven seconds and starts and ends on the neutral
## frame, standing still as long at one end as at the other; the idles are Transition
## Animations, the keywords' looks Effect Animations, and each Effect Animation flashes its
## color on the way in and out.

const IDLES: Array[String] = ["lookout", "doze", "cheer"]
const KEYWORDS: Array[String] = [
	"boost", "lifelink", "deathtouch", "flying", "reach", "vigilance", "haste", "defender",
	"first_strike", "double_strike", "trample", "indestructible", "protection", "menace",
]


func test_the_idles_are_transitions_and_the_keywords_looks_are_effects() -> void:
	assert_eq_deep(SoldierAnimations.TRANSITIONS.keys(), IDLES)
	assert_eq_deep(SoldierAnimations.EFFECTS.keys(), KEYWORDS)


func test_every_animation_lasts_seven_seconds() -> void:
	assert_eq(SoldierAnimations.SECONDS, 7.0)
	for animation: String in _every_animation():
		assert_almost_eq(SoldierAnimations.length_of(animation), 7.0, 0.0001, animation)


func test_every_animation_starts_and_ends_on_the_neutral_frame() -> void:
	for animation: String in _every_animation():
		assert_eq(SoldierAnimations.frame_at(animation, 0.0), SoldierAnimations.NEUTRAL, animation)
		var last: float = SoldierAnimations.SECONDS - 0.001
		assert_eq(SoldierAnimations.frame_at(animation, last), SoldierAnimations.NEUTRAL, animation)


func test_every_animation_stands_still_as_long_at_its_start_as_at_its_end() -> void:
	for animation: String in _every_animation():
		var steps: Array[Array] = SoldierAnimations.steps_of(SoldierAnimations.timeline_of(animation))

		assert_eq(steps[0][0], SoldierAnimations.NEUTRAL, animation)
		assert_eq(steps[-1][0], SoldierAnimations.NEUTRAL, animation)
		assert_almost_eq(steps[0][1] as float, steps[-1][1] as float, 0.0001, animation)
		assert_lt(steps[0][1] as float, 1.0, "%s gets going within a second" % animation)


func test_every_frame_named_is_a_built_sprite() -> void:
	var frames: Array[String] = SoldierAnimations.frames()

	assert_has(frames, SoldierAnimations.NEUTRAL)
	for frame: String in frames:
		assert_true(ResourceLoader.exists(SoldierAnimations.SPRITES % frame), frame)
		assert_eq(frames.count(frame), 1, "%s is listed once" % frame)
	for animation: String in _every_animation():
		for step: Array in SoldierAnimations.steps_of(SoldierAnimations.timeline_of(animation)):
			assert_has(frames, step[0], "%s shows %s" % [animation, step[0]])


func test_every_effect_flashes_its_color_first_on_the_way_in() -> void:
	for effect: String in SoldierAnimations.EFFECTS:
		var flash: String = SoldierAnimations.flash_of(effect)
		var at: float = SoldierAnimations.seconds_to_flash(effect)

		assert_true(SoldierAnimations.FLASH_COLORS.has(flash), "%s flashes %s" % [effect, flash])
		assert_eq(SoldierAnimations.color_of(effect), SoldierAnimations.FLASH_COLORS[flash])
		assert_eq(SoldierAnimations.frame_at(effect, at), flash, effect)
		assert_ne(SoldierAnimations.frame_at(effect, at - 0.001), flash, effect)
		assert_between(at, 0.5, 1.0, "%s stands still a moment first" % effect)


func test_no_transition_flashes() -> void:
	for transition: String in SoldierAnimations.TRANSITIONS:
		for step: Array in SoldierAnimations.steps_of(SoldierAnimations.TRANSITIONS[transition]):
			assert_false(SoldierAnimations.FLASH_COLORS.has(step[0]), "%s: %s" % [transition, step[0]])


func _every_animation() -> Array:
	return SoldierAnimations.TRANSITIONS.keys() + SoldierAnimations.EFFECTS.keys()
