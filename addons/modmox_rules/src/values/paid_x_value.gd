class_name PaidXValue
extends MmValue
## "X" where the spell or ability itself says "you may pay {X}" (CR 107.3, ADR 0061): the X
## its controller paid as it resolved. 0 when none was paid, as before the payment or after
## declining it, and with no context at all, as a static ability's Filter may be asked.


func evaluate(_state: MmGameState, context: MmEffectContext) -> int:
	return 0 if context == null else maxi(0, context.paid_x)
