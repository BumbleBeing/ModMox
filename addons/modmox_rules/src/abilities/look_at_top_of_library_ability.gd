class_name LookAtTopOfLibraryAbility
extends StaticAbility
## "You may look at the top card of your library any time." While a player controls a
## permanent with it, their own Player View shows their library's top card, and nobody
## else's does (ADR 0054). Looking makes it no Known Card: it is seen only while the
## ability lasts, and a new top card is seen as soon as it is on top.


func describe() -> String:
	return "look at the top card of your library"
