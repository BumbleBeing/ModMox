class_name DecisionClicks
extends RefCounted
## What clicking each object or player answers for a Pending Decision, and the Glow (game
## glossary) drawn from the same map: targets orange-red, mana sources blue, attackers and
## blockers to choose gold, abilities to activate purple, and everything else, such as cards
## that can be cast or played, green. A thing with a click answer always glows. Cards to discard glow too, but are
## chosen with a CardPicks, which a click on a card of the hand builds.
##
## An object that offers more than one kind of thing has each kind, and its Glow is split
## between the colors of the first two: a permanent with a mana ability and another
## ability is purple and blue.
##
## A card in hand that can be cast or played, or has an ability used from there, glows too,
## but one click on it answers nothing (A371): what it offers is kept apart, in
## hand_options_of(), for the Drag Card and a double-click.

enum Kind { TARGET, MANA, COMBAT, ABILITY, PLAY, OTHER }

const COLORS: Dictionary[Kind, Color] = {
	Kind.TARGET: Color("#ff5a2a"),
	Kind.MANA: Color("#3aa0ff"),
	Kind.COMBAT: Color("#ffc83a"),
	Kind.ABILITY: Color("#b77cff"),
	Kind.PLAY: Color("#7be36a"),
	Kind.OTHER: Color("#7be36a"),
}

## The kinds one object can have together, in the order its Glow shows them.
const SHARED: Array[Kind] = [Kind.PLAY, Kind.ABILITY, Kind.MANA]
## How many colors a Glow shows at most.
const MOST_COLORS: int = 2

## Player ID → the kind of Glow that player's panel has.
var players: Dictionary[int, Kind] = {}
## While paying a cost: mana type → the answer that spends one unit of it from the pool.
var pool_answers: Dictionary[MmMana.Type, int] = {}
## Player ID → the answer clicking that player's panel gives.
var player_answers: Dictionary[int, int] = {}

## Game Object ID → the ClickOptions clicking it offers, in answer order.
var _options: Dictionary[int, Array] = {}
## Game Object ID of a card in hand → the ClickOptions playing it offers, in answer order.
var _hand_options: Dictionary[int, Array] = {}
## Game Object ID of a card in hand → the ClickOptions its abilities offer, in answer order.
var _hand_abilities: Dictionary[int, Array] = {}
## Game Object ID → the kinds of Glow it has, in the order they are shown.
var _kinds: Dictionary[int, Array] = {}


## The clicks and Glow for [param decision] as the player whose [param view] this is sees
## it. A null decision (nobody is asking the viewer anything) offers and glows nothing.
static func of(decision: MmPendingDecision, view: MmPlayerView) -> DecisionClicks:
	var clicks: DecisionClicks = DecisionClicks.new()
	if decision == null:
		return clicks
	if decision is PriorityDecision:
		var actions: Array[MmAction] = (decision as PriorityDecision).actions
		for index: int in actions.size():
			var object_id: int = object_of(actions[index])
			if object_id == -1:
				continue
			if actions[index] is ActivateAbilityAction:
				clicks._add_ability(index, actions[index] as ActivateAbilityAction, view)
			else:
				clicks._add_play(index, actions[index], view)
	elif decision is PayManaDecision:
		var actions: Array[MmAction] = (decision as PayManaDecision).actions
		var pool: Array = view.mana_pools.get(view.viewer_id, [])
		for index: int in actions.size():
			var spend: PayWithManaAction = actions[index] as PayWithManaAction
			if spend == null:
				clicks._add_ability(index, actions[index] as ActivateAbilityAction, view)
			elif spend.unit_index < pool.size():
				var type: MmMana.Type = (pool[spend.unit_index] as MmMana).type
				if not clicks.pool_answers.has(type):
					clicks.pool_answers[type] = index
	elif decision is ChooseTargetDecision:
		var candidates: Array[MmReference] = (decision as ChooseTargetDecision).candidates
		for index: int in candidates.size():
			if candidates[index].is_player():
				clicks.players[candidates[index].id] = Kind.TARGET
				clicks.player_answers[candidates[index].id] = index
			else:
				clicks.glow_as(candidates[index].id, Kind.TARGET)
				clicks._options[candidates[index].id] = [ClickOption.new(index, "Target")]
	elif decision is DivideCombatDamageDecision:
		clicks._add_references((decision as DivideCombatDamageDecision).recipients, Kind.TARGET)
	elif decision is DeclareBlockersDecision:
		clicks._add_ids((decision as DeclareBlockersDecision).candidate_blocker_ids, Kind.COMBAT)
	elif decision is DeclareAttackersDecision:
		clicks._add_ids((decision as DeclareAttackersDecision).candidate_ids, Kind.COMBAT)
	elif decision is ChooseCardsToDiscardDecision:
		clicks._add_ids((decision as ChooseCardsToDiscardDecision).candidate_ids, Kind.OTHER)
	return clicks


## The Game Object [param action] is about, or -1 for one about none (passing, or spending
## pool mana).
static func object_of(action: MmAction) -> int:
	if action is PlayLandAction:
		return (action as PlayLandAction).object_id
	if action is CastSpellAction:
		return (action as CastSpellAction).object_id
	if action is ActivateAbilityAction:
		return (action as ActivateAbilityAction).object_id
	return -1


