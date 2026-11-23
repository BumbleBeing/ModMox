class_name PayManaDecision
extends MmPendingDecision
## One step of paying a mana cost (CR 601.2g-h). Answer: the index of one of [member actions],
## which spend one unit of pool mana (PayWithManaAction) or activate a mana ability whose
## mana goes straight to the cost (ActivateAbilityAction). Asked again until fully paid.

var actions: Array[MmAction]
## What is still owed, for the GUI.
var remaining_generic: int
var remaining_symbols: Array[MmMana.Type]
## The hybrid symbols still owed (CR 107.4e, ADR 0077).
var remaining_hybrid_symbols: Array[Vector2i]


func _init(deciding_player_id: int, payment_actions: Array[MmAction], generic: int, symbols: Array[MmMana.Type],
		hybrids: Array[Vector2i] = []) -> void:
	super(deciding_player_id)
	actions = payment_actions.duplicate()
	remaining_generic = generic
	remaining_symbols = symbols.duplicate()
	remaining_hybrid_symbols = hybrids.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, actions.size())


func describe() -> String:
	var owed: MmManaCost = MmManaCost.new()
	owed.generic = remaining_generic
	owed.symbols = remaining_symbols
	owed.hybrid_symbols = remaining_hybrid_symbols
	return "player %d: pay %s (%d options)" % [player_id, owed.describe(), actions.size()]
