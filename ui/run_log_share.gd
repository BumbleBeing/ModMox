class_name RunLogShare
extends RefCounted
## How a Run Log reaches the game's makers (milestone 21, ADR 0074). When a run ends, a
## playtest build whose player agreed to share posts the log, gzipped, to the Discord
## webhook named in WEBHOOK_FILE, as a file attached to a message naming the build, the Run
## Seed and how the run ended. A developer build never posts, nor one with no webhook. The
## log stays in the Run Logs folder either way.
##
## The webhook's address is kept out of the public repository: WEBHOOK_FILE is gitignored,
## and an export carries it with the other text files (milestone 20).

const WEBHOOK_FILE: String = "res://config/run_log_webhook.txt"
## Marks where each part of the post begins; it never appears in a part.
const BOUNDARY: String = "ModMoxRunLog7f3c9a2e"
## How long a post may take before it is given up, in seconds.
const TIMEOUT: float = 60.0


## The webhook's address in [param path], or "" when there is none.
static func webhook(path: String = WEBHOOK_FILE) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


## Whether a Run Log is posted: in a playtest build ([param is_playtest]), when the player
## has agreed in [param settings], to [param webhook_url] if there is one.
static func should_send(is_playtest: bool, settings: GameSettings, webhook_url: String) -> bool:
	return is_playtest and settings.has_answered_sharing and settings.is_sharing_run_logs and webhook_url != ""


## The post that shares the Run Log at [param log_path] with [param webhook_url]: its
## "url", its "headers" and its "body", one multipart form with the message and the log,
## gzipped, named for the log.
static func request_for(log_path: String, webhook_url: String) -> Dictionary:
	var lines: Array[Dictionary] = RunLog.read(log_path)
	var build: String = str(lines[0].get("build", "")) if not lines.is_empty() else ""
	# JSON reads every number back as a float: a Run Seed is a whole number.
	var run_seed: String = "%d" % int(lines[0].get("run_seed", 0)) if not lines.is_empty() else ""
	var how: String = ""
	for line: Dictionary in lines:
		if line.get("kind") == "run_ended":
			how = str(line.get("how", ""))
	var message: String = JSON.stringify({"content": "Demo %s · Run Seed %s · %s" % [build, run_seed, how]})
	var gzipped: PackedByteArray = FileAccess.get_file_as_bytes(log_path).compress(FileAccess.COMPRESSION_GZIP)
	var body: PackedByteArray = PackedByteArray()
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"payload_json\"\r\n" % BOUNDARY).to_utf8_buffer())
	body.append_array(("Content-Type: application/json\r\n\r\n%s\r\n" % message).to_utf8_buffer())
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"%s.gz\"\r\n" % [
		BOUNDARY, log_path.get_file()]).to_utf8_buffer())
	body.append_array("Content-Type: application/gzip\r\n\r\n".to_utf8_buffer())
	body.append_array(gzipped)
	body.append_array(("\r\n--%s--\r\n" % BOUNDARY).to_utf8_buffer())
	return {
		"url": webhook_url,
		"headers": PackedStringArray(["Content-Type: multipart/form-data; boundary=%s" % BOUNDARY]),
		"body": body,
	}


## Shares the Run Log at [param log_path] if this build and its player share them: what
## RunFlow calls when a run ends. The post is made from the scene tree's root, so it goes on
## while the screens change, and is let go once it is answered.
static func send(log_path: String) -> void:
	var settings: GameSettings = GameSettings.load_from(GameSettings.PATH)
	var webhook_url: String = webhook()
	if not should_send(OS.has_feature(MainMenu.PLAYTEST_FEATURE), settings, webhook_url):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var request: Dictionary = request_for(log_path, webhook_url)
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT
	tree.root.add_child(http)
	http.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free())
	if http.request_raw(request["url"], request["headers"], HTTPClient.METHOD_POST, request["body"]) != OK:
		http.queue_free()


## The Run Logs folder, as the player's system names it.
static func folder() -> String:
	return ProjectSettings.globalize_path(RunLog.FOLDER)


## Opens the Run Logs folder with [param opener], made first if need be: the Pause Menu's
## Open Run Logs folder.
static func open_folder(opener: Callable = OS.shell_open) -> void:
	DirAccess.make_dir_recursive_absolute(RunLog.FOLDER)
	opener.call(folder())
