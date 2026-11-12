extends GutTest
## Something that offers two kinds of thing glows in both colors: a permanent with a mana
## ability and another ability, or a card in hand that can be cast and has an ability used
## from there. The Glow is split, the first color at the top left.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SIZE: Vector2 = Vector2(120, 100)
const SECONDS: float = 0.2
const PAIR: Array[Color] = [Color.GREEN, Color.BLUE]

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	await wait_process_frames(2)


func test_a_glow_of_two_colors_has_both_and_its_color_is_the_first() -> void:
	var host: Control = _host()

	BorderEffects.add_glow_of(host, SIZE, PAIR)

	assert_eq(BorderEffects.glow_colors(host), PAIR)
	assert_eq(BorderEffects.glow_color(host), Color.GREEN)
	assert_true(BorderEffects.is_glow_showing(host))
	var outlines: Array[Node] = host.get_node(BorderEffects.GLOW).get_children()
	assert_eq(outlines.size(), 2, "A soft line and a hard one, as a Glow of one color has.")
	for outline: Node in outlines:
		assert_true(outline is SplitOutline)


func test_a_glow_of_one_color_has_that_color_alone_and_no_glow_has_none() -> void:
	var host: Control = _host()
	assert_eq(BorderEffects.glow_colors(host).size(), 0)

	BorderEffects.add_glow(host, SIZE, Color.GREEN)

	assert_eq(BorderEffects.glow_colors(host), [Color.GREEN] as Array[Color])
	for outline: Node in host.get_node(BorderEffects.GLOW).get_children():
		assert_true(outline is Panel, "Drawn as it always was.")


func test_setting_the_pair_a_host_already_has_leaves_its_glow_as_it_was() -> void:
	var host: Control = _host()
	BorderEffects.add_glow_of(host, SIZE, PAIR, SECONDS)
	var glow: Control = host.get_node(BorderEffects.GLOW)

	BorderEffects.set_glow_of(host, SIZE, PAIR.duplicate(), SECONDS)

	assert_eq(host.get_node(BorderEffects.GLOW), glow, "The same glow.")
	assert_eq(host.get_child_count(), 1)


func test_a_glow_going_between_one_color_and_two_crossfades() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN)
	var old: Control = host.get_node(BorderEffects.GLOW)

	BorderEffects.set_glow_of(host, SIZE, PAIR, SECONDS)

	assert_eq(BorderEffects.glow_colors(host), PAIR)
	assert_eq(host.get_node(BorderEffects.GLOW).modulate.a, 0.0, "The new one eases in.")
	assert_eq(old.get_parent(), host, "As the old one eases out.")
	await wait_seconds(SECONDS * 1.75)
	assert_eq(host.get_child_count(), 1)

	BorderEffects.set_glow_of(host, SIZE, [Color.GREEN, Color.RED] as Array[Color])
	assert_eq(BorderEffects.glow_colors(host), [Color.GREEN, Color.RED] as Array[Color], "Another pair takes its place.")
	BorderEffects.set_glow_of(host, SIZE, [] as Array[Color])
	assert_null(BorderEffects.glow_color(host), "No colors, no Glow.")


func test_a_split_outline_is_the_first_color_at_the_top_left_and_the_second_at_the_bottom_right() -> void:
	var outline: SplitOutline = autofree(SplitOutline.new(SIZE, Color.GREEN, Color.BLUE, 3, 9, 3))
	var box: Rect2 = outline.box()

	assert_eq(box, Rect2(Vector2.ZERO, SIZE).grow(1.5), "The middle of a line 3 wide whose outer edge is 3 out.")
	assert_eq(outline.color_at(box.position), Color.GREEN)
	assert_eq(outline.color_at(Vector2(box.get_center().x, box.position.y)), Color.GREEN, "All along the top")
	assert_eq(outline.color_at(Vector2(box.position.x, box.get_center().y)), Color.GREEN, "and the left.")
	assert_eq(outline.color_at(box.end), Color.BLUE)
	assert_eq(outline.color_at(Vector2(box.get_center().x, box.end.y)), Color.BLUE, "All along the bottom")
	assert_eq(outline.color_at(Vector2(box.end.x, box.get_center().y)), Color.BLUE, "and the right.")
	assert_eq(outline.color_at(Vector2(box.end.x, box.position.y)), Color.GREEN.lerp(Color.BLUE, 0.5), "Half and half where they meet.")


