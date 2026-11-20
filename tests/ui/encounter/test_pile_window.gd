extends GutTest
## The Zone Window of a graveyard, exile or library: a grid of Card Faces, the newest
## first, or for a library one row with card backs for the cards the Hero does not know.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const CARD: Vector2 = Vector2(PileWindow.CARD_HEIGHT * CardGeometry.ASPECT, PileWindow.CARD_HEIGHT)

var _snapshot: EncounterSnapshot
var _clicked: Array[int] = []


func before_each() -> void:
	_clicked.clear()
	_snapshot = EncounterSnapshot.new()
	_snapshot.view = MmPlayerView.new()
	_snapshot.view.viewer_id = HERO


func after_each() -> void:
	await wait_process_frames(2)


func test_a_graveyard_shows_its_cards_newest_first() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)

	window.show_cards("Hero's Graveyard", _cards([4, 9, 12]), _snapshot, _none())

	assert_eq(window.entries(), [12, 9, 4] as Array[int], "The zone's last card is the one put there last.")
	assert_not_null(window.face_of(12))
	assert_eq(window.face_of(9).title_text().shown_text(), "Card 9")


func test_a_graveyards_flashback_card_shows_its_flashback_chip() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID, true)

	window.show_cards("Hero's Graveyard", [_card(4), _flashback_card(9)], _snapshot, _none())

	assert_eq(window.face_of(9).chips().size(), 1)
	assert_eq(window.face_of(4).chips().size(), 0)


func test_an_exiled_flashback_card_shows_no_chip() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)

	window.show_cards("Hero's Exile", [_flashback_card(9)], _snapshot, _none())

	assert_eq(window.face_of(9).chips().size(), 0)


func test_it_is_titled_with_whose_zone_it_is_and_how_many_cards_it_holds() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)

	window.show_cards("Jackson's Graveyard", _cards([4, 9]), _snapshot, _none())
	assert_eq(window.title_text(), "Jackson's Graveyard (2)")

	window.show_cards("Jackson's Graveyard", _cards([4, 9, 12]), _snapshot, _none())
	assert_eq(window.title_text(), "Jackson's Graveyard (3)")


func test_an_empty_zone_is_an_empty_window() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)

	window.show_cards("Hero's Exile", [], _snapshot, _none())

	assert_eq(window.title_text(), "Hero's Exile (0)")
	assert_eq(window.entries(), [] as Array[int])


func test_a_grid_wraps_its_cards_to_the_windows_width() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)
	window.size = Vector2(2.0 * CARD.x + 60.0, 420.0)

	window.show_cards("Hero's Graveyard", _cards([1, 2, 3]), _snapshot, _none())
	await wait_process_frames(2)

	var rects: Array[Rect2] = window.card_rects()
	assert_almost_eq(rects[0].position.y, rects[1].position.y, 0.5, "Two fit across.")
	assert_gt(rects[1].position.x, rects[0].end.x - 0.5)
	assert_gt(rects[2].position.y, rects[0].end.y - 0.5, "The third starts a new row.")
	assert_almost_eq(rects[2].position.x, rects[0].position.x, 0.5)


func test_a_card_flies_to_its_own_place_in_the_window_while_that_is_in_sight() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)
	window.size = Vector2(2.0 * CARD.x + 60.0, CARD.y + 100.0)
	window.show_cards("Hero's Exile", _cards([1, 2, 3, 4, 5, 6]), _snapshot, _none())
	await wait_process_frames(2)

	var place: Rect2 = window.flight_place(6)

	assert_eq(window.hidden_past(6), 0, "The newest card is first.")
	assert_almost_eq(place.position, window.card_rects()[0].get_center(), Vector2(0.5, 0.5))
	assert_eq(place.size.y, PileWindow.CARD_HEIGHT)


