class_name StackItem
extends RefCounted
## What the Stack Window says about one spell or ability (A338, A341), worked out from the
## Player View: an ability leads with what it does and a spell with its name, then comes
## who controls it and what it targets. Also what hovering its entry marks on the board.

const NONE: int = 0
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID

var id: int = NONE
var first_line: String = ""
var second_line: String = ""
## Everything about it in full, for the Info Panel while its entry is hovered (A342).
var full_text: String = ""
## The permanents and players it targets, and the spells on the stack it targets.
var target_object_ids: Array[int] = []
var target_player_ids: Array[int] = []
var target_stack_ids: Array[int] = []
## For an ability: the permanent or Emblem it came from, or NONE once that has gone.
var source_object_id: int = NONE


## What to say about [param seen], which [param view] shows on the stack.
static func of(seen: MmObjectView, view: MmPlayerView) -> StackItem:
	var item: StackItem = StackItem.new()
	item.id = seen.id
	if seen.ability != null:
		# The engine calls an ability on the stack "<its source's name> ability".
		var source_name: String = seen.name.trim_suffix(" ability")
		var source: MmObjectView = _find(seen.source_object_id, view.battlefield + view.command)
		var noun: String = source_name
		if source != null:
			item.source_object_id = source.id
			noun = AbilityText.self_noun(source.card_types, source.name)
		item.first_line = AbilityText.effect_of(seen.ability, noun)
		item.full_text = "%s ability — %s" % [_possessive(source_name), item.first_line]
	else:
		item.first_line = seen.name
		var rules: String = AbilityText.of_card(seen.abilities, seen.card_types, seen.supertypes, seen.name)
		item.full_text = seen.name if rules == "" else "%s — %s" % [seen.name, rules.replace("\n", " · ")]
	item.second_line = player_name(seen.controller_id)
	var names: PackedStringArray = []
	for target: MmReference in seen.targets:
		if target == null:
			continue
		if target.is_player():
			item.target_player_ids.append(target.id)
			names.append(player_name(target.id))
			continue
		var on_stack: MmObjectView = _find(target.id, view.stack)
		var permanent: MmObjectView = _find(target.id, view.battlefield)
		if on_stack != null:
			item.target_stack_ids.append(target.id)
			names.append(on_stack.name)
		elif permanent != null:
			item.target_object_ids.append(target.id)
			names.append(permanent.name)
	if not names.is_empty():
		item.second_line += " → " + ", ".join(names)
	return item


static func player_name(player_id: int) -> String:
	return "Hero" if player_id == HERO else "Villain"


static func _find(object_id: int, among: Array[MmObjectView]) -> MmObjectView:
	for seen: MmObjectView in among:
		if seen.id == object_id:
			return seen
	return null


static func _possessive(owner: String) -> String:
	return owner + ("'" if owner.ends_with("s") else "'s")
