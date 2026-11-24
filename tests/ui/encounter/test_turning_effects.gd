extends GutTest
## A Battlefield Face's border effects are drawn on the part of it that turns, so the Glow,
## the mark, the Pinned ring and the pointer lie round the card all the way through a tap,
## not round the footprint it is turning in.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const HEIGHT: float = 140.0
const PAIR: Array[Color] = [Color.GREEN, Color.BLUE]


func after_each() -> void:
	await wait_process_frames(2)


func test_a_battlefield_faces_glow_is_drawn_round_its_card_and_turns_with_it() -> void:
	var face: BattlefieldFace = _face()

	BorderEffects.add_glow(face, face.size, Color.GREEN)
	face.show_turn(0.5)

	var glow: Control = face.card().get_node_or_null(BorderEffects.GLOW) as Control
	assert_not_null(glow, "On the part that turns.")
	assert_null(face.get_node_or_null(BorderEffects.GLOW), "Not on the footprint.")
	assert_almost_eq(glow.get_global_transform().get_rotation(), PI / 4.0, 0.0001)
	var hard: Control = glow.get_child(1) as Control
	assert_eq(hard.size, face.card().size + Vector2(6, 6))
	assert_almost_eq(hard.get_global_transform() * (hard.size / 2.0), face.global_position + face.size / 2.0,
			Vector2(0.01, 0.01), "Round the middle of the card.")


func test_a_tapped_faces_glow_is_made_for_the_card_and_not_for_its_sideways_footprint() -> void:
	var face: BattlefieldFace = _face(true)
	assert_ne(face.size, face.card().size, "Its footprint lies sideways.")

	BorderEffects.add_glow(face, face.size, Color.GREEN)

	var hard: Control = face.card().get_node(BorderEffects.GLOW).get_child(1) as Control
	assert_eq(hard.size, face.card().size + Vector2(6, 6))
	assert_almost_eq(_drawn(hard).size, face.size + Vector2(6, 6), Vector2(0.01, 0.01),
			"Turned with the card, it lies round the footprint.")
	assert_almost_eq(_drawn(hard).get_center(), face.global_position + face.size / 2.0, Vector2(0.01, 0.01))

	face.show_turn(0.0)

	assert_almost_eq(_drawn(hard).size, face.card().size + Vector2(6, 6), Vector2(0.01, 0.01),
			"And stands up with it.")


func test_a_glow_of_two_colors_turns_with_the_card_too() -> void:
	var face: BattlefieldFace = _face()

	BorderEffects.add_glow_of(face, face.size, PAIR)
	face.show_turn(1.0)

	var glow: Control = face.card().get_node(BorderEffects.GLOW) as Control
	for outline: Node in glow.get_children():
		assert_eq((outline as SplitOutline).size, face.card().size)
	assert_almost_eq(glow.get_global_transform().get_rotation(), PI / 2.0, 0.0001)


func test_a_battlefield_face_is_still_asked_about_its_own_glow() -> void:
	var face: BattlefieldFace = _face()

	BorderEffects.add_glow_of(face, face.size, PAIR)

	assert_eq(BorderEffects.glow_colors(face), PAIR)
	assert_eq(BorderEffects.glow_color(face), Color.GREEN)
	assert_true(BorderEffects.is_glow_showing(face))
	var glow: Node = face.card().get_node(BorderEffects.GLOW)

	BorderEffects.set_glow_of(face, face.size, PAIR.duplicate())
	assert_eq(face.card().get_node(BorderEffects.GLOW), glow, "The same Glow: nothing changed.")

	BorderEffects.set_glow(face, face.size, Color.RED)
	assert_eq(BorderEffects.glow_color(face), Color.RED)

	BorderEffects.remove_glow(face)
	assert_null(BorderEffects.glow_color(face))


func test_a_battlefield_faces_mark_turns_with_its_card_and_hides_its_glow() -> void:
	var face: BattlefieldFace = _face()
	BorderEffects.add_glow(face, face.size, Color.GREEN)

	BorderEffects.add_mark(face, face.size, Color.RED, false)
	face.show_turn(0.5)

	var mark: Control = face.card().get_node_or_null(BorderEffects.MARK) as Control
	assert_not_null(mark, "On the part that turns.")
	assert_eq(BorderEffects.mark_color(face), Color.RED)
	assert_almost_eq(mark.get_global_transform().get_rotation(), PI / 4.0, 0.0001)
	assert_eq((mark.get_child(1) as Control).size, face.card().size + Vector2(6, 6))
	assert_false(BorderEffects.is_glow_showing(face), "The mark takes the Glow's place.")

	BorderEffects.remove_mark(face)

	assert_null(BorderEffects.mark_color(face))
	assert_true(BorderEffects.is_glow_showing(face))


func test_a_dashed_mark_turns_with_the_card() -> void:
	var face: BattlefieldFace = _face(true)

	BorderEffects.add_mark(face, face.size, Color.RED, true)

	var mark: Control = face.card().get_node(BorderEffects.MARK) as Control
	assert_true(BorderEffects.is_mark_dashed(face))
	assert_eq((mark.get_child(0) as Control).size, face.card().size)


func test_the_pinned_ring_and_the_pointer_turn_with_the_card() -> void:
	var face: BattlefieldFace = _face()

	BorderEffects.add_pin(face, face.size)
	BorderEffects.add_pointer(face, face.size)
	face.show_turn(0.5)

	assert_true(BorderEffects.has_pin(face))
	assert_true(BorderEffects.has_pointer(face))
	var ring: Control = face.card().get_node(BorderEffects.PIN).get_child(0) as Control
	var pointer: Control = face.card().get_node(BorderEffects.POINTER) as Control
	assert_eq(ring.size, face.card().size + Vector2(8, 8))
	assert_eq(pointer.size, face.card().size + Vector2(10, 10))
	assert_almost_eq(ring.get_global_transform().get_rotation(), PI / 4.0, 0.0001)
	assert_almost_eq(pointer.get_global_transform().get_rotation(), PI / 4.0, 0.0001)

	BorderEffects.remove_pin(face)
	BorderEffects.remove_pointer(face)

	assert_false(BorderEffects.has_pin(face))
	assert_false(BorderEffects.has_pointer(face))


func test_anything_else_bears_its_own_effects() -> void:
	var host: Control = Control.new()
	add_child_autofree(host)

	BorderEffects.add_glow(host, Vector2(100, 140), Color.GREEN)

	assert_eq(BorderEffects.bearer_of(host), host)
	assert_eq(host.get_node(BorderEffects.GLOW).get_parent(), host)
	assert_eq((host.get_node(BorderEffects.GLOW).get_child(1) as Control).size, Vector2(106, 146))


## The rectangle [param drawn] covers on screen, however it is turned.
func _drawn(drawn: Control) -> Rect2:
	return drawn.get_global_transform() * Rect2(Vector2.ZERO, drawn.size)


func _face(is_tapped: bool = false) -> BattlefieldFace:
	var look: CardLook = CardLook.of_definition(load(ALPHA % "grizzly_bears") as MmCardDefinition)
	look.is_tapped = is_tapped
	var face: BattlefieldFace = BattlefieldFace.new()
	add_child_autofree(face)
	face.setup(look, HEIGHT)
	return face
