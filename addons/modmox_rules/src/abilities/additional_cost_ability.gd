class_name AdditionalCostAbility
extends StaticAbility
## "As an additional cost to cast this spell, [costs]" (CR 601.2f, 118.8), as Fear of
## Isolation's "return a permanent you control to its owner's hand". It works only as its card
## is cast: the spell is offered only while every one of [member costs] can be paid, and
## CastProcedure adds them to the rest of the cost, a flashback cost's included. Each that
## asks a choice is asked once the mana is paid (CR 601.2g-h, engine ADR 0086), so a land just
## tapped for mana may be returned; the rest are paid with it. A cost paid stays paid whatever
## becomes of the spell. It does nothing on the battlefield.

@export var costs: Array[MmCost] = []
