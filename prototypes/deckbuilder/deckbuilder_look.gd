class_name DeckbuilderLook
extends RefCounted
## How the deckbuilder's own text looks: everything that is not printed on a card is set in
## Linux Libertine (SIL Open Font License, bundled in assets/fonts/). Cards keep their own
## fonts (CardFonts).

const FOLDER: String = "res://assets/fonts/linux_libertine/linlibertine-%s.ttf"

static var _theme: Theme = null


static func regular() -> Font:
	return load(FOLDER % "regular") as Font


static func bold() -> Font:
	return load(FOLDER % "bold") as Font


## The theme a deckbuilder window takes, so that every label, button and box under it is
## set in the deckbuilder's font.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = regular()
		_theme.default_font_size = 18
	return _theme
