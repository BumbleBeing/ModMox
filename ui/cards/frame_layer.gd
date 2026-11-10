class_name FrameLayer
extends RefCounted
## One image in a Frame's stack: drawn at its bounds and kept only where every mask is
## opaque. A layer with no image is the black strip that covers the frame under a crown.

## A path under assets/card_frames/ without its extension, such as "frames/w"; empty for
## the crown's cover strip.
var image: String = ""
## Mask names under assets/card_frames/masks/, multiplied together.
var masks: Array[String] = []
## Where the image is drawn, as a fraction of the card.
var bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)


static func full(layer_image: String, layer_masks: Array[String] = []) -> FrameLayer:
	var layer: FrameLayer = FrameLayer.new()
	layer.image = layer_image
	layer.masks = layer_masks
	return layer


static func placed(layer_image: String, layer_bounds: Rect2, layer_masks: Array[String] = []) -> FrameLayer:
	var layer: FrameLayer = full(layer_image, layer_masks)
	layer.bounds = layer_bounds
	return layer


static func cover() -> FrameLayer:
	return placed("", CardGeometry.CROWN_COVER)


func is_cover() -> bool:
	return image == ""


## "frames/w through rules ∩ right_half", for test messages.
func describe() -> String:
	var text: String = "cover" if is_cover() else image
	if not masks.is_empty():
		text += " through " + " ∩ ".join(PackedStringArray(masks))
	return text
