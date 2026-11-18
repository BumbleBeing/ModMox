extends Control
## PROTOTYPE (card track, tokens, for Prideful Parent): throwaway. Shows three ways to draw a
## token's Battlefield Face beside the card that made it, with made-up looks and no engine,
## and two ways a token can leave the battlefield. Nothing here is ported as it is; what the
## user signs off on is rebuilt test-first in ui/cards/ and ui/encounter/.
##
## The art is a stand-in: Savannah Lions for Prideful Parent and Charmed Stray for the Cat
## token, since neither has art in content/art/ yet.
##
## Run: godot --path . res://prototypes/tokens/tokens.tscn  (Space: the tokens leave and
## come back)
## For a picture: add -- --shot=/absolute/path.png [--height=170]

enum Style { PLAIN, MARK, FULL_ART }

const STYLE_NAMES: Dictionary[Style, String] = {
	Style.PLAIN: "A. Plain: a token is drawn as any card is; only the Inspector says it is a token",
	Style.MARK: "B. Token Mark: a silver coin at the end of the name bar says it is a token",
	Style.FULL_ART: "C. Full art: the art runs to the edges under a dark name strip, like Magic's token frame",
}
## Each example: name, art key, power, toughness, tapped, +1/+1 counters, damage, is a token.
const EXAMPLES: Array[Array] = [
	["Prideful Parent", "savannah_lions", 2, 2, false, 0, 0, false],
	["Cat", "charmed_stray", 1, 1, false, 0, 0, true],
	["Cat", "charmed_stray", 1, 1, true, 0, 0, true],
	["Cat", "charmed_stray", 2, 2, false, 1, 1, true],
]
const COIN_DARK: Color = Color("#5d6470")
const COIN_LIGHT: Color = Color("#eef1f5")
const RIM: Color = Color("#0b0b10")

var _height: float = 170.0
## The faces that leave on Space: [face, how it leaves, where it stood].
var _leavers: Array[Array] = []
var _graveyard: Vector2 = Vector2.ZERO


func _ready() -> void:
	var shot: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot = argument.trim_prefix("--shot=")
		elif argument.begins_with("--height="):
			_height = float(argument.trim_prefix("--height="))
	_build()
	if shot != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_leave_and_return()


func _build() -> void:
	var board: ColorRect = ColorRect.new()
	board.color = Color("#2a2f3a")
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	add_child(_label("PROTOTYPE: tokens on the battlefield (faces %d px tall). The first face in each row is the card that made them." % int(_height),
		24, Color("#f1dc9a"), Vector2(32, 16)))
	var slot: float = _height * CardGeometry.FIELD_ASPECT
	var row_height: float = slot + 70.0
	var y: float = 64.0
	for style: Style in [Style.PLAIN, Style.MARK, Style.FULL_ART]:
		add_child(_label(STYLE_NAMES[style], 18, Color.WHITE, Vector2(32, y)))
		var x: float = 32.0
		for example: Array in EXAMPLES:
			var face: BattlefieldFace = _face(example, style)
			face.position = Vector2(x + (slot - face.size.x) / 2.0, y + 36.0 + (slot - face.size.y) / 2.0)
			add_child(face)
			x += slot + 28.0
		y += row_height
	_build_leaving(Vector2(32, y))
	_build_inspector(Vector2(1584, 64))


## How a token leaves: two tokens, two ways, shown on Space.
func _build_leaving(at: Vector2) -> void:
	add_child(_label("Leaving (press Space): left, it fades where it stands (CR 111.7: it ceases to exist); right, it flies to the graveyard and fades on the pile.",
		18, Color.WHITE, at))
	var slot: float = _height * CardGeometry.FIELD_ASPECT
	var pile: Panel = CardShapes.rounded(Vector2(_height * 0.72, _height), 8.0, Color("#1b1f27"))
	pile.position = Vector2(at.x + (slot + 28.0) * 4.0, at.y + 36.0)
	add_child(pile)
	pile.add_child(_label("Graveyard", 16, Color("#9aa3af"), Vector2(10, 8)))
	_graveyard = pile.position + pile.size / 2.0
	for index: int in 2:
		var face: BattlefieldFace = _face(EXAMPLES[1], Style.MARK)
		face.position = Vector2(at.x + (slot + 28.0) * index * 1.5, at.y + 36.0)
		face.pivot_offset = face.size / 2.0
		add_child(face)
		_leavers.append([face, index, face.position])


