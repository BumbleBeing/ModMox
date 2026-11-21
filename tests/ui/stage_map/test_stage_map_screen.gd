extends GutTest
## The Stage Map screen (milestone 17, signed off as prototypes/stage_map_screen): clicking a
## glowing Node to glide there, the view following, encounters opening the Deckbox, the
## walked Path drawn apart, hover labels, the Boss's Node and the Run Bar. The "Run won"
## notice it once showed gave way to Run Won (milestone 19).

var _run: Run
var _screen: StageMapScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	RunFlow.clear()
	_run = Run.debug(7)
	RunFlow.start(_run)
	RunFlow.finish_intro()


func after_each() -> void:
	RunFlow.clear()
	await wait_process_frames(2)


func _open() -> void:
	_screen = StageMapScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	add_child_autofree(_screen)
	_screen.size = StageMapLayout.SCREEN
	_screen.set_process(false)
	_screen.begin(_run)
	await wait_process_frames(1)


## Clicks the Node [param id] and lets the glide run to its end.
func _go_to(id: int) -> void:
	assert_true(_screen.click_at(_screen.node_spot(id)), "Node %d glows" % id)
	_screen.advance(10.0)


## S2: a click on a glowing Node glides the Portrait and the view there.
func test_a_click_on_a_glowing_node_glides_the_hero_there() -> void:
	await _open()
	var start: Vector2 = _screen.hero_spot()
	var going: int = _run.stage_visit.choices()[0]

	assert_true(_screen.click_at(_screen.node_spot(going)))
	_screen.advance(0.3)

	assert_true(_screen.is_gliding())
	assert_ne(_screen.hero_spot(), start)
	assert_eq(_run.stage_visit.current, _run.stage_visit.map.start().id, "The Hero arrives only at the glide's end.")
	_screen.advance(10.0)
	assert_false(_screen.is_gliding())
	assert_eq(_run.stage_visit.current, going)
	assert_eq(_screen.hero_spot(), _screen.node_spot(going))


## S2: clicks during the glide do nothing.
func test_clicks_during_a_glide_do_nothing() -> void:
	await _open()
	var choices: Array[int] = _run.stage_visit.choices()
	_screen.click_at(_screen.node_spot(choices[0]))
	_screen.advance(0.1)

	assert_false(_screen.click_at(_screen.node_spot(choices[1])))
	assert_true(_screen.glowing().is_empty(), "Nothing glows while the Hero glides.")
	_screen.advance(10.0)
	assert_eq(_run.stage_visit.current, choices[0])


## S3: a click on any other Node does nothing.
func test_a_click_on_a_node_that_does_not_glow_does_nothing() -> void:
	await _open()
	var far: MapNode = _run.stage_visit.map.in_row(3)[0]

	assert_false(_screen.click_at(_screen.node_spot(far.id)))
	assert_false(_screen.click_at(_screen.node_spot(_run.stage_visit.current)))
	assert_false(_screen.is_gliding())


## S1: the view follows the Hero up the map.
func test_the_view_follows_the_hero_up_the_map() -> void:
	await _open()
	assert_eq(_screen.scroll_row(), 1.0)

	_go_to(_run.stage_visit.choices()[0])

	assert_almost_eq(_screen.scroll_row(), 2.0, 0.01)


## S4: arriving at an encounter opens the Deckbox with Start and that Node's Villain.
func test_arriving_at_an_encounter_opens_the_deckbox_against_its_villain() -> void:
	await _open()

	while _went_to.is_empty():
		_go_to(_run.stage_visit.choices()[0])

	assert_eq(_went_to, [Screens.DECKBOX] as Array[String])
	assert_true(StageMap.is_encounter(_run.stage_visit.node()))
	assert_eq(RunFlow.villain, _run.stage_visit.meeting)


