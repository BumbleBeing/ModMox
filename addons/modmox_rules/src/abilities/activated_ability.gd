class_name ActivatedAbility
extends MmAbility
## "[Cost]: [Effect]" (CR 602). Whether it is a mana ability is worked out from its
## content (CR 605.1a), never set by hand, so a Modification that adds a target turns a
## mana ability into one that uses the stack.

## The mana part of its cost, such as {B} in "{B}: Regenerate this creature", paid like a
## spell's mana cost (CR 602.2b). Null when it costs no mana.
@export var mana_cost: MmManaCost = null
## "This ability costs {1} less to activate for each [Value]" (CR 602.2b, 601.2f, ADR
## 0050), such as Jodah's Codex's Domain: one generic mana off [member mana_cost] for each
## point of the Value, fixed as the activation begins. Null for none.
@export var generic_reduction: MmValue = null
## Every other part of its cost, such as {T}, paid once the mana is (CR 601.2h).
@export var costs: Array[MmCost] = []
@export var targets: Array[TargetRequirement] = []
@export var effects: Array[MmEffect] = []
## "Activate only once each game" (CR 602.5b, ADR 0036): its source marks it Spent when it
## is activated, and it is never offered again from that object.
@export var is_once_each_game: bool = false
## "Activate only once each turn" (CR 602.5b, ADR 0036's addendum), as Cutthroat
## Centurion's: its source marks it Spent for the Game Turn it is activated in, whoever's
## turn that is, and it is offered again in the next. Never set with
## [member is_once_each_game].
@export var is_once_each_turn: bool = false
## "Activate only as a sorcery" (CR 602.5d): only in its controller's main phase with an
## empty stack.
@export var is_sorcery_speed: bool = false
## "Activate only if this permanent is attached to a creature" (CR 602.5, 702.151a), as
## reconfigure's unattaching half is: only while its source is attached to a creature.
@export var is_only_while_attached: bool = false
## Works only while its card is in its owner's hand, as cycling does (CR 113.6b, 702.29b,
## ADR 0059), and never on the battlefield or in the command zone. Every other activated
## ability works only there, never from the hand or the graveyard.
@export var is_activated_from_hand: bool = false
## Works only while its card is in its owner's graveyard, as Sanitarium Skeleton's "Return
## this card from your graveyard to your hand" does (CR 113.6k, ADR 0094), and never on the
## battlefield, in the hand or in the command zone. Never set with
## [member is_activated_from_hand].
@export var is_activated_from_graveyard: bool = false
## "Activate only if [condition]" (CR 602.5b, ADR 0095), as Cult Conscript's "Activate only
## if a non-Skeleton creature died under your control this turn": it is offered only while
## the condition holds for its activator. Null for none.
@export var condition: MmCondition = null


## Whether it may be activated only once, each game or each turn (CR 602.5b), so that
## activating it marks it Spent on its source with an AbilitySpentEvent.
func is_activated_only_once() -> bool:
	return is_once_each_game or is_once_each_turn


## Whether its source, at [param ability_index] among its abilities, has used up its one
## activation: ever, for once each game, or in [param game_turn], for once each turn.
func is_spent_on(source: MmGameObject, ability_index: int, game_turn: int) -> bool:
	if is_once_each_game and source.is_ability_spent(ability_index):
		return true
	return is_once_each_turn and source.has_activated_in(ability_index, game_turn)


## CR 605.1a: it could add mana and it has no target. There are no loyalty abilities in
## this game (ADR 0001), so that part of the rule never applies.
func is_mana_ability() -> bool:
	if not targets.is_empty():
		return false
	var adds_mana: bool = false
	for effect: MmEffect in effects:
		if effect.has_targets():
			return false
		if effect.adds_mana():
			adds_mana = true
	return adds_mana


## The colors its activator chooses among as it is activated (CR 605.3a, ADR 0072), in WUBRG
## order: the five colors for a mana ability that adds mana of any color, its colors for one
## that adds "{U}, {B}, or {R}", and none for any other ability.
func mana_types_to_choose() -> Array[MmMana.Type]:
	var none: Array[MmMana.Type] = []
	if not is_mana_ability():
		return none  # Later: an ability that uses the stack asks its color as it resolves.
	for effect: MmEffect in effects:
		var add_mana: AddManaEffect = effect as AddManaEffect
		if add_mana != null and not add_mana.colors_to_choose().is_empty():
			return add_mana.colors_to_choose()
	return none


## Whether this ability works where [param source] is now (CR 113.6): from the hand or the
## graveyard if it says so (CR 113.6k, ADR 0059, 0094), and otherwise anywhere but those.
func works_in(state: MmGameState, source: MmGameObject) -> bool:
	var owner: MmPlayer = state.player(source.owner_id)
	var in_hand: bool = source.zone() == owner.hand
	var in_graveyard: bool = source.zone() == owner.graveyard
	if is_activated_from_graveyard:
		return in_graveyard
	return is_activated_from_hand == in_hand and not in_graveyard


