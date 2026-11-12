class_name FrameCache
extends RefCounted
## Keeps baked Frames on disk between runs. Composing a Frame from its layers takes about a
## fifth of a second and loading a kept one about a hundredth, so a screen that shows every
## kind of card at once opens seconds sooner after the first time.
##
## A kept Frame is filed under its key and a stamp. The stamp names what it was baked from
## (FrameBaker.stamp()), so a Frame baked from older frame images or by older code is never
## used. Each Frame is stored as its raw pixels, compressed, so it comes back exactly as it
## was baked.

## Where Frames are kept unless the environment turns the cache off.
const DEFAULT_FOLDER: String = "user://frame_cache/"
## Set MODMOX_FRAME_CACHE=off to bake every Frame afresh, as tools/test.sh does so that the
## suite always tests the baking itself.
const SWITCH: String = "MODMOX_FRAME_CACHE"
const EXTENSION: String = ".frame"

## The folder Frames are kept in, or "" when nothing is kept. Tests replace it.
static var folder: String = folder_for(OS.get_environment(SWITCH))


## The folder to keep Frames in when the switch is set to [param setting].
static func folder_for(setting: String) -> String:
	return "" if setting == "off" else DEFAULT_FOLDER


## The file the Frame named [param key] is kept in under [param stamp].
static func path_of(key: String, stamp: String) -> String:
	return "%s%s-%s%s" % [folder, _file_name(key), stamp, EXTENSION]


## The kept Frame named [param key], or null if none was kept under [param stamp] or the
## file is not a whole Frame of the bake size.
static func load_image(key: String, stamp: String) -> Image:
	if folder == "" or not FileAccess.file_exists(path_of(key, stamp)):
		return null
	var file: FileAccess = FileAccess.open_compressed(path_of(key, stamp), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var width: int = file.get_32()
	var height: int = file.get_32()
	var data: PackedByteArray = file.get_buffer(file.get_length() - file.get_position())
	file.close()
	if Vector2i(width, height) != CardGeometry.BAKE_SIZE or data.size() != width * height * 4:
		return null
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


## Keeps [param image] as the Frame named [param key] under [param stamp], and clears away
## any copy of that Frame kept under another stamp.
static func save_image(key: String, stamp: String, image: Image) -> void:
	if folder == "":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var kept: String = path_of(key, stamp)
	for other: String in DirAccess.get_files_at(folder):
		if other.begins_with(_file_name(key) + "-") and folder + other != kept:
			DirAccess.remove_absolute(folder + other)
	var file: FileAccess = FileAccess.open_compressed(kept, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return
	file.store_32(image.get_width())
	file.store_32(image.get_height())
	file.store_buffer(image.get_data())
	file.close()


## A Frame's key as a file name: a key such as "card1:w:pt" has colons, which not every
## disk allows.
static func _file_name(key: String) -> String:
	return key.replace(":", "_")
