class_name FrameBaker
extends RefCounted
## Bakes a FrameSpec's layers into one image on the CPU, once per key (A210). The frame
## images are imported as Images, so baking works headless and tests can check real pixels.

const FOLDER: String = "res://assets/card_frames/"

static var _sources: Dictionary[String, Image] = {}
static var _masks: Dictionary[String, PackedByteArray] = {}
static var _images: Dictionary[String, Image] = {}
static var _textures: Dictionary[String, ImageTexture] = {}
static var _borders: Dictionary[String, Image] = {}
static var _border_textures: Dictionary[String, ImageTexture] = {}
static var _source_textures: Dictionary[String, ImageTexture] = {}


## The baked Frame for [param spec], at CardGeometry.BAKE_SIZE.
static func image(spec: FrameSpec) -> Image:
	var key: String = spec.key()
	if not _images.has(key):
		var size: Vector2i = CardGeometry.BAKE_SIZE
		var canvas: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		for layer: FrameLayer in spec.layers():
			var area: Rect2i = _pixels(layer.bounds, size)
			if layer.is_cover():
				canvas.fill_rect(area, Color.BLACK)
				continue
			canvas.blend_rect(_layer_image(layer, area), Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
		_images[key] = canvas
	return _images[key]


## The baked Frame for [param spec] as a texture, with mipmaps for drawing it small.
static func texture(spec: FrameSpec) -> ImageTexture:
	var key: String = spec.key()
	if not _textures.has(key):
		_textures[key] = _mipmapped(image(spec))
	return _textures[key]


## The Battlefield Face's border for [param spec]: its Frame without the P/T box, from the
## top down to the bottom of the art window, then the strip under the rules box.
static func field_border(spec: FrameSpec) -> Image:
	var bare: FrameSpec = spec.without_power_toughness()
	var key: String = bare.key()
	if not _borders.has(key):
		var frame: Image = image(bare)
		var width: int = CardGeometry.BAKE_SIZE.x
		var top_end: int = roundi(CardGeometry.FIELD_TOP_END * CardGeometry.BAKE_SIZE.y)
		var strip_start: int = roundi(CardGeometry.FIELD_BOTTOM_START * CardGeometry.BAKE_SIZE.y)
		var strip_end: int = roundi(CardGeometry.FIELD_BOTTOM_END * CardGeometry.BAKE_SIZE.y)
		var border: Image = Image.create_empty(width, field_border_height(), false, Image.FORMAT_RGBA8)
		border.blit_rect(frame, Rect2i(0, 0, width, top_end), Vector2i.ZERO)
		border.blit_rect(frame, Rect2i(0, strip_start, width, strip_end - strip_start), Vector2i(0, top_end))
		_borders[key] = border
	return _borders[key]


## The border's height in baked pixels: the frame's top down to the art window's bottom,
## plus the strip under the rules box.
static func field_border_height() -> int:
	var size: int = CardGeometry.BAKE_SIZE.y
	return roundi(CardGeometry.FIELD_TOP_END * size) + roundi(CardGeometry.FIELD_BOTTOM_END * size) \
			- roundi(CardGeometry.FIELD_BOTTOM_START * size)


## A frame image resized to [param size], as a texture, cached.
static func source_texture(path: String, size: Vector2i) -> ImageTexture:
	var key: String = "%s@%dx%d" % [path, size.x, size.y]
	if not _source_textures.has(key):
		_source_textures[key] = _mipmapped(source(path, size))
	return _source_textures[key]


static func field_border_texture(spec: FrameSpec) -> ImageTexture:
	var key: String = spec.without_power_toughness().key()
	if not _border_textures.has(key):
		_border_textures[key] = _mipmapped(field_border(spec))
	return _border_textures[key]


## A frame image (such as "frames/w" or "pt/r") resized to [param size], cached.
static func source(path: String, size: Vector2i) -> Image:
	var key: String = "%s@%dx%d" % [path, size.x, size.y]
	if not _sources.has(key):
		var loaded: Image = load(FOLDER + path + ".png") as Image
		assert(loaded != null, "Missing frame image %s." % path)
		# Never change a loaded Resource: resize a copy.
		var copy: Image = loaded.duplicate() as Image
		copy.convert(Image.FORMAT_RGBA8)
		copy.resize(size.x, size.y, Image.INTERPOLATE_CUBIC)
		_sources[key] = copy
	return _sources[key]


## [param layer]'s image placed in [param area] of a full-size canvas, with its alpha
## multiplied by every mask's.
static func _layer_image(layer: FrameLayer, area: Rect2i) -> Image:
	var size: Vector2i = CardGeometry.BAKE_SIZE
	var placed: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	placed.blit_rect(source(layer.image, area.size), Rect2i(Vector2i.ZERO, area.size), area.position)
	if layer.masks.is_empty():
		return placed
	var data: PackedByteArray = placed.get_data()
	var mask: PackedByteArray = _mask(layer.masks)
	var index: int = 3
	while index < data.size():
		data[index] = data[index] * mask[index] / 255
		index += 4
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)


## The masks' alpha multiplied together, at the bake size. Masks always cover the whole
## card, even when the image they clip is placed at bounds (a crown).
static func _mask(names: Array[String]) -> PackedByteArray:
	var key: String = "+".join(PackedStringArray(names))
	if not _masks.has(key):
		var data: PackedByteArray = source("masks/" + names[0], CardGeometry.BAKE_SIZE).get_data()
		for other_name: String in names.slice(1):
			var other: PackedByteArray = source("masks/" + other_name, CardGeometry.BAKE_SIZE).get_data()
			var index: int = 3
			while index < data.size():
				data[index] = data[index] * other[index] / 255
				index += 4
		_masks[key] = data
	return _masks[key]


static func _pixels(fraction: Rect2, size: Vector2i) -> Rect2i:
	return Rect2i(roundi(fraction.position.x * size.x), roundi(fraction.position.y * size.y),
			roundi(fraction.size.x * size.x), roundi(fraction.size.y * size.y))


static func _mipmapped(source_image: Image) -> ImageTexture:
	var copy: Image = source_image.duplicate() as Image
	copy.generate_mipmaps()
	return ImageTexture.create_from_image(copy)
