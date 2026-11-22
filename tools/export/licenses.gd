class_name ExportLicenses
extends SceneTree
## Developer tool (milestone 20): writes LICENSES.txt, which tools/export/export.sh puts
## beside each playtest build. It holds Godot's license, the notice of every library Godot
## bundles with the license each names, the text of every license Godot names, and the
## fonts' licenses: what the Credits leave to a file shipped with the export (milestone 19).
##
## Run: godot --headless --path . -s res://tools/export/licenses.gd -- <file to write>

## The fonts' licenses, as their makers ship them: Linux Libertine is used under the SIL
## Open Font License (it is also offered under the GPL), TeX Gyre Schola under GUST's.
const FONT_LICENSES: Array[String] = [
	"res://assets/fonts/linux_libertine/OFL.txt",
	"res://assets/fonts/tex_gyre_schola/GUST-FONT-LICENSE.txt",
]
const RULE: String = "========================================================================"


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		printerr("Give the file to write after --.")
		quit(1)
		return
	var file: FileAccess = FileAccess.open(arguments[0], FileAccess.WRITE)
	if file == null:
		printerr("Cannot write %s: %s" % [arguments[0], error_string(FileAccess.get_open_error())])
		quit(1)
		return
	file.store_string(text())
	file.close()
	quit()


## The whole of LICENSES.txt.
static func text() -> String:
	var lines: PackedStringArray = []
	lines.append("ModMox %s" % ProjectSettings.get_setting("application/config/version", ""))
	lines.append("")
	lines.append("ModMox is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.")
	lines.append("")
	_heading(lines, "Godot Engine")
	lines.append("ModMox is made with Godot Engine, available under the following license:")
	lines.append("")
	lines.append(Engine.get_license_text().strip_edges())
	lines.append("")
	_heading(lines, "Libraries bundled with Godot Engine")
	for part: Dictionary in Engine.get_copyright_info():
		lines.append(str(part["name"]))
		for piece: Dictionary in part["parts"]:
			for line: String in piece["copyright"]:
				lines.append("  Copyright: " + line)
			lines.append("  License: " + str(piece["license"]))
		lines.append("")
	_heading(lines, "The licenses those libraries name")
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for name: String in names:
		lines.append("-- " + name + " --")
		lines.append("")
		lines.append(str(licenses[name]).strip_edges())
		lines.append("")
	_heading(lines, "Fonts")
	lines.append("Linux Libertine by Philipp H. Poll, under the SIL Open Font License:")
	lines.append("")
	lines.append(FileAccess.get_file_as_string(FONT_LICENSES[0]).strip_edges())
	lines.append("")
	lines.append("TeX Gyre Schola by the GUST e-foundry, under the GUST Font License:")
	lines.append("")
	lines.append(FileAccess.get_file_as_string(FONT_LICENSES[1]).strip_edges())
	return "\n".join(lines) + "\n"


static func _heading(lines: PackedStringArray, title: String) -> void:
	lines.append(RULE)
	lines.append(title)
	lines.append(RULE)
	lines.append("")
