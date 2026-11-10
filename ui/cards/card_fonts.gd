class_name CardFonts
extends RefCounted
## The fonts cards are printed in: TeX Gyre Schola, a Century Schoolbook design under the
## GUST Font License (A234), bundled in assets/fonts/.

const FOLDER: String = "res://assets/fonts/tex_gyre_schola/texgyreschola-%s.otf"


## Names, type lines, P/T and chip letters.
static func title() -> Font:
	return load(FOLDER % "bold") as Font


## Rules text and the artist credit.
static func body() -> Font:
	return load(FOLDER % "regular") as Font


## Reminder text.
static func italic() -> Font:
	return load(FOLDER % "italic") as Font
