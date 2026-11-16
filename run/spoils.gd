class_name Spoils
extends RefCounted
## What a win paid (game glossary; milestone 18, ADR 0039): the gold and the Run Cards
## added to the Collection. Paid the moment the win is counted; the Spoils screen only
## shows it.

var gold: int = 0
var cards: Array[MmRunCard] = []