## S4: after the encounter the Stage Map opens with the Hero there and Hearts updated.
func test_after_an_encounter_the_map_shows_the_hero_there_with_hearts_updated() -> void:
	await _open()
	while _went_to.is_empty():
		_go_to(_run.stage_visit.choices()[0])
	var at: int = _run.stage_visit.current
	_screen.queue_free()
	_went_to.clear()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.STAGE_MAP)
	await _open()

	assert_eq(_screen.hero_spot(), _screen.node_spot(at))
	assert_eq(_screen.run_bar().hearts_shown(), [true, true, false] as Array[bool])
	assert_false(_screen.glowing().is_empty(), "The Hero may move on.")


## S5: arriving at any other Node opens nothing.
func test_arriving_anywhere_else_opens_nothing() -> void:
	await _open()

	_go_to(_run.stage_visit.choices()[0])

	assert_eq(_run.stage_visit.node().kind, StageMap.Kind.STORE)
	assert_true(_went_to.is_empty())
	assert_false(_screen.glowing().is_empty())


## S6: visited Nodes and the walked Path are drawn apart.
func test_visited_nodes_and_the_walked_path_are_drawn_apart() -> void:
	await _open()
	var start: int = _run.stage_visit.current
	var choices: Array[int] = _run.stage_visit.choices()

	_go_to(choices[0])

	assert_eq(_screen.node_tint(start), StageMapScreen.VISITED_TINT)
	assert_eq(_screen.node_tint(choices[1]), Color.WHITE)
	assert_eq(_screen.link_color(start, choices[0]), StageMapLinks.WALKED)
	assert_eq(_screen.link_color(start, choices[1]), StageMapLinks.DARK, "No longer takeable.")


## S7: hovering a Node names its kind.
func test_hovering_a_node_names_its_kind() -> void:
	await _open()
	var store: int = _run.stage_visit.map.in_row(2)[0].id

	_screen.point_at(_screen.node_spot(store))

	assert_eq(_screen.label_text(), "Store")
	assert_true(_screen.label_rect().get_center().x - _screen.node_spot(store).x < 1.0, "Centered under it.")
	assert_gt(_screen.label_rect().position.y, _screen.node_spot(store).y)
	_screen.point_at(Vector2(5, 1075))
	assert_eq(_screen.label_text(), "")


## S8: the Boss's Node shows its Portrait, and its label its name.
func test_the_bosss_node_shows_the_boss() -> void:
	_run.stage_visit.current = _run.stage_visit.map.in_row(9)[0].id
	await _open()
	var boss: int = _run.stage_visit.map.boss().id

	_screen.point_at(_screen.node_spot(boss))

	assert_eq(_screen.boss_portrait(), _run.stage_visit.boss.sprite)
	assert_eq(_screen.label_text(), _run.stage_visit.boss.name)


## S9: the Run Bar shows the Stage, Tier, Hearts and gold.
func test_the_run_bar_shows_the_stage_tier_hearts_and_gold() -> void:
	_run.hearts = 2
	_run.gold = 135
	await _open()
	var bar: RunBar = _screen.run_bar()

	assert_eq(bar.stage_text(), _run.stage_visit.stage.name)
	assert_eq(bar.tier_text(), "Tier 1")
	assert_eq(bar.hearts_shown(), [true, true, false] as Array[bool])
	assert_eq(bar.gold_text(), "135")


## S9: Satchel does nothing; Deckbox opens the Deckbox with Close, which returns here.
func test_satchel_does_nothing_and_deckbox_opens_the_deckbox_with_close() -> void:
	await _open()
	var bar: RunBar = _screen.run_bar()

	bar.button(RunBar.SATCHEL).pressed.emit()
	assert_true(_went_to.is_empty())
	assert_false(bar.button(RunBar.SATCHEL).disabled)
	bar.button(RunBar.DECKBOX).pressed.emit()

	assert_eq(_went_to, [Screens.DECKBOX] as Array[String])
	assert_null(RunFlow.villain)
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)


## The Glow is a 32 x 32 sprite at seven-tenths opacity on the Nodes the Hero can move to.
func test_the_nodes_the_hero_can_move_to_glow_at_seven_tenths() -> void:
	await _open()
	var choices: Array[int] = _run.stage_visit.choices()

	assert_eq(StageMapScreen.GLOW_SPRITE.get_size(), Vector2(32, 32))
	assert_eq(StageMapScreen.BOSS_GLOW_SPRITE.get_size(), Vector2(32, 32))
	for id: int in choices:
		assert_almost_eq(_screen.glow_of(id), 0.7, 0.001)
	assert_eq(_screen.glow_of(_run.stage_visit.current), 0.0)


