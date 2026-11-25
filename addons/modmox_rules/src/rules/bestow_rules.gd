class_name BestowRules
extends RefCounted
## Bestow (CR 702.103, engine ADR 0089): finding a card's BestowAbility, and what being
## bestowed makes of an object's characteristics.


## The bestow ability among [param characteristics]' abilities, or null for a card without
## bestow.
static func bestow_of(characteristics: MmCharacteristics) -> BestowAbility:
	for ability: MmAbility in characteristics.abilities:
		if ability is BestowAbility:
			return ability as BestowAbility
	return null


## Makes [param characteristics] those of a bestowed object (CR 702.103b): an Aura
## enchantment with enchant creature, with no creature type and no creature subtypes. It
## applies first, before any continuous effect, as the card's own text does, so an effect
## that takes its abilities away takes enchant creature too. Nothing changes for a card
## without bestow.
static func make_bestowed(characteristics: MmCharacteristics) -> void:
	var bestow: BestowAbility = bestow_of(characteristics)
	if bestow == null:
		return
	characteristics.card_types.erase(MmCardTypes.CardType.CREATURE)
	if not characteristics.card_types.has(MmCardTypes.CardType.ENCHANTMENT):
		characteristics.card_types.append(MmCardTypes.CardType.ENCHANTMENT)
	var kept: Array[String] = []
	for subtype: String in characteristics.subtypes:
		if not CreatureTypes.is_creature_type(subtype):
			kept.append(subtype)
	if not kept.has(AttachmentRules.AURA):
		kept.append(AttachmentRules.AURA)
	characteristics.subtypes = kept
	characteristics.is_every_creature_type = false
	characteristics.abilities.append(bestow.enchant_creature())


## The characteristics [param card], in a hand, would have cast bestowed: worked out anew
## each time, so the card's own are never changed.
static func as_bestowed(state: MmGameState, card: MmGameObject) -> MmCharacteristics:
	var characteristics: MmCharacteristics = LayerEngine.outside_the_battlefield(state, card)
	make_bestowed(characteristics)
	return characteristics
