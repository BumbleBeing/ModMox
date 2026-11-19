class_name InstantSpeedEquipAbility
extends StaticAbility
## "You may activate equip abilities any time you could cast an instant", as on Leonin
## Shikari: a permission for the controller of its permanent or Emblem to activate any
## EquipAbility whenever they have priority, lifting its "activate only as a sorcery"
## (CR 702.6a, ADR 0036). It changes no ability: equip keeps its restriction, and the
## permission is asked beside it as the ability is offered. Any other ability's "only as a
## sorcery" stays.
## Later: a permission for other kinds of abilities, such as loyalty abilities, when a card
## has one.


func describe() -> String:
	return "activate equip abilities any time you could cast an instant"
