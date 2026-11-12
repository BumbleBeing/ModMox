extends GutTest
## The Hold Panel says "Holding Priority" in large type, and only while the Hold Key is down.

const BOX: Rect2 = Rect2(352, 6, 300, 68)


func test_it_is_hidden_until_the_key_is_down_and_hidden_again_when_it_is_let_go() -> void:
	var panel: HoldPanel = _panel()
	assert_false(panel.visible)

	panel.set_key_down(true)
	assert_true(panel.visible)

	panel.set_key_down(false)
	assert_false(panel.visible)


func test_it_says_holding_priority_in_large_type_inside_its_box() -> void:
	var panel: HoldPanel = _panel()
	panel.set_key_down(true)

	assert_eq(panel.text(), "Holding Priority")
	assert_gte(panel.font_size(), 28, "Larger than anything in the Info Panel.")
	assert_eq(Rect2(panel.position, panel.size), BOX)
	assert_lte(panel.text_width(), BOX.size.x - 16.0, "The words fit on one line.")


func test_it_takes_no_clicks() -> void:
	assert_eq(_panel().mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_moving_it_keeps_whether_it_shows() -> void:
	var panel: HoldPanel = _panel()
	panel.set_key_down(true)

	panel.place(Rect2(10, 10, 300, 68))

	assert_true(panel.visible)
	assert_eq(panel.position, Vector2(10, 10))


func _panel() -> HoldPanel:
	var panel: HoldPanel = HoldPanel.new()
	add_child_autofree(panel)
	panel.place(BOX)
	return panel
