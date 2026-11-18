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


## What to say about [param seen], which [param view] shows on the stack, calling each
## player what [param names] does; without it they go by their parts.
static func of(seen: MmObjectView, view: MmPlayerView, names: PlayerNames = null) -> StackItem:
	var called: PlayerNames = names if names != null else PlayerNames.new()
	var item: StackItem = StackItem.new()
	item.id = seen.id
	if seen.ability != null:
		# The engine calls an ability on the stack "<its source's name> ability".
		var source_name: String = seen.name.trim_suffix(" ability")
		var source: MmObjectView = _find(seen.source_object_id, view.battlefield + view.command)
		var noun: String = source_name
		if source != null:
			item.source_object_id = source.id
			# An Emblem has no card type to name itself by (ADR 0036).
			noun = CardLook.noun_of(CardLook.Kind.EMBLEM) if _find(seen.source_object_id, view.command) != null \
				else AbilityText.self_noun(source.card_types, source.name)
		elif seen.source_potion_index != MmGameObject.NOT_A_POTION:
			# Its Potion was used up to pay for it, so nothing is left to find.
			noun = CardLook.noun_of(CardLook.Kind.POTION)
		item.first_line = AbilityText.effect_of(seen.ability, noun)
		item.full_text = "%s ability — %s" % [_possessive(source_name), item.first_line]
	else:
		item.first_line = seen.name
		var rules: String = AbilityText.of_card(seen.abilities, seen.card_types, seen.supertypes, seen.name)
		var spell: SpellAbility = spell_of(seen)
		if spell != null and spell.is_modal() and seen.chosen_mode != SpellAbility.NO_MODE:
			# ADR 0046: a modal spell on the stack does only what its chosen mode does.
			rules = AbilityText.mode_text(spell, seen.chosen_mode, seen.name)
		item.full_text = seen.name if rules == "" else "%s — %s" % [seen.name, rules.replace("\n", " · ")]
		if seen.cast_with_flashback:
			# CR 702.34a, game ADR 0049: both players see it, and where it will go.
			item.first_line += " (flashback)"
			item.full_text += " · Cast with flashback: exiled as it leaves the stack."
		if seen.cast_from_library:
			# Game ADR 0055: both players see where it came from.
			item.first_line += " (top of library)"
	item.second_line = called.of(seen.controller_id)
	var target_names: PackedStringArray = []
	for target: MmReference in seen.targets:
		if target == null:
			continue
		if target.is_player():
			item.target_player_ids.append(target.id)
			target_names.append(called.of(target.id))
			continue
		var on_stack: MmObjectView = _find(target.id, view.stack)
		var permanent: MmObjectView = _find(target.id, view.battlefield)
		if on_stack != null:
			item.target_stack_ids.append(target.id)
			target_names.append(on_stack.name)
		elif permanent != null:
			item.target_object_ids.append(target.id)
			target_names.append(permanent.name)
		else:
			# A card in a graveyard: named, with nothing on the board to mark.
			for player_id: int in view.graveyards:
				var card: MmObjectView = _find(target.id, view.graveyards[player_id])
				if card != null:
					target_names.append(card.name)
	if not target_names.is_empty():
		item.second_line += " → " + ", ".join(target_names)
	return item


static func _find(object_id: int, among: Array) -> MmObjectView:
	for seen: MmObjectView in among:
		if seen.id == object_id:
			return seen
	return null


static func _possessive(owner: String) -> String:
	return owner + ("'" if owner.ends_with("s") else "'s")


## The spell ability of [param seen], or null.
static func spell_of(seen: MmObjectView) -> SpellAbility:
	for ability: MmAbility in seen.abilities:
		if ability is SpellAbility:
			return ability as SpellAbility
	return null
