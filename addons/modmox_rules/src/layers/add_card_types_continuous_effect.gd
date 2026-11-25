class_name AddCardTypesContinuousEffect
extends MmContinuousEffect
## "[affected] becomes a [card types]" (layer 4, CR 613.1d), as Bring to Life's "becomes a
## 0/0 artifact creature" (engine ADR 0091). An effect that makes an object an artifact
## creature, or any other card types, lets it keep every type and subtype it had (CR 205.1b),
## and a card type it already has is not added again.

## The card types it adds, in the order they are added.
@export var card_types: Array[MmCardTypes.CardType] = []


func layer() -> Layer:
	return Layer.TYPE


func apply_to(characteristics: MmCharacteristics, _amounts: Array[int]) -> void:
	for card_type: MmCardTypes.CardType in card_types:
		if not characteristics.card_types.has(card_type):
			characteristics.card_types.append(card_type)
