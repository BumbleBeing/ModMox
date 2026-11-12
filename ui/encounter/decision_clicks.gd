class_name DecisionClicks
extends RefCounted
## What clicking each object or player answers for a Pending Decision, and the Glow (game
## glossary) drawn from the same map: targets orange-red, mana sources blue, everything
## else green. A thing with a click answer always glows. A decision kind that has no input
## of its own yet (A243) glows what it can choose, but gives no click answers.
##
## A card in hand that can be cast or played glows too, but one click on it answers
## nothing (A371): what it offers is kept apart, in hand_options_of(), for the Drag Card and
## a double-click.

enum Kind { TARGET, MANA, OTHER }

const COLORS: Dictionary[Kind, Color] = {
	Kind.TARGET: Color("#ff5a2a"),
	Kind.MANA: Color("#3aa0ff"),
	Kind.OTHER: Color("#7be36a"),
}

## Game Object ID → the kind of Glow it has.
var objects: Dictionary[int, Kind] = {}
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
				clicks.objects[candidates[index].id] = Kind.TARGET
				clicks._options[candidates[index].id] = [ClickOption.new(index, "Target")]
	elif decision is DivideCombatDamageDecision:
		clicks._add_references((decision as DivideCombatDamageDecision).recipients, Kind.TARGET)
	elif decision is DeclareBlockersDecision:
		clicks._add_ids((decision as DeclareBlockersDecision).candidate_blocker_ids)
	elif decision is DeclareAttackersDecision:
		clicks._add_ids((decision as DeclareAttackersDecision).candidate_ids)
	elif decision is ChooseCardsToDiscardDecision:
		clicks._add_ids((decision as ChooseCardsToDiscardDecision).candidate_ids)
	elif decision is ChooseCardsToBottomDecision:
		clicks._add_ids((decision as ChooseCardsToBottomDecision).candidate_ids)
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


## What playing the card in hand that is Game Object [param object_id] offers: nothing, one
## way, or several for the Option Menu. Each reads "Cast Hill Giant" or "Play Forest".
func hand_options_of(object_id: int) -> Array[ClickOption]:
	var found: Array[ClickOption] = []
	found.assign(_hand_options.get(object_id, []))
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


## A permanent's ability that [param answer] activates. A permanent glows blue only when
## mana is all it offers (A306).
func _add_ability(answer: int, action: ActivateAbilityAction, view: MmPlayerView) -> void:
	var is_mana: bool = AutoPass.is_mana_ability(action, view)
	var text: String = "Ability %d" % (action.ability_index + 1)
	var is_permanent: bool = false
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == action.object_id:
			is_permanent = true
			if action.ability_index < permanent.abilities.size() and permanent.abilities[action.ability_index] is ActivatedAbility:
				# A row of the Option Menu reads as the ability is printed on the card.
				text = AbilityText.of_ability(permanent.abilities[action.ability_index], AbilityText.self_noun(permanent.card_types, permanent.name))
	if is_permanent:
		# An ability used from another zone gets its input with that zone's viewer (13f).
		if not _options.has(action.object_id):
			_options[action.object_id] = []
		(_options[action.object_id] as Array).append(ClickOption.new(answer, text, is_mana))
	var is_blue: bool = is_mana and objects.get(action.object_id, Kind.MANA) == Kind.MANA
	objects[action.object_id] = Kind.MANA if is_blue else Kind.OTHER


## Casting a card or playing it as a land, which [param answer] does.
func _add_play(answer: int, action: MmAction, view: MmPlayerView) -> void:
	var object_id: int = object_of(action)
	var verb: String = "Play" if action is PlayLandAction else "Cast"
	objects[object_id] = Kind.OTHER
	if not _hand_options.has(object_id):
		_hand_options[object_id] = []
	(_hand_options[object_id] as Array).append(ClickOption.new(answer, "%s %s" % [verb, DebugDecisionForm.name_of(view, object_id)]))


func _add_ids(ids: Array[int]) -> void:
	for id: int in ids:
		objects[id] = Kind.OTHER


func _add_references(references: Array[MmReference], kind: Kind) -> void:
	for reference: MmReference in references:
		if reference.is_player():
			players[reference.id] = kind
		else:
			objects[reference.id] = kind
