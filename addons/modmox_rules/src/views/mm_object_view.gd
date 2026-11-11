class_name MmObjectView
extends RefCounted
## What a player can see of one Game Object they are allowed to see.

var id: int
## The physical card's Card Identity, or MmGameObject.NO_CARD for an ability or Emblem.
## For presentation only, such as finding the card again after it changes zones.
var card_id: int
## For an ability on the stack: its source object and that source's Card Identity, so the
## GUI can highlight the card while the ability is hovered (NO_CARD for an Emblem's).
var source_object_id: int = 0
var source_card_id: int = MmGameObject.NO_CARD
var name: String
var owner_id: int
var controller_id: int
var is_tapped: bool
## The characteristics a card is drawn from, so the GUI can choose its Frame (ADR 0009).
## In WUBRG order; empty means colorless.
var colors: Array[MmCardTypes.CardColor] = []
var card_types: Array[MmCardTypes.CardType] = []
var supertypes: Array[MmCardTypes.Supertype] = []
var subtypes: Array[String] = []
## Null for a card with no mana cost, which is not the same as {0}.
var mana_cost: MmManaCost = null
## For a spell or ability on the stack: its chosen targets, in order (null if not chosen).
var targets: Array[MmReference] = []
var is_creature: bool = false
## Current power and toughness; meaningful only for a creature (CR 208.3).
var power: int = 0
var toughness: int = 0
## Printed power and toughness, so the GUI can show when they have changed.
var base_power: int = 0
var base_toughness: int = 0
## CR 604.3: shown as "*" when not worked out, as on a card. Never true on the battlefield,
## where power and toughness hold the worked-out numbers.
var is_power_variable: bool = false
var is_toughness_variable: bool = false
## Every ability it has right now, including granted ones such as "gains flying".
var abilities: Array[MmAbility] = []
## The "until end of turn" and other created effects applying to it, so the GUI can say
## where a change came from.
var continuous_effects: Array[ActiveContinuousEffect] = []
## The shields and other replacement effects locked to it, such as "prevent the next 1
## damage" or a regeneration shield, each with what it has left and its source's Card
## Identity (A140). Protection's prevention shows as the ability instead.
var replacement_effects: Array[ActiveReplacementEffect] = []
var damage_marked: int = 0
## CR 302.6: a creature that cannot attack or pay {T} yet.
var is_summoning_sick: bool = false
var is_attacking: bool = false
## For an attacker: whether it has been blocked, even if its blockers are gone (CR 509.1h).
var is_blocked: bool = false
## For a blocker: the attackers it is blocking, in ID order.
var blocking_ids: Array[int] = []


## The view of [param game_object] as it is now.
static func of(state: MmGameState, game_object: MmGameObject) -> MmObjectView:
	var view: MmObjectView = MmObjectView.new()
	view.id = game_object.id
	view.card_id = game_object.card_id
	view.source_object_id = game_object.source_object_id
	view.source_card_id = game_object.source_card_id
	view.name = state.characteristics_of(game_object).name
	view.owner_id = game_object.owner_id
	view.controller_id = game_object.controller_id
	view.is_tapped = game_object.is_tapped
	view.targets = game_object.targets.duplicate()
	var characteristics: MmCharacteristics = state.characteristics_of(game_object)
	view.colors = characteristics.colors.duplicate()
	view.card_types = characteristics.card_types.duplicate()
	view.supertypes = characteristics.supertypes.duplicate()
	view.subtypes = characteristics.subtypes.duplicate()
	view.mana_cost = characteristics.mana_cost
	view.is_creature = characteristics.has_card_type(MmCardTypes.CardType.CREATURE)
	view.power = characteristics.power
	view.toughness = characteristics.toughness
	view.base_power = characteristics.base_power
	view.base_toughness = characteristics.base_toughness
	view.is_power_variable = characteristics.is_power_variable
	view.is_toughness_variable = characteristics.is_toughness_variable
	view.abilities = characteristics.abilities.duplicate()
	for active: ActiveContinuousEffect in state.continuous_effects:
		if active.affected_ids.has(game_object.id):
			view.continuous_effects.append(active)
	for active: ActiveReplacementEffect in state.replacement_effects:
		if active.is_locked_to(MmReference.to_object(game_object.id)):
			view.replacement_effects.append(active)
	view.damage_marked = game_object.damage_marked
	view.is_summoning_sick = state.is_summoning_sick(game_object)
	if game_object.zone() == state.battlefield:
		# CR 604.3: a permanent's numbers are worked out, so it no longer reads "*".
		view.is_power_variable = false
		view.is_toughness_variable = false
		view.is_attacking = state.combat.attackers(state).has(game_object.id)
		view.is_blocked = view.is_attacking and state.combat.is_blocked(game_object.id)
		view.blocking_ids = state.combat.attackers_blocked_by(state, game_object.id)
	return view
