extends SceneTree
## Writes a Villain in content/villains/ that plays a deck in content/decks/, and puts it in
## a list of a Stage, for /add-enemy-deck (ADR 0024).
##
## Run: godot --headless --path . -s <this script> -- VILLAIN DECK [options]
##   VILLAIN          the Villain's file name without ".tres", such as "ajani"
##   DECK             the deck it plays, such as "ajani" or "ajani_2"
##   --name TEXT      what the Villain is called on the screen (needed for a new Villain)
##   --sprite PATH    its 32 × 32 Portrait; a new Villain defaults to
##                    res://ui/sprites/portraits/VILLAIN.png when that exists
##   --tier N         DECK is its setup at Tier N (1 to 5), written in Tier order; without
##                    it, DECK is its one setup at every Tier
##   --stage FILE     also put it in a list of content/stages/FILE.tres...
##   --rank RANK      ...as lesser, elite or boss. A Villain still missing Tier decks is
##                    invalid, and no Stage can list it.

const VILLAINS: String = "res://content/villains/"
const STAGES: String = "res://content/stages/"
const DECKS: String = "res://content/decks/"
const PORTRAITS: String = "res://ui/sprites/portraits/"
const RANKS: PackedStringArray = ["lesser", "elite", "boss"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	quit(0 if _write(OS.get_cmdline_user_args()) else 1)


func _write(arguments: PackedStringArray) -> bool:
	if arguments.size() < 2:
		printerr("Usage: write_villain.gd -- VILLAIN DECK [--name TEXT] [--sprite PATH] [--tier N] [--stage FILE --rank RANK]")
		return false
	var file: String = arguments[0]
	var deck_path: String = DECKS + arguments[1] + ".tres"
	var options: Dictionary[String, String] = {}
	var index: int = 2
	while index < arguments.size():
		var flag: String = arguments[index]
		if not flag in ["--name", "--sprite", "--tier", "--stage", "--rank"] or index + 1 >= arguments.size():
			printerr("Unknown argument, or one without its value: %s" % flag)
			return false
		options[flag] = arguments[index + 1]
		index += 2
	if not ResourceLoader.exists(deck_path):
		printerr("No deck at %s: write it first." % deck_path)
		return false
	if options.has("--stage") != options.has("--rank") or (options.has("--rank") and not options["--rank"] in RANKS):
		printerr("--stage and --rank go together, and the rank is lesser, elite or boss.")
		return false

	var path: String = VILLAINS + file + ".tres"
	var villain: Villain
	if ResourceLoader.exists(path):
		villain = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Villain
		print("Updating %s" % path)
	else:
		villain = Villain.new()
		var default_sprite: String = PORTRAITS + file + ".png"
		if not options.has("--sprite") and ResourceLoader.exists(default_sprite):
			options["--sprite"] = default_sprite
		if not options.has("--name") or not options.has("--sprite"):
			printerr("A new Villain needs --name, and --sprite unless %s exists." % default_sprite)
			return false
	if options.has("--name"):
		villain.name = options["--name"]
	if options.has("--sprite"):
		var sprite: Texture2D = load(options["--sprite"]) as Texture2D
		if sprite == null or sprite.get_size() != Vector2(32, 32):
			printerr("%s is not a 32 × 32 Portrait." % options["--sprite"])
			return false
		villain.sprite = sprite

	var deck: MmPlayerSetup = load(deck_path) as MmPlayerSetup
	if options.has("--tier"):
		var tier: int = options["--tier"].to_int()
		if tier < 1 or tier > Villain.TIERS:
			printerr("A Tier is from 1 to %d." % Villain.TIERS)
			return false
		if tier > villain.setups.size() + 1:
			printerr("%s has %d Tier decks; write Tier %d first." % [file, villain.setups.size(), villain.setups.size() + 1])
			return false
		if tier == villain.setups.size() + 1:
			villain.setups.append(deck)
		else:
			villain.setups[tier - 1] = deck
	else:
		villain.setups = [deck] as Array[MmPlayerSetup]

	var error: Error = ResourceSaver.save(villain, path)
	if error != OK:
		printerr("Could not save %s: %s" % [path, error_string(error)])
		return false
	print("Wrote %s: \"%s\", %d setup(s)%s" % [path, villain.name, villain.setups.size(),
		"" if villain.validate() == "" else " (not playable yet: %s)" % villain.validate()])
	return _place(path, options)


## Puts the Villain at [param path] in the Stage list the options name, if they name one.
func _place(path: String, options: Dictionary[String, String]) -> bool:
	if not options.has("--stage"):
		return true
	var stage_path: String = STAGES + options["--stage"] + ".tres"
	if not ResourceLoader.exists(stage_path):
		printerr("No Stage at %s." % stage_path)
		return false
	var stage: StageDefinition = load(stage_path) as StageDefinition
	var villain: Villain = load(path) as Villain
	if villain.validate() != "":
		printerr("No Stage can list %s yet: %s" % [villain.name, villain.validate()])
		return false
	for list: Array[Villain] in [stage.lesser_villains, stage.elite_villains, stage.bosses]:
		for listed: Villain in list:
			if listed.resource_path == path:
				print("%s already lists %s." % [stage.name, villain.name])
				return true
	match options["--rank"]:
		"lesser":
			stage.lesser_villains.append(villain)
		"elite":
			stage.elite_villains.append(villain)
		"boss":
			stage.bosses.append(villain)
	var reason: String = stage.validate()
	if reason != "":
		printerr("%s would be invalid, so it was not saved: %s" % [stage.name, reason])
		return false
	var error: Error = ResourceSaver.save(stage, stage_path)
	if error != OK:
		printerr("Could not save %s: %s" % [stage_path, error_string(error)])
		return false
	print("%s now lists %s as a %s Villain." % [stage.name, villain.name, options["--rank"]])
	return true
