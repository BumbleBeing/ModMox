extends GutTest
## Scenery (ADR 0038, milestone 17): the Stage Map places each Stage's Scenery Kinds at
## random from the run's scenery seed, under its rules: wholly on the Map Backdrop, clear of
## every Node's edge by 40 pixels and every link by 16, and clear of each other.

const SEEDS: int = 25


## A Kind [param side] pixels square at [param scale], placing [param least] to [param most].
func _kind(side: int, scale: int, least: int, most: int, frames: int = 1) -> SceneryKind:
	var kind: SceneryKind = SceneryKind.new()
	kind.name = "Test %d" % side
	for frame: int in frames:
		var image: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color(frame / 4.0, 0.5, 0.5))
		kind.frames.append(ImageTexture.create_from_image(image))
	kind.scale = scale
	kind.least = least
	kind.most = most
	kind.frames_per_second = 4.0 if frames > 1 else 0.0
	return kind


## A visit of a debug run with [param seed] to a Stage holding only [param kinds].
func _visit(run_seed: int, kinds: Array[SceneryKind]) -> StageVisit:
	var stage: StageDefinition = (load("res://content/stages/kitty_keep.tres") as StageDefinition).duplicate()
	stage.scenery = kinds
	return Run.debug(run_seed, stage).stage_visit


## SC1: the same Run Seed places the same Scenery.
func test_the_same_run_seed_places_the_same_scenery() -> void:
	var kinds: Array[SceneryKind] = [_kind(16, 4, 3, 6), _kind(32, 4, 2, 4)]
	var first: Array[SceneryPiece] = SceneryLayout.place(_visit(7, kinds))
	var second: Array[SceneryPiece] = SceneryLayout.place(_visit(7, kinds))
	var other: Array[SceneryPiece] = SceneryLayout.place(_visit(8, kinds))

	assert_gt(first.size(), 0)
	assert_eq(_described(first), _described(second))
	assert_ne(_described(first), _described(other))


## SC2: no piece breaks a rule, over many seeds.
func test_no_piece_breaks_a_rule() -> void:
	var kinds: Array[SceneryKind] = [_kind(32, 4, 4, 8), _kind(16, 3, 6, 12), _kind(16, 4, 4, 8)]
	for run_seed: int in SEEDS:
		var visit: StageVisit = _visit(run_seed, kinds)
		var pieces: Array[SceneryPiece] = SceneryLayout.place(visit)
		var bounds: Rect2 = StageMapLayout.map_backdrop_rect(1.0)
		for index: int in pieces.size():
			var rect: Rect2 = pieces[index].rect
			assert_true(bounds.encloses(rect), "Seed %d: on the Map Backdrop." % run_seed)
			for node: MapNode in visit.map.nodes:
				var spot: Vector2 = StageMapLayout.node_spot(node, visit.offsets[node.id], 1.0)
				assert_gte(SceneryLayout.distance_to_point(rect, spot) - StageMapLayout.radius_of(node.kind),
						SceneryLayout.NODE_CLEARANCE, "Seed %d: clear of Node %d." % [run_seed, node.id])
			for link: PackedVector2Array in SceneryLayout.links(visit):
				assert_gte(SceneryLayout.distance_to_segment(rect, link[0], link[1]), SceneryLayout.LINK_CLEARANCE,
						"Seed %d: clear of a link." % run_seed)
			for other: int in range(index + 1, pieces.size()):
				assert_false(rect.intersects(pieces[other].rect), "Seed %d: pieces do not overlap." % run_seed)


## SC6: a piece lies wholly on its Stage's Scenery Ground, so none stands on its castle or
## in its sky.
func test_a_piece_lies_wholly_on_the_scenery_ground() -> void:
	var ground: Image = Image.create_empty(StageMapLayout.MAP_BACKDROP_SIZE.x, StageMapLayout.MAP_BACKDROP_SIZE.y,
			false, Image.FORMAT_RGBA8)
	ground.fill_rect(Rect2i(0, 300, 320, 260), Color.WHITE)
	var bounds: Rect2 = StageMapLayout.map_backdrop_rect(1.0)
	var lowest: float = bounds.position.y + 300 * StageMapLayout.BACKDROP_PIXEL
	for run_seed: int in 10:
		var visit: StageVisit = _visit(run_seed, [_kind(16, 4, 4, 8), _kind(16, 3, 4, 8)] as Array[SceneryKind])
		visit.stage.scenery_ground = ground
		var pieces: Array[SceneryPiece] = SceneryLayout.place(visit)

		assert_gt(pieces.size(), 0)
		for piece: SceneryPiece in pieces:
			assert_gte(piece.rect.position.y, lowest, "Seed %d: on the ground." % run_seed)


