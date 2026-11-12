class_name DeckbuilderFace
extends RefCounted
## Makes the Card Faces the deckbuilder shows: a Card Face that takes no clicks, with the
## card's Mod Slots drawn on it.


## A Card Face for [param card], [param height] tall, showing its Mod Slots if it has any,
## unless [param shows_slots] is false.
static func make(card: DeckbuilderCard, height: float, shows_slots: bool = true) -> CardFace:
	var face: CardFace = CardFace.new()
	face.setup(card.look(), height)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shows_slots and card.mod_slots() > 0:
		var row: ModSlotRow = ModSlotRow.new()
		row.name = "ModSlots"
		row.setup(card, height)
		face.add_child(row)
	return face


## The Mod Slots drawn on [param face], or null if it has none.
static func mod_slots_on(face: CardFace) -> ModSlotRow:
	return face.get_node_or_null("ModSlots") as ModSlotRow
