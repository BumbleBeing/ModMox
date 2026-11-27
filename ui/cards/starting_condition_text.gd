class_name StartingConditionText
extends RefCounted
## The words of a Starting Condition, and so of an Armor (game ADR 0106): one sentence for
## each, written from what it does and never by hand, as ModText writes a Mod's (ADR 0023). An
## Emblem's abilities are quoted in AbilityText's words.


## The sentence [param condition] reads as: "You start each encounter with 3 more life."
static func of(condition: StartingCondition) -> String:
	if condition is LifeStartingCondition:
		var amount: int = (condition as LifeStartingCondition).amount
		return "You start each encounter with %d %s life." % [absi(amount), "more" if amount > 0 else "less"]
	if condition is OpeningHandStartingCondition:
		var fewer: int = (condition as OpeningHandStartingCondition).fewer_cards
		return "Your opening hand has %s fewer %s." % [_number_word(fewer), "card" if fewer == 1 else "cards"]
	if condition is FreeMulliganStartingCondition:
		var amount: int = (condition as FreeMulliganStartingCondition).amount
		if amount == 1:
			return "You start each encounter with an extra free mulligan."
		return "You start each encounter with %s extra free mulligans." % _number_word(amount)
	if condition is EmblemStartingCondition:
		return _emblem_words((condition as EmblemStartingCondition).emblem)
	# A kind with no words yet shows as its class name, as AbilityText's fallback does.
	return "[%s]" % condition.get_script().get_global_name()


## The sentence for each of [param conditions], in order: an Armor's words.
static func lines_of(conditions: Array[StartingCondition]) -> Array[String]:
	var lines: Array[String] = []
	for condition: StartingCondition in conditions:
		lines.append(of(condition))
	return lines


## "You get an emblem with "…"", each of its abilities quoted, joined by "and".
static func _emblem_words(emblem: MmCardDefinition) -> String:
	var quoted: Array[String] = []
	for line: String in AbilityText.lines_of(emblem.abilities, AbilityText.EMBLEM_NOUN):
		quoted.append("\"%s\"" % line)
	return "You get an emblem with %s" % " and ".join(quoted)


static func _number_word(number: int) -> String:
	if number >= 0 and number < AbilityText.NUMBER_WORDS.size():
		return AbilityText.NUMBER_WORDS[number]
	return str(number)
