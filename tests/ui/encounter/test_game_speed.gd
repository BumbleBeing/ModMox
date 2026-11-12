extends GutTest
## Game Speed: one setting that scales every wait, move, flight and fade together (13d-2).


func test_each_speed_scales_time_by_its_share() -> void:
	assert_eq(GameSpeed.scale_of(GameSpeed.Speed.SLOW), 2.0)
	assert_eq(GameSpeed.scale_of(GameSpeed.Speed.NORMAL), 1.5)
	assert_eq(GameSpeed.scale_of(GameSpeed.Speed.FAST), 1.0)
	assert_eq(GameSpeed.scale_of(GameSpeed.Speed.BLAZING), 0.5)


func test_waits_and_moves_are_scaled() -> void:
	assert_eq(GameSpeed.msec(500, GameSpeed.Speed.SLOW), 1000)
	assert_eq(GameSpeed.msec(500, GameSpeed.Speed.NORMAL), 750)
	assert_eq(GameSpeed.msec(270, GameSpeed.Speed.NORMAL), 405)
	assert_eq(GameSpeed.msec(270, GameSpeed.Speed.FAST), 270)
	assert_eq(GameSpeed.msec(270, GameSpeed.Speed.BLAZING), 135)
	assert_almost_eq(GameSpeed.seconds(0.25, GameSpeed.Speed.NORMAL), 0.375, 0.0001)
	assert_almost_eq(GameSpeed.seconds(0.25, GameSpeed.Speed.BLAZING), 0.125, 0.0001)


func test_the_speeds_are_listed_slowest_first_with_their_names() -> void:
	assert_eq(GameSpeed.ALL, [GameSpeed.Speed.SLOW, GameSpeed.Speed.NORMAL, GameSpeed.Speed.FAST, GameSpeed.Speed.BLAZING] as Array[GameSpeed.Speed])
	assert_eq(GameSpeed.name_of(GameSpeed.Speed.SLOW), "Slow")
	assert_eq(GameSpeed.name_of(GameSpeed.Speed.NORMAL), "Normal")
	assert_eq(GameSpeed.name_of(GameSpeed.Speed.FAST), "Fast")
	assert_eq(GameSpeed.name_of(GameSpeed.Speed.BLAZING), "Blazing")


func test_a_speed_is_read_back_from_its_name_and_anything_else_is_normal() -> void:
	for speed: GameSpeed.Speed in GameSpeed.ALL:
		assert_eq(GameSpeed.named(GameSpeed.name_of(speed)), speed)
	assert_eq(GameSpeed.named("fast"), GameSpeed.Speed.FAST, "Whatever its capitals.")
	assert_eq(GameSpeed.named("Ludicrous"), GameSpeed.Speed.NORMAL)
	assert_eq(GameSpeed.named(""), GameSpeed.Speed.NORMAL)
	assert_eq(GameSpeed.named("Instant"), GameSpeed.Speed.NORMAL, "A speed the game no longer has.")


func test_no_speed_stops_the_game_from_waiting() -> void:
	for speed: GameSpeed.Speed in GameSpeed.ALL:
		assert_gt(GameSpeed.scale_of(speed), 0.0, GameSpeed.name_of(speed))
