class_name ButtonShading
extends RefCounted
## How the buttons of the opening-hand overlay are drawn: a color lit from above, lighter
## at the top and darker at the bottom, with rounded corners, a lighter rim and a soft
## shadow underneath. A button is lighter under the cursor and darker held down, and never
## changes size.
##
## The shading is painted once for each color and height and kept. Only a narrow strip is
## painted: the light changes from top to bottom alone, so the middle of the strip stretches
## to any width.

const RADIUS: float = 9.0
const RIM: float = 1.5
## The room around the button the shadow is painted in, and how far down the shadow falls.
const PAD: int = 6
const SHADOW_DROP: float = 3.0
const SHADOW_ALPHA: float = 0.5
const TOP_LIGHTER: float = 0.22
const BOTTOM_DARKER: float = 0.38
const RIM_LIGHTER: float = 0.45
const HOVER_LIGHTER: float = 0.15
const PRESSED_DARKER: float = 0.2
## A button that cannot be pressed.
const DISABLED: Color = Color("#3d424b")
const DISABLED_TEXT: Color = Color(1, 1, 1, 0.4)

static var _boxes: Dictionary[String, StyleBoxTexture] = {}


## Shades [param button] in [param color].
static func apply(button: Button, color: Color) -> void:
	var height: int = roundi(button.size.y)
	button.add_theme_stylebox_override("normal", box(color, height))
	button.add_theme_stylebox_override("hover", box(hover_color(color), height))
	button.add_theme_stylebox_override("pressed", box(pressed_color(color), height))
	button.add_theme_stylebox_override("hover_pressed", box(pressed_color(color), height))
	button.add_theme_stylebox_override("disabled", box(DISABLED, height))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)


static func hover_color(color: Color) -> Color:
	return color.lightened(HOVER_LIGHTER)


static func pressed_color(color: Color) -> Color:
	return color.darkened(PRESSED_DARKER)


## The box a button [param height] pixels tall is drawn with in [param color]. It draws
## PAD pixels beyond the button on every side, for the shadow.
static func box(color: Color, height: int) -> StyleBoxTexture:
	var key: String = "%s/%d" % [color.to_html(), height]
	if _boxes.has(key):
		return _boxes[key]
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image(color, height))
	var side: float = PAD + ceilf(RADIUS)
	made.texture_margin_left = side
	made.texture_margin_right = side
	for margin: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		made.set_expand_margin(margin, PAD)
		made.set_content_margin(margin, 8.0)
	_boxes[key] = made
	return made


## The strip a box is drawn from: the button's two ends and a middle to stretch, with PAD
## pixels of room all around.
static func image(color: Color, height: int) -> Image:
	var body: Rect2 = Rect2(PAD, PAD, ceilf(RADIUS) * 2.0 + 2.0, height)
	var strip: Image = Image.create_empty(int(body.size.x) + PAD * 2, height + PAD * 2, false, Image.FORMAT_RGBA8)
	var rim: Color = color.lightened(RIM_LIGHTER)
	for y: int in strip.get_height():
		var down: float = clampf((y + 0.5 - body.position.y) / body.size.y, 0.0, 1.0)
		var lit: Color = shade(color, down)
		for x: int in strip.get_width():
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			var outside: float = _distance(point, body)
			var cover: float = clampf(0.5 - outside, 0.0, 1.0)
			var paint: Color = lit.lerp(rim, clampf(outside + RIM + 0.5, 0.0, 1.0))
			var fall: float = maxf(_distance(point - Vector2(0, SHADOW_DROP), body), 0.0)
			var shadow: float = SHADOW_ALPHA * pow(clampf(1.0 - fall / (PAD - SHADOW_DROP), 0.0, 1.0), 2.0)
			var alpha: float = cover + shadow * (1.0 - cover)
			if alpha <= 0.0:
				continue
			var mixed: Color = Color.BLACK.lerp(paint, cover / alpha)
			strip.set_pixel(x, y, Color(mixed.r, mixed.g, mixed.b, alpha))
	return strip


## [param color] as lit [param down] of the way from the top of a button (0) to its
## bottom (1).
static func shade(color: Color, down: float) -> Color:
	var top: Color = color.lightened(TOP_LIGHTER)
	var bottom: Color = color.darkened(BOTTOM_DARKER)
	return top.lerp(color, down * 2.0) if down < 0.5 else color.lerp(bottom, down * 2.0 - 1.0)


## How far [param point] is outside [param body] with its corners rounded; negative inside.
static func _distance(point: Vector2, body: Rect2) -> float:
	var from_corner: Vector2 = (point - body.get_center()).abs() - body.size / 2.0 + Vector2(RADIUS, RADIUS)
	return Vector2(maxf(from_corner.x, 0.0), maxf(from_corner.y, 0.0)).length() + minf(maxf(from_corner.x, from_corner.y), 0.0) - RADIUS
