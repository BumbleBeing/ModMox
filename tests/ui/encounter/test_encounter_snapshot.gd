extends GutTest
## A snapshot is everything the Encounter Screen draws from.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_it_lists_what_the_view_shows_in_every_zone() -> void:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.hand = [_object(1)]
	snapshot.view.battlefield = [_object(2)]
	snapshot.view.stack = [_object(3)]
	snapshot.view.command = [_object(4)]
	snapshot.view.graveyards = {HERO: [_object(5)], VILLAIN: [_object(6)]}
	snapshot.view.exiles = {HERO: [_object(7)], VILLAIN: [_object(8)]}

	var ids: Array[int] = []
	for seen: MmObjectView in snapshot.visible_objects():
		ids.append(seen.id)
	ids.sort()

	assert_eq(ids, [1, 2, 3, 4, 5, 6, 7, 8] as Array[int])


func test_an_encounter_with_no_winner_is_a_draw() -> void:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.life_totals = {HERO: 0, VILLAIN: 0}
	assert_false(snapshot.is_over())
	assert_false(snapshot.is_draw(), "Still being played.")

	snapshot.view.is_over = true
	assert_true(snapshot.is_draw())

	snapshot.view.winner_id = VILLAIN
	assert_true(snapshot.is_over())
	assert_false(snapshot.is_draw())


func _object(id: int) -> MmObjectView:
	var seen: MmObjectView = MmObjectView.new()
	seen.id = id
	return seen
