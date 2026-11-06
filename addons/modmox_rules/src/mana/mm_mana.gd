class_name MmMana
extends RefCounted
## One unit of mana in a mana pool (CR 106), remembering what produced it (ADR 0013).

## Saved card files store these as numbers: never change or reuse a value, only add new ones.
enum Type { WHITE = 0, BLUE = 1, BLACK = 2, RED = 3, GREEN = 4, COLORLESS = 5 }

## The letter used for each type in mana symbols, such as the R in {R}.
const SYMBOLS: Dictionary[Type, String] = {
	Type.WHITE: "W", Type.BLUE: "U", Type.BLACK: "B", Type.RED: "R", Type.GREEN: "G", Type.COLORLESS: "C",
}

var type: Type
## The object whose ability produced this mana.
var source_object_id: int


func _init(mana_type: Type, source_id: int) -> void:
	type = mana_type
	source_object_id = source_id


func describe() -> String:
	return "%s from object %d" % [Type.find_key(type), source_object_id]
