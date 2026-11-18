class_name CardBack
extends RefCounted
## The back of a card, for cards the Hero cannot see: the Villain's hand and both libraries.
## It is edged in the black border a Card Face has at its sides and top, all round.

const IMAGE: String = "res://assets/card_backs/card_back.webp"
## The picture inside the image, leaving out the image's own black margin, which is thicker
## than a Card Face's border and uneven.
const PICTURE: Rect2 = Rect2(0.047, 0.042, 0.906, 0.916)


## A card back [param height] pixels tall, with a card's rounded corners and black border.
static func make(height: float) -> Panel:
	var back_size: Vector2 = Vector2(height * CardGeometry.ASPECT, height)
	var shape: Panel = CardShapes.rounded(back_size, back_size.x * CardGeometry.CORNER, Color.BLACK, true)
	var image: Texture2D = load(IMAGE) as Texture2D
	var box: Rect2 = picture_box(back_size)
	var cropped: AtlasTexture = AtlasTexture.new()
	cropped.atlas = image
	cropped.region = crop(image.get_size(), box.size)
	shape.add_child(CardShapes.image(cropped, box))
	return shape


## Where the picture sits on a back of [param back_size]: inside the border.
static func picture_box(back_size: Vector2) -> Rect2:
	var border: float = back_size.x * CardGeometry.BORDER
	return Rect2(Vector2(border, border), back_size - Vector2(border, border) * 2.0)


## The part of an image of [param image_size] pixels drawn in a box of [param box_size]: its
## picture, trimmed alike at both ends of whichever way it is too long, so it is not stretched.
static func crop(image_size: Vector2, box_size: Vector2) -> Rect2:
	var picture: Rect2 = Rect2(image_size * PICTURE.position, image_size * PICTURE.size)
	var shape: float = box_size.x / box_size.y
	var kept: Vector2 = picture.size
	if picture.size.x / picture.size.y > shape:
		kept.x = picture.size.y * shape
	else:
		kept.y = picture.size.x / shape
	return Rect2(picture.position + (picture.size - kept) / 2.0, kept)
