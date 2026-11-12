extends GutTest
## Baked Frames are kept on disk between runs, so a Frame is composed once per player and
## not once per session. A kept Frame is used only if it was baked from the same frame
## images by the same code.

const FOLDER: String = "user://test_frame_cache/"

var _folder_before: String


func before_each() -> void:
	_folder_before = FrameCache.folder
	FrameCache.folder = FOLDER
	_empty_folder()
	FrameBaker.forget_baked()


func after_each() -> void:
	_empty_folder()
	DirAccess.remove_absolute(FOLDER)
	FrameCache.folder = _folder_before
	FrameBaker.forget_baked()


func test_the_cache_is_off_when_the_environment_says_so() -> void:
	assert_eq(FrameCache.folder_for("off"), "")
	assert_eq(FrameCache.folder_for(""), FrameCache.DEFAULT_FOLDER)
	assert_eq(_folder_before, "", "tools/test.sh turns it off, so the suite always bakes from the frame images.")


func test_baking_a_frame_keeps_it_on_disk() -> void:
	var spec: FrameSpec = _spec(["r"])

	FrameBaker.image(spec)

	assert_true(FileAccess.file_exists(FrameCache.path_of(spec.key(), FrameBaker.stamp())))


func test_a_kept_frame_is_loaded_in_place_of_baking() -> void:
	var spec: FrameSpec = _spec(["r"])
	var baked: Image = FrameBaker.image(spec)
	var marked: Image = baked.duplicate() as Image
	marked.set_pixel(3, 3, Color(0.0, 1.0, 1.0, 1.0))
	FrameCache.save_image(spec.key(), FrameBaker.stamp(), marked)
	FrameBaker.forget_baked()

	var again: Image = FrameBaker.image(spec)

	assert_true(again.get_pixel(3, 3).is_equal_approx(Color(0.0, 1.0, 1.0, 1.0)), "It came from the disk.")
	assert_eq(again.get_size(), CardGeometry.BAKE_SIZE)


func test_a_kept_frame_is_the_baked_frame_pixel_for_pixel() -> void:
	var spec: FrameSpec = _spec(["w", "u"], true)
	var baked: PackedByteArray = FrameBaker.image(spec).get_data()
	FrameBaker.forget_baked()

	var loaded: Image = FrameCache.load_image(spec.key(), FrameBaker.stamp())

	assert_not_null(loaded)
	assert_eq(loaded.get_format(), Image.FORMAT_RGBA8)
	assert_true(loaded.get_data() == baked)


func test_a_frame_kept_under_another_stamp_is_not_used_and_is_cleared_away() -> void:
	var spec: FrameSpec = _spec(["g"])
	var stale: Image = Image.create_empty(CardGeometry.BAKE_SIZE.x, CardGeometry.BAKE_SIZE.y, false, Image.FORMAT_RGBA8)
	stale.fill(Color.MAGENTA)
	FrameCache.save_image(spec.key(), "oldstamp", stale)

	var baked: Image = FrameBaker.image(spec)

	assert_false(baked.get_pixel(3, 3).is_equal_approx(Color.MAGENTA))
	assert_false(FileAccess.file_exists(FrameCache.path_of(spec.key(), "oldstamp")), "Only the newest is kept.")
	assert_true(FileAccess.file_exists(FrameCache.path_of(spec.key(), FrameBaker.stamp())))


func test_keeping_one_frame_leaves_the_others_alone() -> void:
	var red: FrameSpec = _spec(["r"])
	var red_creature: FrameSpec = _spec(["r"], true)
	FrameBaker.image(red)

	FrameBaker.image(red_creature)

	assert_true(FileAccess.file_exists(FrameCache.path_of(red.key(), FrameBaker.stamp())))
	assert_true(FileAccess.file_exists(FrameCache.path_of(red_creature.key(), FrameBaker.stamp())))


func test_a_damaged_file_is_ignored_and_the_frame_is_baked_again() -> void:
	var spec: FrameSpec = _spec(["b"])
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file: FileAccess = FileAccess.open(FrameCache.path_of(spec.key(), FrameBaker.stamp()), FileAccess.WRITE)
	file.store_string("not a frame")
	file.close()

	assert_null(FrameCache.load_image(spec.key(), FrameBaker.stamp()))
	var baked: Image = FrameBaker.image(spec)

	assert_eq(baked.get_size(), CardGeometry.BAKE_SIZE)
	assert_not_null(FrameCache.load_image(spec.key(), FrameBaker.stamp()), "The good one replaced it.")


func test_a_kept_image_of_the_wrong_size_is_not_used() -> void:
	var small: Image = Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	FrameCache.save_image("card1:r", FrameBaker.stamp(), small)

	assert_null(FrameCache.load_image("card1:r", FrameBaker.stamp()))


func test_with_the_cache_off_nothing_is_written_or_read() -> void:
	FrameCache.folder = ""
	var spec: FrameSpec = _spec(["r"])

	var baked: Image = FrameBaker.image(spec)

	assert_eq(baked.get_size(), CardGeometry.BAKE_SIZE)
	assert_null(FrameCache.load_image(spec.key(), FrameBaker.stamp()))
	assert_false(DirAccess.dir_exists_absolute(FOLDER) and not DirAccess.get_files_at(FOLDER).is_empty())


func test_the_stamp_is_the_same_every_time_it_is_asked_for() -> void:
	assert_eq(FrameBaker.stamp(), FrameBaker.stamp())
	assert_gt(FrameBaker.stamp().length(), 8)


func _spec(letters: Array[String], is_creature: bool = false) -> FrameSpec:
	var spec: FrameSpec = FrameSpec.new()
	spec.letters = letters
	spec.is_creature = is_creature
	return spec


func _empty_folder() -> void:
	if not DirAccess.dir_exists_absolute(FOLDER):
		return
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER + file)
