class_name EncounterPresenter
extends RefCounted
## The Encounter Presenter (game glossary, ADR 0021): the one object in the GUI that owns
## the engine and the Encounter Driver. It runs the Villain's Agent on a worker thread, a
## decision at a time, takes the Hero's answers, and after every change hands the Encounter
## Screen a snapshot. Nothing else in ui/ may mention the engine or the game state.
##
## While the Villain is thinking, the worker thread is changing the game, so nothing here
## reads the engine until it has finished: the snapshot is made first, and commands are
## refused.
##
## Pacing (A357): the Villain's next answer is held back until the Hero has had time to read
## what the last one did. The answer is simply not collected yet, so thinking counts toward
## the wait and the screen never shows an old game. A step of the turn is shown for a least
## time too, whoever would move the game on: the Villain's answer is held back as above, and
## a pass made for the Hero is put off, the snapshot meanwhile asking the Hero nothing.
##
## Auto-tap (ADR 0031): with it on, the presenter pays the Hero's mana costs, choosing each
## source as the Villain's Agent would, and shows each tap for the mana wait before the
## next. Asked at the Hero's priority, it says what a cast would tap (payment_plan()).

## A snapshot is ready: the game changed, or the Villain began or stopped thinking.
signal changed(snapshot: EncounterSnapshot)

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const BUSY: String = "The Villain is thinking."
const NOT_PRIORITY: String = "You do not have priority."
const PAUSED: String = "The game is paused."
const PAYING: String = "Your mana is being paid."
const NO_TURN: int = -1

## The steps auto-pass stops at. Change them with toggle_stop().
var stops: StepStops = StepStops.new()
## Whether the Hold Key is down, which the screen keeps this equal to. While it is, nothing
## is passed for the Hero: not by auto-pass, not by a Yield, and not after their own spell
## or ability goes on the stack.
var is_hold_key_down: bool = false
## How long a snapshot that showed a Villain action, or only the Villain tapping for mana,
## is left up before the Villain's next answer is collected (Pacing). Zero until the screen
## sets them for a real encounter, so tests and screenshots never wait.
var action_wait_msec: int = 0
var mana_wait_msec: int = 0
## The least time a step of the turn is shown before the game leaves it (Pacing). Zero until
## the screen sets it, as the waits above.
var step_wait_msec: int = 0
## The time in milliseconds. Tests hand in their own.
var clock: Callable = Time.get_ticks_msec

var _engine: MmEngine
var _driver: MmEncounterDriver
## Held so the Agent outlives the driver's use of it on the worker thread.
var _villain_agent: MmAgent
var _is_auto_passing: bool = true
var _is_yielding: bool = false
## The Game Turn the Yield is for, or NO_TURN until the engine can next be read.
var _yield_turn: int = NO_TURN
## Whether auto-pass, a stop or the Yield changed while paused, to be looked at on resuming.
var _is_reconsider_due: bool = false
var _task: int = -1
var _has_started: bool = false
var _snapshot: EncounterSnapshot = null
var _events_seen: int = 0
var _is_holding: bool = false
## The Hero's object last seen on top of the stack, so holding is decided once for each.
var _own_top_seen: int = -1
var _is_paused: bool = false
## When the latest snapshot was made, and how long the Villain's next answer waits after it.
var _shown_at: int = 0
var _wait: int = 0
var _is_rewinding: bool = false
## When the step now showing has been up for the step wait.
var _step_shown_until: int = 0
## Whether a pass for the Hero is being put off until then. The snapshot asks them nothing.
var _is_passing_for_hero: bool = false
## Auto-tap. Off until the screen turns it on from the settings, as Pacing is, so a
## presenter made in a test pays nothing unless the test asks.
var _is_auto_tapping: bool = false
## Whether who pays the cost being paid has been settled. It is settled once, when the cast
## reaches payment, and holds until that payment is over.
var _is_payment_settled: bool = false
var _is_paid_by_hand: bool = false
## Whether the next tap of a payment is being put off for the mana wait, and until when.
## The snapshot asks the Hero nothing meanwhile.
var _is_paying_for_hero: bool = false
var _pay_due_at: int = 0
## What the payment under way has still to tap and spend.
var _payment_left: PaymentPlan = null
## Answer to the latest snapshot's decision → what paying for it would take, or null, for
## each one asked about so far.
var _plans: Dictionary[int, PaymentPlan] = {}


