class_name MmGameObject
extends RefCounted
## An object inside an encounter: a card in a zone, and in later milestones a spell,
## permanent, token or ability. A card that changes zones becomes a new Game Object with
## a new [member id] (ADR 0008, CR 400.7).

## This object's identity. Every stored, logged or answered reference uses it.
var id: int
## The physical card's identity, which survives zone changes. Used only to relate the
## object back to its Run Card for presentation and rewards; rules code never uses it.
var card_id: int
var owner_id: int
## The flattened definition. Rules code reads characteristics through
## MmGameState.characteristics_of(), never from here (ADR 0009).
var definition: MmCardDefinition
## Weak, because the zone already holds this object strongly; a strong reference both ways
## is a cycle that reference counting never frees.
var _zone_ref: WeakRef = null


func _init(object_id: int, object_card_id: int, object_owner_id: int, object_definition: MmCardDefinition) -> void:
	id = object_id
	card_id = object_card_id
	owner_id = object_owner_id
	definition = object_definition


## The zone holding this object, or null while it is between zones.
func zone() -> MmZone:
	return null if _zone_ref == null else _zone_ref.get_ref() as MmZone


## Zone-only: records which zone now holds this object (null when removed).
func attach_to_zone(holder: MmZone) -> void:
	_zone_ref = null if holder == null else weakref(holder)