## The Glow eases out when the Hero sets off, and in on the next Nodes when they arrive.
func test_the_glow_eases_out_and_in() -> void:
	await _open()
	_screen.is_paced = true
	var going: int = _run.stage_visit.choices()[0]
	var other: int = _run.stage_visit.choices()[1]

	_screen.click_at(_screen.node_spot(going))
	_screen.advance(0.05)
	assert_between(_screen.glow_of(other), 0.01, 0.69, "Fading out, not gone at once.")
	_screen.advance(0.5)
	assert_eq(_screen.glow_of(other), 0.0)
	while _screen.is_gliding():
		_screen.advance(0.02)
	var next: int = _run.stage_visit.choices()[0]
	assert_lt(_screen.glow_of(next), 0.69, "Not lit at once when the Hero arrives...")
	_screen.advance(0.05)
	assert_between(_screen.glow_of(next), 0.01, 0.69, "...but easing in.")
	_screen.advance(0.5)
	assert_almost_eq(_screen.glow_of(next), 0.7, 0.001)


## ADR 0038: a Stage's Map Backdrop is drawn behind its map, scrolling with it.
func test_a_stages_map_backdrop_is_drawn_behind_its_map() -> void:
	_run = Run.debug(7, load("res://content/stages/kitty_keep.tres") as StageDefinition)
	RunFlow.start(_run)
	RunFlow.finish_intro()
	await _open()

	assert_eq(_screen.map_backdrop(), _run.stage_visit.stage.map_backdrop)
	assert_not_null(_screen.map_backdrop())
	assert_eq(_screen.map_backdrop_rect(), StageMapLayout.map_backdrop_rect(_screen.scroll_row()))
	_go_to(_run.stage_visit.choices()[0])
	assert_eq(_screen.map_backdrop_rect(), StageMapLayout.map_backdrop_rect(_screen.scroll_row()))


## ADR 0038: a Stage without one shows the plain slate.
func test_a_stage_without_a_map_backdrop_shows_the_slate() -> void:
	_run = Run.debug(7, load("res://content/stages/placeholder_red.tres") as StageDefinition)
	RunFlow.start(_run)
	RunFlow.finish_intro()
	await _open()

	assert_null(_screen.map_backdrop())


## ADR 0038: the Stage's Scenery is drawn as placed, scrolling with the map.
func test_the_stages_scenery_is_drawn_and_scrolls_with_the_map() -> void:
	_run = Run.debug(7, load("res://content/stages/kitty_keep.tres") as StageDefinition)
	RunFlow.start(_run)
	RunFlow.finish_intro()
	await _open()
	var placed: Array[SceneryPiece] = SceneryLayout.place(_run.stage_visit)

	assert_gt(_screen.scenery().size(), 0)
	assert_eq(_screen.scenery().size(), placed.size())
	var before: Rect2 = _screen.scenery_rect(0)
	var node_before: Vector2 = _screen.node_spot(_run.stage_visit.map.start().id)
	_go_to(_run.stage_visit.choices()[0])
	var moved: float = _screen.node_spot(_run.stage_visit.map.start().id).y - node_before.y
	assert_almost_eq(_screen.scenery_rect(0).position.y - before.position.y, moved, 0.001)
	assert_eq(_screen.scenery_rect(0).size, before.size)


## A real click, through the input pipeline, sets the Hero off.
func test_a_real_click_on_a_glowing_node_sets_the_hero_off() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(StageMapLayout.SCREEN)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	_screen = StageMapScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	viewport.add_child(_screen)
	_screen.size = StageMapLayout.SCREEN
	_screen.set_process(false)
	_screen.begin(_run)
	await wait_process_frames(3)
	var spot: Vector2 = _screen.node_spot(_run.stage_visit.choices()[0])

	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		viewport.push_input(click)

	assert_true(_screen.is_gliding())