## An encounter from [param setup], with [param villain_agent] answering for the Villain
## and nobody for the Hero. Nothing runs until start().
func _init(setup: MmEncounterSetup, villain_agent: MmAgent) -> void:
	_engine = MmEngine.start(setup)
	_villain_agent = villain_agent
	_driver = MmEncounterDriver.new(_engine, {VILLAIN: villain_agent} as Dictionary[int, MmAgent])
	# One answer for each task, so the screen is told after every Villain decision (A238).
	_driver.decision_cap = 1


## Hands out the first snapshot and sets the Villain thinking if it is theirs to decide.
## Returns at once: the thinking happens on a worker thread.
func start() -> void:
	_has_started = true
	_advance()


## The latest snapshot.
func snapshot() -> EncounterSnapshot:
	return _snapshot


func is_villain_thinking() -> bool:
	return _task != -1


func is_auto_passing() -> bool:
	return _is_auto_passing


## Whether the Hero is yielding the turn (Yield, game glossary).
func is_yielding() -> bool:
	return _is_yielding


func is_paused() -> bool:
	return _is_paused


func is_auto_tapping() -> bool:
	return _is_auto_tapping


## Whether Auto-tap is partway through a payment, showing one tap before the next: nobody
## is thinking, and the Hero is asked nothing. Only canceling the cast is accepted.
func is_paying_for_hero() -> bool:
	return _is_paying_for_hero


## Pauses or resumes the encounter (the Pause Menu). While paused, a thought the Villain
## had already begun finishes on its thread but is not collected, so no snapshot is handed
## out and the screen stays as it was; the Hero's answers are refused. Conceding and
## leaving still work.
func set_paused(is_on: bool) -> void:
	_is_paused = is_on
	if not is_on and _is_reconsider_due:
		_reconsider()


## Whether the Villain has answered and the answer has not been collected yet: it is being
## held back by Pacing or by the Pause Menu.
func is_villain_answer_ready() -> bool:
	return _task != -1 and WorkerThreadPool.is_task_completed(_task)


## Whether a step is being shown for its wait before the Hero is passed for: nobody is
## thinking, and the Hero is asked nothing.
func is_passing_for_hero() -> bool:
	return _is_passing_for_hero


## What Auto-tap would tap and spend to pay for [param answer] to the Hero's priority, or
## null: Auto-tap is off, the Hero does not have priority, the answer neither casts a spell
## nor activates an ability, or it costs no mana. It is exactly what is then paid.
##
## A plan is worked out when it is first asked for and kept until the next snapshot,
## because paying a cost on a copy of the game takes a millisecond for each mana, and
## doing it for every card at every priority took a frame or two. It reads the engine, so
## it gives null while the Villain is thinking.
func payment_plan(answer: int) -> PaymentPlan:
	if not _is_auto_tapping or _task != -1 or _snapshot == null:
		return null
	var priority: PriorityDecision = _snapshot.decision as PriorityDecision
	if priority == null or answer < 0 or answer >= priority.actions.size():
		return null
	if not _plans.has(answer):
		_plans[answer] = _plan_for(priority, answer, _snapshot.view)
	return _plans[answer]


## Call every frame on the main thread: once the Villain has answered and the last snapshot
## has been up for its wait, carries on; and makes a pass for the Hero that was put off
## while a step was shown. Time spent paused counts toward the waits (A368).
func poll() -> void:
	if _is_paused:
		return
	var now: int = clock.call()
	if _is_paying_for_hero:
		if now >= _pay_due_at:
			_advance()
		return
	if now < _step_shown_until:
		return
	if _is_passing_for_hero:
		_advance(true)
	elif is_villain_answer_ready() and now - _shown_at >= _wait:
		_collect()


## Blocks until the Hero must decide or the encounter is over, sitting through no wait. For
## leaving the screen cleanly, and for tests.
func wait_until_idle() -> void:
	while _task != -1 or _is_passing_for_hero or _is_paying_for_hero:
		if _task != -1:
			_collect()
		elif _is_paying_for_hero:
			_advance()
		else:
			_advance(true)


