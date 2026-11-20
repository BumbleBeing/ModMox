class_name MmGameObject
extends RefCounted
## An object inside an encounter: a card in a zone, a spell or ability on the stack, or a
## token (CR 111), which is not a card and has no Card Identity. A card that changes zones becomes a new Game Object with a new
## [member id] (ADR 0008, CR 400.7). An ability on the stack is a Game Object that is not a
## card (CR 113.7a): it has no definition and no Card Identity.

## Card Identity of an object that is not a card, such as an ability on the stack.
const NO_CARD: int = -1
## The potion_index of anything that is not a Potion.
const NOT_A_POTION: int = -1
## The source_ability_index of anything that is not an ability on the stack.
const NO_ABILITY: int = -1

## This object's identity. Every stored, logged or answered reference uses it.
var id: int
## The physical card's identity, which survives zone changes. Used only to relate the
## object back to its Run Card for presentation and rewards; rules code never uses it.
var card_id: int
var owner_id: int
## Starts as the owner (CR 110.2). Control-changing effects arrive with layers (milestone 9).
var controller_id: int
## Meaningful for permanents (CR 110.5). A new object always starts untapped.
var is_tapped: bool = false
## Damage marked on this permanent (CR 120.3e), until the cleanup step removes it.
var damage_marked: int = 0
## How many counters of each kind are on this permanent (CR 122). A kind it has none of is
## not listed.
var counters: Dictionary[MmCounter.Kind, int] = {}
## CR 704.5h: dealt damage by a source with deathtouch since state-based actions were last
## checked, so it is destroyed at the next check. Cleared when it regenerates, or by that
## check when it can't be destroyed.
var was_dealt_deathtouch_damage: bool = false
## The Game Turn in which this permanent's current controller began controlling it. With
## each player's latest_turn_game_turn it tells summoning sickness (CR 302.6).
var controlled_since_game_turn: int = 0
## The flattened definition, or null for an ability on the stack. Rules code reads
## characteristics through MmGameState.characteristics_of(), never from here (ADR 0009).
var definition: MmCardDefinition
## For a spell or ability on the stack: the chosen targets of its target requirements, in
## order, a place for each target a requirement may choose, so "up to two target creatures"
## takes two (ADR 0014). An entry is null until that target is chosen, and stays null for
## one an "up to" requirement left unchosen.
var targets: Array[MmReference] = []
## For a modal spell or modal triggered ability on the stack: the chosen mode (CR 700.2),
## an index into its spell ability's or triggered ability's modes. SpellAbility.NO_MODE for
## anything else, or until it is chosen.
var chosen_mode: int = SpellAbility.NO_MODE
## For a spell on the stack: cast from a graveyard for its flashback cost, so it is exiled
## instead of going anywhere else as it leaves the stack (CR 702.34a).
var cast_with_flashback: bool = false
## For a spell on the stack: cast from the top of its owner's library with a
## CastFromTopOfLibraryAbility's permission (ADR 0054). Both players see it.
var cast_from_library: bool = false
## For a spell cast from the top of a library: true from the moment it is put on the stack
## until it becomes cast (CR 601.2i), while its owner does not yet see the new top card.
var is_being_cast_from_library: bool = false
## For an ability on the stack: the ability, the object it came from, and that object's
## name when it was activated (the source may have left the battlefield since).
var ability: MmAbility = null
var source_object_id: int = 0
var source_name: String = ""
## For an ability on the stack: its place among its source's abilities as it was put on the
## stack, so "this ability" is known after the source has left (ADR 0056); NO_ABILITY for
## anything else.
var source_ability_index: int = NO_ABILITY
## For an ability on the stack: its source's Card Identity, so the GUI can find the card
## even after it changed zones; NO_CARD for an Emblem's ability.
var source_card_id: int = NO_CARD
## For an ability on the stack whose source is a Potion: that Potion's potion_index, since
## the Potion itself is gone once its cost is paid (ADR 0036). NOT_A_POTION otherwise.
var source_potion_index: int = NOT_A_POTION
## For a triggered ability on the stack: what its event was about ("that player", "that
## creature"); MmGameState.NO_PLAYER and 0 when nothing.
var triggering_player_id: int = -1
var triggering_object_id: int = 0
## Set once this object has left the battlefield: its characteristics as it last existed
## there (CR 608.2h). The object never changes after that.
var last_known_characteristics: MmCharacteristics = null
## For a card in a library: the players who know which card this is, in the order they
## learned it. Empty anywhere else, where the zone itself says who may see a card.
var known_to_player_ids: Array[int] = []
## For a Potion (ADR 0036): its place in its owner's list of Potions in the Encounter Setup,
## which is how the game knows which Item it was. NOT_A_POTION for anything else.
var potion_index: int = NOT_A_POTION
## The once-each-game abilities of this object that have been activated (Spent), by their
## place among its abilities, in the order they were activated (CR 602.5b).
var spent_ability_indexes: Array[int] = []
## The once-each-turn cast permissions of this object that have been used, by their place
## among its abilities: the Game Turn each was last used in, and the name of the spell it
## cast, for presentation (ADR 0054). A permission is Spent while its Game Turn is the
## current one, so nothing has to clear it as a turn begins.
var permission_used_game_turn: Dictionary[int, int] = {}
var permission_used_spell_name: Dictionary[int, String] = {}
## For a card in exile: the object whose ability exiled it, so that object's linked ability
## can find "the exiled card" (CR 607.2a); 0 for anything else. The object that exiled it
## may have left the battlefield since, and is then known only by this ID.
var exiled_with_object_id: int = 0
## For a card in exile: true when it was exiled "until [that object] leaves the
## battlefield" (CR 610.3, ADR 0065), so it comes back once that object has left.
var returns_when_exiler_leaves: bool = false
## For a permanent attached to another, such as an Equipment (CR 301.5): the ID of the
## permanent it is attached to; 0 when it is attached to nothing. That permanent may have
## left the battlefield since, until state-based actions unattach this one (CR 704.5n).
var attached_to_object_id: int = 0
## Whether this is a token (CR 111.1): made by an effect from a Token Definition, which is
## its [member definition]. It is never a card, so its card_id is NO_CARD, and it ceases to
## exist once it is anywhere but the battlefield (CR 704.5d).
var is_token: bool = false
## For a permanent with "As this enters, choose a creature type": the type chosen as it
## entered (CR 614.12, ADR 0052), or "". Public, like the permanent.
var chosen_creature_type: String = ""
## For an exerted permanent (CR 701.43): the player who exerted it, whose next untap step it
## won't untap in; MmGameState.NO_PLAYER for one not exerted. That untap step ends it, and a
## zone change leaves it behind with the old object (ADR 0008). Public, like the permanent.
var exerted_by_player_id: int = MmGameState.NO_PLAYER
## Weak, because the zone already holds this object strongly; a strong reference both ways
## is a cycle that reference counting never frees.
var _zone_ref: WeakRef = null


