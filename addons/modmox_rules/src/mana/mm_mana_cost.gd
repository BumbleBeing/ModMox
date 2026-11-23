class_name MmManaCost
extends Resource
## A mana cost (CR 202): a generic amount plus a list of symbols that each need one mana of
## a particular type. {2}{R}{R} is generic 2 with symbols [RED, RED]; {C} is the symbol
## COLORLESS. Mana value and color are always worked out, never stored. {X}{W} has
## [member x_count] 1: X is chosen as its spell is cast (CR 107.3, ADR 0076). {4}{B/R} is
## generic 4 with the hybrid symbol (BLACK, RED) in [member hybrid_symbols] (CR 107.4e, ADR 0077).

@export var generic: int = 0
@export var symbols: Array[MmMana.Type] = []
## How many {X} symbols it has (CR 107.3). Each costs the X chosen as its spell is cast.
@export var x_count: int = 0
## Its hybrid symbols, each the two types of mana that may pay it, as (BLACK, RED) is {B/R}
## (CR 107.4e). A pair of numbers, not a Resource, so a cost's copies share nothing (ADR 0077).
@export var hybrid_symbols: Array[Vector2i] = []


## CR 202.3: the total amount of mana in the cost, X counted as 0, as it is everywhere but
## on the stack (CR 202.3e); a spell's characteristics add the X chosen there. A hybrid
## symbol counts one (CR 202.3f).
func mana_value() -> int:
	return generic + symbols.size() + hybrid_symbols.size()


## CR 202.2: the colors of the cost's colored symbols, each once, in WUBRG order. A hybrid
## symbol is both its colors (CR 202.2d).
func colors() -> Array[MmCardTypes.CardColor]:
	var result: Array[MmCardTypes.CardColor] = []
	for color: MmCardTypes.CardColor in MmCardTypes.CardColor.values():
		var type: MmMana.Type = MmCardTypes.mana_type_of(color)
		if symbols.has(type) or hybrid_index_of(type) != -1:
			result.append(color)
	return result


## The index of the first hybrid symbol [param type] can pay, or -1.
func hybrid_index_of(type: MmMana.Type) -> int:
	return hybrid_index_in(hybrid_symbols, type)


## The index of the first symbol in [param hybrids] that [param type] can pay, or -1.
static func hybrid_index_in(hybrids: Array[Vector2i], type: MmMana.Type) -> int:
	for index: int in hybrids.size():
		if hybrids[index].x == type or hybrids[index].y == type:
			return index
	return -1


## This cost made less by [param reduction] (CR 118.7), as a new cost; this one is left as it
## was. Generic mana in the reduction comes off the generic part only (CR 118.7a). Each
## colored or {C} symbol in it takes off one symbol of that type, or one generic mana when
## the cost holds no more of that type (CR 118.7b-d). Where a hybrid symbol of that color is
## left, it takes that instead: its caster announces that half of it (CR 601.2b) before the
## reduction applies (ADR 0077). Nothing goes below zero, and a cost reduced to nothing is
## {0} (CR 118.7). A null reduction takes nothing off.
func reduced_by(reduction: MmManaCost) -> MmManaCost:
	var result: MmManaCost = MmManaCost.new()
	result.generic = generic
	result.symbols = symbols.duplicate()
	result.x_count = x_count
	result.hybrid_symbols = hybrid_symbols.duplicate()
	if reduction == null:
		return result
	var taken_from_generic: int = reduction.generic
	for symbol: MmMana.Type in reduction.symbols:
		var at: int = result.symbols.find(symbol)
		var hybrid_at: int = result.hybrid_index_of(symbol)
		if at != -1:
			result.symbols.remove_at(at)
		elif hybrid_at != -1:
			result.hybrid_symbols.remove_at(hybrid_at)
		else:
			taken_from_generic += 1
	result.generic = maxi(0, result.generic - taken_from_generic)
	return result


## This cost with [param x] paid for each {X} as generic mana, as a cast owes it once X is
## chosen (CR 601.2f).
func with_x(x: int) -> MmManaCost:
	var result: MmManaCost = reduced_by(null)
	result.generic += x * x_count
	result.x_count = 0
	return result


func describe() -> String:
	var text: String = "{X}".repeat(x_count)
	text += "{%d}" % generic if generic > 0 or (symbols.is_empty() and hybrid_symbols.is_empty() and x_count == 0) else ""
	for symbol: MmMana.Type in symbols:
		text += "{%s}" % MmMana.SYMBOLS[symbol]
	for hybrid: Vector2i in hybrid_symbols:
		text += "{%s/%s}" % [MmMana.SYMBOLS[hybrid.x as MmMana.Type], MmMana.SYMBOLS[hybrid.y as MmMana.Type]]
	return text