func test_a_split_outlines_points_run_round_the_box_and_join() -> void:
	var box: Rect2 = Rect2(10, 20, 100, 60)

	var points: PackedVector2Array = SplitOutline.points(box, 8.0)

	assert_eq(points[points.size() - 2], points[0], "Closed.")
	assert_almost_eq(points[0], Vector2(10, 28), Vector2(0.01, 0.01), "From the left end of the top left corner.")
	for point: Vector2 in points:
		assert_true(box.grow(0.01).has_point(point), "Never outside the box.")
	var reaches: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		reaches = reaches.expand(point)
	assert_almost_eq(reaches.size, box.size, Vector2(0.01, 0.01), "And out to every side of it.")


func test_a_permanent_with_a_mana_ability_and_another_glows_purple_and_blue() -> void:
	_open([_staff()])
	_do(CastSpellAction, "Staff")
	var staff: int = _permanent("Staff")

	assert_eq(BorderEffects.glow_colors(_screen.face_of(staff)),
		[DecisionClicks.color_of(DecisionClicks.Kind.ABILITY), DecisionClicks.color_of(DecisionClicks.Kind.MANA)] as Array[Color])
	assert_eq(BorderEffects.glow_colors(_screen.face_of(_in_hand("Staff"))),
		[DecisionClicks.color_of(DecisionClicks.Kind.PLAY)] as Array[Color], "One kind, one color.")


func test_a_redraw_leaves_a_glow_of_two_colors_as_it_was_and_a_new_one_eases_in() -> void:
	_open([_staff()], SECONDS)
	_do(CastSpellAction, "Staff")
	var face: Control = _screen.face_of(_permanent("Staff"))
	assert_lt(face.get_node(BorderEffects.GLOW).modulate.a, 1.0, "It began to glow just now.")
	await wait_seconds(SECONDS * 1.5)
	assert_eq(face.get_node(BorderEffects.GLOW).modulate.a, 1.0)

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	var redrawn: Control = _screen.face_of(_permanent("Staff"))
	assert_ne(redrawn, face, "The board was drawn again.")
	assert_eq(BorderEffects.glow_colors(redrawn).size(), 2)
	assert_eq(redrawn.get_node(BorderEffects.GLOW).modulate.a, 1.0, "Glowing as it was, not lit again.")


func test_a_held_card_with_two_kinds_glows_in_both_made_lighter_and_plainly_again_put_down() -> void:
	_open([_staff()])
	var card: MmObjectView = _seen(_in_hand("Staff"))
	_give_an_ability(card.id)
	var face: Control = _screen.face_of(card.id)
	var at: Vector2 = face.position + Vector2(30, 60)

	_screen.press_hand(at, false)
	_screen.drag_to(at + Vector2(0, -400))

	assert_eq(BorderEffects.glow_colors(_screen.lifted_face()), [
		DecisionClicks.bright_color_of(DecisionClicks.Kind.PLAY), DecisionClicks.bright_color_of(DecisionClicks.Kind.ABILITY),
	] as Array[Color], "Letting go here would offer both.")

	_screen.release_hand(at)

	assert_null(_screen.lifted_face())
	assert_eq(BorderEffects.glow_colors(face), [
		DecisionClicks.color_of(DecisionClicks.Kind.PLAY), DecisionClicks.color_of(DecisionClicks.Kind.ABILITY),
	] as Array[Color])


