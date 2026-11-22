extends GutTest
## Milestone 20's T6: LICENSES.txt, written beside each playtest build by
## tools/export/licenses.gd, holds Godot's license, the notice of every library Godot
## bundles with the license each names, and both fonts' licenses.


func test_the_licenses_hold_godots_own() -> void:
	assert_string_contains(ExportLicenses.text(), Engine.get_license_text())


func test_the_licenses_hold_every_bundled_librarys_notice() -> void:
	var text: String = ExportLicenses.text()
	var parts: Array[Dictionary] = Engine.get_copyright_info()
	assert_gt(parts.size(), 10, "Godot bundles many libraries.")

	for part: Dictionary in parts:
		assert_string_contains(text, str(part["name"]))
		for piece: Dictionary in part["parts"]:
			for line: String in piece["copyright"]:
				assert_string_contains(text, line)
			assert_string_contains(text, "License: " + str(piece["license"]))


func test_the_licenses_hold_the_text_of_every_license_godot_names() -> void:
	var text: String = ExportLicenses.text()
	var licenses: Dictionary = Engine.get_license_info()

	for name: String in licenses:
		assert_string_contains(text, str(licenses[name]), name)


func test_the_licenses_hold_both_fonts_licenses() -> void:
	var text: String = ExportLicenses.text()

	assert_eq(ExportLicenses.FONT_LICENSES.size(), 2, "Linux Libertine under the OFL, TeX Gyre Schola under GUST's.")
	for path: String in ExportLicenses.FONT_LICENSES:
		assert_true(FileAccess.file_exists(path), path)
		assert_string_contains(text, FileAccess.get_file_as_string(path).strip_edges(), path)