func _init(object_id: int, object_card_id: int, object_owner_id: int, object_definition: MmCardDefinition) -> void:
	id = object_id
	card_id = object_card_id
	owner_id = object_owner_id
	controller_id = object_owner_id
	definition = object_definition


## A copy of this object, not yet in any zone.
func duplicate_object() -> MmGameObject:
	var copy: MmGameObject = MmGameObject.new(id, card_id, owner_id, definition)
	copy.controller_id = controller_id
	copy.is_tapped = is_tapped
	copy.damage_marked = damage_marked
	copy.counters = counters.duplicate()
	copy.was_dealt_deathtouch_damage = was_dealt_deathtouch_damage
	copy.controlled_since_game_turn = controlled_since_game_turn
	copy.targets = targets.duplicate()  # MmReferences never change, so sharing them is safe.
	copy.chosen_mode = chosen_mode
	copy.cast_with_flashback = cast_with_flashback
	copy.cast_from_library = cast_from_library
	copy.is_being_cast_from_library = is_being_cast_from_library
	copy.ability = ability
	copy.source_object_id = source_object_id
	copy.source_name = source_name
	copy.source_ability_index = source_ability_index
	copy.source_card_id = source_card_id
	copy.source_potion_index = source_potion_index
	copy.triggering_player_id = triggering_player_id
	copy.triggering_object_id = triggering_object_id
	copy.last_known_characteristics = last_known_characteristics  # Read-only, so shared.
	copy.known_to_player_ids = known_to_player_ids.duplicate()
	copy.potion_index = potion_index
	copy.spent_ability_indexes = spent_ability_indexes.duplicate()
	copy.permission_used_game_turn = permission_used_game_turn.duplicate()
	copy.permission_used_spell_name = permission_used_spell_name.duplicate()
	copy.exiled_with_object_id = exiled_with_object_id
	copy.returns_when_exiler_leaves = returns_when_exiler_leaves
	copy.attached_to_object_id = attached_to_object_id
	copy.is_token = is_token
	copy.chosen_creature_type = chosen_creature_type
	copy.exerted_by_player_id = exerted_by_player_id
	return copy


## Whether this object is a card: not an ability on the stack, a token, an Emblem or a
## Potion.
func is_card() -> bool:
	return card_id != NO_CARD


## Whether this object is a Potion (ADR 0036).
func is_potion() -> bool:
	return potion_index != NOT_A_POTION


## Whether the once-each-game ability at [param ability_index] has been activated.
func is_ability_spent(ability_index: int) -> bool:
	return spent_ability_indexes.has(ability_index)


## Whether the cast permission at [param ability_index] was used in [param game_turn].
func is_permission_used_in(ability_index: int, game_turn: int) -> bool:
	return permission_used_game_turn.get(ability_index, -1) == game_turn


## The zone holding this object, or null while it is between zones.
func zone() -> MmZone:
	return null if _zone_ref == null else _zone_ref.get_ref() as MmZone