## Whether [member condition] allows [param player_id] to activate it from [param source]
## now: always without one (CR 602.5b, ADR 0095).
func is_condition_met(state: MmGameState, source: MmGameObject, player_id: int) -> bool:
	return condition == null or condition.is_true(state, MmEffectContext.new(player_id, source.id))


## Whether [member is_only_while_attached] allows activating it from [param source] now:
## always without it, and otherwise only while [param source] is attached to a creature.
func is_attachment_allowed(state: MmGameState, source: MmGameObject) -> bool:
	if not is_only_while_attached:
		return true
	var attached_to: MmGameObject = state.object(source.attached_to_object_id) if source.attached_to_object_id != 0 else null
	return attached_to != null and attached_to.zone() == state.battlefield \
		and state.characteristics_of(attached_to).has_card_type(MmCardTypes.CardType.CREATURE)


## Whether {T} is part of its cost (CR 107.5), so that paying it taps its source.
func has_tap_cost() -> bool:
	for cost: MmCost in costs:
		if cost is TapCost:
			return true
	return false


## The ID of [param source] if paying this ability taps it, or 0: what a payment of its
## mana must leave untapped ([method ManaPayment.can_afford]).
func tapping_source_id(source: MmGameObject) -> int:
	return source.id if has_tap_cost() else 0


## Whether every cost can be paid right now with [param source] as the ability's source,
## by its controller.
func can_pay_costs(state: MmGameState, source: MmGameObject) -> bool:
	for cost: MmCost in costs:
		if not cost.can_pay(state, source, source.controller_id):
			return false
		var tapping: TapCreaturesCost = cost as TapCreaturesCost
		if tapping != null and has_tap_cost() and _besides_source(tapping.candidates(state, source, source.controller_id),
				source).size() < tapping.count:
			return false  # CR 107.5: its {T} taps its source, which can't be tapped again.
	return true


## The mana [param source]'s controller pays to activate this ability now: its
## [member mana_cost] less [member generic_reduction], generic mana only (CR 118.7a). Null
## when it costs no mana.
func mana_to_pay(state: MmGameState, source: MmGameObject) -> MmManaCost:
	if mana_cost == null or generic_reduction == null:
		return mana_cost
	var reduction: MmManaCost = MmManaCost.new()
	reduction.generic = generic_reduction.evaluate(state, MmEffectContext.new(source.controller_id, source.id))
	return mana_cost.reduced_by(reduction)


## What a mana ability's cost asks its controller to choose as it is activated, such as
## Jaspera Sentinel's "Tap an untapped creature you control" (CR 605.3a, 601.2h, engine ADR
## 0105), or null when no cost asks anything. A permanent its own {T} taps is never among
## what may be tapped (CR 107.5). One that uses the stack asks through CastProcedure instead.
func cost_choice(state: MmGameState, source: MmGameObject) -> MmPendingDecision:
	for cost: MmCost in costs:
		var asked: MmPendingDecision = cost.choice(state, source, source.controller_id)
		if asked == null:
			continue
		var picking: ChoosePermanentsDecision = asked as ChoosePermanentsDecision
		assert(picking != null, "A mana ability's cost can ask only which permanents to tap.")
		if has_tap_cost():
			picking.candidate_ids = _besides_source(picking.candidate_ids, source)
		picking.is_for_mana_ability = true
		return picking
	return null


## Pays every cost, in order (CR 602.2b), for a mana ability (CR 605.3a), with
## [param chosen] the answer to [method cost_choice] (empty when it asked none). One that
## uses the stack is paid by CastProcedure, which asks.
# Later: a mana ability with two costs that each ask a choice, once a card has one.
func pay_costs(state: MmGameState, source: MmGameObject, chosen: Array[int] = []) -> void:
	var asking: Array[bool] = []
	for cost: MmCost in costs:
		asking.append(cost.choice(state, source, source.controller_id) != null)  # Before any is paid.
	var nothing_chosen: Array[int] = []
	for index: int in costs.size():
		costs[index].pay(state, source, source.controller_id, chosen if asking[index] else nothing_chosen)


## Carries out every effect at once, in order, for a mana ability, which resolves
## immediately without using the stack (CR 605.3a).
func resolve_effects(state: MmGameState, context: MmEffectContext) -> void:
	for effect: MmEffect in effects:
		effect.perform_now(state, context)


func describe() -> String:
	return "activated ability (%d costs, %d targets, %d effects)" % [costs.size(), targets.size(), effects.size()]


static func _besides_source(ids: Array[int], source: MmGameObject) -> Array[int]:
	var besides: Array[int] = ids.duplicate()
	besides.erase(source.id)
	return besides
