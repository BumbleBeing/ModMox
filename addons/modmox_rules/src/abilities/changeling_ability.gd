class_name ChangelingAbility
extends StaticAbility
## The keyword changeling (CR 702.73a): "This object is every creature type." A
## characteristic-defining ability (CR 604.3), so it works in every zone, applied in layer 4
## before the layer's continuous effects (CR 613.3). Its object keeps its printed subtypes and
## has every creature type besides, which MmCharacteristics.has_subtype() answers, rather than
## a list of all of them (ADR 0075). It applied before layer 6, so an object that then loses
## all its abilities is still every creature type.


func describe() -> String:
	return "changeling"
