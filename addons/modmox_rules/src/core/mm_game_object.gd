class_name MmGameObject
extends RefCounted
## An object inside an encounter: a card in a zone, a spell or ability on the stack, and in
## later milestones a token. A card that changes zones becomes a new Game Object with a new
## [member id] (ADR 0008, CR 400.7). An ability on the stack is a Game Object that is not a
## card (CR 113.7a): it has no definition and no Card Identity.

## Card Identity of an object that is not a card, such as an ability on the stack.
const NO_CARD: int = -1

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
## For a spell or ability on the stack: the chosen target of each target requirement, in
## order. An entry is null until that target is chosen.
var targets: Array[MmReference] = []
## For an ability on the stack: the ability, the object it came from, and that object's
## name when it was activated (the source may have left the battlefield since).
var ability: MmAbility = null
var source_object_id: int = 0
var source_name: String = ""
## For an ability on the stack: its source's Card Identity, so the GUI can find the card
## even after it changed zones; NO_CARD for an Emblem's ability.
var source_card_id: int = NO_CARD
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
	copy.was_dealt_deathtouch_damage = was_dealt_deathtouch_damage
	copy.controlled_since_game_turn = controlled_since_game_turn
	copy.targets = targets.duplicate()  # MmReferences never change, so sharing them is safe.
	copy.ability = ability
	copy.source_object_id = source_object_id
	copy.source_name = source_name
	copy.source_card_id = source_card_id
	copy.triggering_player_id = triggering_player_id
	copy.triggering_object_id = triggering_object_id
	copy.last_known_characteristics = last_known_characteristics  # Read-only, so shared.
	copy.known_to_player_ids = known_to_player_ids.duplicate()
	return copy


## Whether this object is a card (as opposed to an ability on the stack).
func is_card() -> bool:
	return card_id != NO_CARD


## The zone holding this object, or null while it is between zones.
func zone() -> MmZone:
	return null if _zone_ref == null else _zone_ref.get_ref() as MmZone


## Whether [param player_id] knows which card this is while it is in a library.
func is_known_to(player_id: int) -> bool:
	return known_to_player_ids.has(player_id)


## Zone-only: records which zone now holds this object (null when removed).
func attach_to_zone(holder: MmZone) -> void:
	_zone_ref = null if holder == null else weakref(holder)


## Event-only: taps or untaps this permanent.
func set_tapped(tapped: bool) -> void:
	is_tapped = tapped


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


## Event-only: records that the current controller began controlling this permanent in
## [param game_turn].
func record_control_since(game_turn: int) -> void:
	controlled_since_game_turn = game_turn


## Event-only: freezes this object's last-known information as it leaves the battlefield.
func freeze_last_known(characteristics: MmCharacteristics) -> void:
	last_known_characteristics = characteristics


## Event-only: records the target chosen for requirement [param index].
func set_target(index: int, target: MmReference) -> void:
	while targets.size() <= index:
		targets.append(null)
	targets[index] = target


## Event-only: [param player_id] saw this card go into a library.
func make_known_to(player_id: int) -> void:
	if not known_to_player_ids.has(player_id):
		known_to_player_ids.append(player_id)


## Event-only: its library was shuffled, so nobody knows which card it is.
func forget_who_knows() -> void:
	known_to_player_ids.clear()
