class_name HandShow
extends RefCounted
## What the Hand Strip (game glossary) is shown from each snapshot: the cards of the Hero's
## hand, what a click on each would do and how each glows, which are raised to be
## discarded, and which are not to be drawn yet. The Encounter Screen fills it in from the
## snapshot, DecisionClicks and CardPicks, so the Hand Strip sees none of them.

## The Card Identities in the hand, in any order: the Hand Strip keeps the Hand Order.
var cards: Array[int] = []
## What each card is drawn from, by Card Identity.
var looks: Dictionary[int, CardLook] = {}
## The ways each card can be played right now, by Card Identity: ClickOptions. A card
## with none is left out.
var options: Dictionary[int, Array] = {}
## The colors each card glows in, in the hand, by Card Identity. A card with none is left out.
var glows: Dictionary[int, Array] = {}
## The colors each card glows in while it is held where letting go would play it.
var held_glows: Dictionary[int, Array] = {}
## How long a change of Glow eases over, in seconds.
var glow_seconds: float = 0.0
## Cards chosen to be discarded, which rest above the row (A401).
var raised: Array[int] = []
## Cards still flying into the hand, in the order they land. Each joins the row when it is
## no longer listed, and until then is not drawn.
var arriving: Array[int] = []
## Cards the opening-hand overlay is still flying down to the strip. They keep their
## places in the row and are not shown.
var hidden: Array[int] = []
## Whether the snapshot came from an undo or a canceled cast, which puts a card that comes
## back where it was in the Hand Order.
var is_rewind: bool = false
## Whether the cards already drawn ease from where they are to their places, as when a drawn
## card lands and the rest make room for it. Otherwise every card is put at its place at once,
## as after any other redraw.
var is_easing: bool = false
## Where the cursor is, which the hand parts around.
var cursor: Vector2 = Vector2.ZERO
## The Encounter Screen's Regions: the hand's own, the left panels and the Info Panel are
## read.
var regions: Dictionary[String, Rect2] = {}


## Adds the card [param card_id], drawn from [param look], played by [param card_options],
## glowing in [param glow] and, held where letting go would play it, in [param held_glow].
func add(card_id: int, look: CardLook, card_options: Array[ClickOption] = [], glow: Array[Color] = [], held_glow: Array[Color] = []) -> void:
	cards.append(card_id)
	looks[card_id] = look
	if not card_options.is_empty():
		options[card_id] = card_options
	if not glow.is_empty():
		glows[card_id] = glow
	if not held_glow.is_empty():
		held_glows[card_id] = held_glow


## The ways [param card_id] can be played right now.
func options_of(card_id: int) -> Array[ClickOption]:
	var found: Array[ClickOption] = []
	found.assign(options.get(card_id, []))
	return found


## The colors [param card_id] glows in, held where letting go would play it when
## [param is_held_to_play].
func glow_of(card_id: int, is_held_to_play: bool = false) -> Array[Color]:
	var found: Array[Color] = []
	found.assign((held_glows if is_held_to_play else glows).get(card_id, []))
	return found