## Answers the Hero's Pending Decision. Returns "" when accepted, or the reason when the
## answer is illegal, in which case nothing changes.
func answer(hero_answer: Variant) -> String:
	if _is_paused:
		return PAUSED
	if _task != -1:
		return BUSY
	if _is_paying_for_hero:
		return PAYING
	if _is_passing_for_hero or _engine.is_over() or _engine.pending_decision().player_id != HERO:
		return NOT_PRIORITY
	var error: String = _engine.submit(hero_answer)
	if error != "":
		return error
	_is_holding = false
	_advance()
	return ""


## Passes priority, if the Hero has it.
func pass_priority() -> String:
	if _is_paused:
		return PAUSED
	if _task != -1:
		return BUSY
	if _is_paying_for_hero:
		return PAYING
	var priority: PriorityDecision = null if _engine.is_over() else _engine.pending_decision() as PriorityDecision
	if _is_passing_for_hero or priority == null or priority.player_id != HERO:
		return NOT_PRIORITY
	return answer(AutoPass.pass_index(priority))


## Undoes the Hero's most recent answer (ADR 0015). Not while Auto-tap is paying: that can
## only be canceled whole.
func undo() -> String:
	if _is_paying_for_hero and not _is_paused and _task == -1:
		return PAYING
	return _rewind(_engine.undo)


## Abandons the spell or ability the Hero is casting (CR 728), which also stops Auto-tap
## partway through paying for it.
func cancel_cast() -> String:
	return _rewind(_engine.cancel_cast)


## The Hero concedes (CR 104.3a), paused or not. A thought the Villain has already begun
## is waited for first, and nothing more of the encounter is played after it.
func concede() -> String:
	var was_thinking: bool = _task != -1
	if was_thinking:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var error: String = _engine.concede(_engine.hero())
	if error == "" or was_thinking:
		_advance()
	return error


## Turns auto-pass on or off (the Pause Menu's settings). Turning it on passes at once if it
## would pass now.
func set_auto_passing(is_on: bool) -> void:
	_is_auto_passing = is_on
	_reconsider()


## Turns Auto-tap on or off (the Pause Menu's settings). A payment already under way stays
## with whoever was making it, the Hero or the game; the setting is read when the next cast
## reaches payment.
func set_auto_tapping(is_on: bool) -> void:
	_is_auto_tapping = is_on
	_reconsider()


## Starts or ends a Yield: every priority of the turn is passed for the Hero, and it ends by
## itself when the next turn begins. Starting one passes at once if the Hero has priority.
## Asked for while the Villain thinks, it is for the turn the game is in when they are done.
func set_yielding(is_on: bool) -> void:
	_is_yielding = is_on
	_yield_turn = NO_TURN
	if is_on and _task == -1 and _snapshot != null:
		_yield_turn = _snapshot.view.game_turn
	_reconsider()


## Sets or clears the stop at [param step] of [param turn_player_id]'s turn. Clearing the
## stop the Hero is waiting at lets auto-pass carry on.
func toggle_stop(turn_player_id: int, step: MmTurn.Step) -> void:
	stops.toggle(turn_player_id, step)
	_reconsider()


func _rewind(rewind: Callable) -> String:
	if _is_paused:
		return PAUSED
	if _task != -1:
		return BUSY
	var error: String = rewind.call()
	if error != "":
		return error
	_is_holding = false
	_own_top_seen = -1
	_is_rewinding = true
	_advance()
	_is_rewinding = false
	return ""


## Auto-pass, a stop or the Yield changed: look at the pending decision again, unless the
## Villain is thinking, when the new setting simply applies from the next decision. Nothing
## moves under the Pause Menu, so there it waits for the game to resume.
func _reconsider() -> void:
	_is_reconsider_due = _is_paused
	# A payment being shown a tap at a time carries on at its own pace, and the next
	# snapshot it makes reads the new setting.
	if _has_started and _task == -1 and not _is_paused and not _is_paying_for_hero:
		_advance()


## Ends the Yield if [param game_turn] is a later turn than the one it was for.
func _keep_yield(game_turn: int) -> void:
	if not _is_yielding:
		return
	if _yield_turn == NO_TURN:
		_yield_turn = game_turn
	elif game_turn != _yield_turn:
		_is_yielding = false


func _collect() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_advance()
	# Only what a Villain answer showed is waited after, and only by the next one (A359).
	_wait = Pacing.wait_for(_snapshot.events, action_wait_msec, mana_wait_msec)


