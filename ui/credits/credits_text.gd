class_name CreditsText
extends RefCounted
## The Credits' roll as authored in content/credits/credits.txt (milestone 19), read into
## its lines: a line of the file to a line of the roll, top to bottom. "= " starts the
## title (and the closing "Thanks for playing"), "== " a heading, a blank line is a gap,
## "{godot_license}" stands for Godot's license, a line of it to a line of the roll, and any
## other line is plain; a line starting "# " is a comment.

enum Kind { TITLE, HEADING, GAP, PLAIN, LICENSE }

const PATH: String = "res://content/credits/credits.txt"
const GODOT_LICENSE: String = "{godot_license}"


## One line of the roll.
class Line:
	extends RefCounted

	var kind: Kind
	var text: String

	func _init(line_kind: Kind, line_text: String = "") -> void:
		kind = line_kind
		text = line_text


## The roll's lines from the authored file, with Godot's license as the engine gives it.
static func lines() -> Array[Line]:
	return parse(FileAccess.get_file_as_string(PATH), Engine.get_license_text())


## The roll's lines from [param text], [param license] standing in for "{godot_license}";
## a blank line of the license is a LICENSE line with no text, which the roll draws as a
## smaller gap.
static func parse(text: String, license: String) -> Array[Line]:
	var made: Array[Line] = []
	for line: String in text.split("\n"):
		if line.begins_with("# "):
			continue
		if line.strip_edges() == "":
			made.append(Line.new(Kind.GAP))
		elif line.begins_with("== "):
			made.append(Line.new(Kind.HEADING, line.trim_prefix("== ")))
		elif line.begins_with("= "):
			made.append(Line.new(Kind.TITLE, line.trim_prefix("= ")))
		elif line.strip_edges() == GODOT_LICENSE:
			for license_line: String in license.strip_edges().split("\n"):
				made.append(Line.new(Kind.LICENSE, license_line.strip_edges()))
		else:
			made.append(Line.new(Kind.PLAIN, line))
	# The file's own end of line is no gap.
	while not made.is_empty() and made[-1].kind == Kind.GAP:
		made.pop_back()
	while not made.is_empty() and made[0].kind == Kind.GAP:
		made.pop_front()
	return made
