class_name AiAgent
extends MmAgent
## The AI Agent (ADR 0020): answers every kind of Pending Decision for one player. It
## reads its World, the game as its player might imagine it, never the real game state,
## and looks ahead on Simulation Copies. It keeps nothing between decisions apart from the
## reason for its last answer, which is for debugging only.
##
## A FULL Agent answers the real encounter: it scores its options by one-step simulation,
## settles priority decisions by Flat Monte Carlo when its AI Difficulty uses it, and asks
## the Combat Oracle about fights. A CHEAP Agent answers inside simulations by
## heuristics alone, since a simulation inside a simulation would multiply the cost (A178).

enum Mode { FULL, CHEAP }

## A FULL Agent simulates every pick of permanents for a cost up to this many (C(5, 3)).
const MOST_PICKS_SIMULATED: int = 10
## How many creature types a FULL Agent simulates choosing, the best ranked first.
const MOST_TYPES_SIMULATED: int = 3
## What a CHEAP Agent adds to an untapped permanent's worth as the target of its own Aura.
const UNTAPPED_AURA_TARGET_BONUS: int = 1000
## The least life the AI keeps when it pays life for a land to enter untapped, as Temple
## Garden's "you may pay 2 life" (engine ADR 0052).
const MIN_LIFE_AFTER_PAYING: int = 6
## How many lands, controlled and in hand, the AI wants before it graveyards a land it
## surveils: as many as it keeps when it discards (engine ADR 0068).
const SURVEIL_LANDS: int = 6
## The color of mana each basic land type makes (CR 305.6), for ranking what a search finds.
const BASIC_LAND_COLORS: Dictionary[String, MmMana.Type] = {
	"Plains": MmMana.Type.WHITE, "Island": MmMana.Type.BLUE, "Swamp": MmMana.Type.BLACK,
	"Mountain": MmMana.Type.RED, "Forest": MmMana.Type.GREEN,
}

## Why the last answer was chosen (A165). For debugging and tests; never saved.
enum Reason {
	NONE,
	## Only one answer was possible, or the decision has no real choice for it.
	ONLY_CHOICE,
	PLAY_LAND,
	## Nothing but passing was legal or worth looking at.
	NOTHING_WORTH_DOING,
	## A combat trick was held for combat or a response.
	WAIT_FOR_COMBAT,
	## Removal was held for a better moment.
	OUTSIDE_WINDOW,
	## Something could be played, but passing scored at least as well.
	SCORES_WORSE_THAN_PASS,
	## The answer scored best in simulation.
	BEST_SCORE,
	## Attacking with everything is lethal.
	LETHAL_ATTACK,
	## Attackers were chosen by aggression level.
	AGGRESSION,
	## Blocks were made while life was in danger.
	LIFE_IN_DANGER,
	## Blocks were made with life not in danger.
	SAFE_BLOCKS,
	## The AI Profile decided, such as playing first.
	PROFILE,
	## The land count decided a mulligan, or what to put on the bottom or discard.
	LAND_COUNT,
	## Mana was paid by the payment planner.
	PAYMENT_PLAN,
	## Combat damage killed the most valuable blockers first.
	KILL_MOST_VALUABLE,
	## Flat Monte Carlo chose the answer, whether or not it kept the one-step pick (A202).
	ROLLOUT_SCORE,
	## A land was kept back because playing it cost more than it was worth, such as damage
	## from its player's own Ankh of Mishra (AiDifficulty.weighs_land_plays).
	LAND_COSTS_TOO_MUCH,
}

var profile: AiProfile
var mode: Mode
var difficulty: AiDifficulty

## A CHEAP Agent plays no land on this Game Turn or any before it: set in the rollout of a
## land held back, so holding it there means not playing it this turn (_is_land_worth_playing()).
var holds_lands_through_turn: int = 0
var _reason: Reason = Reason.NONE
var _detail: String = ""
var _rollouts: int = 0
var _repeats: int = 0
## The re-dealt worlds the last one-step simulation scored its answers in, as seeds, so a
## Repeat Plan is scored in the same ones.
var _world_seeds: Array[int] = []


## Without [param agent_difficulty] it plays at Normal.
func _init(agent_profile: AiProfile = null, agent_mode: Mode = Mode.FULL, agent_difficulty: AiDifficulty = null) -> void:
	profile = agent_profile if agent_profile != null else AiProfile.new()
	mode = agent_mode
	difficulty = agent_difficulty if agent_difficulty != null else AiDifficulty.normal()


## Why the last answer was chosen.
func explain() -> Reason:
	return _reason


## More about the last answer, for logs, such as each option's score.
func explain_detail() -> String:
	return _detail


## How many rollouts the last answer played, for tests and the benchmark.
func rollout_count() -> int:
	return _rollouts


## How many activations the Repeat Plan behind the last answer holds: 1 for an ability
## weighed once, 0 if the answer activated nothing. For tests and logs.
func repeat_count() -> int:
	return _repeats


func answer(decision: MmPendingDecision, _view: MmPlayerView, source: MmSimulationSource) -> Variant:
	var started: int = Time.get_ticks_msec() if mode == Mode.FULL else 0
	var result: Variant = _answer(decision, source)
	if mode == Mode.FULL:
		_warn_if_slow(decision, Time.get_ticks_msec() - started)
	return result


func _answer(decision: MmPendingDecision, source: MmSimulationSource) -> Variant:
	_reason = Reason.NONE
	_detail = ""
	_rollouts = 0
	_repeats = 0
	var priority: PriorityDecision = decision as PriorityDecision
	if priority != null and priority.actions.size() == 1:
		_reason = Reason.NOTHING_WORTH_DOING
		return 0
	var rng: MmRng = source.ai_rng()
	var world: MmGameState = source.world(rng)
	var me: int = decision.player_id
	if priority != null:
		return _priority(priority, world, source, rng)
	if decision is PayManaDecision:
		_reason = Reason.PAYMENT_PLAN
		return AiPaymentPlanner.choose(world, decision as PayManaDecision)
	if decision is ChooseTargetDecision:
		return _target(decision as ChooseTargetDecision, world, source, rng)
	if decision is ChooseTargetsDecision:
		return _up_to_targets(decision as ChooseTargetsDecision, world, source, rng)
	if decision is DeclareAttackersDecision:
		return _attackers(decision as DeclareAttackersDecision, world, source, rng)
	if decision is DeclareBlockersDecision:
		return _blockers(decision as DeclareBlockersDecision, world, source, rng)
	if decision is DivideCombatDamageDecision:
		return _divide_damage(decision as DivideCombatDamageDecision, world)
	if decision is KeepOrMulliganDecision:
		return _keep_or_mulligan(decision as KeepOrMulliganDecision, world)
	if decision is ChoosePlayOrDrawDecision:
		_reason = Reason.PROFILE
		return ChoosePlayOrDrawDecision.Choice.PLAY if profile.prefers_to_play_first else ChoosePlayOrDrawDecision.Choice.DRAW
	if decision is ChooseCardsToBottomDecision:
		var bottom: ChooseCardsToBottomDecision = decision as ChooseCardsToBottomDecision
		var kept: int = bottom.candidate_ids.size() - bottom.count
		return _least_useful(bottom.candidate_ids, bottom.count, world, me, _ideal_lands(kept))
	if decision is ChooseCardsToDiscardDecision:
		var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
		var on_battlefield: int = _lands_controlled(world, me)
		return _least_useful(discard.candidate_ids, discard.count, world, me, maxi(6 - on_battlefield, 0))
	if decision is OrderTriggersDecision:
		return _order_triggers(decision as OrderTriggersDecision, source, rng)
	if decision is ChooseReplacementEffectDecision:
		return _choose_replacement(decision as ChooseReplacementEffectDecision, source, rng)
	if decision is ChooseObjectDecision:
		return _choose_object(decision as ChooseObjectDecision, world, source, rng)
	if decision is ChooseModeDecision:
		return _choose_mode(decision as ChooseModeDecision, world, source, rng)
	if decision is ChoosePermanentsDecision:
		return _choose_permanents(decision as ChoosePermanentsDecision, world, source, rng)
	if decision is ChooseLegendToKeepDecision:
		return _choose_legend(decision as ChooseLegendToKeepDecision, world, source, rng)
	if decision is ChooseCreatureTypeDecision:
		return _choose_creature_type(decision as ChooseCreatureTypeDecision, world, source, rng)
	if decision is ChooseCardsInLibraryDecision:
		return _search(decision as ChooseCardsInLibraryDecision, world, source, rng)
	if decision is ChooseYesOrNoDecision:
		return _yes_or_no(decision as ChooseYesOrNoDecision, world, source, rng)
	if decision is ChooseXToPayDecision:
		return _choose_x_to_pay(decision as ChooseXToPayDecision, world, source, rng)
	if decision is ChooseXDecision:
		# Engine ADR 0076: the most it could pay. Whether to cast at all was weighed already,
		# with the cast played out by CHEAP Agents, which answer the same.
		_reason = Reason.ONLY_CHOICE if (decision as ChooseXDecision).most == 0 else Reason.BEST_SCORE
		return (decision as ChooseXDecision).most
	if decision is SurveilDecision:
		return _surveil(decision as SurveilDecision, world)
	assert(false, "AiAgent cannot answer %s." % decision.describe())
	return null


