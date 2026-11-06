class_name IndestructibleAbility
extends StaticAbility
## The keyword indestructible (CR 702.12b): the permanent can't be destroyed, so neither
## lethal damage, deathtouch damage nor a destroy effect puts it into the graveyard. It
## still dies from 0 toughness, which is not destruction (CR 704.5f). This is a rule, not
## a replacement effect, so nothing is proposed and a regeneration shield is not used up.


func describe() -> String:
	return "indestructible"
