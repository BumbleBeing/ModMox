extends GutTest
## How the Stage Map colors its links (milestone 17): lit while the Hero can take them,
## dark otherwise, easing between; gold once walked, turning gold while walked.


func test_only_the_links_the_hero_can_take_now_are_lit() -> void:
	var visit: StageVisit = Run.debug(7).stage_visit
	var links: StageMapLinks = StageMapLinks.new()

	links.ease_toward(visit, -1, 1.0)

	for id: int in visit.choices():
		assert_eq(links.light_of(visit.current, id), 1.0)
	var later: MapNode = visit.map.in_row(4)[0]
	assert_eq(links.light_of(later.id, later.forward[0]), 0.0)


func test_a_link_eases_dark_when_the_hero_sets_off_and_the_one_walked_stays_lit() -> void:
	var visit: StageVisit = Run.debug(7).stage_visit
	var links: StageMapLinks = StageMapLinks.new()
	links.ease_toward(visit, -1, 1.0)
	var going: int = visit.choices()[0]
	var other: int = visit.choices()[1]

	links.ease_toward(visit, going, 0.5)

	assert_eq(links.light_of(visit.current, other), 0.5, "Halfway to dark.")
	assert_eq(links.light_of(visit.current, going), 1.0)


func test_a_walked_link_is_gold_and_one_being_walked_turns_gold() -> void:
	var run: Run = Run.debug(7)
	var visit: StageVisit = run.stage_visit
	var links: StageMapLinks = StageMapLinks.new()
	links.ease_toward(visit, -1, 1.0)
	var start: int = visit.current
	var going: int = visit.choices()[0]

	assert_eq(links.color_of(visit, start, going, going, 0.0), StageMapLinks.LIT)
	assert_true(links.color_of(visit, start, going, going, 1.0).is_equal_approx(StageMapLinks.WALKED))
	run.move_to(going)
	assert_eq(links.color_of(visit, start, going, -1, 0.0), StageMapLinks.WALKED)