# --- Priority ----------------------------------------------------------------------

## Plays a land if it can, unless the AI Difficulty weighs land plays and this one costs
## too much (_is_land_worth_playing()); otherwise compares passing with every play worth
## looking at now (_choose_play()). A land kept back is the reason for a pass.
func _priority(decision: PriorityDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	var passing: int = _pass_index(decision)
	var land: int = _best_land(decision, world) if world.game_turn > holds_lands_through_turn else -1
	var land_detail: String = ""
	if land != -1:
		if mode == Mode.CHEAP or not difficulty.weighs_land_plays or _is_land_worth_playing(source, rng, land, passing, decision.player_id):
			_reason = Reason.PLAY_LAND
			return land
		land_detail = _detail
	var answer: int = _choose_play(decision, world, source, rng, passing)
	if land != -1 and answer == passing:
		_reason = Reason.LAND_COSTS_TOO_MUCH
		_detail = land_detail
	return answer


## Whether [param land] is worth playing rather than holding it for the Game Turn. One step
## ahead, a land that scores at least as well as passing is played; one that scores worse,
## as when a trigger of its player's own deals it damage, is rolled out against passing
## with the land as the default (A192), since one step never sees the spells its mana
## would pay for. Passing is rolled out with its player holding its lands for the rest of
## the Game Turn, or the CHEAP Agent would play the land later in the turn instead. Without
## Flat Monte Carlo the land is kept only if it loses the game in every re-dealt world.
func _is_land_worth_playing(source: MmSimulationSource, rng: MmRng, land: int, passing: int, me: int) -> bool:
	var scores: Array[int] = _simulate_each(source, rng, [passing, land], me)
	if scores[1] >= scores[0]:
		return true
	if not difficulty.uses_monte_carlo:
		return scores[1] > -AiBoardEvaluator.WIN * _world_seeds.size()
	var rolled: Array[int] = [land, passing]
	var samples: int = AiDifficulty.scaled(difficulty.rollout_samples, profile.search_budget_percent)
	var rows: Array = AiMonteCarlo.sample_scores(source, rng, rolled, samples, me, profile, {}, passing)
	_rollouts += rolled.size() * samples
	_detail = AiMonteCarlo.describe(rolled, rows)
	return AiMonteCarlo.choose(rolled, AiMonteCarlo.totals(rows, rolled.size()), AiMonteCarlo.margin(profile, samples), rng) == land


## Compares passing with every play worth looking at now (A161, A183), leaving out a land,
## a spell that only adds mana nothing could be spent on and an ability that would go on
## top of its own earlier activation, by one-step simulation and then, if the AI Difficulty
## uses it, by Flat Monte Carlo (A188). An activated ability is weighed as its best Repeat
## Plan. With a trick among the plays, every option is scored once the Game Turn is over,
## if the AI Difficulty says so. CHEAP Agents use a fixed order instead.
func _choose_play(decision: PriorityDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng, passing: int) -> int:
	var me: int = decision.player_id
	if mode == Mode.CHEAP:
		return _cheap_priority(decision, world, passing)
	var candidates: Array[int] = []
	var held_trick: bool = false
	var held_removal: bool = false
	var offers_trick: bool = false
	for index: int in decision.actions.size():
		var action: MmAction = decision.actions[index]
		if action is PassAction or action is PlayLandAction:
			continue
		var ability: ActivatedAbility = AiTiming.activated_ability_of(world, action)
		if ability != null and ability.is_mana_ability():
			continue
		if AiTiming.is_on_top_of_itself(world, action):
			continue
		var tag: AiTiming.Tag = AiTiming.tag_of_action(world, action)
		if not AiTiming.is_in_window(world, me, tag):
			held_trick = held_trick or AiTiming.is_trick(tag)
			held_removal = held_removal or tag == AiTiming.Tag.REMOVAL
			continue
		if _only_adds_mana(AiTiming.effects_of_action(world, action)) and not _mana_unlocks_a_play(decision, index, source, rng):
			continue
		offers_trick = offers_trick or AiTiming.is_trick(tag)
		candidates.append(index)
	if candidates.is_empty():
		_reason = Reason.WAIT_FOR_COMBAT if held_trick else (Reason.OUTSIDE_WINDOW if held_removal else Reason.NOTHING_WORTH_DOING)
		return passing
	var options: Array[int] = [passing]
	options.append_array(candidates)
	var through_turn: bool = offers_trick and difficulty.judges_tricks_after_the_turn
	var scores: Array[int] = _simulate_each(source, rng, options, me, through_turn)
	var repeats: Dictionary[int, int] = _plan_repeats(decision, world, source, rng, options, scores, through_turn)
	var best: int = _best_option(options, scores, rng, 1)
	if best == passing:
		_reason = Reason.SCORES_WORSE_THAN_PASS
	else:
		_reason = Reason.BEST_SCORE
	if not difficulty.uses_monte_carlo:
		_repeats = _repeats_of(decision, best, repeats)
		return best
	var rolled: Array[int] = AiMonteCarlo.candidates(options, scores, best, passing, difficulty.rollout_candidates)
	if rolled.size() < 2:
		_repeats = _repeats_of(decision, best, repeats)
		return best
	var samples: int = AiDifficulty.scaled(difficulty.rollout_samples, profile.search_budget_percent)
	var rows: Array = AiMonteCarlo.sample_scores(source, rng, rolled, samples, me, profile, repeats)
	_rollouts += rolled.size() * samples
	_reason = Reason.ROLLOUT_SCORE
	_detail = AiMonteCarlo.describe(rolled, rows)
	var chosen: int = AiMonteCarlo.choose(rolled, AiMonteCarlo.totals(rows, rolled.size()), AiMonteCarlo.margin(profile, samples), rng)
	_repeats = _repeats_of(decision, chosen, repeats)
	return chosen


## Weighs each activated ability among [param options] as a Repeat Plan (glossary): the
## ability activated several times, each after the last has resolved, up to as many as
## the engine allows on a Simulation Copy and the AI Difficulty's limit (_plan_lengths()). Where a longer
## plan scores better than a single activation, [param scores] takes its score; an equal
## score keeps the shorter plan, which spends less. Each plan is scored in the same
## re-dealt worlds as the single activation, so they differ only by their length. Returns the length of each plan longer
## than one, by option. Only the best length of an ability goes on to Flat Monte Carlo.
func _plan_repeats(decision: PriorityDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng,
		options: Array[int], scores: Array[int], through_turn: bool) -> Dictionary[int, int]:
	var repeats: Dictionary[int, int] = {}
	if difficulty.repeat_plan_length < 2:
		return repeats
	var me: int = decision.player_id
	var world_seeds: Array[int] = _world_seeds.duplicate()
	for index: int in options.size():
		var option: int = options[index]
		if AiTiming.activated_ability_of(world, decision.actions[option]) == null:
			continue
		var probe: MmEngine = source.simulation_copy(MmRng.new(rng.next_seed()))
		var longest: int = AiSimulation.submit_plan(probe, option, difficulty.repeat_plan_length, me, profile)
		for length: int in _plan_lengths(longest):
			var score: int = 0
			for world_seed: int in world_seeds:
				var copy: MmEngine = source.simulation_copy(MmRng.new(world_seed))
				score += AiSimulation.score_answer(copy, option, me, profile, length, through_turn)
			if score > scores[index]:
				scores[index] = score
				repeats[option] = length
				_detail += ", %d x%d: %d" % [option, length, score]
	return repeats


## The plan lengths worth scoring when [param longest] activations are possible: 2, 4, 8
## and so on, and the longest itself. Scoring every length took decisions with many
## abilities past two seconds, and little is lost by skipping some: only the first
## activation is submitted, and the plan is made again, shorter, at the next priority.
func _plan_lengths(longest: int) -> Array[int]:
	var lengths: Array[int] = []
	var length: int = 2
	while length < longest:
		lengths.append(length)
		length *= 2
	if longest >= 2:
		lengths.append(longest)
	return lengths


## How many activations answering [param option] stands for.
func _repeats_of(decision: PriorityDecision, option: int, repeats: Dictionary[int, int]) -> int:
	if not decision.actions[option] is ActivateAbilityAction:
		return 0
	return repeats.get(option, 1)


## Whether the mana from answering [param index] would let its player make a play now
## that [param decision] does not offer: a cast or activation, in its Timing Tag's window,
## that does more than add mana itself. Asked of the engine on a Simulation Copy, so costs,
## timing and Modifications are all the engine's. Mana that unlocks nothing empties unspent,
## and in a rollout it only changes which lands the CHEAP Agent has left.
func _mana_unlocks_a_play(decision: PriorityDecision, index: int, source: MmSimulationSource, rng: MmRng) -> bool:
	var me: int = decision.player_id
	var copy: MmEngine = source.simulation_copy(MmRng.new(rng.next_seed()))
	if copy.submit(index) != "":
		return false
	var step: MmTurn.Step = copy.game_state().step
	AiSimulation.play_out(copy, me, profile)
	var state: MmGameState = copy.game_state()
	var after: PriorityDecision = copy.pending_decision() as PriorityDecision
	if copy.has_failed() or copy.is_over() or after == null or after.player_id != me or state.step != step:
		return false
	var offered: Dictionary[String, bool] = {}
	for action: MmAction in decision.actions:
		offered[_play_key(action)] = true
	for action: MmAction in after.actions:
		if _play_key(action) == "" or offered.has(_play_key(action)):
			continue
		var ability: ActivatedAbility = AiTiming.activated_ability_of(state, action)
		if ability != null and ability.is_mana_ability():
			continue
		if _only_adds_mana(AiTiming.effects_of_action(state, action)):
			continue
		if AiTiming.is_in_window(state, me, AiTiming.tag_of_action(state, action)):
			return true
	return false


## What identifies a cast or activation between two priority decisions of one player, or
## "" for any other action. Object IDs do not change while a card stays where it is.
func _play_key(action: MmAction) -> String:
	if action is CastSpellAction:
		var cast: CastSpellAction = action as CastSpellAction
		return "cast %d%s" % [cast.object_id, " adventure" if cast.as_adventure else ""]
	if action is ActivateAbilityAction:
		var activate: ActivateAbilityAction = action as ActivateAbilityAction
		return "activate %d %d %d" % [activate.object_id, activate.ability_index, activate.mana_type]
	return ""


## A CHEAP Agent's priority: with the other player's spell on top of the stack, counter it
## if it costs at least as much as the counter. Otherwise, in its own main phase with
## nothing on the stack, cast the most expensive spell that is neither a combat trick nor a
## source of mana, removal only with something of the other player's to aim at; of two that
## cost the same, one cast from the top of the library, which keeps a card in hand
## (ADR 0054). (A counter cannot be
## cast then: there is no spell to aim it at.) It never activates abilities, and never
## counters one.
func _cheap_priority(decision: PriorityDecision, world: MmGameState, passing: int) -> int:
	var me: int = decision.player_id
	var counter: int = _cheap_counter(decision, world)
	if counter != -1:
		_reason = Reason.BEST_SCORE
		return counter
	var main_phase: bool = world.step == MmTurn.Step.PRECOMBAT_MAIN or world.step == MmTurn.Step.POSTCOMBAT_MAIN
	if world.active_player_id != me or not main_phase or not world.stack.is_empty():
		_reason = Reason.NOTHING_WORTH_DOING
		return passing
	var best: int = passing
	var best_cost: int = -1
	var best_from_library: bool = false
	for index: int in decision.actions.size():
		var cast: CastSpellAction = decision.actions[index] as CastSpellAction
		if cast == null:
			continue
		var effects: Array[MmEffect] = AiTiming.effects_of_action(world, cast)
		var tag: AiTiming.Tag = AiTiming.tag_of_action(world, cast)
		if AiTiming.is_trick(tag) or _adds_mana(effects):
			continue
		if tag == AiTiming.Tag.REMOVAL and not _has_something_to_remove(world, cast, me):
			continue
		if _life_it_would_pay(world, cast) >= world.player(me).life:
			continue  # Never pay the life it has left.
		var cost: int = AiTiming.characteristics_of_cast(world, cast).mana_value()
		var from_library: bool = world.object(cast.object_id).zone().kind == MmZone.Kind.LIBRARY
		if cost > best_cost or (cost == best_cost and from_library and not best_from_library):
			best = index
			best_cost = cost
			best_from_library = from_library
	_reason = Reason.NOTHING_WORTH_DOING if best == passing else Reason.BEST_SCORE
	return best


## How much life casting [param cast] would cost: a flashback cost's "Pay N life" for a card
## in a graveyard (CR 702.34a), and nothing from the hand.
static func _life_it_would_pay(world: MmGameState, cast: CastSpellAction) -> int:
	var card: MmGameObject = world.object(cast.object_id)
	if card.zone().kind != MmZone.Kind.GRAVEYARD:
		return 0
	var flashback: FlashbackAbility = CastProcedure.flashback_of(world.characteristics_of(card))
	var life: int = 0
	for cost: MmCost in flashback.costs:
		if cost is PayLifeCost:
			life += (cost as PayLifeCost).amount
	return life


## Whether removal cast by [param me] has something of the other player's to aim at: a
## permanent its first target requirement accepts, so that it is never left with only its
## own. Removal that targets nothing needs only an opposing creature.
func _has_something_to_remove(world: MmGameState, cast: CastSpellAction, me: int) -> bool:
	for ability: MmAbility in AiTiming.characteristics_of_cast(world, cast).abilities:
		var spell: SpellAbility = ability as SpellAbility
		if spell == null:
			continue
		var first_targets: Array[TargetRequirement] = []
		for requirements: Array[TargetRequirement] in _target_lists(spell):
			if not requirements.is_empty():
				first_targets.append(requirements[0])
		if first_targets.is_empty():
			continue
		# A modal spell has something to remove when any mode has.
		for requirement: TargetRequirement in first_targets:
			for found: MmReference in requirement.legal_targets(world, MmEffectContext.new(me, cast.object_id)):
				if found.is_object() and world.object(found.id).controller_id != me:
					return true
		return false
	return not _creatures_of(world, 1 - me).is_empty()


## The target requirements of [param spell]: its own, or each of its modes'.
static func _target_lists(spell: SpellAbility) -> Array[Array]:
	if not spell.is_modal():
		return [spell.targets]
	var lists: Array[Array] = []
	for mode: AbilityMode in spell.modes:
		lists.append(mode.targets)
	return lists


## The cheapest counter worth casting at the other player's spell on top of the stack: one
## that costs no more than that spell does. -1 if there is none. A counter that can only
## be aimed at an ability is never cast: what an ability would do is not read from a cost.
func _cheap_counter(decision: PriorityDecision, world: MmGameState) -> int:
	if world.stack.is_empty():
		return -1
	var top: MmGameObject = world.stack.objects().back()
	if not top.is_card() or top.controller_id == decision.player_id \
			or world.characteristics_of(top).has_ability(CantBeCounteredAbility):
		return -1
	var top_cost: int = world.characteristics_of(top).mana_value()
	var best: int = -1
	var best_cost: int = top_cost + 1
	for index: int in decision.actions.size():
		var cast: CastSpellAction = decision.actions[index] as CastSpellAction
		if cast == null or AiTiming.tag_of_action(world, cast) != AiTiming.Tag.COUNTER or not _targets_spells(world, cast):
			continue
		var cost: int = AiTiming.characteristics_of_cast(world, cast).mana_value()
		if cost < best_cost:
			best = index
			best_cost = cost
	return best


## Whether the spell [param cast] casts has a target requirement that asks for a spell.
func _targets_spells(world: MmGameState, cast: CastSpellAction) -> bool:
	for ability: MmAbility in AiTiming.characteristics_of_cast(world, cast).abilities:
		var spell: SpellAbility = ability as SpellAbility
		if spell == null:
			continue
		for requirements: Array[TargetRequirement] in _target_lists(spell):
			for requirement: TargetRequirement in requirements:
				if requirement.among == TargetRequirement.Among.SPELLS:
					return true
	return false


## The land to play: the one making the color the hand needs most. When one of them enters
## tapped (EntersTappedAbility, or an entry cost it would not pay), an untapped land that
## lets a spell in hand be cast this turn comes first, one that costs no life before one
## that does, then a land that enters tapped, since its mana is not missed this turn, then
## the other untapped lands.
func _best_land(decision: PriorityDecision, world: MmGameState) -> int:
	var needed: Dictionary[int, int] = AiPaymentPlanner.colors_needed_by_hand(world, decision.player_id)
	var plays: Array[int] = []
	var any_enters_tapped: bool = false
	for index: int in decision.actions.size():
		var play: PlayLandAction = decision.actions[index] as PlayLandAction
		if play != null:
			plays.append(index)
			var characteristics: MmCharacteristics = world.characteristics_of(world.object(play.object_id))
			any_enters_tapped = any_enters_tapped or characteristics.has_ability(EntersTappedAbility) \
				or characteristics.has_ability(AsEntersPayOrEntersTappedAbility)
	var best: int = -1
	var best_rank: int = -1
	var best_need: int = -1
	for index: int in plays:
		var land: MmGameObject = world.object((decision.actions[index] as PlayLandAction).object_id)
		var characteristics: MmCharacteristics = world.characteristics_of(land)
		var made: Array[MmMana.Type] = _mana_made_by_land(characteristics)
		var need: int = 0
		for type: MmMana.Type in made:
			need = maxi(need, needed.get(type, 0))
		var rank: int = 0
		if any_enters_tapped:
			var paid_for: bool = characteristics.has_ability(AsEntersPayOrEntersTappedAbility)
			if characteristics.has_ability(EntersTappedAbility) or (paid_for and not _pays_to_enter(world, land)):
				rank = 1
			elif _unlocks_a_spell(world, decision.player_id, made):
				rank = 2 if paid_for else 3
		if rank > best_rank or (rank == best_rank and need > best_need):
			best = index
			best_rank = rank
			best_need = need
	return best


## The types of mana the mana abilities of a land with [param characteristics] add, every
## color for mana of any color.
static func _mana_made_by_land(characteristics: MmCharacteristics) -> Array[MmMana.Type]:
	var made: Array[MmMana.Type] = []
	for ability: MmAbility in characteristics.abilities:
		var activated: ActivatedAbility = ability as ActivatedAbility
		if activated == null:
			continue
		for effect: MmEffect in activated.effects:
			var add_mana: AddManaEffect = effect as AddManaEffect
			if add_mana == null:
				continue
			for type: MmMana.Type in add_mana.possible_types():
				if not made.has(type):
					made.append(type)
	return made


## Whether one more mana of a type in [param made] would let [param player_id] pay for a
## spell in their hand that they cannot pay for now, at the cost a cast would pay, less its
## cost reductions as they are now (ADR 0050).
static func _unlocks_a_spell(world: MmGameState, player_id: int, made: Array[MmMana.Type]) -> bool:
	for card: MmGameObject in world.player(player_id).hand.objects():
		var cost: MmManaCost = CastProcedure.mana_to_pay(world, player_id, card)
		if world.characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND) or cost == null \
				or ManaPayment.can_afford(world, player_id, cost):
			continue
		for type: MmMana.Type in made:
			if ManaPayment.can_afford(world, player_id, _less_one(cost, type)):
				return true
	return false


