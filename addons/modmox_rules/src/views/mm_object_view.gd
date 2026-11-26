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
## For an ability on the stack that came from a Potion: that Potion's place in its
## controller's list in the Encounter Setup, so the GUI can still show which Potion it was.
var source_potion_index: int = MmGameObject.NOT_A_POTION
## For an ability on the stack: the ability itself, so the GUI can say what it does, and
## what its event was about ("that player", "that creature"); null, MmGameState.NO_PLAYER
## and 0 for anything else. Card data, never to be changed.
var ability: MmAbility = null
var triggering_player_id: int = MmGameState.NO_PLAYER
var triggering_object_id: int = 0
var name: String
var owner_id: int
var controller_id: int
var is_tapped: bool
## Exerted (CR 701.43): it won't untap during its controller's next untap step. Public.
var is_exerted: bool = false
## It won't untap during its controller's next untap step (CR 502.3), as a DoesntUntapEffect
## says. Public.
var skips_next_untap: bool = false
## The characteristics a card is drawn from, so the GUI can choose its Frame (ADR 0009).
## In WUBRG order; empty means colorless.
var colors: Array[MmCardTypes.CardColor] = []
var card_types: Array[MmCardTypes.CardType] = []
var supertypes: Array[MmCardTypes.Supertype] = []
var subtypes: Array[String] = []
## Every creature type besides its [member subtypes], as changeling makes it (CR 702.73a,
## ADR 0075).
var is_every_creature_type: bool = false
## Null for a card with no mana cost, which is not the same as {0}.
var mana_cost: MmManaCost = null
## For a spell or ability on the stack: its chosen targets, in order (null if not chosen).
var targets: Array[MmReference] = []
## For a modal spell or modal triggered ability on the stack: its chosen mode, which both
## players see (CR 700.2).
## SpellAbility.NO_MODE otherwise.
var chosen_mode: int = SpellAbility.NO_MODE
## For a spell on the stack: cast with flashback, so it will be exiled as it leaves the
## stack (CR 702.34a). Both players see it.
var cast_with_flashback: bool = false
## For a spell on the stack: cast from the top of its owner's library (ADR 0054). Both
## players see it.
var cast_from_library: bool = false
## For an Adventurer card (CR 715.2): its Adventure's characteristics as printed, for drawing
## the card whole. Null for any other card, and for a spell cast as its Adventure.
var adventure: MmCharacteristics = null
## For a spell on the stack: cast as its Adventure (CR 715.3). Both players see it.
var is_adventure_spell: bool = false
## For a spell cast as its Adventure: its card's creature half as printed, so the whole
## card can be drawn with the Adventure's page lit (engine ADR 0078). Null otherwise.
var adventurer: MmCharacteristics = null
## For a card in exile: on an adventure, so its owner may cast it as the creature (CR 715.3d).
var is_on_adventure: bool = false
## For a card in exile: the player who may play it and the last Game Turn they may (engine
## ADR 0100), or MmGameState.NO_PLAYER. Public, like exile.
var playable_by_player_id: int = MmGameState.NO_PLAYER
var playable_through_game_turn: int = 0
## The cast permissions of this permanent Spent this turn (ADR 0054), by their place among
## its abilities, each with the name of the spell it cast. Public, like the permanent.
var permissions_used_this_turn: Dictionary[int, String] = {}
## Its once-each-turn triggered abilities that have triggered this turn, Spent until the
## next turn (ADR 0054's addendum), by their place among its abilities, lowest first.
## Public, like the permanent.
var triggered_this_turn: Array[int] = []
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
## How many counters of each kind are on it (CR 122); a kind it has none of is not listed.
## Public, like the permanent.
var counters: Dictionary[MmCounter.Kind, int] = {}
## For a permanent attached to another, such as an Equipment (CR 301.5): the ID of the
## permanent it is attached to; 0 for anything else. Public, like the permanent.
var attached_to_object_id: int = 0
## For a card in exile that an object's ability exiled (CR 607.2a): the ID of that object;
## 0 for anything else. That object may have left the battlefield since. Public, like the
## exile zone.
var exiled_with_object_id: int = 0
## Its once-each-game abilities that have been activated, and its once-each-turn ones
## activated this turn, by their place in abilities, so the GUI can gray them (ADR 0036 and
## its addendum). Public, like the object.
var spent_ability_indexes: Array[int] = []
## For a Potion: its place in its owner's list of Potions in the Encounter Setup;
## MmGameObject.NOT_A_POTION for anything else.
var potion_index: int = MmGameObject.NOT_A_POTION
## Whether it is a token (CR 111.1), and the Token Definition it was made from, so the
## GUI can find its art; null for anything that is not a token or a copy of a spell. For a
## copy of a spell (CR 707.10), and the token a copy of a permanent spell becomes, it is the
## copied card's definition, whose Original names the card.
var is_token: bool = false
## Whether it is a copy of a spell on the stack (CR 707.10). Both players see it.
var is_copy: bool = false
## For a permanent with "As this enters, choose a creature type": the type chosen as it
## entered, or "". Both players see it (ADR 0052).
var chosen_creature_type: String = ""
var token_definition: MmCardDefinition = null
## For a copy of a spell, and a token made from a card's definition: the Card Identity of
## the card it was copied from, so the GUI can call it by that card's Modded Name;
## MmGameObject.NO_CARD for anything else, a token from a Token Definition included.
var made_from_card_id: int = MmGameObject.NO_CARD
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
	view.source_potion_index = game_object.source_potion_index
	view.ability = game_object.ability
	view.triggering_player_id = game_object.triggering_player_id
	view.triggering_object_id = game_object.triggering_object_id
	view.name = state.characteristics_of(game_object).name
	view.owner_id = game_object.owner_id
	view.controller_id = game_object.controller_id
	view.is_tapped = game_object.is_tapped
	view.is_exerted = game_object.exerted_by_player_id != MmGameState.NO_PLAYER
	view.skips_next_untap = game_object.skips_next_untap
	view.targets = game_object.targets.duplicate()
	view.chosen_mode = game_object.chosen_mode
	view.cast_with_flashback = game_object.cast_with_flashback
	view.cast_from_library = game_object.cast_from_library
	view.is_adventure_spell = game_object.is_adventure_spell
	view.is_on_adventure = game_object.is_on_adventure
	view.playable_by_player_id = game_object.playable_by_player_id
	view.playable_through_game_turn = game_object.playable_through_game_turn
	if game_object.is_adventure_spell and game_object.definition != null:
		# Not the spell's characteristics, which are the Adventure's: the card it is printed on.
		view.adventurer = MmCharacteristics.printed(game_object.definition)
	for index: int in game_object.permission_used_game_turn:
		if game_object.is_permission_used_in(index, state.game_turn):
			view.permissions_used_this_turn[index] = game_object.permission_used_spell_name[index]
	for index: int in game_object.triggered_game_turn:
		if game_object.has_triggered_in(index, state.game_turn):
			view.triggered_this_turn.append(index)
	view.triggered_this_turn.sort()
	var characteristics: MmCharacteristics = state.characteristics_of(game_object)
	view.colors = characteristics.colors.duplicate()
	view.card_types = characteristics.card_types.duplicate()
	view.adventure = characteristics.adventure
	view.supertypes = characteristics.supertypes.duplicate()
	view.subtypes = characteristics.subtypes.duplicate()
	view.is_every_creature_type = characteristics.is_every_creature_type
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
	view.counters = game_object.counters.duplicate()
	view.attached_to_object_id = game_object.attached_to_object_id
	view.exiled_with_object_id = game_object.exiled_with_object_id
	view.spent_ability_indexes = game_object.spent_ability_indexes.duplicate()
	for index: int in game_object.activated_game_turn:
		if game_object.has_activated_in(index, state.game_turn) and not view.spent_ability_indexes.has(index):
			view.spent_ability_indexes.append(index)  # ADR 0036's addendum: Spent for the rest of the turn.
	view.potion_index = game_object.potion_index
	view.is_token = game_object.is_token
	view.chosen_creature_type = game_object.chosen_creature_type
	view.is_copy = game_object.is_copy
	view.token_definition = game_object.definition if game_object.is_token or game_object.is_copy else null
	if view.token_definition != null:
		view.made_from_card_id = state.card_id_made_from(view.token_definition)
	view.is_summoning_sick = state.is_summoning_sick(game_object)
	if game_object.zone() == state.battlefield:
		# CR 604.3: a permanent's numbers are worked out, so it no longer reads "*".
		view.is_power_variable = false
		view.is_toughness_variable = false
		view.is_attacking = state.combat.attackers(state).has(game_object.id)
		view.is_blocked = view.is_attacking and state.combat.is_blocked(game_object.id)
		view.blocking_ids = state.combat.attackers_blocked_by(state, game_object.id)
	return view


## How many counters of [param kind] are on it.
func counters_of(kind: MmCounter.Kind) -> int:
	return counters.get(kind, 0)
