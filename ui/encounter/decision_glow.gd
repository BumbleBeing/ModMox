class_name DecisionGlow
extends RefCounted
## The Glow (game glossary): which objects and players a Pending Decision can choose, and
## in which color. Targets glow orange-red, mana sources blue, everything else green.

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


## The Glow for [param decision] as the player whose [param view] this is sees it. A null
## decision (nobody is asking the viewer anything) glows nothing.
static func of(decision: MmPendingDecision, view: MmPlayerView) -> DecisionGlow:
	var glow: DecisionGlow = DecisionGlow.new()
	if decision == null:
		return glow
	if decision is PriorityDecision:
		for action: MmAction in (decision as PriorityDecision).actions:
			var object_id: int = object_of(action)
			if object_id != -1:
				glow.objects[object_id] = Kind.MANA if AutoPass.is_mana_ability(action, view) else Kind.OTHER
	elif decision is PayManaDecision:
		var actions: Array[MmAction] = (decision as PayManaDecision).actions
		var pool: Array = view.mana_pools.get(view.viewer_id, [])
		for index: int in actions.size():
			var spend: PayWithManaAction = actions[index] as PayWithManaAction
			if spend == null:
				glow.objects[object_of(actions[index])] = Kind.MANA
			elif spend.unit_index < pool.size():
				var type: MmMana.Type = (pool[spend.unit_index] as MmMana).type
				if not glow.pool_answers.has(type):
					glow.pool_answers[type] = index
	elif decision is ChooseTargetDecision:
		glow._add_references((decision as ChooseTargetDecision).candidates, Kind.TARGET)
	elif decision is DivideCombatDamageDecision:
		glow._add_references((decision as DivideCombatDamageDecision).recipients, Kind.TARGET)
	elif decision is DeclareBlockersDecision:
		glow._add_ids((decision as DeclareBlockersDecision).candidate_blocker_ids)
	elif decision is DeclareAttackersDecision:
		glow._add_ids((decision as DeclareAttackersDecision).candidate_ids)
	elif decision is ChooseCardsToDiscardDecision:
		glow._add_ids((decision as ChooseCardsToDiscardDecision).candidate_ids)
	elif decision is ChooseCardsToBottomDecision:
		glow._add_ids((decision as ChooseCardsToBottomDecision).candidate_ids)
	elif decision is OrderTriggersDecision:
		glow._add_ids((decision as OrderTriggersDecision).source_object_ids)
	return glow


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


func _add_ids(ids: Array[int]) -> void:
	for id: int in ids:
		objects[id] = Kind.OTHER


func _add_references(references: Array[MmReference], kind: Kind) -> void:
	for reference: MmReference in references:
		if reference.is_player():
			players[reference.id] = kind
		else:
			objects[reference.id] = kind