func test_a_card_scrolled_out_of_sight_flies_to_the_nearest_edge_above_or_below() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)
	window.size = Vector2(2.0 * CARD.x + 60.0, CARD.y + 100.0)
	window.show_cards("Hero's Exile", _cards([1, 2, 3, 4, 5, 6]), _snapshot, _none())
	await wait_process_frames(2)
	var seen: Rect2 = Rect2(window.scroll().global_position - window.global_position, window.scroll().size)

	assert_eq(window.hidden_past(1), 1, "The oldest card is in the third row, below.")
	var below: Rect2 = window.flight_place(1)
	assert_almost_eq(below.position.y, seen.end.y, 0.5, "On the bottom edge of what the window shows,")
	assert_almost_eq(below.position.x, window.card_rects()[5].get_center().x, 0.5, "under its own column,")
	assert_lt(below.size.y, PileWindow.CARD_HEIGHT, "and small.")

	window.scroll().scroll_vertical = 100000
	await wait_process_frames(2)

	assert_eq(window.hidden_past(1), 0)
	assert_eq(window.hidden_past(6), -1, "Now the newest is above.")
	assert_almost_eq(window.flight_place(6).position.y, seen.position.y, 0.5)


func test_a_card_the_window_does_not_show_is_nowhere_out_of_sight_and_flies_to_its_middle() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)
	window.show_cards("Hero's Exile", _cards([1]), _snapshot, _none())

	assert_eq(window.hidden_past(99), 0)
	assert_eq(window.flight_place(99).position, window.size / 2.0)


func test_a_window_first_opens_with_room_for_four_cards_across() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)

	window.show_cards("Hero's Graveyard", _cards([1, 2, 3, 4, 5]), _snapshot, _none())
	await wait_process_frames(2)

	var rects: Array[Rect2] = window.card_rects()
	assert_almost_eq(rects[3].position.y, rects[0].position.y, 0.5)
	assert_gt(rects[4].position.y, rects[0].position.y + 1.0)


func test_a_library_is_one_row_with_its_top_card_on_the_left() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.ROW)
	var cards: Array = [null, null, null, null, null, null, null]
	cards.append(_card(7))

	window.show_cards("Hero's Library", cards, _snapshot, _none())
	await wait_process_frames(2)

	assert_eq(window.entries(), [0, 0, 0, 0, 0, 0, 0, 7] as Array[int], "In the library's own order, top first.")
	assert_eq(window.title_text(), "Hero's Library (8)")
	var rects: Array[Rect2] = window.card_rects()
	for index: int in range(1, rects.size()):
		assert_almost_eq(rects[index].position.y, rects[0].position.y, 0.5, "One row, however many cards.")
		assert_gt(rects[index].position.x, rects[index - 1].position.x)
	assert_gt(rects[7].end.x, window.size.x, "It runs past the window, which scrolls sideways.")
	assert_eq(window.scroll().vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "And never down.")
	assert_not_null(window.face_of(7), "A card the Hero knows is face up.")
	assert_eq(window.face_of(7).title_text().shown_text(), "Card 7")
	assert_null(window.face_of(0))


func test_a_card_that_answers_glows_and_is_clicked() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)
	var cards: Array = _cards([4, 9])
	_snapshot.view.graveyards = {HERO: cards}
	var decision: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 20, 0, [MmReference.to_object(9)] as Array[MmReference])

	window.show_cards("Hero's Graveyard", cards, _snapshot, DecisionClicks.of(decision, _snapshot.view))

	assert_eq(BorderEffects.glow_colors(window.face_of(9)), [DecisionClicks.color_of(DecisionClicks.Kind.TARGET)] as Array[Color])
	assert_eq(BorderEffects.glow_colors(window.face_of(4)), [] as Array[Color])
	assert_null(window.catcher_of(4), "A card that answers nothing takes no click.")
	window.catcher_of(9).clicked.emit()
	assert_eq(_clicked, [9] as Array[int])


