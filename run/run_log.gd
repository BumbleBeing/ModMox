class_name RunLog
extends RefCounted
## The Run Log (game glossary, ADR 0074): every choice made in a run, written a line at a
## time as the run goes, so a game that stops keeps everything before it. Each line is a
## JSON object whose "kind" says what it records. The first names the log's format, the
## build that wrote it and the Run Seed; with them the log replays the run exactly
## (tools/run_log/replay.gd). It never resumes a run: that is the saved run's job.
##
## The kinds of line, each with what it holds:
## - run_log: format, build, run_seed, time.
## - run_started: how the run began ("debug"), and what it began with.
## - node_chosen: node, the Node walked to, and options, those it could have been.
## - deck_saved: deck, its place in the Deckbox, and its name, card_ids and basic_lands.
## - deck_duplicated and deck_deleted: deck, its place. active_deck: deck, its place.
## - mod_applied: mod, its path; card, the identity of the card it went on; base, that card's
##   Card Definition.
## - encounter_started: villain, encounter_seed, and the Deck played (deck, card_ids,
##   basic_lands).
## - answer: by ("hero" or "villain"), decision, the decision's words, answer, as given, and
##   for a choice from a list options, how many there were, and chosen, the words of the one
##   chosen. A concession is an answer of its own: ["concede", player ID] (ADR 0010).
## - encounter_ended: won, winner, turns, hero_life and villain_life.
## - encounter_quit: the encounter was left for the main menu, to start over on Continue.
## - quit: screen, where the run was left. continued: screen, where it was taken up again.
## - run_ended: how ("won", "lost" or "abandoned").

## Bump it whenever a line changes what it holds.
const FORMAT: int = 1
## Where the game keeps its Run Logs. Tests use another.
const FOLDER: String = "user://run_logs/"
const EXTENSION: String = ".jsonl"

## The file the log is written to, or "" for a log kept in memory alone.
var path: String = ""

var _lines: Array[Dictionary] = []


func _init(file_path: String = "") -> void:
	path = file_path


## A new log for a run with [param run_seed], in a file of its own in [param folder] named
## for the time and the Run Seed, or in memory alone when [param folder] is "". Its first
## line names its format and build.
static func begin(folder: String, run_seed: int) -> RunLog:
	var file_path: String = ""
	if folder != "":
		DirAccess.make_dir_recursive_absolute(folder)
		var base_name: String = file_name(Time.get_datetime_string_from_system(), run_seed)
		file_path = folder.path_join(base_name)
		var number: int = 2
		while FileAccess.file_exists(file_path):
			file_path = folder.path_join(base_name.trim_suffix(EXTENSION) + "-%d%s" % [number, EXTENSION])
			number += 1
	var made: RunLog = RunLog.new(file_path)
	made.record("run_log", {
		"format": FORMAT, "build": SavedRun.build(), "run_seed": run_seed,
		"time": Time.get_datetime_string_from_system(),
	})
	return made


## A log's file name: the time it began and the Run Seed. A time's colons become dashes, which
## every system allows in a name.
static func file_name(time: String, run_seed: int) -> String:
	return "%s-%d%s" % [time.replace(":", "-"), run_seed, EXTENSION]


## Writes a line of [param kind] holding [param fields].
func record(kind: String, fields: Dictionary = {}) -> void:
	var line: Dictionary = {"kind": kind}
	line.merge(fields)
	_lines.append(line)
	if path == "":
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(line, "", false, true))
	file.close()


## The lines written through this log since it was made, in order.
func lines() -> Array[Dictionary]:
	return _lines.duplicate()


## Every line of the log at [param file_path], in order; a line that cannot be read is left
## out.
static func read(file_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not FileAccess.file_exists(file_path):
		return found
	for text: String in FileAccess.get_file_as_string(file_path).split("\n", false):
		var json: JSON = JSON.new()
		if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
			found.append(json.data)
	return found
