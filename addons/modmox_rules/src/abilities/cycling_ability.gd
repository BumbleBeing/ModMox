class_name CyclingAbility
extends ActivatedAbility
## The keyword "Cycling [cost]" (CR 702.29a): "[Cost], Discard this card: Draw a card",
## activated only while its card is in its owner's hand (CR 702.29b, ADR 0059), whenever
## its owner has priority. Authored with its [member mana_cost] alone: it is made with its
## discard cost, its effect and [member is_activated_from_hand], which are saved with it like
## any activated ability's, so a Modification changes them the same way. With a
## [member search] it is typecycling (CR 702.29e), such as basic landcycling, which searches
## instead of drawing.

## Null for plain cycling. Otherwise typecycling: "[Cost], Discard this card: Search your
## library for a [search] card, reveal it, put it into your hand, then shuffle" (CR 702.29e),
## such as a basic land card for basic landcycling. Setting it remakes the effect, unless
## the effects were changed by other means, such as being loaded from a file after it.
@export var search: MmFilter = null:
	set(value):
		search = value
		if effects.size() == 1 and effects[0] == _made_effect:
			_make_effect()

## The effect this ability last made for itself, so a later [member search] replaces it and
## nothing else.
var _made_effect: MmEffect = null


func _init() -> void:
	costs = [DiscardThisCardCost.new()]
	is_activated_from_hand = true
	_make_effect()


func describe() -> String:
	return "cycling"


# "Draw a card", or for typecycling the search that stands in for it (CR 702.29e).
func _make_effect() -> void:
	var one: ConstantValue = ConstantValue.new()
	one.value = 1
	if search == null:
		var draw: DrawCardsEffect = DrawCardsEffect.new()
		draw.amount = one
		draw.players = YouSelection.new()
		_made_effect = draw
	else:
		var searching: SearchLibraryEffect = SearchLibraryEffect.new()
		searching.filter = search
		searching.amount = one
		searching.reveal = true
		searching.destination = MmZone.Kind.HAND
		_made_effect = searching
	effects = [_made_effect]
