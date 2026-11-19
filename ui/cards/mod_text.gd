class_name ModText
extends RefCounted
## What a Mod does, in words, for wherever it is shown off a card (ADR 0029): one sentence
## for its Augmentation and one for its Mod Cost. "Modified card gets +1/+1 and gains
## trample. It costs {1} more to cast." Power and toughness come first, with "gets", then
## every ability after one "gains", keywords before quoted abilities, joined as Oracle text
## joins them. A quoted ability calls the card what its own text would (AbilityText).
##
## A Modification there are no words for yet is written as its class name in square
## brackets, as AbilityText writes what it has no words for.

const SUBJECT: String = "Modified card"
## What a quoted ability calls a card that is none of the types AbilityText names.
const ANY_CARD_NOUN: String = "this card"


## The whole text of [param mod]: its Augmentation's sentence, then its Mod Cost's if it has
## one.
static func of(mod: Mod) -> String:
	var text: String = augmentation_of(mod)
	if mod.mod_cost != null:
		text += " " + mod_cost_of(mod.mod_cost)
	return text


## The sentence for what [param mod] does to the card.
static func augmentation_of(mod: Mod) -> String:
	var noun: String = AbilityText.self_noun(mod.card_types, ANY_CARD_NOUN)
	var power: int = 0
	var toughness: int = 0
	var has_power_toughness: bool = false
	var keywords: Array[String] = []
	var quoted: Array[String] = []
	var unknown: Array[String] = []
	for modification: MmModification in mod.augmentation:
		if modification is AddPowerToughnessModification:
			var added: AddPowerToughnessModification = modification as AddPowerToughnessModification
			power += added.power
			toughness += added.toughness
			has_power_toughness = true
		elif modification is AddAbilityModification:
			var ability: MmAbility = (modification as AddAbilityModification).ability
			var words: String = AbilityText.of_ability(ability, noun)
			if AbilityText.is_keyword(ability):
				# Only the keyword's first letter: "cycling {R}", never "cycling {r}".
				keywords.append(words.left(1).to_lower() + words.substr(1))
			else:
				quoted.append("\"%s\"" % words)
		else:
			var script: Script = modification.get_script()
			var class_label: String = script.get_global_name()
			unknown.append("[%s]" % (class_label if class_label != "" else script.resource_path.get_file().get_basename()))
	var clauses: Array[String] = []
	if has_power_toughness:
		clauses.append("gets %s/%s" % [_signed(power), _signed(toughness)])
	if not keywords.is_empty() or not quoted.is_empty():
		var abilities: Array[String] = keywords.duplicate()
		abilities.append_array(quoted)
		clauses.append("gains " + joined(abilities))
	clauses.append_array(unknown)
	var sentence: String = "%s %s" % [SUBJECT, " and ".join(PackedStringArray(clauses))]
	# A quoted ability ends with its own period, inside the quotation marks.
	return sentence if sentence.ends_with("\"") else sentence + "."


## The sentence for what [param mod_cost] adds to the card's mana cost.
static func mod_cost_of(mod_cost: AddManaCostModification) -> String:
	return "It costs %s more to cast." % mod_cost.cost.describe()


## [param parts] joined as Oracle text joins a list: "a", "a and b", "a, b, and c".
static func joined(parts: Array[String]) -> String:
	if parts.size() <= 2:
		return " and ".join(PackedStringArray(parts))
	return ", ".join(PackedStringArray(parts.slice(0, parts.size() - 1))) + ", and " + parts.back()


static func _signed(amount: int) -> String:
	return "+%d" % amount if amount >= 0 else "%d" % amount
