class_name WindowLook
extends RefCounted
## How a window standing over a screen looks, as the Spoils screen's does (milestone 18):
## Dither Shaded in a warm dark gray, edged near-black and well rounded, with dithered
## slate-gray buttons. The Pause Menu, the encounter's ending banner and the Run Won notice
## are drawn in it.

const FILL: Color = Color("#4b3f3f")
const EDGE: Color = Color("#14171c")
const EDGE_WIDTH: int = 2
const RADIUS: int = 24
## The Spoils screen's title bar gray (#656a75) darkened a fifth, as its Continue is.
const BUTTON: Color = Color("#51555e")
const BUTTON_RADIUS: int = 12


## A window's Dither Shaded plate, [param height] pixels tall.
static func plate(height: int) -> StyleBoxTexture:
	return DitherShading.plate(FILL.lightened(0.06), FILL.darkened(0.3), EDGE, RADIUS, EDGE_WIDTH, 0, height)
