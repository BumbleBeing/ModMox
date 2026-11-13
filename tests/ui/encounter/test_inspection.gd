extends GutTest
## Which card the Inspector shows (13h, ADR 0033): the Pinned card and no other. Hovering
## shows nothing (A472).

const BEARS: int = 7
const ANGEL: int = 8


func test_nothing_is_shown_until_a_card_is_pinned() -> void:
	var inspection: Inspection = Inspection.new()

	assert_eq(inspection.shown(), Inspection.NOTHING)
	assert_eq(inspection.pinned(), Inspection.NOTHING)


func test_a_right_click_pins_a_card_and_it_is_shown() -> void:
	var inspection: Inspection = Inspection.new()

	inspection.right_click(BEARS)

	assert_eq(inspection.pinned(), BEARS)
	assert_eq(inspection.shown(), BEARS)


func test_a_second_right_click_on_it_or_one_on_nothing_lets_it_go() -> void:
	var inspection: Inspection = Inspection.new()
	inspection.right_click(BEARS)
	inspection.right_click(BEARS)
	assert_eq(inspection.shown(), Inspection.NOTHING)

	inspection.right_click(BEARS)
	inspection.right_click(Inspection.NOTHING)
	assert_eq(inspection.shown(), Inspection.NOTHING)


func test_a_right_click_on_another_card_pins_that_one() -> void:
	var inspection: Inspection = Inspection.new()
	inspection.right_click(BEARS)

	inspection.right_click(ANGEL)

	assert_eq(inspection.shown(), ANGEL)


func test_letting_go_unpins() -> void:
	var inspection: Inspection = Inspection.new()
	inspection.right_click(BEARS)

	inspection.let_go()

	assert_eq(inspection.shown(), Inspection.NOTHING)


func test_a_right_click_pins_nothing_while_something_is_dragged() -> void:
	var inspection: Inspection = Inspection.new()

	inspection.set_dragging(true)
	inspection.right_click(ANGEL)
	assert_eq(inspection.pinned(), Inspection.NOTHING, "It puts the held thing down.")

	inspection.set_dragging(false)
	inspection.right_click(ANGEL)
	assert_eq(inspection.pinned(), ANGEL)


func test_a_card_that_is_gone_is_forgotten() -> void:
	var inspection: Inspection = Inspection.new()
	inspection.right_click(BEARS)

	inspection.keep_only([BEARS, ANGEL] as Array[int])
	assert_eq(inspection.shown(), BEARS)
	inspection.keep_only([ANGEL] as Array[int])
	assert_eq(inspection.shown(), Inspection.NOTHING)
