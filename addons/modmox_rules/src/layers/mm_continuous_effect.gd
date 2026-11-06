class_name MmContinuousEffect
extends Resource
## A change to characteristics that lasts (CR 611), applied in its layer (CR 613). It comes
## from a static ability, applying to whatever [member affected] finds right now, or from a
## resolved spell or ability, applying to what it found then. Subclasses describe one kind
## each.

## The layers and sublayers, in the order they apply (CR 613.1, 613.4).
enum Layer {
	COPY = 1, CONTROL = 2, TEXT = 3, TYPE = 4, COLOR = 5, ABILITY = 6,
	DEFINING_POWER_TOUGHNESS = 7, SETTING_POWER_TOUGHNESS = 8, MODIFYING_POWER_TOUGHNESS = 9,
}

## The objects it changes.
@export var affected: MmSelection


## Which layer it applies in.
func layer() -> Layer:
	assert(false, "%s must override layer()." % get_script().resource_path)
	return Layer.COPY


## The numbers it uses, worked out now. A resolved spell's effect keeps the numbers from
## when it resolved (CR 608.2h); a static ability's are worked out each time.
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	return []


## Changes [param characteristics], using [param amounts] from numbers().
func apply_to(_characteristics: MmCharacteristics, _amounts: Array[int]) -> void:
	assert(false, "%s must override apply_to()." % get_script().resource_path)


## Whether it uses a target, worked out from its Selection (ADR 0014).
func has_targets() -> bool:
	return affected != null and affected.is_targeted()