func _leave_and_return() -> void:
	for leaver: Array in _leavers:
		var face: BattlefieldFace = leaver[0]
		var home: Vector2 = leaver[2]
		var tween: Tween = create_tween()
		if leaver[1] == 0:
			tween.tween_property(face, "modulate:a", 0.0, 0.45)
			tween.parallel().tween_property(face, "scale", Vector2(0.85, 0.85), 0.45)
		else:
			tween.tween_property(face, "position", _graveyard - face.size / 2.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(face, "scale", Vector2(0.66, 0.66), 0.4)
			tween.tween_property(face, "modulate:a", 0.0, 0.3)
		tween.tween_interval(0.6)
		tween.tween_callback(func() -> void:
			face.position = home
			face.scale = Vector2.ONE)
		tween.tween_property(face, "modulate:a", 1.0, 0.3)


func _face(example: Array, style: Style) -> BattlefieldFace:
	var look: CardLook = CardLook.of_definition(load("res://content/cards/alpha/savannah_lions.tres") as MmCardDefinition)
	look.name = example[0]
	look.art_key = example[1]
	look.power = example[2]
	look.toughness = example[3]
	look.base_power = 1 if example[7] else 2
	look.base_toughness = 1 if example[7] else 2
	look.is_tapped = example[4]
	if example[5] > 0:
		look.counters[MmCounter.Kind.PLUS_ONE_PLUS_ONE] = example[5]
	look.damage_marked = example[6]
	look.mana_cost = null if example[7] else look.mana_cost
	look.subtypes = ["Cat"] as Array[String]
	look.abilities = [] as Array[MmAbility]
	if not example[7]:
		look.abilities = [VigilanceAbility.new()] as Array[MmAbility]
	var face: BattlefieldFace = BattlefieldFace.new()
	face.setup(look, _height)
	if example[7]:
		if style == Style.MARK:
			_add_coin(face)
		elif style == Style.FULL_ART:
			_make_full_art(face, look)
	return face


## Style B: a silver coin with a dark rim at the right end of the name bar.
func _add_coin(face: BattlefieldFace) -> void:
	var shape: Control = face.card().get_child(0)
	var title: Rect2 = CardGeometry.TITLE
	var face_size: Vector2 = BattlefieldFace.size_for(_height)
	var scale_now: float = _height / FrameBaker.field_border_height()
	var bar_top: float = title.position.y * CardGeometry.BAKE_SIZE.y * scale_now
	var bar_height: float = title.size.y * CardGeometry.BAKE_SIZE.y * scale_now
	var inset: float = title.position.x * CardGeometry.BAKE_SIZE.x * scale_now
	var coin: Coin = Coin.new()
	coin.size = Vector2(bar_height, bar_height) * 1.05
	coin.position = Vector2(face_size.x - inset - coin.size.x, bar_top + (bar_height - coin.size.y) / 2.0)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_child(coin)
	# Under the shade, so a tapped token's coin darkens with it.
	shape.move_child(coin, _shade_index(shape))


## Style C: the art fills the card inside its black rim, the colored border is gone, and
## the name sits white on a dark strip across the top of the art.
func _make_full_art(face: BattlefieldFace, look: CardLook) -> void:
	var shape: Control = face.card().get_child(0)
	var face_size: Vector2 = BattlefieldFace.size_for(_height)
	var rim: float = maxf(2.0, roundf(_height * 0.022))
	var whole: Rect2 = Rect2(Vector2(rim, rim), face_size - Vector2(rim, rim) * 2.0)
	# Children as setup() made them: art, border, name, then the P/T box and the rest.
	var art: Control = shape.get_child(0)
	var border: Control = shape.get_child(1)
	border.visible = false
	art.queue_free()
	var full: TextureRect = CardShapes.image(ArtLibrary.shared().cropped(look.art_key, whole.size), whole)
	shape.add_child(full)
	shape.move_child(full, 0)
	face.name_text().visible = false
	var strip_height: float = roundf(_height * 0.15)
	var strip: ColorRect = ColorRect.new()
	strip.color = Color(0.04, 0.04, 0.06, 0.72)
	strip.position = whole.position
	strip.size = Vector2(whole.size.x, strip_height)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_child(strip)
	shape.move_child(strip, 1)
	var name_label: Label = _label(look.name, int(strip_height * 0.66), Color.WHITE, Vector2.ZERO)
	name_label.add_theme_font_override("font", CardFonts.title())
	name_label.position = whole.position + Vector2(strip_height * 0.35, 0)
	name_label.size = Vector2(whole.size.x, strip_height)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shape.add_child(name_label)
	shape.move_child(name_label, 2)


func _shade_index(shape: Control) -> int:
	for child: Node in shape.get_children():
		if child is ColorRect and (child as ColorRect).color.a > 0.3 and (child as ColorRect).color.r == 0.0:
			return child.get_index()
	return shape.get_child_count()


func _build_inspector(at: Vector2) -> void:
	var panel: Panel = Panel.new()
	panel.position = at
	panel.size = Vector2(320, 470)
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(16, 12)
	column.size = Vector2(288, 440)
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_label("The Inspector on a Cat token (mock),\nthe same in every style.", 16, Color("#9aa3af"), Vector2.ZERO))
	var entries: Array[Array] = [
		["Card Text", "Cat\nToken Creature — Cat\n1/1"],
		["View Original", "Disabled: \"A token has no original.\""],
		["State Information", "Token: Prideful Parent created it. It ceases to exist if it leaves the battlefield."],
	]
	for entry: Array in entries:
		column.add_child(_label(entry[0], 18, Color("#f1dc9a"), Vector2.ZERO))
		var text: Label = _label(entry[1], 15, Color("#c8ced8"), Vector2.ZERO)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(288, 0)
		column.add_child(text)


func _label(text: String, font_size: int, color: Color, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The Token Mark of style B: a shaded silver disc with a dark rim and a small pip.
class Coin:
	extends Control

	func _draw() -> void:
		var middle: Vector2 = size / 2.0
		var radius: float = size.x / 2.0
		draw_circle(middle + Vector2(0, radius * 0.12), radius * 1.04, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(middle, radius, RIM, true, -1.0, true)
		for step: int in DamageChip.SHADES:
			var along: float = DamageChip.shade_along(step)
			draw_circle(DamageChip.shade_center(middle, radius, along), DamageChip.shade_radius(radius, along),
				COIN_DARK.lerp(COIN_LIGHT, along), true, -1.0, true)
		draw_circle(middle, radius * 0.5, COIN_DARK, false, maxf(1.5, radius * 0.16), true)
