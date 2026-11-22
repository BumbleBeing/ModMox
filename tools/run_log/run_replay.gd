class_name RunReplay
extends RefCounted
## Replays a Run Log (milestone 21, ADR 0074): the run begun as its log says, then every line
## done again through RunFlow and the Run, each checked against what the log says came of it.
## An encounter is replayed from its answers, the Villain's among them, so the AI never runs.
## A Continue takes the run up from the last snapshot the replay itself took, as the game
## took it up from the last one it saved. The first line that does not hold stops the replay
## and is named, with why.

## The line that did not hold, counting the first as 0, or -1 when every line held.
var line: int = -1
## Why it did not hold, or "".
var reason: String = ""
## The run as the replay left it.
var run: Run = null

var _screen: RunFlow.Screen = RunFlow.Screen.NONE
var _request: EncounterRequest = null
var _answers: Array = []


## The replay of the Run Log whose [param lines] are given, in order.
static func replay(lines: Array[Dictionary]) -> RunReplay:
	var made: RunReplay = RunReplay.new()
	RunFlow.clear()
	RunFlow.use_storage("", "")
	RunFlow.remembers_saves = true
	made._play(lines)
	RunFlow.remembers_saves = false
	if made.run == null:
		made.run = RunFlow.run
	RunFlow.clear()
	return made


func _play(lines: Array[Dictionary]) -> void:
	if lines.size() < 2 or lines[0].get("kind") != "run_log" or lines[1].get("kind") != "run_started":
		_stop(0, "A Run Log begins with its run_log and run_started lines.")
		return
	if int(lines[0].get("format", -1)) != RunLog.FORMAT:
		_stop(0, "The log is of format %s; this build replays format %d." % [lines[0].get("format"), RunLog.FORMAT])
		return
	var begun: Dictionary = lines[1]
	if begun.get("how") != "debug":
		_stop(1, "A run begun as \"%s\" cannot be replayed yet." % begun.get("how"))
		return
	var stage_path: String = str(begun.get("stage", ""))
	var stage: StageDefinition = load(stage_path) as StageDefinition if stage_path != "" else null
	var begun_run: Run = Run.debug(int(lines[0]["run_seed"]), stage, int(begun.get("tier", Run.FIRST_TIER)))
	_screen = RunFlow.start(begun_run)
	for index: int in range(2, lines.size()):
		var refusal: String = _replay_line(lines[index])
		if refusal != "":
			_stop(index, refusal)
			return


## Does again what [param logged] records, and says why it does not hold, or "".
func _replay_line(logged: Dictionary) -> String:
	var playing: Run = RunFlow.run
	match str(logged.get("kind")):
		"node_chosen":
			var moved: String = _go_to(RunFlow.Screen.STAGE_MAP)
			if moved != "":
				return moved
			var options: Array[int] = _ints(logged["options"])
			if options != playing.stage_visit.choices():
				return "The Nodes to choose from were %s, not %s." % [playing.stage_visit.choices(), options]
			var refusal: String = playing.move_to(int(logged["node"]))
			if refusal != "":
				return refusal
			var arrived: RunFlow.Screen = RunFlow.arrive()
			_screen = RunFlow.Screen.STAGE_MAP if arrived == RunFlow.Screen.NONE else arrived
		"deck_saved":
			return _save_deck(playing, logged)
		"deck_duplicated", "deck_deleted", "active_deck":
			var deck: Deck = _deck(playing, logged)
			if deck == null:
				return "There is no Deck %s." % logged.get("deck")
			match str(logged["kind"]):
				"deck_duplicated":
					playing.deckbox.duplicate_deck(deck)
				"deck_deleted":
					playing.deckbox.delete(deck)
				_:
					playing.deckbox.set_active(deck)
		"mod_applied":
			return _apply_mod(playing, logged)
		"encounter_started":
			return _start_encounter(playing, logged)
		"answer":
			_answers.append(_whole(logged["answer"]))
		"encounter_ended":
			return _end_encounter(logged)
		"encounter_quit":
			_request = null
			_answers.clear()
		"quit":
			var where: String = str(logged.get("screen", ""))
			if where != "ENCOUNTER":
				var moved: String = _go_to(RunFlow.Screen.get(where, RunFlow.Screen.NONE) as RunFlow.Screen)
				if moved != "":
					return moved
			RunFlow.quit()
			_screen = RunFlow.Screen.MENU
		"continued":
			_screen = RunFlow.continue_run(RunFlow.last_save())
			if RunFlow.Screen.keys()[_screen] != str(logged.get("screen")):
				return "The run was taken up on %s, not %s." % [RunFlow.Screen.keys()[_screen], logged.get("screen")]
		"run_ended":
			return _end_run(str(logged.get("how")))
		_:
			return "There is no kind of line called \"%s\"." % logged.get("kind")
	return ""


