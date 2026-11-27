class_name Prices
extends RefCounted
## What everything costs at a Store, and what a Store pays (ADR 0070): one price for each
## kind of good and Rarity, worked out by one formula and never varied. A card's Store price
## starts from its Rarity's price, each Hex on it takes 40% off what is left, then half of each
## Mod's Workshop price is added, rounded to the nearest 5 and never below 5. An Armor has no
## Rarity and carries its own price. A Store buys at a third of what it sells for, rounded
## down. The numbers are placeholders (roadmap, milestone 24) and do not change with the Tier.

## From Common to Mythic.
const CARD: Array[int] = [25, 50, 100, 150]
const POTION: Array[int] = [20, 35, 60, 100]
## What the Workshop sells a Mod for (milestone 25); a Mod on a card adds half of it.
const MOD: Array[int] = [40, 75, 125, 160]
## What each Hex takes off a card's price, of what is left.
const HEX_DISCOUNT: float = 0.4
const LOWEST: int = 5
## What a Store pays is its price divided by this, rounded down.
const SALE_DIVISOR: int = 3


## What a Store asks for [param card] as it is. A Power-9 card is never for sale and is priced
## as a Mythic, should anything ask.
static func of_card(card: DeckbuilderCard) -> int:
	var price: float = CARD[mini(card.run_card.base.rarity, CARD.size() - 1)]
	# The Hexes discount the card before any Mod is added, so a Hex never discounts a Mod.
	for mod: Mod in card.mods:
		if mod.is_hex:
			price *= 1.0 - HEX_DISCOUNT
	for mod: Mod in card.mods:
		if not mod.is_hex:
			price += of_mod(mod) / 2.0
	return maxi(LOWEST, roundi(price / LOWEST) * LOWEST)


static func of_potion(potion: MmCardDefinition) -> int:
	return POTION[mini(potion.rarity, POTION.size() - 1)]


static func of_armor(armor: Armor) -> int:
	return armor.price


## What the Workshop asks for [param mod]. Later (milestone 27): a Unique Mod, which is never
## sold, has no price of its own yet and is priced as a Mythic.
static func of_mod(mod: Mod) -> int:
	return MOD[mini(mod.rarity, MOD.size() - 1)]


## What a Store pays for what it would sell for [param price].
static func sale_of(price: int) -> int:
	return price / SALE_DIVISOR


## What a Store pays for [param card] as it is, its Mods going with it.
static func sale_of_card(card: DeckbuilderCard) -> int:
	return sale_of(of_card(card))


## Whether a Store buys [param card]: never a Power-9 card, which has no price, nor a basic
## land, which a Deck counts for free (ADR 0028), with a Mod or without.
static func can_be_sold(card: DeckbuilderCard) -> bool:
	return card.run_card.base.rarity != MmCardDefinition.Rarity.POWER_NINE and not card.is_basic_land()
