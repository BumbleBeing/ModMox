class_name MmManaCost
extends Resource
## A mana cost (CR 202): a generic amount plus a list of symbols that each need one mana of
## a particular type. {2}{R}{R} is generic 2 with symbols [RED, RED]; {C} is the symbol
## COLORLESS. Mana value and color are always worked out, never stored.

@export var generic: int = 0
@export var symbols: Array[MmMana.Type] = []


## CR 202.3: the total amount of mana in the cost.
func mana_value() -> int:
	return generic + symbols.size()


## CR 202.2: the colors of the cost's colored symbols, each once, in WUBRG order.
func colors() -> Array[MmCardTypes.CardColor]:
	var result: Array[MmCardTypes.CardColor] = []
	for color: MmCardTypes.CardColor in MmCardTypes.CardColor.values():
		if symbols.has(MmCardTypes.mana_type_of(color)):
			result.append(color)
	return result


func describe() -> String:
	var text: String = "{%d}" % generic if generic > 0 or symbols.is_empty() else ""
	for symbol: MmMana.Type in symbols:
		text += "{%s}" % MmMana.SYMBOLS[symbol]
	return text
