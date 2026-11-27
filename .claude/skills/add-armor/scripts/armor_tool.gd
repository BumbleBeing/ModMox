extends SceneTree
## /add-armor's tool (.claude/skills/add-armor/SKILL.md, game ADR 0106). Saves an Armor to
## content/armor/ from its parts, each Starting Condition new, and shows an Armor's shape and
## words. Its Emblem, when it has one, is composed apart, since it is built from the engine's
## primitives as a card's abilities are, and saved first to content/emblems/<key>.tres.
##
##   save <key> <name> <helm|cuirass|greaves> <price> <condition>...
##       Each condition, in the order the Armor's words give them:
##         life:<n>       n more starting life, negative for less
##         hand:<n>       an opening hand of n fewer cards
##         mulligans:<n>  n extra free mulligans
##         emblem         the Emblem saved in content/emblems/<key>.tres
##       Its icon is ui/sprites/armor/<key>.png. It refuses to replace an Armor already saved
##       unless --replace is given anywhere.
##   show <key>...
##       Each Armor's problems (none when it is well shaped) and its words.
##   worn <key>...
##       The Hero's setup in a debug encounter wearing these Armor, as --armor= makes it:
##       starting life, opening hand, free mulligans and the Emblems' names, beside the setup
##       wearing none. The encounter's picture shows only how many Emblems there are.

const USAGE: String = "Usage: armor_tool.gd -- save <key> <name> <helm|cuirass|greaves> <price> <condition>... [--replace] | show <key>... | worn <key>..."
const ARMOR: String = "res://content/armor/"
const EMBLEMS: String = "res://content/emblems/"
const ICONS: String = "res://ui/sprites/armor/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var is_replacing: bool = arguments.has("--replace")
	var rest: PackedStringArray = []
	for argument: String in arguments:
		if argument != "--replace":
			rest.append(argument)
	var command: String = rest[0] if not rest.is_empty() else ""
	var failed: bool = true
	match command:
		"save":
			failed = not _save(rest.slice(1), is_replacing)
		"show":
			failed = not _show(rest.slice(1))
		"worn":
			failed = not _worn(rest.slice(1))
		_:
			print(USAGE)
	quit(1 if failed else 0)


func _save(parts: PackedStringArray, is_replacing: bool) -> bool:
	if parts.size() < 5:
		print(USAGE)
		return false
	var key: String = parts[0]
	var path: String = ARMOR + key + ".tres"
	if ResourceLoader.exists(path) and not is_replacing:
		print("%s is already in Content. Pass --replace to replace it." % path)
		return false
	var made: Armor = Armor.new()
	made.name = parts[1]
	var slot_word: String = parts[2].to_upper()
	if not Armor.Slot.has(slot_word):
		print("\"%s\" is not an Armor Slot: helm, cuirass or greaves." % parts[2])
		return false
	made.slot = Armor.Slot[slot_word]
	if not parts[3].is_valid_int():
		print("The price \"%s\" is not a whole number of gold." % parts[3])
		return false
	made.price = int(parts[3])
	for written: String in parts.slice(4):
		var condition: StartingCondition = _condition(written, key)
		if condition == null:
			return false
		made.starting_conditions.append(condition)
	var icon: String = ICONS + key + ".png"
	if not ResourceLoader.exists(icon):
		print("There is no Armor Icon at %s. Place and import it first." % icon)
		return false
	made.icon = load(icon) as Texture2D
	DirAccess.make_dir_recursive_absolute(ARMOR)
	if ResourceSaver.save(made, path) != OK:
		print("Could not save %s." % path)
		return false
	print("Saved %s." % path)
	return _show([key])


## The Starting Condition [param written] names, made new, or null after saying why not.
func _condition(written: String, key: String) -> StartingCondition:
	var kind: String = written.get_slice(":", 0)
	var amount: String = written.get_slice(":", 1) if written.contains(":") else ""
	if kind != "emblem" and not amount.is_valid_int():
		print("\"%s\" needs a whole number after its colon, as life:3." % written)
		return null
	match kind:
		"life":
			var life: LifeStartingCondition = LifeStartingCondition.new()
			life.amount = int(amount)
			return life
		"hand":
			var hand: OpeningHandStartingCondition = OpeningHandStartingCondition.new()
			hand.fewer_cards = int(amount)
			return hand
		"mulligans":
			var mulligans: FreeMulliganStartingCondition = FreeMulliganStartingCondition.new()
			mulligans.amount = int(amount)
			return mulligans
		"emblem":
			var emblem_path: String = EMBLEMS + key + ".tres"
			if not ResourceLoader.exists(emblem_path):
				print("There is no Emblem at %s. Compose and save it first." % emblem_path)
				return null
			var emblem: EmblemStartingCondition = EmblemStartingCondition.new()
			emblem.emblem = load(emblem_path) as MmCardDefinition
			return emblem
	print("\"%s\" is not a kind of Starting Condition: life, hand, mulligans or emblem." % written)
	return null


func _show(keys: PackedStringArray) -> bool:
	var all_well: bool = true
	for key: String in keys:
		var path: String = ARMOR + key + ".tres"
		if not ResourceLoader.exists(path):
			print("%s: no such Armor." % path)
			all_well = false
			continue
		var armor: Armor = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Armor
		print("%s (%s, %d gold)" % [armor.name, Armor.slot_name(armor.slot), armor.price])
		var problems: Array[String] = armor.problems()
		print("  problems: %s" % ("none" if problems.is_empty() else "; ".join(problems)))
		all_well = all_well and problems.is_empty()
		for line: String in StartingConditionText.lines_of(armor.starting_conditions):
			print("  %s" % line)
	return all_well


func _worn(keys: PackedStringArray) -> bool:
	var bare: EncounterRequest = EncounterRequest.from_arguments(PackedStringArray(["--seed=7"]))
	var wearing: EncounterRequest = EncounterRequest.from_arguments(
		PackedStringArray(["--seed=7", "--armor=" + ",".join(keys)]))
	var refusal: String = wearing.validate()
	if refusal != "":
		print(refusal)
		return false
	print("  wearing none: %s" % _setup_words(bare.setup().hero))
	print("  wearing %s: %s" % [", ".join(keys), _setup_words(wearing.setup().hero)])
	return true


func _setup_words(setup: MmPlayerSetup) -> String:
	var emblems: Array[String] = []
	for emblem: MmCardDefinition in setup.emblems:
		emblems.append(emblem.name)
	return "life %d, opening hand %d, free mulligans %d, Emblems [%s]" % [
		setup.starting_life, setup.opening_hand_size, setup.free_mulligans, ", ".join(emblems)]
