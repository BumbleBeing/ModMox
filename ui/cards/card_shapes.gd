class_name CardShapes
extends RefCounted
## Small drawing pieces the faces share: rounded panels, outlines and keyword chips.


## A rounded panel of [param color]. When [param clips], its children are cut to its shape.
static func rounded(size: Vector2, radius: float, color: Color, clips: bool = false) -> Panel:
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(radius))
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if clips:
		panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	return panel


static func outline(size: Vector2, radius: float, width: float, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(maxi(1, roundi(width)))
	style.set_corner_radius_all(roundi(radius))
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


static func image(texture: Texture2D, box: Rect2) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.position = box.position
	rect.size = box.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A Keyword Chip of [param size] pixels at [param at]: its Keyword Icon, or its letters.
static func chip(keyword: KeywordChip, at: Vector2, size: float) -> Panel:
	var panel: Panel = rounded(Vector2(size, size), size * 0.25, Color(0.08, 0.08, 0.1, 0.88))
	panel.position = at
	panel.add_child(outline(panel.size, size * 0.25, size / 16.0, Color(1, 1, 1, 0.55)))
	var icon: Texture2D = KeywordChips.icon_texture(keyword)
	if icon != null:
		# Pixel art: a chip is a whole multiple of 16 px, so nearest keeps every pixel square.
		var picture: TextureRect = image(icon, Rect2(Vector2.ZERO, panel.size))
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(picture)
	else:
		var letters: AnchoredText = AnchoredText.new()
		letters.setup(Rect2(size * 0.08, 0.0, size * 0.84, size), [keyword.letters] as Array[String],
				[Color.WHITE] as Array[Color], CardFonts.title(), 0.62 if keyword.letters.length() == 1 else 0.48,
				HORIZONTAL_ALIGNMENT_CENTER, AnchoredText.Fit.SHRINK)
		panel.add_child(letters)
	if keyword.has_protection_color:
		var dot: Panel = rounded(Vector2(size, size) * 0.38, size, color_of(keyword.protection_color))
		dot.position = Vector2(size, size) * 0.62
		panel.add_child(dot)
	return panel


## The color a protection chip's dot is drawn in.
static func color_of(color: MmCardTypes.CardColor) -> Color:
	match color:
		MmCardTypes.CardColor.WHITE:
			return Color("#f8f3d8")
		MmCardTypes.CardColor.BLUE:
			return Color("#3d7fd1")
		MmCardTypes.CardColor.BLACK:
			return Color("#2b2b2b")
		MmCardTypes.CardColor.RED:
			return Color("#d8432f")
	return Color("#3c9a4c")
