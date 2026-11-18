extends GutTest
## How long a hurt player's Pain Portrait shows (game glossary), and who was hurt between two
## snapshots: whoever's life total went down, counted net.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const NORMAL: GameSpeed.Speed = GameSpeed.Speed.NORMAL


func test_the_hold_at_normal_speed_grows_with_the_life_lost() -> void:
	for pair: Array in [[1, 0.3], [2, 0.3], [3, 0.5], [6, 0.5], [7, 0.8], [10, 0.8], [11, 1.3], [40, 1.3]]:
		assert_almost_eq(PainHold.seconds(pair[0] as int, NORMAL), pair[1] as float, 0.0001, "%d life lost" % pair[0])


func test_the_hold_scales_with_the_game_speed_as_everything_else_does() -> void:
	assert_almost_eq(PainHold.seconds(3, GameSpeed.Speed.SLOW), 0.75, 0.0001)
	assert_almost_eq(PainHold.seconds(3, GameSpeed.Speed.FAST), 0.375, 0.0001)
	assert_almost_eq(PainHold.seconds(3, GameSpeed.Speed.BLAZING), 0.25, 0.0001)


func test_a_player_whose_life_went_down_was_hurt_by_the_net_amount() -> void:
	var losses: Dictionary[int, int] = PainHold.losses(_snapshot(20, 20), _snapshot(14, 21))

	assert_eq(losses, {HERO: 6} as Dictionary[int, int], "The Villain gained, so only the Hero was hurt.")


func test_losing_and_gaining_as_much_at_once_hurts_no_one() -> void:
	assert_true(PainHold.losses(_snapshot(20, 20), _snapshot(20, 20)).is_empty())


func test_nothing_hurts_on_an_undo_or_with_no_snapshot_before() -> void:
	var undone: EncounterSnapshot = _snapshot(17, 20)
	undone.is_rewind = true

	assert_true(PainHold.losses(_snapshot(20, 20), undone).is_empty(), "ADR 0015: an undo is never animated.")
	assert_true(PainHold.losses(null, _snapshot(3, 20)).is_empty(), "The first snapshot has nothing to lose from.")


func _snapshot(hero_life: int, villain_life: int) -> EncounterSnapshot:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.life_totals = {HERO: hero_life, VILLAIN: villain_life}
	return snapshot