## Moves on through the Screens that lead only one way until the run is on [param wanted],
## as the player did by pressing their one button. Says why not, or "".
func _go_to(wanted: RunFlow.Screen) -> String:
	for step: int in 8:
		if _screen == wanted:
			return ""
		match _screen:
			RunFlow.Screen.SPOILS:
				_screen = RunFlow.finish_spoils()
			RunFlow.Screen.STAGE_INTRO:
				_screen = RunFlow.finish_intro()
			RunFlow.Screen.DECKBOX when RunFlow.villain == null:
				_screen = RunFlow.close_deckbox()
			RunFlow.Screen.STAGE_MAP when wanted == RunFlow.Screen.DECKBOX:
				_screen = RunFlow.open_deckbox()
			_:
				break
	return "The run was on %s, which does not lead to %s." % [
		RunFlow.Screen.keys()[_screen], RunFlow.Screen.keys()[wanted]]


func _save_deck(playing: Run, logged: Dictionary) -> String:
	var index: int = int(logged["deck"])
	var decks: Array[Deck] = playing.deckbox.decks()
	var deck: Deck = Deck.new() if index == -1 or index == decks.size() else _deck(playing, logged)
	if deck == null:
		return "There is no Deck %d." % index
	deck.name = str(logged["name"])
	deck.card_ids = _ints(logged["card_ids"])
	deck.basic_lands.clear()
	var lands: Dictionary = logged["basic_lands"]
	for land: String in lands:
		deck.basic_lands[land] = int(lands[land])
	playing.deckbox.put(deck)
	return ""


func _deck(playing: Run, logged: Dictionary) -> Deck:
	var index: int = int(logged.get("deck", -1))
	var decks: Array[Deck] = playing.deckbox.decks()
	return decks[index] if index >= 0 and index < decks.size() else null


func _apply_mod(playing: Run, logged: Dictionary) -> String:
	var id: int = int(logged["card"])
	var card: DeckbuilderCard = playing.collection.card(id)
	if card == null:
		# A basic land takes its identity with its first Mod (A558).
		var land: MmRunCard = MmRunCard.new()
		land.base = load(str(logged["base"])) as MmCardDefinition
		card = DeckbuilderCard.new(0, land)
	if not playing.held_mods.apply(load(str(logged["mod"])) as Mod, card, playing.collection):
		return "The Mod could not be applied."
	if card.id != id:
		return "The card the Mod went on became %d, not %d." % [card.id, id]
	return ""


func _start_encounter(playing: Run, logged: Dictionary) -> String:
	if not playing.stage_visit.must_play():
		return "There is no encounter to begin here."
	var villain: String = playing.stage_visit.meeting.resource_path
	if villain != str(logged["villain"]):
		return "The Villain met was %s, not %s." % [villain, logged["villain"]]
	RunFlow.begin_encounter()
	_request = EncounterRequest.for_run(playing)
	_answers.clear()
	if _request.encounter_seed != int(logged["encounter_seed"]):
		return "The Encounter Seed was %d, not %s." % [_request.encounter_seed, logged["encounter_seed"]]
	return ""


func _end_encounter(logged: Dictionary) -> String:
	if _request == null:
		return "No encounter had begun."
	var record: Dictionary = EncounterPresenter.record_of(_request.setup(), _answers)
	for answer: Dictionary in record["answers"]:
		if answer.has("refused"):
			return "An answer was refused: %s" % answer["refused"]
	for key: String in ["winner", "turns", "hero_life", "villain_life"]:
		if str(record[key]) != str(_whole(logged.get(key))):
			return "The encounter ended with %s %s, not %s." % [key, record[key], logged.get(key)]
	_request = null
	_screen = RunFlow.finish_encounter(bool(logged["won"]))
	return ""


func _end_run(how: String) -> String:
	match how:
		"abandoned":
			run = RunFlow.run
			RunFlow.abandon()
		"won":
			var moved: String = _go_to(RunFlow.Screen.RUN_WON)
			if moved != "":
				return moved
		"lost":
			if _screen != RunFlow.Screen.RUN_LOST:
				return "The run had not been lost."
	return ""


func _stop(at: int, why: String) -> void:
	line = at
	reason = why
	run = RunFlow.run


static func _ints(values: Array) -> Array[int]:
	var found: Array[int] = []
	for value: Variant in values:
		found.append(int(value))
	return found


## [param value] with every number made whole again: JSON reads each back as a float, and an
## answer is whole numbers and lists of them (ADR 0010).
static func _whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_ARRAY:
		var made: Array = []
		for entry: Variant in value:
			made.append(_whole(entry))
		return made
	return value
