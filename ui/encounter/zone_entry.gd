class_name ZoneEntry
extends PanelContainer
## One thing in a Zone Window: a rectangle with art on its left, a name, and a line under
## it. Everything on the stack is drawn this way, spell or ability, and so is an Emblem.

const ART_SIZE: float = 64.0

var _name: Label
var _detail: Label


## [param art_key] is the art to show, or "" for none.
func _init(art_key: String, entry_name: String, detail: String, tint: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#2c323c")
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var picture: TextureRect = TextureRect.new()
	picture.texture = ArtLibrary.shared().cropped(art_key, Vector2(ART_SIZE, ART_SIZE)) if art_key != "" else null
	picture.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(picture)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lines)
	_name = Label.new()
	_name.text = entry_name
	_name.add_theme_font_override("font", CardFonts.title())
	_name.add_theme_font_size_override("font_size", 20)
	_name.clip_text = true
	lines.add_child(_name)
	_detail = Label.new()
	_detail.text = detail
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 15)
	_detail.modulate = Color(1, 1, 1, 0.75)
	lines.add_child(_detail)


func name_text() -> String:
	return _name.text


func detail_text() -> String:
	return _detail.text
