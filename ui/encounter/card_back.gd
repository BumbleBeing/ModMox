class_name CardBack
extends RefCounted
## The back of a card, for cards the Hero cannot see: the Villain's hand and both libraries.

const IMAGE: String = "res://assets/card_backs/card_back.webp"
## The card inside the image, which has a black margin around it.
const CROP: Rect2 = Rect2(0.047, 0.042, 0.906, 0.916)


## A card back [param height] pixels tall, with a card's rounded corners.
static func make(height: float) -> Panel:
	var back_size: Vector2 = Vector2(height * CardGeometry.ASPECT, height)
	var shape: Panel = CardShapes.rounded(back_size, back_size.x * CardGeometry.CORNER, Color.BLACK, true)
	var image: Texture2D = load(IMAGE) as Texture2D
	var crop: AtlasTexture = AtlasTexture.new()
	crop.atlas = image
	crop.region = Rect2(image.get_size() * CROP.position, image.get_size() * CROP.size)
	shape.add_child(CardShapes.image(crop, Rect2(Vector2.ZERO, back_size)))
	return shape
