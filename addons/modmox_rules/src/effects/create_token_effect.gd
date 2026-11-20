class_name CreateTokenEffect
extends MmEffect
## "Create [amount] [token]" (CR 111.2): puts that many tokens made from the Token
## Definition [member token] onto the battlefield, all at once, under the control of the
## player whose spell or ability created them. Each is a new object (ADR 0008), so it enters
## untapped, with summoning sickness, and its own "enters" abilities trigger.
##
## "... that's attacking" (CR 508.4) with [member attacking]: each token enters attacking the
## player the combat's attackers attack, never declared as an attacker (ADR 0044).
## "... that's blocking that creature" (CR 509.7) with [member blocking]: each token enters
## blocking the creature it names, never declared as a blocker (ADR 0044).

## The steps in which blockers have been declared, if there are any attackers to block.
const BLOCKS_DECLARED_STEPS: Array[MmTurn.Step] = [
	MmTurn.Step.DECLARE_BLOCKERS, MmTurn.Step.COMBAT_DAMAGE, MmTurn.Step.END_OF_COMBAT,
]

## The Token Definition: the token's name, color, types, power and toughness and abilities
## (CR 111.3), kept in its own file under content/tokens/.
@export var token: MmCardDefinition
@export var amount: int = 1
## "that's attacking": the tokens are put onto the battlefield attacking (CR 508.4).
@export var attacking: bool = false
## "that's blocking [blocking]": the tokens are put onto the battlefield blocking the
## creature this finds (CR 509.7), such as "that creature" (TriggeringObjectSelection) for
## Brimaz, King of Oreskos. Null when they don't enter blocking. Never set with
## [member attacking]: one creature can't be on both sides.
@export var blocking: MmSelection = null


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	var enters_attacking: bool = attacking and _may_enter_attacking(state, context.controller_id)
	var blocked_id: int = _attacker_to_block(state, context)
	for index: int in amount:
		var created: TokenCreatedEvent = TokenCreatedEvent.new(token, context.controller_id)
		created.attacking_on_arrival = enters_attacking
		created.blocking_on_arrival = blocked_id
		events.append(created)
	return events


func selections() -> Array[MmSelection]:
	var used: Array[MmSelection] = []
	if blocking != null:
		used.append(blocking)
	return used


## CR 506.3b: a token put onto the battlefield attacking under the control of a player who
## isn't the attacking player just enters; outside combat no player is attacking (CR 506.2).
## One on one there is only one defending player and nothing else to attack (game ADR
## 0040), so CR 508.4 leaves nothing to choose.
## Later: CR 506.2 has it attacking from the beginning of combat step, before attackers are
## declared; until a card can create one then, it just enters there.
func _may_enter_attacking(state: MmGameState, controller_id: int) -> bool:
	return state.combat.has_declared_attackers() and controller_id == state.active_player_id


## The attacker the tokens enter blocking, or 0 if they just enter. CR 506.3c: only under the
## control of the defending player, and only blocking a creature that is still attacking:
## one that has left the battlefield or been removed from combat since "that creature" was
## named can't be blocked (CR 506.4). The effect names it; no block restriction is checked,
## since those are about declaring blockers (CR 509.1b-c).
## Later: before blockers are declared, in the declare attackers step, it just enters, as
## otherwise the blockers decision would offer it as a blocker again; until a card can
## create one then.
func _attacker_to_block(state: MmGameState, context: MmEffectContext) -> int:
	if blocking == null or not BLOCKS_DECLARED_STEPS.has(state.step) \
			or context.controller_id != state.combat.defending_player_id:
		return 0
	var found: Array[MmReference] = blocking.select(state, context)
	if found.size() != 1 or not found[0].is_object() or not state.combat.attackers(state).has(found[0].id):
		return 0
	return found[0].id
