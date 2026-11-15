class_name Deck
extends RefCounted
## A named list of Run Cards from the Collection, each at most once and by identity, plus
## how many of each basic land (ADR 0028). Its layout in the deckbuilder is not part of it.

var name: String = ""
var card_ids: Array[int] = []
## Basic land name to how many of it.
var basic_lands: Dictionary[String, int] = {}


func size() -> int:
	var total: int = card_ids.size()
	for count: int in basic_lands.values():
		total += count
	return total