func test_every_card_has_room_around_it_for_its_glow() -> void:
	for arrangement: PileWindow.Arrangement in [PileWindow.Arrangement.GRID, PileWindow.Arrangement.ROW]:
		var window: PileWindow = _window(arrangement)

		window.show_cards("Hero's Graveyard", _cards([1, 2]), _snapshot, _none())
		await wait_process_frames(2)

		# A Glow reaches 7 pixels past its card, and the window draws nothing outside what scrolls.
		var shown: Rect2 = Rect2(window.scroll().global_position - window.global_position, window.scroll().size)
		var first: Rect2 = window.card_rects()[0]
		assert_gte(first.position.x - shown.position.x, 7.0, "On the left.")
		assert_gte(first.position.y - shown.position.y, 7.0, "Above.")
		assert_gte(shown.end.y - first.end.y, 7.0, "Below.")


func test_a_snapshot_that_changes_nothing_here_rebuilds_nothing() -> void:
	var window: PileWindow = _window(PileWindow.Arrangement.GRID)
	var cards: Array = _cards([4, 9])
	_snapshot.view.graveyards = {HERO: cards}
	window.show_cards("Hero's Graveyard", cards, _snapshot, _none())
	var face: CardFace = window.face_of(9)

	window.show_cards("Hero's Graveyard", cards, _snapshot, _none())
	assert_same(window.face_of(9), face)

	var decision: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 20, 0, [MmReference.to_object(9)] as Array[MmReference])
	window.show_cards("Hero's Graveyard", cards, _snapshot, DecisionClicks.of(decision, _snapshot.view))
	assert_not_same(window.face_of(9), face, "What answers changed, so it is drawn again.")


func test_a_top_card_the_hero_may_look_at_shows_face_up_first_among_the_backs_and_casts() -> void:
	# Game ADR 0055.
	var window: PileWindow = _window(PileWindow.Arrangement.ROW)
	var top: MmObjectView = _card(5)
	var library: Array = [top, null, null]
	_snapshot.view.libraries[HERO] = library
	var clicks: DecisionClicks = DecisionClicks.of(PriorityDecision.new(HERO,
		[PassAction.new(), CastSpellAction.new(5)] as Array[MmAction]), _snapshot.view)
	var hovered: Array = []
	window.card_hovered.connect(func(object_id: int, is_over: bool) -> void: hovered.append([object_id, is_over]))

	window.show_cards("Hero's Library", library, _snapshot, clicks)

	assert_eq(window.title_text(), "Hero's Library (3)")
	assert_eq(window.entries(), [5, PileWindow.UNKNOWN, PileWindow.UNKNOWN] as Array[int], "The whole library, the top card face up.")
	assert_eq(BorderEffects.glow_colors(window.face_of(5)), [Color("#7be36a")] as Array[Color])
	window.catcher_of(5).clicked.emit()
	assert_eq(_clicked, [5] as Array[int])
	window.catcher_of(5).mouse_entered.emit()
	window.catcher_of(5).mouse_exited.emit()
	assert_eq(hovered, [[5, true], [5, false]])


func _window(arrangement: PileWindow.Arrangement, is_graveyard: bool = false) -> PileWindow:
	var window: PileWindow = PileWindow.new(arrangement, Color.GRAY, is_graveyard)
	add_child_autofree(window)
	window.card_clicked.connect(func(object_id: int) -> void: _clicked.append(object_id))
	return window


func _none() -> DecisionClicks:
	return DecisionClicks.of(null, _snapshot.view)


func _cards(ids: Array[int]) -> Array:
	var cards: Array = []
	for id: int in ids:
		cards.append(_card(id))
	return cards


func _card(id: int) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.name = "Card %d" % id
	_snapshot.looks[id] = CardLook.of_view(seen)
	return seen


func _flashback_card(id: int) -> MmObjectView:
	var seen: MmObjectView = _card(id)
	_snapshot.looks[id].abilities = [FlashbackAbility.new()] as Array[MmAbility]
	return seen
