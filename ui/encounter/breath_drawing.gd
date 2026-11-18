class_name BreathDrawing
extends RefCounted
## Where a breathing Portrait is drawn in its square, which crops it (game glossary,
## Breath): grown round its center a whole screen pixel at a time, so it moves almost
## smoothly while each of its pixels is six screen pixels or seven. The user chose this in
## the breath lab over smooth growth with hard pixels, filtered growth, a whole art pixel at
## a time, and growing from the bottom.


## Where a picture of [param art_size] pixels, drawn to fill [param box] at rest, is drawn
## in the box's own coordinates when it has grown by [param growth] of its pixels.
static func rect(box: Vector2, art_size: Vector2, growth: float) -> Rect2:
	var extra: Vector2 = (box / art_size * growth).round()
	return Rect2((-extra / 2.0).floor(), box + extra)
