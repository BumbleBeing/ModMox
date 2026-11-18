extends GutTest
## Which cards in exile are Tucked Cards (game ADR 0043): a card is tucked behind the
## permanent that exiled it while that permanent stands on the battlefield, and is in the
## exile pile like any other once it has gone.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_tucked_cards_are_listed_under_the_permanent_that_exiled_them_in_id_order() -> void:
	var view: MmPlayerView = _view({HERO: [_card(12, 4), _card(9, 0)], VILLAIN: [_card(8, 4), _card(15, 5)]})

	var tucked: Dictionary[int, Array] = Tucks.by_host(view, [4, 5] as Array[int])

	assert_eq(_ids(tucked[4]), [8, 12], "Whoever owns them.")
	assert_eq(_ids(tucked[5]), [15])
	assert_eq(tucked.size(), 2)


func test_a_card_whose_permanent_has_gone_is_not_tucked() -> void:
	var view: MmPlayerView = _view({HERO: [_card(12, 4), _card(9, 0)]})

	assert_eq(Tucks.by_host(view, [5] as Array[int]).size(), 0)
	assert_eq(Tucks.owners(view, [5] as Array[int]).size(), 0)


func test_each_tucked_card_is_known_by_its_owner() -> void:
	var view: MmPlayerView = _view({HERO: [_card(12, 4)], VILLAIN: [_card(8, 4), _card(15, 0)]})

	assert_eq(Tucks.owners(view, [4] as Array[int]), {12: HERO, 8: VILLAIN} as Dictionary[int, int])


func test_the_loose_cards_of_an_exile_are_those_not_tucked_in_the_zones_order() -> void:
	var cards: Array = [_card(3, 0), _card(8, 4), _card(15, 7), _card(16, 4)]

	assert_eq(_ids(Tucks.loose(cards, [4] as Array[int])), [3, 15])


func _view(exiles: Dictionary) -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	for player_id: int in exiles:
		view.exiles[player_id] = exiles[player_id]
	return view


func _card(id: int, exiled_with: int) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	seen.exiled_with_object_id = exiled_with
	return seen


func _ids(views: Array) -> Array[int]:
	var ids: Array[int] = []
	for seen: MmObjectView in views:
		ids.append(seen.id)
	return ids