## SC3: each Kind places at most its most, and as many as it draws where there is room.
func test_each_kind_places_its_count_where_there_is_room() -> void:
	var exact: SceneryKind = _kind(8, 2, 3, 3)
	var ranged: SceneryKind = _kind(8, 2, 1, 4)
	for run_seed: int in SEEDS:
		var pieces: Array[SceneryPiece] = SceneryLayout.place(_visit(run_seed, [exact, ranged] as Array[SceneryKind]))

		assert_eq(_count(pieces, exact), 3, "Small and few: always room.")
		assert_between(_count(pieces, ranged), 1, 4)


## SC4: a crowded Kind places fewer and still breaks no rule.
func test_a_crowded_kind_places_fewer() -> void:
	var crowded: SceneryKind = _kind(32, 6, 200, 200)
	var pieces: Array[SceneryPiece] = SceneryLayout.place(_visit(3, [crowded] as Array[SceneryKind]))

	assert_gt(pieces.size(), 0)
	assert_lt(pieces.size(), 200)


## SC5: pieces come lower last, so the lower is drawn in front; some face the other way.
func test_pieces_come_lower_last_and_some_face_the_other_way() -> void:
	var flipped: int = 0
	for run_seed: int in SEEDS:
		var pieces: Array[SceneryPiece] = SceneryLayout.place(_visit(run_seed, [_kind(16, 4, 6, 10)] as Array[SceneryKind]))
		for index: int in range(1, pieces.size()):
			assert_gte(pieces[index].rect.end.y, pieces[index - 1].rect.end.y)
		for piece: SceneryPiece in pieces:
			flipped += 1 if piece.is_flipped else 0

	assert_gt(flipped, 0)


## A piece's size is its Kind's picture at its Kind's scale, at whole screen pixels.
func test_a_piece_is_its_kinds_picture_at_its_scale() -> void:
	var kind: SceneryKind = _kind(16, 3, 2, 2)
	for piece: SceneryPiece in SceneryLayout.place(_visit(5, [kind] as Array[SceneryKind])):
		assert_eq(piece.rect.size, Vector2(48, 48))
		assert_eq(piece.rect.position, piece.rect.position.round())


## SC5: a creature loops its frames on time; a still piece shows its one picture.
func test_a_creature_loops_its_frames_on_time() -> void:
	var cat: SceneryKind = _kind(16, 3, 1, 1, 3)
	var piece: SceneryPiece = SceneryPiece.new(cat, Rect2(0, 0, 48, 48), false, 0.0)

	assert_eq(piece.frame_at(0.0), cat.frames[0])
	assert_eq(piece.frame_at(0.3), cat.frames[1])
	assert_eq(piece.frame_at(0.6), cat.frames[2])
	assert_eq(piece.frame_at(0.8), cat.frames[0])
	var tree: SceneryKind = _kind(32, 4, 1, 1)
	assert_eq(SceneryPiece.new(tree, Rect2(), false, 0.0).frame_at(5.3), tree.frames[0])


## A Kind is valid only with frames of one size, a scale and a count that make sense.
func test_a_kind_says_why_it_cannot_be_placed() -> void:
	assert_eq(_kind(16, 3, 1, 2, 2).validate(), "")
	assert_ne(_kind(16, 3, 3, 2).validate(), "", "Its least is above its most.")
	assert_ne(_kind(16, 0, 1, 2).validate(), "", "No scale.")
	var none: SceneryKind = _kind(16, 3, 1, 2)
	none.frames = []
	assert_ne(none.validate(), "", "No picture.")
	var uneven: SceneryKind = _kind(16, 3, 1, 2)
	uneven.frames.append(_kind(8, 3, 1, 2).frames[0])
	assert_ne(uneven.validate(), "", "Frames of two sizes.")
	var unmoving: SceneryKind = _kind(16, 3, 1, 2, 2)
	unmoving.frames_per_second = 0.0
	assert_ne(unmoving.validate(), "", "Frames but no rate.")


func _count(pieces: Array[SceneryPiece], kind: SceneryKind) -> int:
	var count: int = 0
	for piece: SceneryPiece in pieces:
		count += 1 if piece.kind == kind else 0
	return count


func _described(pieces: Array[SceneryPiece]) -> Array[String]:
	var described: Array[String] = []
	for piece: SceneryPiece in pieces:
		described.append("%s %s %s %.3f" % [piece.kind.name, piece.rect, piece.is_flipped, piece.phase])
	return described
