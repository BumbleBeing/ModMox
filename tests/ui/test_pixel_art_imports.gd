extends GutTest
## Pixel art imports without mipmaps (the conventions' "Game-side code"): every picture in
## ui/sprites/, at any depth.

const SPRITES: String = "res://ui/sprites/"


func test_every_sprite_imports_without_mipmaps() -> void:
	var imports: Array[String] = _imports_in(SPRITES)

	assert_gt(imports.size(), 0)
	for path: String in imports:
		var config: ConfigFile = ConfigFile.new()
		assert_eq(config.load(path), OK, path)
		assert_false(config.get_value("params", "mipmaps/generate", true), "%s has no mipmaps." % path)


func _imports_in(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".png.import"):
			found.append(folder + file)
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_imports_in(folder + child + "/"))
	return found
