class_name MmCardTypes
extends RefCounted
## The card types and supertypes the rules define (CR 300.1, 205.4a), and the basic land
## types with the mana each one grants (CR 305.6). Subtypes are free text, so modified
## cards can have subtypes nobody planned for.

## Saved card files store these as numbers: never change or reuse a value, only add new ones.
enum CardType { ARTIFACT = 0, CREATURE = 1, ENCHANTMENT = 2, INSTANT = 3, LAND = 4, SORCERY = 5 }
## Saved card files store these as numbers: never change or reuse a value, only add new ones.
enum Supertype { BASIC = 0, LEGENDARY = 1 }
## The five colors (CR 105.1). Colorless is the absence of color, not a color.
## Saved card files store these as numbers: never change or reuse a value, only add new ones.
enum CardColor { WHITE = 0, BLUE = 1, BLACK = 2, RED = 3, GREEN = 4 }

## Each basic land type and the color of mana its intrinsic ability adds.
const BASIC_LAND_TYPES: Dictionary[String, MmMana.Type] = {
	"Plains": MmMana.Type.WHITE,
	"Island": MmMana.Type.BLUE,
	"Swamp": MmMana.Type.BLACK,
	"Mountain": MmMana.Type.RED,
	"Forest": MmMana.Type.GREEN,
}


## The type of mana that pays a colored symbol of [param color].
static func mana_type_of(color: CardColor) -> MmMana.Type:
	match color:
		CardColor.WHITE:
			return MmMana.Type.WHITE
		CardColor.BLUE:
			return MmMana.Type.BLUE
		CardColor.BLACK:
			return MmMana.Type.BLACK
		CardColor.RED:
			return MmMana.Type.RED
	return MmMana.Type.GREEN
