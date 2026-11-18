extends GutTest
## Blinking: now and then a Portrait's Blink Portrait shows for a moment, sometimes twice,
## at moments fixed by the encounter's seed.


## When the eyes were shut over [param seconds], in steps of a hundredth of a second, as
## [start, end] pairs.
func _shut_spans(blink: Blink, seconds: float) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	var time: float = 0.0
	var shut_at: float = -1.0
	while time < seconds:
		blink.advance(0.01)
		time += 0.01
		if blink.is_shut() and shut_at < 0.0:
			shut_at = time
		elif not blink.is_shut() and shut_at >= 0.0:
			spans.append(Vector2(shut_at, time))
			shut_at = -1.0
	return spans


func test_it_starts_with_its_eyes_open_and_blinks_before_long() -> void:
	var blink: Blink = Blink.new(7, 0)

	assert_false(blink.is_shut())
	var spans: Array[Vector2] = _shut_spans(blink, Blink.MOST_GAP + 0.5)
	assert_gt(spans.size(), 0)


func test_each_blink_is_brief() -> void:
	for span: Vector2 in _shut_spans(Blink.new(7, 0), 60.0):
		assert_almost_eq(span.y - span.x, Blink.SHUT_SECONDS, 0.02)


func test_blinks_come_now_and_then_sometimes_twice() -> void:
	var spans: Array[Vector2] = _shut_spans(Blink.new(7, 0), 120.0)
	var doubles: int = 0
	for index: int in range(1, spans.size()):
		var open_for: float = spans[index].x - spans[index - 1].y
		if open_for < Blink.LEAST_GAP:
			assert_almost_eq(open_for, Blink.DOUBLE_GAP, 0.02, "A double blink opens only briefly.")
			doubles += 1
		else:
			assert_lt(open_for, Blink.MOST_GAP + 0.02)
	assert_gt(spans.size(), 120.0 / Blink.MOST_GAP)
	assert_gt(doubles, 0, "Some blinks are double.")
	assert_lt(doubles, spans.size() / 2, "Most are single.")


func test_the_seed_fixes_when_each_player_blinks() -> void:
	var first: Array[Vector2] = _shut_spans(Blink.new(7, 0), 20.0)

	assert_eq(_shut_spans(Blink.new(7, 0), 20.0), first)
	assert_ne(_shut_spans(Blink.new(7, 1), 20.0), first, "The two players do not blink together.")
