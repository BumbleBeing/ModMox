extends SceneTree
## Replays a Run Log headless (milestone 21, ADR 0074) and says whether every line held, or
## the first that did not and why: for chasing a playtester's bug. Replay it against the build
## that wrote it, whose tag the log's first line names (demo-<build>).
##
##   godot --headless --path . -s res://tools/run_log/replay.gd -- /path/to/run_log.jsonl


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty() or not FileAccess.file_exists(arguments[0]):
		printerr("Give the Run Log to replay after --.")
		quit(2)
		return
	var lines: Array[Dictionary] = RunLog.read(arguments[0])
	var build: String = str(lines[0].get("build", "")) if not lines.is_empty() else ""
	if build != SavedRun.build():
		print("The log was written by Demo %s; this is Demo %s. Check out demo-%s to replay it exactly." % [
			build, SavedRun.build(), build])
	var replay: RunReplay = RunReplay.replay(lines)
	if replay.line == -1:
		print("Every one of the %d lines held." % lines.size())
		quit(0)
		return
	print("Line %d did not hold: %s" % [replay.line + 1, replay.reason])
	print(JSON.stringify(lines[replay.line]))
	quit(1)
