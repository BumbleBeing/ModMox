class_name PayManaDecision
extends MmPendingDecision
## One step of paying a mana cost (CR 601.2g-h). Answer: the index of one of [member actions],
## which spend one unit of pool mana (PayWithManaAction) or activate a mana ability whose
## mana goes straight to the cost (ActivateAbilityAction). Asked again until fully paid.

var actions: Array[MmAction]
## What is still owed, for the GUI.
var remaining_generic: int
var remaining_symbols: Array[MmMana.Type]


func _init(deciding_player_id: int, payment_actions: Array[MmAction], generic: int, symbols: Array[MmMana.Type]) -> void:
	super(deciding_player_id)
	actions = payment_actions.duplicate()
	remaining_generic = generic
	remaining_symbols = symbols.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, actions.size())


func describe() -> String:
	var owed: MmManaCost = MmManaCost.new()
	owed.generic = remaining_generic
	owed.symbols = remaining_symbols
	return "player %d: pay %s (%d options)" % [player_id, owed.describe(), actions.size()]
