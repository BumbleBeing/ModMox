extends GutTest
## Milestone 21: how a Run Log reaches the game's makers (ADR 0074). At a run's end a
## playtest build whose player agreed posts the log, gzipped, to the Discord webhook, as a
## file attached to a message; a developer build, a player who said no, or a build with no
## webhook posts nothing. The request is checked here without being sent.

const FOLDER: String = "user://test_run_log_share/"
const LOG: String = FOLDER + "2026-11-21T19-30-05-2718281828.jsonl"
const SETTINGS: String = FOLDER + "settings.cfg"
const WEBHOOK: String = "https://discord.com/api/webhooks/1/abc"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var run_log: RunLog = RunLog.new(LOG)
	run_log.record("run_log", {"format": RunLog.FORMAT, "build": "0.0.1", "run_seed": 2718281828})
	run_log.record("node_chosen", {"node": 3, "options": [2, 3]})
	run_log.record("run_ended", {"how": "lost"})


func after_each() -> void:
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER + file)
	DirAccess.remove_absolute(FOLDER)


## S9: only a playtest build whose player agreed, with a webhook, sends.
func test_only_a_playtest_build_whose_player_agreed_with_a_webhook_sends() -> void:
	var agreed: GameSettings = GameSettings.new()
	agreed.has_answered_sharing = true
	agreed.is_sharing_run_logs = true
	var refused: GameSettings = GameSettings.new()
	refused.has_answered_sharing = true
	var unasked: GameSettings = GameSettings.new()

	assert_true(RunLogShare.should_send(true, agreed, WEBHOOK))
	assert_false(RunLogShare.should_send(false, agreed, WEBHOOK), "A developer build never posts.")
	assert_false(RunLogShare.should_send(true, refused, WEBHOOK))
	assert_false(RunLogShare.should_send(true, unasked, WEBHOOK))
	assert_false(RunLogShare.should_send(true, agreed, ""), "No webhook, no post.")


## S9: the request is one multipart post to the webhook, with a message naming the build,
## the Run Seed and how the run ended, and the log gzipped as a file of its own name.
func test_the_request_posts_the_log_gzipped_with_a_message() -> void:
	var request: Dictionary = RunLogShare.request_for(LOG, WEBHOOK)

	assert_eq(request["url"], WEBHOOK)
	var headers: PackedStringArray = request["headers"]
	assert_eq(headers.size(), 1)
	assert_string_starts_with(headers[0], "Content-Type: multipart/form-data; boundary=")
	var boundary: String = headers[0].get_slice("boundary=", 1)
	var body: PackedByteArray = request["body"]
	var text: String = body.get_string_from_ascii()
	assert_string_contains(text, "--%s\r\nContent-Disposition: form-data; name=\"payload_json\"" % boundary)
	assert_string_contains(text, "Demo 0.0.1 · Run Seed 2718281828 · lost".to_utf8_buffer().get_string_from_ascii())
	var file_part: String = "Content-Disposition: form-data; name=\"files[0]\"; filename=\"2026-11-21T19-30-05-2718281828.jsonl.gz\"\r\nContent-Type: application/gzip\r\n\r\n"
	var start: int = _find(body, file_part.to_ascii_buffer()) + file_part.length()
	var end: int = _find(body, ("\r\n--%s--\r\n" % boundary).to_ascii_buffer())
	assert_gt(start, file_part.length())
	assert_eq(end, body.size() - ("\r\n--%s--\r\n" % boundary).length(), "The body ends with its closing boundary.")
	var gzipped: PackedByteArray = body.slice(start, end)
	assert_eq([gzipped[0], gzipped[1]], [0x1f, 0x8b], "A gzip file, which any tool opens.")
	assert_eq(gzipped.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP),
		FileAccess.get_file_as_bytes(LOG))


## S9: the webhook is read from its file, without the line's end; with no file there is none.
func test_the_webhook_is_read_from_its_file() -> void:
	var path: String = FOLDER + "webhook.txt"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(WEBHOOK + "\n")
	file.close()

	assert_eq(RunLogShare.webhook(path), WEBHOOK)
	assert_eq(RunLogShare.webhook(FOLDER + "missing.txt"), "")


## S10: the answer to the opt-in is kept in the settings file; before it is given, the player
## has not been asked.
func test_the_answer_to_sharing_is_kept_in_the_settings() -> void:
	var settings: GameSettings = GameSettings.load_from(SETTINGS)
	assert_false(settings.has_answered_sharing)
	assert_false(settings.is_sharing_run_logs)

	settings.has_answered_sharing = true
	settings.is_sharing_run_logs = true
	settings.save_to(SETTINGS)
	var read: GameSettings = GameSettings.load_from(SETTINGS)

	assert_true(read.has_answered_sharing)
	assert_true(read.is_sharing_run_logs)
	read.is_sharing_run_logs = false
	read.save_to(SETTINGS)
	assert_true(GameSettings.load_from(SETTINGS).has_answered_sharing)
	assert_false(GameSettings.load_from(SETTINGS).is_sharing_run_logs)


## S10: Open Run Logs folder opens the game's Run Logs folder, made first if need be.
func test_open_run_logs_folder_opens_the_run_logs_folder() -> void:
	var opened: Array[String] = []

	RunLogShare.open_folder(func(path: String) -> void: opened.append(path))

	assert_eq(opened, [ProjectSettings.globalize_path(RunLog.FOLDER)] as Array[String])
	assert_true(DirAccess.dir_exists_absolute(RunLog.FOLDER))


func _find(haystack: PackedByteArray, needle: PackedByteArray) -> int:
	for index: int in haystack.size() - needle.size() + 1:
		if haystack.slice(index, index + needle.size()) == needle:
			return index
	return -1
