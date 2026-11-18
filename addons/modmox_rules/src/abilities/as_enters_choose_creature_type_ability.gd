class_name AsEntersChooseCreatureTypeAbility
extends StaticAbility
## "As [this permanent] enters, choose a creature type." (CR 614.1c, 614.12). It does nothing
## on the battlefield: whatever puts its permanent there asks its controller for a creature
## type first, and the zone change carries the answer, so the permanent has it from the
## moment it arrives (ADR 0052). Its other abilities read the type through
## IsOfChosenTypeFilter.


func describe() -> String:
	return "as enters, choose a creature type"
