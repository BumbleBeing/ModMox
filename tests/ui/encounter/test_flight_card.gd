extends GutTest
## The Flight Card: a card drawn in the air, as what it was where it left and as what it is
## where it lands (13d-2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_a_card_is_drawn_as_its_zone_shows_it() -> void:
	assert_eq(FlightCard.kind_in(MmZone.Kind.BATTLEFIELD), FlightCard.Kind.FIELD)
	assert_eq(FlightCard.kind_in(MmZone.Kind.LIBRARY), FlightCard.Kind.BACK)
	for zone_kind: MmZone.Kind in [MmZone.Kind.HAND, MmZone.Kind.STACK, MmZone.Kind.GRAVEYARD, MmZone.Kind.EXILE]:
		assert_eq(FlightCard.kind_in(zone_kind), FlightCard.Kind.CARD)


func test_a_card_that_changes_shape_fades_from_one_face_into_the_other_and_is_never_see_through() -> void:
	var card: FlightCard = _card(FlightCard.Kind.CARD, _look(), FlightCard.Kind.FIELD, _look())

	assert_true(card.leaving_face() is CardFace)
	assert_true(card.landing_face() is BattlefieldFace)
	card.show_pose(FacePose.of(Vector2(400, 300), 200.0, 0.0), 0.0)
	assert_eq(card.leaving_face().modulate.a, 1.0)
	assert_eq(card.landing_face().modulate.a, 0.0)
	card.show_pose(FacePose.of(Vector2(400, 300), 200.0, 0.0), 0.5)
	assert_eq(card.leaving_face().modulate.a, 1.0, "Both are solid half-way.")
	assert_eq(card.landing_face().modulate.a, 1.0)
	card.show_pose(FacePose.of(Vector2(400, 300), 200.0, 0.0), 1.0)
	assert_eq(card.leaving_face().modulate.a, 0.0)
	assert_eq(card.landing_face().modulate.a, 1.0)


func test_a_card_that_keeps_its_shape_is_one_face() -> void:
	var card: FlightCard = _card(FlightCard.Kind.CARD, _look(), FlightCard.Kind.CARD, _look())

	assert_true(card.leaving_face() is CardFace)
	assert_null(card.landing_face())
	card.show_pose(FacePose.of(Vector2(400, 300), 200.0, 0.0), 0.5)
	assert_eq(card.leaving_face().modulate.a, 1.0)


func test_a_card_nobody_may_see_is_a_card_back() -> void:
	var hidden: FlightCard = _card(FlightCard.Kind.BACK, null, FlightCard.Kind.CARD, null)
	var drawn: FlightCard = _card(FlightCard.Kind.BACK, null, FlightCard.Kind.CARD, _look())

	assert_true(hidden.is_face_down(), "With no look at either end it is a back all the way.")
	assert_null(hidden.landing_face())
	assert_false(drawn.is_face_down(), "A card the Hero draws turns face up.")
	assert_false(drawn.leaving_face() is CardFace)
	assert_true(drawn.landing_face() is CardFace)


func test_it_is_drawn_about_its_middle_at_the_poses_height_turn_and_solidity() -> void:
	var card: FlightCard = _card(FlightCard.Kind.FIELD, _look(), FlightCard.Kind.CARD, _look())

	card.show_pose(FacePose.of(Vector2(400, 300), 125.0, 0.5, 0.4), 0.0)

	var field: BattlefieldFace = card.leaving_face() as BattlefieldFace
	assert_eq(card.position, Vector2(400, 300))
	assert_almost_eq(card.modulate.a, 0.4, 0.001)
	assert_almost_eq(field.get_global_rect().get_center(), card.global_position, Vector2(0.5, 0.5))
	assert_almost_eq(field.scale.y * field.card().size.y, 125.0, 0.01)
	assert_almost_eq(field.turn(), 0.5, 0.001)
	assert_almost_eq(card.landing_face().scale.y * card.landing_face().size.y, 125.0, 0.01)


func test_it_takes_no_clicks() -> void:
	var card: FlightCard = _card(FlightCard.Kind.CARD, _look(), FlightCard.Kind.FIELD, _look())

	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(card.leaving_face().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(card.landing_face().mouse_filter, Control.MOUSE_FILTER_IGNORE)


func _card(from_kind: FlightCard.Kind, from_look: CardLook, to_kind: FlightCard.Kind, to_look: CardLook) -> FlightCard:
	var card: FlightCard = FlightCard.new(from_kind, from_look, to_kind, to_look)
	add_child_autofree(card)
	return card


func _look() -> CardLook:
	return CardLook.of_characteristics(MmCharacteristics.printed(Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))))
