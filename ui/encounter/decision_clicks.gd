class_name DecisionClicks
extends RefCounted
## What clicking each object or player answers for a Pending Decision, and the Glow (game
## glossary) drawn from the same map: targets orange-red, mana sources blue, everything
## else green. A thing with a click answer always glows. A decision kind that has no input
## of its own yet (A243) glows what it can choose, but gives no click answers.

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
				# Casting and playing a land get their input with the hand (13e).
				clicks.objects[object_id] = Kind.OTHER
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
	elif decision is OrderTriggersDecision:
		clicks._add_ids((decision as OrderTriggersDecision).source_object_ids)
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


## What [param ability] costs and does, for a row of the Option Menu, such as
## "{1}{R}, {T}: Deal Damage". Until rules text is generated from abilities (13h), an effect
## is named after its class.
static func ability_text(ability: ActivatedAbility) -> String:
	var costs: Array[String] = []
	if ability.mana_cost != null:
		costs.append(ability.mana_cost.describe())
	for cost: MmCost in ability.costs:
		costs.append("{T}" if cost is TapCost else _class_words(cost, "_cost"))
	var effects: Array[String] = []
	for effect: MmEffect in ability.effects:
		effects.append(_class_words(effect, "_effect"))
	return "%s: %s" % [", ".join(costs) if not costs.is_empty() else "{0}", ", ".join(effects)]


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
				text = ability_text(permanent.abilities[action.ability_index] as ActivatedAbility)
	if is_permanent:
		# An ability used from another zone gets its input with that zone's viewer (13f).
		if not _options.has(action.object_id):
			_options[action.object_id] = []
		(_options[action.object_id] as Array).append(ClickOption.new(answer, text, is_mana))
	var is_blue: bool = is_mana and objects.get(action.object_id, Kind.MANA) == Kind.MANA
	objects[action.object_id] = Kind.MANA if is_blue else Kind.OTHER


func _add_ids(ids: Array[int]) -> void:
	for id: int in ids:
		objects[id] = Kind.OTHER


func _add_references(references: Array[MmReference], kind: Kind) -> void:
	for reference: MmReference in references:
		if reference.is_player():
			players[reference.id] = kind
		else:
			objects[reference.id] = kind


## "deal_damage_effect.gd" → "Deal Damage".
static func _class_words(resource: Resource, suffix: String) -> String:
	var file: String = (resource.get_script() as Script).resource_path.get_file().get_basename()
	return file.trim_suffix(suffix).replace("_", " ").capitalize()
