extends GutTest
## Assemble the Players on the Encounter Screen (game ADR 0055). While the Hero controls a
## permanent that lets them look at the top card of their library, their Library pile shows
## that card face up with an eye, to the Hero alone. While it can be cast the pile glows
## green; its window holds the whole library with that card face up first, glowing, and a
## click on it casts it, the Info
## Panel saying so while the cursor is on it. On the stack it reads "(top of library)", and
## once its cast is Spent the permanent is drawn dimmed. Lookout is the card as an
## enchantment costing {0}; Cub is a 2/2 costing {0}, and Kit a 1/1 costing {W}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MINE: String = "hero_library"
const PLAY: Color = Color("#7be36a")
## A place on the board with nothing on it.
const AWAY: Vector2 = Vector2(1000, 500)

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _window: SubViewport = null


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_top_card_shows_face_up_on_the_pile_with_an_eye_once_the_lookout_is_in_play() -> void:
	_open([Scenario.lookout(), _cub(), Scenario.basic_land("Plains")], "Cub")
	assert_null(_screen.library_top_face(), "Not before the Hero controls a Lookout.")

	_cast("Lookout")

	var face: CardFace = _screen.library_top_face()
	assert_not_null(face)
	assert_eq(face.title_text().shown_text(), "Cub")
	var eyes: int = 0
	for child: Node in face.get_children():
		if child is SeenEye:
			eyes += 1
	assert_eq(eyes, 1, "An eye: only the Hero sees it.")
	assert_eq(_presenter.snapshot().view.libraries[VILLAIN].count(null), _presenter.snapshot().view.libraries[VILLAIN].size(),
		"The Villain's library stays face down.")


func test_the_pile_glows_green_and_its_window_holds_the_whole_library_and_casts_the_top_card() -> void:
	_open([Scenario.lookout(), _cub(), Scenario.basic_land("Plains")], "Cub")
	_cast("Lookout")
	var top: int = _top_id()

	assert_eq(_screen.pile_glow(MINE), [PLAY] as Array[Color], "Green: a card to cast.")
	assert_false(_screen.pile_window(MINE).is_open(), "Passing answers too, so it waits for a click.")
	_screen.pile_catcher(MINE).clicked.emit()
	var window: PileWindow = _screen.pile_window(MINE)
	assert_true(window.is_open())
	var backs: Array[int] = []
	backs.resize(_presenter.snapshot().view.libraries[HERO].size() - 1)
	backs.fill(PileWindow.UNKNOWN)
	assert_eq(window.entries(), ([top] as Array[int]) + backs, "Every card, the top one face up and the rest face down.")
	assert_gt(backs.size(), 0, "The scenario's library holds more than its top card.")
	assert_eq(BorderEffects.glow_colors(window.face_of(top)), [PLAY] as Array[Color], "The top card glows: it can be cast.")
	assert_eq(_screen.pile_glow(MINE), [PLAY] as Array[Color], "The pile keeps glowing while its window is open.")
	assert_not_null(window.catcher_of(top), "The card takes the click.")
	window.catcher_of(top).clicked.emit()
	_presenter.wait_until_idle()

	assert_false(window.is_open(), "Closed with the click that began the cast.")
	assert_eq(_names_on_battlefield().count("Cub"), 1, "Cast from the top.")


func test_on_the_stack_it_reads_top_of_library_and_the_lookout_is_then_dimmed() -> void:
	_open([Scenario.lookout(), _cub(), Scenario.basic_land("Plains")], "Cub")
	_cast("Lookout")
	var lookout: int = _permanent("Lookout")
	assert_null((_screen.face_of(lookout) as BattlefieldFace).dim(), "Not dimmed while it can be used.")
	_presenter.is_hold_key_down = true

	_presenter.answer(_cast_index(_top_id()))
	_presenter.wait_until_idle()

	var spell: MmObjectView = _presenter.snapshot().view.stack[0]
	assert_eq(StackItem.of(spell, _presenter.snapshot().view).first_line, "Cub (top of library)")
	assert_not_null((_screen.face_of(lookout) as BattlefieldFace).dim(), "Its cast from the top is Spent this turn.")
	var entries: Array = []
	for entry: StateEntry in _presenter.snapshot().state_information_of(lookout):
		entries.append([entry.title, entry.text])
	assert_eq(entries, [["Cast from the top this turn", "You cast Cub from the top of your library."]])
	_presenter.is_hold_key_down = false