## Whether [param player_id] knows which card this is while it is in a library.
func is_known_to(player_id: int) -> bool:
	return known_to_player_ids.has(player_id)


## How many counters of [param kind] are on this permanent.
func counters_of(kind: MmCounter.Kind) -> int:
	return counters.get(kind, 0)


## Zone-only: records which zone now holds this object (null when removed).
func attach_to_zone(holder: MmZone) -> void:
	_zone_ref = null if holder == null else weakref(holder)


## Event-only: makes this object a token (CR 111.1).
func become_token() -> void:
	is_token = true


## Event-only: attaches this permanent to [param object_id], or to nothing for 0.
func attach_to(object_id: int) -> void:
	attached_to_object_id = object_id


## Event-only: taps or untaps this permanent.
func set_tapped(tapped: bool) -> void:
	is_tapped = tapped


## Event-only: exerts this permanent for [param player_id]'s next untap step.
func exert(player_id: int) -> void:
	exerted_by_player_id = player_id


## Event-only: the untap step this permanent was exerted for has come.
func end_exertion() -> void:
	exerted_by_player_id = MmGameState.NO_PLAYER


## Event-only: marks [param amount] more damage on this permanent.
func mark_damage(amount: int) -> void:
	damage_marked += amount


## Event-only: records damage from a source with deathtouch (CR 704.5h).
func mark_deathtouch_damage() -> void:
	was_dealt_deathtouch_damage = true


## Event-only: CR 704.5h asks only about deathtouch damage since the last check.
func clear_deathtouch_damage() -> void:
	was_dealt_deathtouch_damage = false


## Event-only: removes all damage marked on this permanent.
func remove_damage() -> void:
	damage_marked = 0


## Event-only: puts [param amount] more counters of [param kind] on this permanent.
func put_counters(kind: MmCounter.Kind, amount: int) -> void:
	counters[kind] = counters_of(kind) + amount


## Event-only: removes [param amount] counters of [param kind], or all of them if it has
## fewer.
func remove_counters(kind: MmCounter.Kind, amount: int) -> void:
	var left: int = counters_of(kind) - amount
	if left > 0:
		counters[kind] = left
	else:
		counters.erase(kind)


## Event-only: records that the current controller began controlling this permanent in
## [param game_turn].
func record_control_since(game_turn: int) -> void:
	controlled_since_game_turn = game_turn


## Event-only: freezes this object's last-known information as it leaves the battlefield.
func freeze_last_known(characteristics: MmCharacteristics) -> void:
	last_known_characteristics = characteristics


## Event-only: marks a spell as cast with flashback (CR 702.34a), as it is put on the stack.
func record_cast_with_flashback() -> void:
	cast_with_flashback = true


## Event-only: marks a spell as cast from the top of a library (ADR 0054), as it is put on
## the stack; it is being cast until finish_cast_from_library().
func record_cast_from_library() -> void:
	cast_from_library = true
	is_being_cast_from_library = true


## Event-only: the spell cast from the top of a library has become cast (CR 601.2i).
func finish_cast_from_library() -> void:
	is_being_cast_from_library = false


## Event-only: the cast permission at [param ability_index] was used in [param game_turn]
## to cast [param spell_name].
func record_permission_used(ability_index: int, game_turn: int, spell_name: String) -> void:
	permission_used_game_turn[ability_index] = game_turn
	permission_used_spell_name[ability_index] = spell_name


## Event-only: records the creature type chosen as this permanent entered (CR 614.12).
func record_chosen_creature_type(creature_type: String) -> void:
	chosen_creature_type = creature_type


## Event-only: records the mode chosen for a modal spell or triggered ability (CR 601.2b,
## 603.3c).
func set_chosen_mode(mode_index: int) -> void:
	chosen_mode = mode_index


## Event-only: records the target chosen for place [param index] of the targets.
func set_target(index: int, target: MmReference) -> void:
	while targets.size() <= index:
		targets.append(null)
	targets[index] = target


## Event-only: [param player_id] saw this card go into a library, or saw it revealed
## as it went into a hand (ADR 0057), or kept it on top of their library with a surveil
## (ADR 0068).
func make_known_to(player_id: int) -> void:
	if not known_to_player_ids.has(player_id):
		known_to_player_ids.append(player_id)


## Event-only: its library was shuffled, or a card left its hand for the library unseen
## (ADR 0057), so nobody knows which card it is.
func forget_who_knows() -> void:
	known_to_player_ids.clear()


## Event-only: an ability of the object [param object_id] exiled this card (CR 607.2a),
## until that object leaves the battlefield when [param until_it_leaves] (CR 610.3).
func record_exiled_with(object_id: int, until_it_leaves: bool = false) -> void:
	exiled_with_object_id = object_id
	returns_when_exiler_leaves = until_it_leaves


## Event-only: the once-each-game ability at [param ability_index] was activated.
func mark_ability_spent(ability_index: int) -> void:
	if not spent_ability_indexes.has(ability_index):
		spent_ability_indexes.append(ability_index)
