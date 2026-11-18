class_name CastFromTopOfLibraryAbility
extends StaticAbility
## "Once each turn, you may cast [filter] from the top of your library": a permission for
## the controller of its permanent to cast the top card of their own library when it
## matches [member filter], with its usual timing and for its mana cost (ADR 0054). Each
## instance may be used once each turn, by its own Game Object, so two permanents with it
## give two casts, and one that leaves and comes back is a new object that may be used
## again (ADR 0008). It is used as the cast begins (CR 601.3), and is not asked again.
## Later: a permission with no "once each turn", when a card has one.

## What the card must be as it is cast, such as "creature spell with power 2 or less".
## Null for any card.
@export var filter: MmFilter = null


func describe() -> String:
	return "cast from the top of your library once each turn"