func test_letting_go_of_a_card_with_two_kinds_opens_the_option_menu_with_both() -> void:
	_open([_staff()])
	var card: MmObjectView = _seen(_in_hand("Staff"))
	_give_an_ability(card.id)
	var at: Vector2 = _screen.face_of(card.id).position + Vector2(30, 60)

	_screen.press_hand(at, false)
	_screen.drag_to(at + Vector2(0, -400))
	_screen.release_hand(at + Vector2(0, -400))

	assert_true(_screen.option_menu().is_open())
	var rows: Array[Button] = _screen.option_menu().rows()
	assert_eq(rows.size(), 2)
	assert_eq([rows[0].text, rows[1].text], ["Cast Staff", "Its ability"])
	_screen.cancel_drag()


func test_letting_go_of_a_card_with_only_an_ability_uses_it() -> void:
	_open([_staff()])
	var card: MmObjectView = _seen(_in_hand("Staff"))
	var clicks: DecisionClicks = _screen._clicks
	# The answer that casts it stands in for the ability's: no card has one used from the hand yet.
	clicks._hand_abilities[card.id] = clicks._hand_options[card.id]
	clicks._hand_options.erase(card.id)
	clicks.glow_as(card.id, DecisionClicks.Kind.ABILITY)
	var at: Vector2 = _screen.face_of(card.id).position + Vector2(30, 60)

	_screen.press_hand(at, false)
	_screen.drag_to(at + Vector2(0, -400))
	assert_eq(BorderEffects.glow_colors(_screen.lifted_face()), [DecisionClicks.bright_color_of(DecisionClicks.Kind.ABILITY)] as Array[Color])
	_screen.release_hand(at + Vector2(0, -400))
	_presenter.wait_until_idle()

	assert_false(_screen.option_menu().is_open(), "One thing to do: no menu.")
	assert_ne(_permanent("Staff"), -1, "The answer was given.")


func test_a_permanent_glowing_in_two_colors_scrolled_out_of_sight_colors_the_arrow_with_the_first() -> void:
	_open([_staff()])
	for cast: int in 7:
		_do(CastSpellAction, "Staff")
	_screen.size = Vector2(1100, 1080)
	var line: ScrollRow = _screen.line("hero_others")
	line.scroll_to(0.0)

	assert_eq(line.arrow_tint(line.right_arrow()), DecisionClicks.color_of(DecisionClicks.Kind.ABILITY))


## Gives the card in hand that is [param object_id] an ability used from the hand, as the
## first card with one will have: here the answer that casts it, under another name.
func _give_an_ability(object_id: int) -> void:
	var clicks: DecisionClicks = _screen._clicks
	clicks._hand_abilities[object_id] = [ClickOption.new(clicks.hand_options_of(object_id)[0].answer, "Its ability")]
	clicks._add_kind(object_id, DecisionClicks.Kind.ABILITY)


## An artifact costing {0} with a mana ability and one that deals damage.
func _staff() -> MmCardDefinition:
	var ping: ActivatedAbility = ActivatedAbility.new()
	ping.costs = [TapCost.new()]
	ping.targets = [Scenario.any_target()]
	ping.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	return Scenario.artifact("Staff", [Scenario.tap_for_mana(MmMana.Type.RED, 1), ping])


## Opens an encounter whose Hero's deck cycles through [param cards], at the Hero's first
## main phase.
func _open(cards: Array[MmCardDefinition], ease_seconds: float = 0.0) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.set_ease_seconds(ease_seconds)
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	_presenter = EncounterPresenter.new(Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


## Takes the priority action of [param kind] about the card named [param card_name].
func _do(kind: Script, card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if is_instance_of(action, kind) and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No %s action for %s." % [kind.resource_path.get_file(), card_name])


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			return permanent.id
	return -1


func _in_hand(card_name: String) -> int:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.name == card_name:
			return card.id
	return -1


func _seen(object_id: int) -> MmObjectView:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.id == object_id:
			return card
	return null


func _host() -> Control:
	var host: Control = Control.new()
	host.size = SIZE
	add_child_autofree(host)
	return host
