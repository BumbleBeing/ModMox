extends SceneTree
## Developer tool: draws the review sheet of a Portrait drawn after a Magic character
## (PortraitSheet), from its reference art in tools/sprites/reference/ and its PNGs in
## ui/sprites/portraits/ (the Portrait, the Pain Portrait, and the Blink Portrait when it
## has one), to tools/sprites/preview/<key>_review.png.
##
## Run: godot --headless --path . -s res://tools/sprites/review_portrait.gd -- --key=keldon_warlord

const PORTRAITS: String = "res://ui/sprites/portraits/"
const PREVIEW: String = "res://tools/sprites/preview/"


func _initialize() -> void:
	var key: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--key="):
			key = argument.trim_prefix("--key=").strip_edges()
	if key == "":
		printerr("Name the Portrait: -- --key=keldon_warlord")
		quit(2)
		return
	var art: Image = _load(ReferenceArt.path_of(key))
	var portrait: Image = _load(PORTRAITS + key + ".png")
	var pain: Image = _load(PORTRAITS + key + "_pain.png")
	if art == null or portrait == null or pain == null:
		quit(1)
		return
	var pictures: Array[Image] = [portrait, pain]
	var blink_path: String = PORTRAITS + key + "_blink.png"
	if FileAccess.file_exists(blink_path):
		var blink: Image = _load(blink_path)
		if blink == null:
			quit(1)
			return
		pictures.append(blink)
	else:
		print("No Blink Portrait yet: the sheet shows two pictures.")
	var sheet: Image = PortraitSheet.compose(art, pictures, Inspector.palette().panel)
	var path: String = ProjectSettings.globalize_path(PREVIEW + key + "_review.png")
	if sheet.save_png(path) != OK:
		printerr("Cannot write %s" % path)
		quit(1)
		return
	print("Sheet: %s" % path)
	quit(0)


## The image at [param path], read from the file itself so the reference art, which is
## never imported, can be read too; null, with the reason printed, if it cannot be.
static func _load(path: String) -> Image:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		printerr("Cannot read %s" % path)
		return null
	return image