static func color_of(kind: Kind) -> Color:
	return COLORS[kind]


## The Glow of a held card that letting go would play: its color, much lighter (A375).
static func bright_color_of(kind: Kind) -> Color:
	return COLORS[kind].lightened(0.55)


## The kinds of Glow Game Object [param object_id] has, in the order they are shown; none
## if it does not glow.
func kinds_of(object_id: int) -> Array[Kind]:
	var found: Array[Kind] = []
	found.assign(_kinds.get(object_id, []))
	return found


## The colors of Game Object [param object_id]'s Glow: none, one, or two for something
## that offers more than one kind of thing. With [param is_bright] each is the lighter
## color of a held card.
func colors_of(object_id: int, is_bright: bool = false) -> Array[Color]:
	var colors: Array[Color] = []
	for kind: Kind in kinds_of(object_id).slice(0, MOST_COLORS):
		colors.append(bright_color_of(kind) if is_bright else color_of(kind))
	return colors


## Every Game Object that glows.
func glowing_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_kinds.keys())
	return ids


## Makes Game Object [param object_id] glow as [param kind] alone, whatever it glowed as.
func glow_as(object_id: int, kind: Kind) -> void:
	_kinds[object_id] = [kind]


## What letting go of the card in hand that is Game Object [param object_id] offers:
## nothing, one thing, or several for the Option Menu. The ways to play it come first, each
## reading "Cast Hill Giant" or "Play Forest", then its abilities as they are printed.
func hand_options_of(object_id: int) -> Array[ClickOption]:
	var found: Array[ClickOption] = []
	found.assign(_hand_options.get(object_id, []) + _hand_abilities.get(object_id, []))
	return found


## What clicking Game Object [param object_id] offers: nothing, one answer, or several for
## the Option Menu.
func options_of(object_id: int) -> Array[ClickOption]:
	var found: Array[ClickOption] = []
	found.assign(_options.get(object_id, []))
	return found


## Every Game Object a click answers something on.
func clickable_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_options.keys())
	return ids


## An ability that [param answer] activates: a permanent's is clicked on it, and one of a
## card in hand is offered when the card is let go. One anywhere else glows and gets its
## input with that zone's viewer (13f).
func _add_ability(answer: int, action: ActivateAbilityAction, view: MmPlayerView) -> void:
	var text: String = "Ability %d" % (action.ability_index + 1)
	var is_mana: bool = false
	var permanent: MmObjectView = _find(view.battlefield, action.object_id)
	var in_hand: MmObjectView = _find(view.hand, action.object_id)
	var seen: MmObjectView = permanent if permanent != null else in_hand
	if seen != null and action.ability_index < seen.abilities.size() and seen.abilities[action.ability_index] is ActivatedAbility:
		var ability: ActivatedAbility = seen.abilities[action.ability_index]
		is_mana = ability.is_mana_ability()
		# A row of the Option Menu reads as the ability is printed on the card.
		text = AbilityText.of_ability(ability, AbilityText.self_noun(seen.card_types, seen.name))
	_add_kind(action.object_id, Kind.MANA if is_mana else Kind.ABILITY)
	if permanent != null:
		_append(_options, action.object_id, ClickOption.new(answer, text, is_mana))
	elif in_hand != null:
		_append(_hand_abilities, action.object_id, ClickOption.new(answer, text, is_mana))


## Casting a card or playing it as a land, which [param answer] does.
func _add_play(answer: int, action: MmAction, view: MmPlayerView) -> void:
	var object_id: int = object_of(action)
	var verb: String = "Play" if action is PlayLandAction else "Cast"
	_add_kind(object_id, Kind.PLAY)
	_append(_hand_options, object_id, ClickOption.new(answer, "%s %s" % [verb, EncounterSnapshot.name_in(view, object_id)]))


## Gives [param object_id] the Glow of [param kind] beside any it has, kept in the order
## of SHARED.
func _add_kind(object_id: int, kind: Kind) -> void:
	var kinds: Array = _kinds.get(object_id, [])
	if kinds.has(kind):
		return
	kinds.append(kind)
	kinds.sort_custom(func(a: Kind, b: Kind) -> bool: return SHARED.find(a) < SHARED.find(b))
	_kinds[object_id] = kinds


static func _append(options: Dictionary[int, Array], object_id: int, option: ClickOption) -> void:
	if not options.has(object_id):
		options[object_id] = []
	(options[object_id] as Array).append(option)


static func _find(zone: Array, object_id: int) -> MmObjectView:
	for seen: MmObjectView in zone:
		if seen.id == object_id:
			return seen
	return null


func _add_ids(ids: Array[int], kind: Kind) -> void:
	for id: int in ids:
		glow_as(id, kind)


func _add_references(references: Array[MmReference], kind: Kind) -> void:
	for reference: MmReference in references:
		if reference.is_player():
			players[reference.id] = kind
		else:
			glow_as(reference.id, kind)