## Carries on until the Hero must decide, the Villain must think, a step must be shown
## before the Hero is passed for, or the encounter is over. [param is_passing_now] makes the
## pass that was put off, without asking again whether to: asking changes the answer.
func _advance(is_passing_now: bool = false) -> void:
	_wait = 0
	var is_pass_due: bool = is_passing_now and _is_passing_for_hero
	_is_passing_for_hero = false
	_is_paying_for_hero = false
	while not _engine.is_over():
		var decision: MmPendingDecision = _engine.pending_decision()
		if not (decision is PayManaDecision and decision.player_id == HERO):
			_is_payment_settled = false
			_payment_left = null
		if decision.player_id != HERO:
			# The snapshot comes first: once the task starts, the engine is the worker's.
			_emit()
			_task = WorkerThreadPool.add_task(_think)
			_snapshot.is_villain_thinking = true
			changed.emit(_snapshot)
			return
		var order: OrderTriggersDecision = decision as OrderTriggersDecision
		if order != null and TriggerOrder.are_alike(order):
			# A344: their order changes nothing, so the Hero is not asked.
			_engine.submit(range(order.abilities.size()))
			continue
		var payment: PayManaDecision = decision as PayManaDecision
		if payment != null:
			if not _pays_for_hero():
				break
			_pay_one(payment)
			if mana_wait_msec > 0 and not _engine.is_over() and _engine.pending_decision() is PayManaDecision:
				# Each tap is shown for the mana wait before the next, as the Villain's are.
				_is_paying_for_hero = true
				_pay_due_at = (clock.call() as int) + mana_wait_msec
				break
			continue
		if is_pass_due:
			is_pass_due = false
		elif not _passes_for_hero(decision):
			break
		elif _is_step_still_showing():
			_is_passing_for_hero = true
			break
		_engine.submit(AutoPass.pass_index(decision as PriorityDecision))
	_emit()
	changed.emit(_snapshot)


## Whether Auto-tap pays the cost the Hero is being asked for. Settled once for each
## payment, when the cast reaches it: by hand with Auto-tap off or the Hold Key down at
## that moment, and always by hand for a payment that a rewind led back to, so that undo
## never has its step paid again under it.
func _pays_for_hero() -> bool:
	if _is_rewinding:
		_is_payment_settled = true
		_is_paid_by_hand = true
	elif not _is_payment_settled:
		_is_payment_settled = true
		_is_paid_by_hand = not _is_auto_tapping or is_hold_key_down
		if not _is_paid_by_hand:
			_payment_left = _plan_on(_copy())
	if _is_paid_by_hand:
		_payment_left = null
	return not _is_paid_by_hand


## Makes one payment of [param payment] as the Villain's Agent would choose it.
func _pay_one(payment: PayManaDecision) -> void:
	var state: MmGameState = _engine.game_state()
	var choice: int = AiPaymentPlanner.choose(state, payment)
	if _payment_left != null:
		_take(_payment_left, state, payment.actions[choice])
	_engine.submit(choice)


## A copy of the game to pay on, with every card where it is.
func _copy() -> MmEngine:
	return _engine.simulation_copy(HERO, MmRng.new(1), true)


## Pays whatever the Hero is asked to pay on [param copy], choosing as _pay_one() does,
## and says what it took. A target asked for on the way is the first offered: what a spell
## is aimed at changes nothing about its cost.
func _plan_on(copy: MmEngine) -> PaymentPlan:
	var plan: PaymentPlan = PaymentPlan.new()
	while not copy.is_over() and not copy.has_failed():
		var decision: MmPendingDecision = copy.pending_decision()
		if decision.player_id != HERO:
			break
		if decision is ChooseTargetDecision:
			copy.submit(0)
			continue
		var payment: PayManaDecision = decision as PayManaDecision
		if payment == null:
			break
		var state: MmGameState = copy.game_state()
		var choice: int = AiPaymentPlanner.choose(state, payment)
		var spend: PayWithManaAction = payment.actions[choice] as PayWithManaAction
		if spend != null:
			plan.add_pool(state.player(HERO).mana_pool()[spend.unit_index].type)
		else:
			plan.add_source((payment.actions[choice] as ActivateAbilityAction).object_id)
		copy.submit(choice)
	return plan