## [param cost] with one mana of [param type] already paid: a symbol of that type if it has
## one, else a hybrid symbol of that type, else one generic, as a payment spends it (ADR 0077).
static func _less_one(cost: MmManaCost, type: MmMana.Type) -> MmManaCost:
	var one: MmManaCost = MmManaCost.new()
	one.symbols = [type] as Array[MmMana.Type]
	return cost.reduced_by(one)


# --- Targets, triggers and replacement effects --------------------------------------

## FULL: simulates each target; a tap, through the turn, with the CHEAP pick the default.
## CHEAP: harmful effects at the most valuable opposing creature they would kill, else the
## opponent; a tap at the most valuable untapped one; helpful ones at its own best
## creature; a counter at the other player's most expensive spell. A fight (CR 701.14) sends
## in its own most powerful creature, then aims at what that creature's power would kill. An Aura spell is aimed
## only at its own permanents (_is_helpful_aura()), an untapped one first in CHEAP.
func _target(decision: ChooseTargetDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	if decision.candidates.size() == 1:
		_reason = Reason.ONLY_CHOICE
		return 0
	if mode == Mode.FULL:
		var effects: Array[MmEffect] = _effects_of_stack_object(world, decision.stack_object_id)
		var taps: bool = AiTiming.taps(effects)
		var options: Array[int] = []
		# A tap often changes nothing the turn can show, as after combat, so the Cheap pick
		# is the default and another target must score better.
		if taps:
			options.append(_cheap_target(decision, world))
		# A helpful Aura scores the same on either side, since the Board Evaluator values
		# what is enchanted and the Aura apart, so only its own permanents are simulated.
		var own_only: bool = _is_helpful_aura(world, decision.stack_object_id) \
			and _has_own_candidate(decision, world)
		for index: int in decision.candidates.size():
			if own_only and not _is_own_object(decision.candidates[index], world, decision.player_id):
				continue
			if not options.has(index):
				options.append(index)
		var lasts_the_turn: bool = AiTiming.is_trick(AiTiming.tag_of_effects(effects)) or taps
		var scores: Array[int] = _simulate_each(source, rng, options, decision.player_id,
			lasts_the_turn and difficulty.judges_tricks_after_the_turn)
		_reason = Reason.BEST_SCORE
		return _best_option(options, scores, rng, 1 if taps else 0)
	return _cheap_target(decision, world)


func _cheap_target(decision: ChooseTargetDecision, world: MmGameState) -> int:
	var me: int = decision.player_id
	var effects: Array[MmEffect] = _effects_of_stack_object(world, decision.stack_object_id)
	var tag: AiTiming.Tag = AiTiming.tag_of_effects(effects)
	var harmful: bool = AiTiming.is_harmful(effects)
	var taps: bool = AiTiming.taps(effects)
	var damage: int = _damage_of(effects, world, decision.stack_object_id)
	var fight: FightEffect = _fight_of(effects)
	if fight != null:
		if _is_target(fight.creature, decision.target_index):
			return _strongest_own_fighter(decision, world)
		damage = _fighter_power(fight, world, decision.stack_object_id)
	var is_aura: bool = _is_helpful_aura(world, decision.stack_object_id)
	var best: int = -1
	var best_value: int = -1
	var player_index: int = -1
	for index: int in decision.candidates.size():
		var candidate: MmReference = decision.candidates[index]
		if candidate.is_player():
			if (candidate.id != me) == harmful:
				player_index = index
			continue
		var target: MmGameObject = world.object(candidate.id)
		if (target.controller_id != me) != harmful:
			continue
		if not _can_pay_ward_of(world, me, target, decision.stack_object_id):
			continue
		if harmful and damage > 0 and world.characteristics_of(target).toughness - target.damage_marked > damage:
			continue
		if taps and target.is_tapped:
			continue
		if tag == AiTiming.Tag.COUNTER and world.characteristics_of(target).has_ability(CantBeCounteredAbility):
			continue
		var value: int = AiBoardEvaluator.creature_value(world, target)
		if tag == AiTiming.Tag.COUNTER:
			value = world.characteristics_of(target).mana_value()
		if is_aura and not target.is_tapped:
			value += UNTAPPED_AURA_TARGET_BONUS  # What it gives can be used this turn.
		if value > best_value:
			best = index
			best_value = value
	_reason = Reason.BEST_SCORE
	if best != -1:
		return best
	return player_index if player_index != -1 else 0


## The fight among [param effects] (CR 701.14), or null.
static func _fight_of(effects: Array[MmEffect]) -> FightEffect:
	for effect: MmEffect in AiTiming.unwrapped(effects):
		if effect is FightEffect:
			return effect as FightEffect
	return null


## Whether [param selection] is the target chosen for requirement [param target_index].
static func _is_target(selection: MmSelection, target_index: int) -> bool:
	var targeted: TargetSelection = selection as TargetSelection
	return targeted != null and targeted.target_index == target_index


## The candidate of [param decision] that is its chooser's own creature with the most
## power, the most toughness breaking a tie: it deals the most and is likeliest to live.
func _strongest_own_fighter(decision: ChooseTargetDecision, world: MmGameState) -> int:
	_reason = Reason.BEST_SCORE
	var best: int = 0
	var best_power: int = -1
	var best_toughness: int = -1
	for index: int in decision.candidates.size():
		if not _is_own_object(decision.candidates[index], world, decision.player_id):
			continue
		var characteristics: MmCharacteristics = world.characteristics_of(world.object(decision.candidates[index].id))
		if characteristics.power > best_power or (characteristics.power == best_power and characteristics.toughness > best_toughness):
			best = index
			best_power = characteristics.power
			best_toughness = characteristics.toughness
	return best


## The power of the creature [param fight] sends in, once its target is chosen, else 0.
func _fighter_power(fight: FightEffect, world: MmGameState, stack_object_id: int) -> int:
	var item: MmGameObject = world.object(stack_object_id)
	if item == null:
		return 0
	for found: MmReference in fight.creature.select(world, MmEffectContext.of_stack_object(item, item.targets)):
		var fighter: MmGameObject = world.object(found.id) if found.is_object() else null
		if fighter != null:
			return maxi(0, world.characteristics_of(fighter).power)
	return 0


## Whether [param stack_object_id] is an Aura spell (CR 303.4a) whose enchanting helps what
## it enchants, so it is aimed at its controller's own permanents. Every Aura so far helps.
# Later: an Aura whose static abilities harm what it enchants, such as "Enchanted creature
# can't attack", aimed at the other player's permanents, once a card has one.
static func _is_helpful_aura(world: MmGameState, stack_object_id: int) -> bool:
	var item: MmGameObject = world.object(stack_object_id)
	return item != null and item.is_card() and world.characteristics_of(item).has_ability(EnchantAbility)


## Whether [param candidate] is a permanent [param player_id] controls.
static func _is_own_object(candidate: MmReference, world: MmGameState, player_id: int) -> bool:
	return candidate.is_object() and world.object(candidate.id).controller_id == player_id


static func _has_own_candidate(decision: ChooseTargetDecision, world: MmGameState) -> bool:
	for candidate: MmReference in decision.candidates:
		if _is_own_object(candidate, world, decision.player_id):
			return true
	return false


## "Up to N" targets (CR 601.2c). FULL: one target at a time, simulating each candidate
## added to those already chosen beside stopping there, and stopping when no addition scores
## better than stopping. CHEAP: the candidates _cheap_target() would aim at, most valuable
## first, as many as may be chosen.
func _up_to_targets(decision: ChooseTargetsDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> Array:
	_reason = Reason.BEST_SCORE
	var most: int = mini(decision.most, decision.candidates.size())
	if mode == Mode.CHEAP:
		return _cheap_up_to_targets(decision, world).slice(0, most)
	var effects: Array[MmEffect] = _effects_of_stack_object(world, decision.stack_object_id)
	var lasts_the_turn: bool = AiTiming.is_trick(AiTiming.tag_of_effects(effects)) or AiTiming.taps(effects)
	var chosen: Array = []
	while chosen.size() < most:
		var answers: Array = [chosen.duplicate()]
		for index: int in decision.candidates.size():
			if not chosen.has(index):
				var added: Array = chosen.duplicate()
				added.append(index)
				answers.append(added)
		var options: Array[int] = []
		for index: int in answers.size():
			options.append(index)
		var scores: Array[int] = _simulate_each(source, rng, answers, decision.player_id,
			lasts_the_turn and difficulty.judges_tricks_after_the_turn)
		# Stopping is the default: another target must score better to be added.
		var best: int = _best_option(options, scores, rng, 1)
		if best == 0:
			break
		chosen = answers[best]
	return chosen


## The candidates of [param decision] _cheap_target() would aim at, most valuable first:
## harmful effects at the other player's creatures, helpful ones at its own.
func _cheap_up_to_targets(decision: ChooseTargetsDecision, world: MmGameState) -> Array:
	var me: int = decision.player_id
	var effects: Array[MmEffect] = _effects_of_stack_object(world, decision.stack_object_id)
	var harmful: bool = AiTiming.is_harmful(effects)
	var taps: bool = AiTiming.taps(effects)
	var ranked: Array[int] = []
	var values: Dictionary[int, int] = {}
	for index: int in decision.candidates.size():
		var target: MmGameObject = world.object(decision.candidates[index].id)
		if (target.controller_id != me) != harmful or (taps and target.is_tapped):
			continue
		if not _can_pay_ward_of(world, me, target, decision.stack_object_id):
			continue
		values[index] = AiBoardEvaluator.creature_value(world, target)
		ranked.append(index)
	ranked.sort_custom(func(a: int, b: int) -> bool: return values[a] > values[b] or (values[a] == values[b] and a < b))
	var answer: Array = []
	answer.assign(ranked)
	return answer


func _order_triggers(decision: OrderTriggersDecision, source: MmSimulationSource, rng: MmRng) -> Array:
	var count: int = decision.source_object_ids.size()
	var orders: Array = _permutations(count) if mode == Mode.FULL and count <= 3 else [range(count)]
	if orders.size() == 1:
		_reason = Reason.ONLY_CHOICE
		return orders[0]
	var scores: Array[int] = _simulate_each(source, rng, orders, decision.player_id)
	var options: Array[int] = []
	for index: int in orders.size():
		options.append(index)
	_reason = Reason.BEST_SCORE
	return orders[_best_option(options, scores, rng, 0)]


## A choice made as a spell or ability resolves (CR 608.2d). FULL: simulates each
## candidate. CHEAP: its own least valuable permanent, which costs it least to lose or have
## returned to its hand; with none of its own, the first. A card chosen from among cards
## that are not permanents, such as the cards just milled (engine ADR 0080), is going to
## its hand, so CHEAP takes the one with the greatest mana value.
func _choose_object(decision: ChooseObjectDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	if decision.candidates.size() == 1:
		_reason = Reason.ONLY_CHOICE
		return 0
	_reason = Reason.BEST_SCORE
	if mode == Mode.FULL:
		var options: Array[int] = []
		for index: int in decision.candidates.size():
			options.append(index)
		return _best_option(options, _simulate_each(source, rng, options, decision.player_id), rng, 0)
	var first: MmGameObject = world.object(decision.candidates[0].id)
	if first != null and first.zone() != world.battlefield:
		return _greatest_mana_value(decision.candidates, world)
	var least: int = 0
	var least_value: int = -1
	for index: int in decision.candidates.size():
		var candidate: MmGameObject = world.object(decision.candidates[index].id)
		if candidate == null or candidate.controller_id != decision.player_id:
			continue
		var value: int = AiBoardEvaluator.permanent_value(world, candidate, profile)
		if least_value == -1 or value < least_value:
			least = index
			least_value = value
	return least


## The index of the card in [param candidates] with the greatest mana value, the first of
## those tied.
static func _greatest_mana_value(candidates: Array[MmReference], world: MmGameState) -> int:
	var best: int = 0
	var best_value: int = -1
	for index: int in candidates.size():
		var card: MmGameObject = world.object(candidates[index].id)
		var value: int = world.characteristics_of(card).mana_value() if card != null else -1
		if value > best_value:
			best = index
			best_value = value
	return best


## The permanents picked to pay part of a cost, such as creatures to tap (CR 601.2h).
## FULL: simulates every pick while there are at most MOST_PICKS_SIMULATED of them. Otherwise,
## and at CHEAP, its least valuable, which puts first a creature with summoning sickness,
## since it could not attack this turn anyway (AiBoardEvaluator.permanent_value()).
func _choose_permanents(decision: ChoosePermanentsDecision, world: MmGameState, source: MmSimulationSource,
		rng: MmRng) -> Array[int]:
	if decision.candidate_ids.size() == decision.count:
		_reason = Reason.ONLY_CHOICE
		return decision.candidate_ids.duplicate()
	_reason = Reason.BEST_SCORE
	if mode == Mode.FULL:
		var picks: Array = _combinations(decision.candidate_ids, decision.count)
		if picks.size() <= MOST_PICKS_SIMULATED:
			var options: Array[int] = []
			for index: int in picks.size():
				options.append(index)
			var chosen: Array[int] = []
			chosen.assign(picks[_best_option(options, _simulate_each(source, rng, picks, decision.player_id), rng, 0)])
			return chosen
	var ranked: Array[int] = decision.candidate_ids.duplicate()
	var values: Dictionary[int, int] = {}
	for id: int in ranked:
		values[id] = AiBoardEvaluator.permanent_value(world, world.object(id), profile)
	ranked.sort_custom(func(a: int, b: int) -> bool: return values[a] < values[b] or (values[a] == values[b] and a < b))
	var least: Array[int] = ranked.slice(0, decision.count)
	least.sort()
	return least


## The legend kept by the legend rule (CR 704.5j). FULL: simulates keeping each. CHEAP: its
## most valuable, which keeps one that can attack over one with summoning sickness
## (AiBoardEvaluator.permanent_value()); on a tie, the oldest.
func _choose_legend(decision: ChooseLegendToKeepDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	_reason = Reason.BEST_SCORE
	if mode == Mode.FULL:
		var options: Array[int] = []
		for index: int in decision.candidate_ids.size():
			options.append(index)
		return _best_option(options, _simulate_each(source, rng, options, decision.player_id), rng, 0)
	var most: int = 0
	var most_value: int = -1
	for index: int in decision.candidate_ids.size():
		var value: int = AiBoardEvaluator.permanent_value(world, world.object(decision.candidate_ids[index]), profile)
		if value > most_value:
			most = index
			most_value = value
	return most


## The creature type chosen as a permanent enters (CR 614.12). Only the types of its own
## creatures are worth anything to it, ranked by how many it controls, then how many creature
## cards of the type it owns in its hand, graveyard and library (it knows its own deck), then
## the list's order. FULL: simulates the best MOST_TYPES_SIMULATED. CHEAP: the best. With no
## creature anywhere: the first type, with nothing simulated.
func _choose_creature_type(decision: ChooseCreatureTypeDecision, world: MmGameState, source: MmSimulationSource,
		rng: MmRng) -> int:
	var ranked: Array[int] = _ranked_creature_types(decision, world)
	if ranked.size() <= 1:
		_reason = Reason.ONLY_CHOICE
		return 0 if ranked.is_empty() else ranked[0]
	_reason = Reason.BEST_SCORE
	if mode == Mode.CHEAP:
		return ranked[0]
	var options: Array[int] = ranked.slice(0, MOST_TYPES_SIMULATED)
	return _best_option(options, _simulate_each(source, rng, options, decision.player_id), rng, 0)


## The answers to [param decision] naming a type of a creature the deciding player controls or
## a creature card they own, best first (_choose_creature_type()).
static func _ranked_creature_types(decision: ChooseCreatureTypeDecision, world: MmGameState) -> Array[int]:
	var me: MmPlayer = world.player(decision.player_id)
	var controlled: Dictionary[int, int] = {}
	var elsewhere: Dictionary[int, int] = {}
	for permanent: MmGameObject in world.battlefield.objects():
		if permanent.controller_id == me.id:
			_count_creature_types(decision, world, permanent, controlled)
	for zone: MmZone in [me.hand, me.graveyard, me.library]:
		for card: MmGameObject in zone.objects():
			_count_creature_types(decision, world, card, elsewhere)
	var ranked: Array[int] = []
	for index: int in controlled.keys() + elsewhere.keys():
		if not ranked.has(index):
			ranked.append(index)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		if controlled.get(a, 0) != controlled.get(b, 0):
			return controlled.get(a, 0) > controlled.get(b, 0)
		if elsewhere.get(a, 0) != elsewhere.get(b, 0):
			return elsewhere.get(a, 0) > elsewhere.get(b, 0)
		return a < b)
	return ranked


## Adds one to [param counts] for each creature type of [param game_object], if it is a
## creature, keyed by the type's answer to [param decision].
static func _count_creature_types(decision: ChooseCreatureTypeDecision, world: MmGameState, game_object: MmGameObject,
		counts: Dictionary[int, int]) -> void:
	var characteristics: MmCharacteristics = world.characteristics_of(game_object)
	if not characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		return
	for index: int in decision.creature_types.size():
		if characteristics.has_subtype(decision.creature_types[index]):
			counts[index] = counts.get(index, 0) + 1


## Every way to pick [param count] of [param ids], each in ID order, in a fixed order.
static func _combinations(ids: Array[int], count: int) -> Array:
	if count == 0:
		return [[]]
	var result: Array = []
	for first: int in range(ids.size() - count + 1):
		for rest: Variant in _combinations(ids.slice(first + 1), count - 1):
			result.append([ids[first]] + (rest as Array))
	return result


## The mode of a modal spell being cast (CR 601.2b), or of a modal triggered ability being
## put on the stack (CR 603.3c). FULL: simulates each mode. CHEAP:
## the first mode that could reach a permanent or player of the other player's; with none,
## the first.
func _choose_mode(decision: ChooseModeDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	if decision.modes.size() == 1:
		_reason = Reason.ONLY_CHOICE
		return 0
	_reason = Reason.BEST_SCORE
	if mode == Mode.FULL:
		var options: Array[int] = []
		for index: int in decision.modes.size():
			options.append(index)
		return _best_option(options, _simulate_each(source, rng, options, decision.player_id), rng, 0)
	for index: int in decision.modes.size():
		for reached: MmReference in decision.mode_targets[index]:
			if reached.is_player() and reached.id != decision.player_id:
				return index
			if reached.is_object() and world.object(reached.id).controller_id != decision.player_id:
				return index
	return 0


## Whether to do what a "you may" offers (CR 603.5). CHEAP: a harmful effect, such as a
## tap, only when it reaches something of the other player's; any other only when it
## reaches something of its own or nothing chosen at all. FULL: simulates both, a tap
## through the turn, with the CHEAP answer the default that the other must beat.
## Whether to pay a cost so as not to be countered, as ward's (ADR 0062): CHEAP pays, since
## it is asked only when it can and the spell or ability was worth casting; FULL simulates
## both, with paying the default.
## Whether to pay for a land to enter untapped (engine ADR 0052): CHEAP as _pays_to_enter()
## says; FULL simulates both, with that answer the default.
func _yes_or_no(decision: ChooseYesOrNoDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	_reason = Reason.BEST_SCORE
	var cheap: int = ChooseYesOrNoDecision.Choice.YES
	if decision.entry_cost != null:
		var pays: bool = _pays_to_enter(world, world.object(decision.entering_object_id))
		cheap = ChooseYesOrNoDecision.Choice.YES if pays else ChooseYesOrNoDecision.Choice.NO
	elif decision.cost == null:
		cheap = _cheap_yes_or_no(decision, world)
	if mode == Mode.CHEAP:
		return cheap
	var offered: Array[MmEffect] = []
	if decision.effect != null:
		offered.append(decision.effect)
	var other: int = ChooseYesOrNoDecision.Choice.NO if cheap == ChooseYesOrNoDecision.Choice.YES \
		else ChooseYesOrNoDecision.Choice.YES
	var options: Array[int] = [cheap, other]
	var scores: Array[int] = _simulate_each(source, rng, options, decision.player_id,
		AiTiming.taps(offered) and difficulty.judges_tricks_after_the_turn)
	return _best_option(options, scores, rng, 1)


## How much X to pay for a "you may pay {X}" (ADR 0061). Only the Xs worth paying are
## weighed (xs_worth_paying()). CHEAP: the largest of them, or declining when there is
## none. FULL: simulates declining and each of them, with the CHEAP answer the default that
## another must beat, so mana kept for the rest of the turn is weighed against what X buys.
func _choose_x_to_pay(decision: ChooseXToPayDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> int:
	var worth: Array[int] = xs_worth_paying(decision, world)
	if worth.is_empty():
		_reason = Reason.ONLY_CHOICE
		return ChooseXToPayDecision.DECLINE
	_reason = Reason.BEST_SCORE
	var cheap: int = ChooseXToPayDecision.answer_for(worth.back())
	if mode == Mode.CHEAP:
		return cheap
	var options: Array[int] = [cheap, ChooseXToPayDecision.DECLINE]
	for x: int in worth:
		if ChooseXToPayDecision.answer_for(x) != cheap:
			options.append(ChooseXToPayDecision.answer_for(x))
	var scores: Array[int] = _simulate_each(source, rng, options, decision.player_id)
	return _best_option(options, scores, rng, 1)


## The Xs worth paying, smallest first: each X at which what the "you may pay {X}" wraps,
## begun with that X paid, offers something no smaller X does, such as a search finding a
## card of a higher mana value. Every other X pays more for the same. For an effect that
## asks nothing of its own, only the most, and only if it is more than 0. The Encounter
## Presenter starts the Hero's X stepper at the largest of them (game ADR 0063).
static func xs_worth_paying(decision: ChooseXToPayDecision, world: MmGameState) -> Array[int]:
	var worth: Array[int] = []
	var item: MmGameObject = world.object(decision.stack_object_id)
	var context: MmEffectContext = MmEffectContext.of_stack_object(item, item.targets)
	var offered: Array[String] = []
	for x: int in decision.most + 1:
		var asked: MmPendingDecision = decision.effect.decision_as_it_begins(world, context.with_paid_x(x), decision.stack_object_id)
		if asked == null or not asked is ChooseCardsInLibraryDecision:
			return [decision.most] as Array[int] if decision.most > 0 else worth
		var search: ChooseCardsInLibraryDecision = asked as ChooseCardsInLibraryDecision
		var found: Array[int] = search.candidate_ids.duplicate()
		found.sort()
		var findable: String = "%s up to %d" % [found, mini(search.most, found.size())]
		if found.is_empty() or search.most <= 0 or offered.has(findable):
			continue
		offered.append(findable)
		worth.append(x)
	return worth


## Whether to pay for [param land] to enter untapped, as Temple Garden's 2 life (engine
## ADR 0052): only when its mana lets a spell in hand be cast this turn and its controller
## keeps at least MIN_LIFE_AFTER_PAYING life.
func _pays_to_enter(world: MmGameState, land: MmGameObject) -> bool:
	var characteristics: MmCharacteristics = world.characteristics_of(land)
	var cost: PayLifeCost = null
	for ability: MmAbility in characteristics.abilities:
		if ability is AsEntersPayOrEntersTappedAbility:
			cost = (ability as AsEntersPayOrEntersTappedAbility).cost as PayLifeCost
	if cost == null or not cost.can_pay(world, land, land.controller_id):
		return false  # Later: an entry cost other than life, once a card has one.
	return world.player(land.controller_id).life - cost.amount >= MIN_LIFE_AFTER_PAYING \
		and _unlocks_a_spell(world, land.controller_id, _mana_made_by_land(characteristics))


func _cheap_yes_or_no(decision: ChooseYesOrNoDecision, world: MmGameState) -> int:
	var me: int = decision.player_id
	var harmful: bool = AiTiming.is_harmful([decision.effect])
	var reaches_theirs: bool = false
	var reaches_mine: bool = false
	var item: MmGameObject = world.object(decision.stack_object_id)
	var chosen_targets: Array[MmReference] = item.targets if item != null else [] as Array[MmReference]
	for chosen: MmReference in chosen_targets:
		if chosen == null:
			continue
		var whose: int = chosen.id
		if chosen.is_object():
			var reached: MmGameObject = world.object(chosen.id)
			whose = reached.controller_id if reached != null else me
		if whose == me:
			reaches_mine = true
		else:
			reaches_theirs = true
	var says_yes: bool = reaches_theirs if harmful else (reaches_mine or not reaches_theirs)
	return ChooseYesOrNoDecision.Choice.YES if says_yes else ChooseYesOrNoDecision.Choice.NO


## The cards found by a search (ADR 0057), always as many as may be found. FULL: simulates
## finding one card of each name it could find, and keeps the best; any more are found as
## CHEAP finds them. CHEAP: ranks the cards with _search_rank().
func _search(decision: ChooseCardsInLibraryDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> Array[int]:
	var found: Array[int] = []
	if decision.candidate_ids.is_empty() or decision.most <= 0:
		_reason = Reason.ONLY_CHOICE
		return found
	var ranked: Array[int] = _search_rank(decision.candidate_ids, world, decision.player_id)
	_reason = Reason.BEST_SCORE
	if mode == Mode.FULL:
		var one_of_each: Array[int] = []
		var names: Dictionary[String, bool] = {}
		for id: int in ranked:
			var card_name: String = world.characteristics_of(world.object(id)).name
			if not names.has(card_name):
				names[card_name] = true
				one_of_each.append(id)
		if one_of_each.size() > 1:
			var answers: Array = []
			var options: Array[int] = []
			for index: int in one_of_each.size():
				answers.append([one_of_each[index]])
				options.append(index)
			var best: int = one_of_each[_best_option(options, _simulate_each(source, rng, answers, decision.player_id), rng, 0)]
			ranked.erase(best)
			ranked.push_front(best)
	return ranked.slice(0, decision.most)


## What to graveyard and what to keep with a surveil (engine ADR 0068), FULL and CHEAP alike:
## one-step simulation sees neither the library's top nor the graveyard, so it would score
## every answer the same. From the top down, a land is kept while the lands its player
## controls and holds, and those kept above it, number fewer than SURVEIL_LANDS, and a spell
## is kept when that many lands and one more would cast it. Kept lands go on top while the
## player is short of lands, then the kept spells, cheapest first.
func _surveil(decision: SurveilDecision, world: MmGameState) -> Array:
	var me: int = decision.player_id
	var lands: int = _lands_controlled(world, me)
	for card: MmGameObject in world.player(me).hand.objects():
		if world.characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
			lands += 1
	var is_short: bool = lands < SURVEIL_LANDS
	var graveyarded: Array[int] = []
	var kept_lands: Array[int] = []
	var kept_spells: Array[int] = []
	for id: int in decision.card_ids:
		var characteristics: MmCharacteristics = world.characteristics_of(world.object(id))
		if characteristics.has_card_type(MmCardTypes.CardType.LAND):
			if lands < SURVEIL_LANDS:
				kept_lands.append(id)
				lands += 1
			else:
				graveyarded.append(id)
		elif characteristics.mana_value() <= lands + 1:
			kept_spells.append(id)
		else:
			graveyarded.append(id)
	kept_spells.sort_custom(func(first: int, second: int) -> bool:
		return world.characteristics_of(world.object(first)).mana_value() < world.characteristics_of(world.object(second)).mana_value())
	var kept: Array[int] = []
	if is_short:
		kept.append_array(kept_lands)
		kept.append_array(kept_spells)
	else:
		kept.append_array(kept_spells)
		kept.append_array(kept_lands)
	_reason = Reason.LAND_COUNT
	return [graveyarded, kept]


## [param candidate_ids] best first for [param me] to find: a basic land of the color their
## hand most lacks (the colored symbols of the nonland cards in their hand, less the lands
## of that color they control), then other lands, then other cards by mana value, highest
## first. Ties keep library order.
func _search_rank(candidate_ids: Array[int], world: MmGameState, me: int) -> Array[int]:
	var lacking: Dictionary[MmMana.Type, int] = {}
	for card: MmGameObject in world.player(me).hand.objects():
		var cost: MmManaCost = world.characteristics_of(card).mana_cost
		if cost == null or world.characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
			continue
		for symbol: MmMana.Type in AiPaymentPlanner.types_wanted_by(cost):
			lacking[symbol] = lacking.get(symbol, 0) + 1
	for permanent: MmGameObject in world.battlefield.objects():
		if permanent.controller_id != me:
			continue
		for made: MmMana.Type in _basic_colors(world.characteristics_of(permanent)):
			lacking[made] = lacking.get(made, 0) - 1
	var scores: Dictionary[int, int] = {}
	for id: int in candidate_ids:
		var characteristics: MmCharacteristics = world.characteristics_of(world.object(id))
		if characteristics.has_card_type(MmCardTypes.CardType.LAND):
			var need: int = 0
			for made: MmMana.Type in _basic_colors(characteristics):
				need = maxi(need, lacking.get(made, 0))
			scores[id] = 1000 + need
		else:
			scores[id] = characteristics.mana_value()
	var ranked: Array[int] = candidate_ids.duplicate()
	var order: Dictionary[int, int] = {}
	for index: int in ranked.size():
		order[ranked[index]] = index
	ranked.sort_custom(func(a: int, b: int) -> bool:
		return scores[a] > scores[b] or (scores[a] == scores[b] and order[a] < order[b]))
	return ranked


## The colors of mana [param characteristics]'s basic land types make (CR 305.6).
static func _basic_colors(characteristics: MmCharacteristics) -> Array[MmMana.Type]:
	var made: Array[MmMana.Type] = []
	for subtype: String in characteristics.subtypes:
		if BASIC_LAND_COLORS.has(subtype):
			made.append(BASIC_LAND_COLORS[subtype])
	return made


func _choose_replacement(decision: ChooseReplacementEffectDecision, source: MmSimulationSource, rng: MmRng) -> int:
	if mode == Mode.CHEAP or decision.options.size() == 1:
		_reason = Reason.ONLY_CHOICE
		return 0
	var options: Array[int] = []
	for index: int in decision.options.size():
		options.append(index)
	_reason = Reason.BEST_SCORE
	return _best_option(options, _simulate_each(source, rng, options, decision.player_id), rng, 0)


# --- Combat ------------------------------------------------------------------------

func _attackers(decision: DeclareAttackersDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> Array[int]:
	var me: int = decision.player_id
	var duel: Callable
	var blockable: Dictionary[int, Array]
	# Held here for the whole plan: a Callable to a method does not keep its object alive.
	var oracle: AiCombatOracle = null
	if mode == Mode.FULL:
		oracle = AiCombatOracle.new(source, rng.next_seed(), profile)
		blockable = oracle.blockable(decision.candidate_ids)
		duel = oracle.duel_among
	else:
		blockable = _guess_blockable(world, me, decision.candidate_ids)
		# The quick guess plays no triggers, so who else attacks changes nothing.
		duel = func(attacker_id: int, blocker_id: int, _attacking: Array[int]) -> Array[bool]:
			return AiQuickCombat.duel(world, attacker_id, blocker_id)
	var planner: AiAttackPlanner = AiAttackPlanner.new(world, me, profile, rng, duel, blockable)
	var attacking: Array[int] = planner.plan(decision.candidate_ids)
	_reason = Reason.LETHAL_ATTACK if planner.was_lethal else Reason.AGGRESSION
	_detail = "aggression %d" % planner.aggression
	return attacking


func _blockers(decision: DeclareBlockersDecision, world: MmGameState, source: MmSimulationSource, rng: MmRng) -> Array:
	var duel: Callable
	var gang: Callable = Callable()
	var oracle: AiCombatOracle = null
	if mode == Mode.FULL:
		oracle = AiCombatOracle.new(source, rng.next_seed(), profile)
		duel = oracle.duel
		gang = func(attacker_id: int, blocker_ids: Array[int]) -> Array[int]:
			var blocks: Array = []
			for blocker_id: int in blocker_ids:
				blocks.append([blocker_id, attacker_id])
			var no_attackers: Array[int] = []
			return oracle.fight(no_attackers, blocks).dead_ids
	else:
		duel = func(attacker_id: int, blocker_id: int) -> Array[bool]:
			return AiQuickCombat.duel(world, attacker_id, blocker_id)
	var planner: AiBlockPlanner = AiBlockPlanner.new(world, decision.player_id, profile, decision, duel, gang)
	var blocks: Array = planner.plan()
	_reason = Reason.LIFE_IN_DANGER if planner.was_in_danger or planner.was_lethal else Reason.SAFE_BLOCKS
	return blocks


## Lethal damage to each blocker, most valuable first; the rest to the player if it may
## trample over, otherwise onto the most valuable blocker.
func _divide_damage(decision: DivideCombatDamageDecision, world: MmGameState) -> Array[int]:
	var amounts: Array[int] = []
	var creatures: Array[int] = []
	for index: int in decision.recipients.size():
		amounts.append(0)
		if decision.recipients[index].is_object():
			creatures.append(index)
	creatures.sort_custom(func(first: int, second: int) -> bool:
		return _reference_value(world, decision.recipients[first]) > _reference_value(world, decision.recipients[second]))
	var left: int = decision.amount
	for index: int in creatures:
		var given: int = mini(decision.lethal_amounts[index], left)
		amounts[index] += given
		left -= given
	if left > 0:
		var last: int = decision.recipients.size() - 1 if decision.includes_player() else (creatures[0] if not creatures.is_empty() else 0)
		amounts[last] += left
	_reason = Reason.KILL_MOST_VALUABLE
	return amounts


## Blocks a CHEAP Agent assumes possible: flying attackers only by flying or reach, and
## none of an attacker that can't be blocked.
func _guess_blockable(world: MmGameState, me: int, candidate_ids: Array[int]) -> Dictionary[int, Array]:
	var blockable: Dictionary[int, Array] = {}
	for blocker: MmGameObject in _creatures_of(world, 1 - me):
		if blocker.is_tapped:
			continue
		var reaches: bool = world.characteristics_of(blocker).has_ability(FlyingAbility) \
			or world.characteristics_of(blocker).has_ability(ReachAbility)
		var attackers: Array = []
		for attacker_id: int in candidate_ids:
			var attacker: MmCharacteristics = world.characteristics_of(world.object(attacker_id))
			if attacker.has_ability(CantBeBlockedAbility):
				continue
			if reaches or not attacker.has_ability(FlyingAbility):
				attackers.append(attacker_id)
		if not attackers.is_empty():
			blockable[blocker.id] = attackers
	return blockable


# --- Pregame and hand size ---------------------------------------------------------

func _keep_or_mulligan(decision: KeepOrMulliganDecision, world: MmGameState) -> int:
	var hand: Array[MmGameObject] = world.player(decision.player_id).hand.objects()
	_reason = Reason.LAND_COUNT
	if hand.size() - decision.cards_to_bottom_if_kept <= profile.always_keeps_at:
		return KeepOrMulliganDecision.Choice.KEEP
	var lands: int = 0
	for card: MmGameObject in hand:
		if world.characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
			lands += 1
	var low: int = profile.mulligan_min_lands
	var high: int = profile.mulligan_max_lands
	var owner: MmPlayer = world.player(decision.player_id)
	if owner.free_mulligans > decision.mulligans_taken:
		low += 1
		high -= 1
	var keeps: bool = lands >= low and lands <= high
	_detail = "%d lands" % lands
	return KeepOrMulliganDecision.Choice.KEEP if keeps else KeepOrMulliganDecision.Choice.MULLIGAN


## The [param count] least useful of [param candidate_ids]: lands beyond
## [param ideal_lands] first, then the most expensive spells, then the other lands.
func _least_useful(candidate_ids: Array[int], count: int, world: MmGameState, _me: int, ideal_lands: int) -> Array[int]:
	var lands: Array[int] = []
	var spells: Array[int] = []
	for id: int in candidate_ids:
		if world.characteristics_of(world.object(id)).has_card_type(MmCardTypes.CardType.LAND):
			lands.append(id)
		else:
			spells.append(id)
	spells.sort_custom(func(first: int, second: int) -> bool:
		return world.characteristics_of(world.object(first)).mana_value() > world.characteristics_of(world.object(second)).mana_value())
	var order: Array[int] = []
	var excess: int = maxi(lands.size() - ideal_lands, 0)
	order.append_array(lands.slice(0, excess))
	order.append_array(spells)
	order.append_array(lands.slice(excess))
	_reason = Reason.LAND_COUNT
	return order.slice(0, count)


func _ideal_lands(hand_size: int) -> int:
	return roundi(hand_size * profile.land_share_percent / 100.0)


func _lands_controlled(world: MmGameState, player_id: int) -> int:
	var lands: int = 0
	for permanent: MmGameObject in world.battlefield.objects():
		if permanent.controller_id == player_id and world.characteristics_of(permanent).has_card_type(MmCardTypes.CardType.LAND):
			lands += 1
	return lands


# --- Shared ------------------------------------------------------------------------

## Scores each of [param answers] by one-step simulation (A181, A182): each sample is one
## re-dealt world, shared by every answer so they are compared on the same cards. Returns
## the total score of each answer, in order. With [param through_turn] each is scored once
## the Game Turn is over.
func _simulate_each(source: MmSimulationSource, rng: MmRng, answers: Array, me: int, through_turn: bool = false) -> Array[int]:
	var scores: Array[int] = []
	scores.resize(answers.size())
	scores.fill(0)
	var details: PackedStringArray = PackedStringArray()
	_world_seeds.clear()
	for _sample: int in AiDifficulty.scaled(difficulty.one_step_samples, profile.search_budget_percent):
		var world_seed: int = rng.next_seed()
		_world_seeds.append(world_seed)
		for index: int in answers.size():
			var copy: MmEngine = source.simulation_copy(MmRng.new(world_seed))
			scores[index] += AiSimulation.score_answer(copy, answers[index], me, profile, 1, through_turn)
	for index: int in answers.size():
		details.append("%s: %d" % [answers[index], scores[index]])
	_detail = ", ".join(details)
	return scores


## The best-scoring of [param options]. With a [param margin], the first option is the
## default and another wins only by beating it by at least that much, as playing must beat
## passing (A161). Ties are broken with [param rng] (A156).
func _best_option(options: Array[int], scores: Array[int], rng: MmRng, margin: int) -> int:
	var best: Array[int] = [options[0]]
	var best_score: int = scores[0]
	var first_is_default: bool = margin > 0
	for index: int in range(1, options.size()):
		if first_is_default and scores[index] < scores[0] + margin:
			continue
		var replaces_default: bool = first_is_default and best[0] == options[0]
		if replaces_default or scores[index] > best_score:
			best = [options[index]]
			best_score = scores[index]
		elif scores[index] == best_score:
			best.append(options[index])
	return best[0] if best.size() == 1 else best[rng.next_int(best.size())]


func _pass_index(decision: PriorityDecision) -> int:
	for index: int in decision.actions.size():
		if decision.actions[index] is PassAction:
			return index
	return 0


## What the spell or ability [param object_id] on the stack does, each "you may" read as
## what it offers (CR 603.5).
func _effects_of_stack_object(world: MmGameState, object_id: int) -> Array[MmEffect]:
	var effects: Array[MmEffect] = []
	var item: MmGameObject = world.object(object_id)
	if item == null:
		return effects
	if item.ability is ActivatedAbility:
		effects.append_array((item.ability as ActivatedAbility).effects)
		return AiTiming.unwrapped(effects)
	if item.ability is TriggeredAbility:
		# A modal triggered ability does what its chosen mode does (ADR 0046).
		effects.append_array((item.ability as TriggeredAbility).effects_for(item.chosen_mode))
		return AiTiming.unwrapped(effects)
	for ability: MmAbility in world.characteristics_of(item).abilities:
		if ability is SpellAbility:
			# A modal spell does what its chosen mode does (ADR 0046).
			effects.append_array((ability as SpellAbility).effects_for(item.chosen_mode))
	return AiTiming.unwrapped(effects)


## Whether [param player_id] could pay both what [param stack_object_id] still costs and
## the ward of [param target], if it has ward and is not theirs (CR 702.21a, ADR 0062): a
## spell aimed at a warded permanent whose ward cannot also be paid is only countered.
func _can_pay_ward_of(world: MmGameState, player_id: int, target: MmGameObject, stack_object_id: int) -> bool:
	if target.controller_id == player_id:
		return true
	var total: MmManaCost = MmManaCost.new()
	for ability: MmAbility in world.characteristics_of(target).abilities:
		var ward: WardAbility = ability as WardAbility
		if ward != null and ward.mana_cost != null:
			total = _with_cost(total, ward.mana_cost)
	if total.mana_value() == 0:
		return true
	var item: MmGameObject = world.object(stack_object_id)
	if item != null and item.is_card():
		total = _with_cost(total, world.characteristics_of(item).mana_cost)
	elif item != null and item.ability is ActivatedAbility:
		total = _with_cost(total, (item.ability as ActivatedAbility).mana_cost)
	return ManaPayment.can_afford(world, player_id, total)


## [param total] and [param more] together, or [param total] alone for a null [param more].
static func _with_cost(total: MmManaCost, more: MmManaCost) -> MmManaCost:
	if more == null:
		return total
	var both: MmManaCost = MmManaCost.new()
	both.generic = total.generic + more.generic
	both.symbols = total.symbols + more.symbols
	both.hybrid_symbols = total.hybrid_symbols + more.hybrid_symbols
	return both


## The damage the first damage effect of [param stack_object_id] would deal, its Value
## worked out on [param world] as if it resolved now, such as "1 plus [Domain]"; 0 when it
## deals none.
func _damage_of(effects: Array[MmEffect], world: MmGameState, stack_object_id: int) -> int:
	var item: MmGameObject = world.object(stack_object_id)
	for effect: MmEffect in effects:
		var damage: DealDamageEffect = effect as DealDamageEffect
		if damage != null and item != null:
			return damage.amount.evaluate(world, MmEffectContext.of_stack_object(item))
	return 0


func _adds_mana(effects: Array[MmEffect]) -> bool:
	for effect: MmEffect in effects:
		if effect is AddManaEffect:
			return true
	return false


func _only_adds_mana(effects: Array[MmEffect]) -> bool:
	for effect: MmEffect in effects:
		if not effect is AddManaEffect:
			return false
	return not effects.is_empty()


func _creatures_of(world: MmGameState, player_id: int) -> Array[MmGameObject]:
	var creatures: Array[MmGameObject] = []
	for permanent: MmGameObject in world.battlefield.objects():
		if permanent.controller_id == player_id and world.characteristics_of(permanent).has_card_type(MmCardTypes.CardType.CREATURE):
			creatures.append(permanent)
	return creatures


func _reference_value(world: MmGameState, reference: MmReference) -> int:
	var creature: MmGameObject = world.object(reference.id)
	return 0 if creature == null else AiBoardEvaluator.creature_value(world, creature)


func _permutations(count: int) -> Array:
	if count <= 1:
		return [range(count)]
	var result: Array = []
	for first: int in count:
		for rest: Variant in _permutations(count - 1):
			var order: Array = [first]
			for index: int in rest as Array:
				order.append(index if index < first else index + 1)
			result.append(order)
	return result


## A159: budgets are counts, never time, so time only ever produces a warning.
func _warn_if_slow(decision: MmPendingDecision, elapsed_ms: int) -> void:
	if elapsed_ms > profile.slow_decision_warning_ms:
		push_warning("AiAgent took %d ms to answer %s." % [elapsed_ms, decision.describe()])
