extends GutTest


func test_version_is_semantic() -> void:
	var regex: RegEx = RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_not_null(regex.search(MmEngine.VERSION), "VERSION must look like MAJOR.MINOR.PATCH, got '%s'." % MmEngine.VERSION)