func test_the_cursor_on_the_card_in_the_window_says_what_a_click_does() -> void:
	_open([Scenario.lookout(), _cub(), Scenario.basic_land("Plains")], "Cub", true)
	_cast("Lookout")
	_screen.pile_catcher(MINE).clicked.emit()
	var window: PileWindow = _screen.pile_window(MINE)
	await wait_process_frames(3)
	var on_card: Vector2 = window.face_of(_top_id()).get_global_rect().get_center()

	_window.push_input(_motion(on_card))
	await wait_process_frames(2)

	assert_eq(_screen.info_panel().option_text(), "Cast Cub from the top of your library")
	_window.push_input(_motion(AWAY))
	await wait_process_frames(2)
	assert_eq(_screen.info_panel().option_text(), "")


func test_the_cursor_on_the_card_in_the_window_previews_what_paying_for_it_taps() -> void:
	_open([Scenario.lookout(), _kit(), Scenario.basic_land("Plains")], "Kit", true)
	_presenter.set_auto_tapping(true)
	_play_a_land()
	_cast("Lookout")
	var cast: int = _cast_index(_top_id())
	assert_ne(cast, -1, "The Plains pays for it.")
	_screen.pile_catcher(MINE).clicked.emit()
	var window: PileWindow = _screen.pile_window(MINE)
	await wait_process_frames(3)

	_window.push_input(_motion(window.face_of(_top_id()).get_global_rect().get_center()))
	await wait_process_frames(2)
	_screen.follow_preview(0.0)

	assert_eq(_screen.previewed_answer(), cast, "Paid for like a card in hand.")
	_window.push_input(_motion(AWAY))
	await wait_process_frames(2)
	_screen.follow_preview(0.0)
	assert_eq(_screen.previewed_answer(), EncounterScreen.NO_PREVIEW)


## A 2/2 creature costing {0}.
func _cub() -> MmCardDefinition:
	return Scenario.creature("Cub", 2, 2)


## A 1/1 creature costing {W}.
func _kit() -> MmCardDefinition:
	return Scenario.creature("Kit", 1, 1, [], Scenario.mana_cost(0, [MmMana.Type.WHITE]))


## Opens the screen on a seed where the Hero, whose deck cycles through [param cards],
## starts, keeps a hand with the first of them and a land, and has a [param top_name] on
## top of their library; then plays to the Hero's first main phase. In a SubViewport with
## [param in_a_viewport], so the mouse goes through the real input pipeline.
func _open(cards: Array[MmCardDefinition], top_name: String, in_a_viewport: bool = false) -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled(cards)
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		var held: Array[String] = Scenario.names(engine, engine.hero().hand)
		if held.has(cards[0].name) and held.has("Plains") and Scenario.top_name(engine, engine.hero()) == top_name:
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if in_a_viewport:
		_window = SubViewport.new()
		_window.size = Vector2i(SCREEN)
		add_child_autofree(_window)
		_window.add_child(_screen)
	else:
		add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
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
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	if in_a_viewport:
		_window.push_input(_motion(AWAY))


## Casts the card named [param card_name] from the hand and lets it resolve.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and _in_hand(cast.object_id) and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			while not _presenter.snapshot().view.stack.is_empty():
				_presenter.pass_priority()
				_presenter.wait_until_idle()
			return
	fail_test("No cast of %s." % card_name)


func _play_a_land() -> void:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	var land: int = Scenario.action_index(priority, func(action: MmAction) -> bool: return action is PlayLandAction)
	assert_eq(_presenter.answer(land), "")
	_presenter.wait_until_idle()


func _cast_index(object_id: int) -> int:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	return -1 if priority == null else Scenario.cast_index(priority, object_id)


func _in_hand(object_id: int) -> bool:
	for seen: MmObjectView in _presenter.snapshot().view.hand:
		if seen.id == object_id:
			return true
	return false


## The top card of the Hero's library as they see it.
func _top_id() -> int:
	var top: MmObjectView = _presenter.snapshot().view.libraries[HERO][0] as MmObjectView
	return -1 if top == null else top.id


func _permanent(card_name: String) -> int:
	for seen: MmObjectView in _presenter.snapshot().view.battlefield:
		if seen.name == card_name and seen.controller_id == HERO:
			return seen.id
	return -1


func _names_on_battlefield() -> Array[String]:
	var names: Array[String] = []
	for seen: MmObjectView in _presenter.snapshot().view.battlefield:
		names.append(seen.name)
	return names


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion
