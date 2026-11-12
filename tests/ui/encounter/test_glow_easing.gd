extends GutTest
## Glows and Stack Marks ease in and out over the time they are given, and a color change
## crossfades. Given no time, as in tests and screenshots, they come and go at once. A glow
## already showing in the same color is left as it is, so a redraw does not light it again.

const SIZE: Vector2 = Vector2(120, 100)
const SECONDS: float = 0.2

var _presenter: EncounterPresenter


func after_each() -> void:
	await wait_process_frames(2)


func test_a_glow_given_no_time_shows_at_once() -> void:
	var host: Control = _host()

	BorderEffects.add_glow(host, SIZE, Color.GREEN)

	assert_eq(_alpha(host, BorderEffects.GLOW), 1.0)


func test_a_glow_eases_in_over_the_time_it_is_given() -> void:
	var host: Control = _host()

	BorderEffects.add_glow(host, SIZE, Color.GREEN, SECONDS)

	assert_eq(_alpha(host, BorderEffects.GLOW), 0.0, "It starts unseen.")
	assert_eq(BorderEffects.glow_color(host), Color.GREEN, "But it is there from the start.")
	assert_true(BorderEffects.is_glow_showing(host))
	await wait_seconds(SECONDS / 2.0)
	assert_between(_alpha(host, BorderEffects.GLOW), 0.05, 0.99, "Partway.")
	await wait_seconds(SECONDS)
	assert_eq(_alpha(host, BorderEffects.GLOW), 1.0)


func test_a_glow_taken_away_is_gone_at_once_but_eases_out_before_it_is_freed() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN)
	var old: Control = host.get_node(BorderEffects.GLOW)

	BorderEffects.remove_glow(host, SECONDS)

	assert_null(BorderEffects.glow_color(host), "Nothing glows any more, as far as anyone asks.")
	assert_false(BorderEffects.is_glow_showing(host))
	assert_eq(old.get_parent(), host, "It is still drawn while it fades.")
	await wait_seconds(SECONDS / 2.0)
	assert_between(old.modulate.a, 0.01, 0.95, "Partway.")
	await wait_seconds(SECONDS)
	assert_false(is_instance_valid(old) and old.get_parent() == host, "Then it is gone.")
	assert_eq(host.get_child_count(), 0)


func test_a_glow_taken_away_with_no_time_goes_at_once() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN)

	BorderEffects.remove_glow(host)

	assert_eq(host.get_child_count(), 0)


func test_setting_the_glow_a_host_already_has_leaves_it_easing_as_it_was() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN, SECONDS)
	var glow: Control = host.get_node(BorderEffects.GLOW)
	await wait_seconds(SECONDS / 2.0)
	var partway: float = glow.modulate.a

	BorderEffects.set_glow(host, SIZE, Color.GREEN, SECONDS)

	assert_eq(host.get_node(BorderEffects.GLOW), glow, "The same glow.")
	assert_gte(glow.modulate.a, partway, "Not started over.")
	assert_eq(host.get_child_count(), 1)


func test_a_glow_changing_color_crossfades() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN)
	var old: Control = host.get_node(BorderEffects.GLOW)

	BorderEffects.set_glow(host, SIZE, Color.RED, SECONDS)

	assert_eq(BorderEffects.glow_color(host), Color.RED)
	assert_eq(_alpha(host, BorderEffects.GLOW), 0.0, "The new one eases in.")
	assert_eq(old.get_parent(), host, "As the old one eases out.")
	await wait_seconds(SECONDS * 1.75)
	assert_eq(_alpha(host, BorderEffects.GLOW), 1.0)
	assert_eq(host.get_child_count(), 1)


func test_a_mark_eases_in_and_out_and_the_glow_shows_again_at_once() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN)

	BorderEffects.add_mark(host, SIZE, Color.RED, false, SECONDS)

	assert_eq(_alpha(host, BorderEffects.MARK), 0.0)
	await wait_seconds(SECONDS * 1.5)
	assert_eq(_alpha(host, BorderEffects.MARK), 1.0)
	var mark: Control = host.get_node(BorderEffects.MARK)

	BorderEffects.remove_mark(host, SECONDS)

	assert_null(BorderEffects.mark_color(host))
	assert_true(BorderEffects.is_glow_showing(host))
	assert_eq(mark.get_parent(), host, "Still fading.")
	await wait_seconds(SECONDS * 1.5)
	assert_eq(host.get_child_count(), 1, "Only the glow is left.")


func test_a_redraw_leaves_a_glow_that_was_showing_as_it_was_and_a_new_one_eases_in() -> void:
	var screen: EncounterScreen = _open()
	var bear: Control = _hand_face(screen, "Bear")
	assert_eq(BorderEffects.glow_color(bear), DecisionClicks.color_of(DecisionClicks.Kind.OTHER))
	assert_lt(_alpha(bear, BorderEffects.GLOW), 1.0, "It began to glow just now.")
	await wait_seconds(SECONDS * 1.5)
	assert_eq(_alpha(bear, BorderEffects.GLOW), 1.0)

	_presenter.toggle_stop(MmEncounterSetup.HERO_PLAYER_ID, MmTurn.Step.UPKEEP)

	var redrawn: Control = _hand_face(screen, "Bear")
	assert_ne(redrawn, bear, "The hand was drawn again.")
	assert_eq(_alpha(redrawn, BorderEffects.GLOW), 1.0, "Glowing as it was, not lit again.")


func test_a_held_card_that_glows_brighter_keeps_its_glow_through_a_redraw() -> void:
	var screen: EncounterScreen = _open()
	var bear: Control = _hand_face(screen, "Bear")
	await wait_seconds(SECONDS * 1.5)
	var at: Vector2 = bear.position + Vector2(30, 60)
	screen.press_hand(at, false)
	screen.drag_to(at + Vector2(0, -400))
	await wait_seconds(SECONDS * 1.5)
	var bright: Color = BorderEffects.glow_color(screen.lifted_face())
	assert_eq(bright, DecisionClicks.bright_color_of(DecisionClicks.Kind.OTHER))

	_presenter.toggle_stop(MmEncounterSetup.HERO_PLAYER_ID, MmTurn.Step.UPKEEP)

	assert_eq(BorderEffects.glow_color(screen.lifted_face()), bright)
	assert_eq(_alpha(screen.lifted_face(), BorderEffects.GLOW), 1.0)
	assert_eq(screen.lifted_face().get_child_count(), _children_but_leaving(screen.lifted_face()), "Nothing fading out.")
	screen.release_hand(at + Vector2(0, -400))


func _open() -> EncounterScreen:
	var screen: EncounterScreen = EncounterScreen.new()
	screen.starts_itself = false
	add_child_autofree(screen)
	screen.size = Vector2(1920, 1080)
	screen.set_ease_seconds(SECONDS)
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(Scenario.basic_land("Forest") if index % 2 == 0 else Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0)))
	var presenter: EncounterPresenter = EncounterPresenter.new(
			Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	presenter.set_auto_passing(false)
	screen.begin(presenter)
	presenter.wait_until_idle()
	if presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		presenter.wait_until_idle()
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	for guard: int in 40:
		var view: MmPlayerView = presenter.snapshot().view
		if view.step == MmTurn.Step.PRECOMBAT_MAIN and view.active_player_id == MmEncounterSetup.HERO_PLAYER_ID:
			break
		presenter.pass_priority()
		presenter.wait_until_idle()
	_presenter = presenter
	return screen


func _hand_face(screen: EncounterScreen, card_name: String) -> Control:
	for seen: MmObjectView in _presenter.snapshot().view.hand:
		if seen.name == card_name:
			return screen.face_of(seen.id)
	return null


func _children_but_leaving(host: Control) -> int:
	var count: int = 0
	for child: Node in host.get_children():
		if not String(child.name).begins_with(BorderEffects.LEAVING):
			count += 1
	return count


func _alpha(host: Control, effect: String) -> float:
	var node: Control = host.get_node_or_null(effect) as Control
	return node.modulate.a if node != null else -1.0


func _host() -> Control:
	var host: Control = Control.new()
	host.size = SIZE
	add_child_autofree(host)
	return host


const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