## Takes what [param action] pays with out of [param plan].
static func _take(plan: PaymentPlan, state: MmGameState, action: MmAction) -> void:
	var spend: PayWithManaAction = action as PayWithManaAction
	if spend != null:
		plan.take_pool(state.player(HERO).mana_pool()[spend.unit_index].type)
	else:
		plan.take_source((action as ActivateAbilityAction).object_id)


## What paying for [param answer] to [param priority] would take, or null if it casts and
## activates nothing that costs mana.
func _plan_for(priority: PriorityDecision, answer: int, view: MmPlayerView) -> PaymentPlan:
	var action: MmAction = priority.actions[answer]
	var is_ability: bool = action is ActivateAbilityAction and not AutoPass.is_mana_ability(action, view)
	if not (action is CastSpellAction) and not is_ability:
		return null
	var copy: MmEngine = _copy()
	if copy.submit(answer) != "":
		return null
	var plan: PaymentPlan = _plan_on(copy)
	return null if plan.is_empty() else plan


## Whether the step the game is in has not been shown for the step wait yet: it started
## since the last snapshot, or that snapshot has not been up long enough.
func _is_step_still_showing() -> bool:
	if step_wait_msec <= 0:
		return false
	if (clock.call() as int) < _step_shown_until:
		return true
	var entries: Array[MmEvent] = _engine.event_log()
	return entries.size() > _events_seen and Pacing.starts_step(entries.slice(_events_seen))


## Runs on the worker thread: one answer from the Villain's Agent.
func _think() -> void:
	_driver.run()


func _passes_for_hero(decision: MmPendingDecision) -> bool:
	if not (decision is PriorityDecision):
		return false
	var view: MmPlayerView = _engine.view_for(_engine.hero())
	_keep_yield(view.game_turn)
	if not AutoPass.is_own_object_on_top(view):
		_own_top_seen = -1
	elif view.stack.back().id != _own_top_seen:
		# The Hero's own spell or ability has just gone on top: they get priority back
		# only if the hold key is down right now. Letting go later changes nothing.
		_own_top_seen = view.stack.back().id
		_is_holding = is_hold_key_down
		if not _is_holding:
			return true
	if _is_holding:
		return false
	if not (_is_yielding and AutoPass.yields(decision)) and not (_is_auto_passing and AutoPass.passes(decision, view, stops)):
		return false
	# A pass is due. With the Hold Key down it is not made, and the priority is the Hero's
	# until they answer, as it is after a spell of their own.
	_is_holding = is_hold_key_down
	return not _is_holding


## Builds the snapshot from the engine. Only ever called while no task is running.
func _emit() -> void:
	var made: EncounterSnapshot = EncounterSnapshot.new()
	made.view = _engine.view_for(_engine.hero())
	_keep_yield(made.view.game_turn)
	made.can_undo = _engine.can_undo() and not _is_paying_for_hero
	made.is_holding_priority = _is_holding
	made.is_rewind = _is_rewinding
	if _is_paying_for_hero:
		made.paying = _engine.pending_decision() as PayManaDecision
		made.payment_left = _payment_left.copy()
	elif not _engine.is_over() and _engine.pending_decision().player_id == HERO and not _is_passing_for_hero:
		made.decision = _engine.pending_decision()
	var entries: Array[MmEvent] = _engine.event_log()
	# ADR 0015: a rewind only shortens the log, so it hands out nothing and is never
	# animated; what happens afterwards is counted from the shorter log.
	if entries.size() > _events_seen:
		made.events = entries.slice(_events_seen)
	_events_seen = entries.size()
	_shown_at = clock.call()
	if step_wait_msec > 0 and Pacing.starts_step(made.events):
		_step_shown_until = _shown_at + step_wait_msec
	for seen: MmObjectView in made.visible_objects():
		made.looks[seen.id] = CardLook.of_view(seen, _art_key(seen))
	_snapshot = made
	_plans.clear()


## The art of the card [param seen] is, or for an ability, of the card it came from.
func _art_key(seen: MmObjectView) -> String:
	var card_id: int = seen.card_id if seen.card_id != MmGameObject.NO_CARD else seen.source_card_id
	var run_card: MmRunCard = _engine.run_card(card_id)
	if run_card == null or run_card.base == null:
		return ""
	return run_card.base.resource_path.get_file().get_basename()
