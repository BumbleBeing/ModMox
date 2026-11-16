class_name DeckbuilderLooks
extends RefCounted
## The CardLook a DeckbuilderCard is drawn from: its printed characteristics with every Mod
## applied, or its Original's (ADR 0009). The run knows nothing of how a card is drawn, so
## the look is made here, and kept on the card until a Mod changes it (its revision), since
## the search works the rules text of every card out again at each key typed.

const _LOOK: StringName = &"deckbuilder_look"
const _LOOK_REVISION: StringName = &"deckbuilder_look_revision"
const _ORIGINAL: StringName = &"deckbuilder_original_look"


## How [param card] reads now, with every Mod applied.
static func look_of(card: DeckbuilderCard) -> CardLook:
	if card.has_meta(_LOOK) and (card.get_meta(_LOOK_REVISION) as int) == card.revision:
		return card.get_meta(_LOOK) as CardLook
	var look: CardLook = CardLook.of_characteristics(card.characteristics(), card.art_key())
	card.set_meta(_LOOK, look)
	card.set_meta(_LOOK_REVISION, card.revision)
	return look


## How [param card]'s Card Definition reads: no Mods and no Hexes. It never changes.
static func original_of(card: DeckbuilderCard) -> CardLook:
	if card.has_meta(_ORIGINAL):
		return card.get_meta(_ORIGINAL) as CardLook
	var look: CardLook = CardLook.of_characteristics(card.original_characteristics(), card.art_key())
	card.set_meta(_ORIGINAL, look)
	return look
