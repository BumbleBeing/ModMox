extends GutTest
## How Run Won and Run Lost come in (milestone 19): the title rising in, each part dropping in
## a card's gap apart, the gold counting up, the button last.


func test_the_title_rises_into_place_over_a_quarter_second() -> void:
	assert_eq(RunEndReveal.title(0.0), Vector2(RunEndReveal.RISE, 0.0))
	var halfway: Vector2 = RunEndReveal.title(RunEndReveal.TITLE_IN / 2.0)
	assert_between(halfway.x, 0.0, RunEndReveal.RISE)
	assert_almost_eq(halfway.y, 0.5, 0.001)
	assert_eq(RunEndReveal.title(RunEndReveal.TITLE_IN), Vector2(0.0, 1.0))


func test_each_part_drops_in_a_cards_gap_after_the_last() -> void:
	assert_eq(RunEndReveal.part_at(0), RunEndReveal.TITLE_IN)
	assert_almost_eq(RunEndReveal.part_at(3) - RunEndReveal.part_at(2), RunEndReveal.PART_GAP, 0.0001)
	assert_eq(RunEndReveal.part(RunEndReveal.part_at(2), 2), Vector2(-RunEndReveal.DROP, 0.0), "Above its place.")
	assert_eq(RunEndReveal.part(RunEndReveal.part_at(2) + RunEndReveal.PART_IN, 2), Vector2(0.0, 1.0))


func test_the_gold_counts_up_from_zero_with_its_part() -> void:
	assert_eq(RunEndReveal.gold_shown(RunEndReveal.part_at(5), 5, 900), 0)
	assert_between(RunEndReveal.gold_shown(RunEndReveal.part_at(5) + 0.3, 5, 900), 1, 899)
	assert_eq(RunEndReveal.gold_shown(RunEndReveal.part_at(5) + RunEndReveal.COUNT_SECONDS, 5, 900), 900)


func test_the_button_comes_last_once_the_gold_has_counted() -> void:
	var counting: float = RunEndReveal.button_at(6, true)
	var plain: float = RunEndReveal.button_at(3, false)

	assert_almost_eq(counting, RunEndReveal.part_at(5) + RunEndReveal.COUNT_SECONDS, 0.0001)
	assert_almost_eq(plain, RunEndReveal.part_at(2) + RunEndReveal.PART_IN, 0.0001)
	assert_eq(RunEndReveal.button(counting, 6, true), 0.0)
	assert_eq(RunEndReveal.button(counting + RunEndReveal.BUTTON_IN, 6, true), 1.0)
	assert_almost_eq(RunEndReveal.length(6, true), counting + RunEndReveal.BUTTON_IN, 0.0001)
