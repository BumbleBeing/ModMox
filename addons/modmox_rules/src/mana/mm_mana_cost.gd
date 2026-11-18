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


## This cost made less by [param reduction] (CR 118.7), as a new cost; this one is left as it
## was. Generic mana in the reduction comes off the generic part only (CR 118.7a). Each
## colored or {C} symbol in it takes off one symbol of that type, or one generic mana when
## the cost holds no more of that type (CR 118.7b-d). Nothing goes below zero, and a cost
## reduced to nothing is {0} (CR 118.7). A null reduction takes nothing off.
func reduced_by(reduction: MmManaCost) -> MmManaCost:
	var result: MmManaCost = MmManaCost.new()
	result.generic = generic
	result.symbols = symbols.duplicate()
	if reduction == null:
		return result
	var taken_from_generic: int = reduction.generic
	for symbol: MmMana.Type in reduction.symbols:
		var at: int = result.symbols.find(symbol)
		if at == -1:
			taken_from_generic += 1
		else:
			result.symbols.remove_at(at)
	result.generic = maxi(0, result.generic - taken_from_generic)
	return result


func describe() -> String:
	var text: String = "{%d}" % generic if generic > 0 or symbols.is_empty() else ""
	for symbol: MmMana.Type in symbols:
		text += "{%s}" % MmMana.SYMBOLS[symbol]
	return text
