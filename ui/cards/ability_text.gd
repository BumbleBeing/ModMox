class_name AbilityText
extends RefCounted
## Rules text generated from abilities (A333), in current Oracle wording (A343): a
## permanent calls itself "this creature" or "this artifact", and anything else goes by its
## name. A card prints whole abilities; a stack entry shows only what an ability does,
## since its cost is paid and its trigger has happened.
##
## Something there are no words for yet is written as its class name in square brackets,
## which a test over every authored card catches.

const NUMBER_WORDS: Array[String] = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
const ORDINAL_WORDS: Array[String] = ["zeroth", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth",
	"ninth", "tenth"]
## The ending of an ordinal past "tenth", by its last digit: "21st", "22nd", "23rd", "24th".
const ORDINAL_SUFFIXES: Array[String] = ["th", "st", "nd", "rd"]
const STEP_NAMES: Dictionary[MmTurn.Step, String] = {
	MmTurn.Step.UNTAP: "untap step", MmTurn.Step.UPKEEP: "upkeep", MmTurn.Step.DRAW: "draw step",
	MmTurn.Step.PRECOMBAT_MAIN: "precombat main phase", MmTurn.Step.BEGINNING_OF_COMBAT: "beginning of combat step",
	MmTurn.Step.DECLARE_ATTACKERS: "declare attackers step", MmTurn.Step.DECLARE_BLOCKERS: "declare blockers step",
	MmTurn.Step.COMBAT_DAMAGE: "combat damage step", MmTurn.Step.END_OF_COMBAT: "end of combat step",
	MmTurn.Step.POSTCOMBAT_MAIN: "postcombat main phase", MmTurn.Step.END: "end step", MmTurn.Step.CLEANUP: "cleanup step",
}
const ZONE_NAMES: Dictionary[MmZone.Kind, String] = {
	MmZone.Kind.LIBRARY: "a library", MmZone.Kind.HAND: "a hand", MmZone.Kind.GRAVEYARD: "a graveyard",
	MmZone.Kind.BATTLEFIELD: "the battlefield", MmZone.Kind.STACK: "the stack", MmZone.Kind.EXILE: "exile",
	MmZone.Kind.COMMAND: "the command zone",
}
## What an Emblem and a Potion call themselves in their own text (ADR 0036). Neither is a
## card type, so self_noun() cannot tell: whoever knows which it is passes the noun.
const EMBLEM_NOUN: String = "this emblem"
const POTION_NOUN: String = "this potion"
## What an OwnedByFilter says after its noun, which a graveyard's phrase turns into whose
## graveyard it is.
const YOU_OWN: String = "you own"
const OPPONENT_OWNS: String = "an opponent owns"
## What a Filter leaving out the source says before its noun: "each other creature".
const OTHER: String = "other"
## What an IsTokenFilter names: the noun after any card type, "artifact token" (CR 111.1).
const TOKEN_NOUN: String = "token"
## Between the kinds of a noun of either kind, "artifact or creature"; counted several, it is
## "artifacts and/or creatures" (EITHER_PLURAL), since a mix of the two may be chosen.
const EITHER: String = " or "
const EITHER_PLURAL: String = " and/or "
## What a ControlsMoreFilter says after "players", made singular for "a player".
const WHO_CONTROL: String = "who control"
const WHO_DONT_CONTROL: String = "who don't control"
## Nouns whose plural is the noun itself: "the number of Equipment you control", "the
## number of Plains you control".
const PLURAL_AS_SINGULAR: Array[String] = ["Equipment", "Plains"]
## What a triggered ability limited to once each turn says after what it does (engine ADR
## 0054's addendum).
const ONCE_EACH_TURN: String = "This ability triggers only once each turn."
## What a ModifiedFilter names (CR 700.9), and what one negated names.
const MODIFIED: String = "modified"
const UNMODIFIED: String = "unmodified"
## The predefined tokens the game has (CR 111.10), by subtype, which is a token's name less
## "Token" (CR 111.4). One is created by that word alone, "create a Treasure token", since
## the rules give its characteristics, and calls itself "this token", as CR 111.10a words a
## Treasure's ability. Treasure, Clue, Map, Blood and Food so far (ADR 0001).
const PREDEFINED_TOKENS: Array[String] = ["Treasure", "Clue", "Map", "Blood", "Food"]

## What the ability's source calls itself.
var _noun: String
## What an Aura's "enchanted" names, from its enchant ability: "enchanted land", or "".
var _enchanted: String = ""
var _targets: Array[TargetRequirement] = []
var _trigger: MmTrigger = null
## The target requirements an overload changed to "each" (CR 702.96b), by number.
var _overloaded: Array[TargetRequirement] = []
## The overloaded requirements already named, which are "those" from then on.
var _named_overloaded: Dictionary[int, bool] = {}
## What an overloaded "its controller" stands for each of, "those creatures", which the
## sentence then begins with: "For each of those creatures, its controller gains 3 life."
var _for_each_of: String = ""
## Whether the spell exiled what an overload found, so "the exiled card" is several cards.
var _exiles_several: bool = false
## The target requirements already named, which are "it" from then on.
var _named: Dictionary[int, bool] = {}
## Whether a target already named is "that creature" rather than "it", as it is in what an
## InsteadEffect does instead: "double the number of +1/+1 counters on that creature
## instead".
var _names_again_with_that: bool = false
## What "X" stands for in the sentence being written, or "".
var _where: String = ""
## What an amount is given "for each" of, kept for the end of the sentence as [member _where]
## is: "Equipment attached to it" (ProductValue).
var _for_each: String = ""
## The color an Option Menu row's activation makes of mana of any color (ADR 0072), an
## MmMana.Type, or MmMana.NO_TYPE to say "one mana of any color".
var _chosen_mana_type: int = MmMana.NO_TYPE
## Whether the words written so far say "that creature", the object a trigger's event was
## about.
var _says_triggering_object: bool = false
## Whether the ability being written works from its card's graveyard (engine ADR 0094), so
## it calls its source "this card" and returns it "from your graveyard", as Sanitarium
## Skeleton's does.
var _is_from_graveyard: bool = false
## What "the sacrificed [noun]" calls what the ability being written sacrifices, as a cost
## or by an effect (engine ADR 0098): "creature" for "another creature".
var _sacrificed_noun: String = "permanent"
## Whether the only thing the ability being written sacrifices is its own source, as
## Heartfire Immolator's "Sacrifice this creature: It deals damage equal to its power" does
## (engine ADR 0098's addendum), so "the sacrificed creature" is "it".
var _sacrifices_itself: bool = false


## The words of a Filter: what goes before its noun, the noun, and what follows it.
class FilterWords:
	extends RefCounted
	var adjectives: Array[String] = []
	## The last kind named, such as "creature" in "artifact creature", or "" for none.
	var noun: String = ""
	var after: Array[String] = []


## What a card with [param card_types] named [param card_name] calls itself in its own
## text. A card with reconfigure is "this permanent", as Oracle words it: it is a creature
## only while it is not attached (CR 702.151b). A predefined token is "this token"
## (CR 111.10a).
static func self_noun(card_types: Array[MmCardTypes.CardType], card_name: String,
		abilities: Array[MmAbility] = []) -> String:
	if PREDEFINED_TOKENS.has(card_name.trim_suffix(" Token")):
		return "this token"
	for ability: MmAbility in abilities:
		if ability is ReconfigureAbility:
			return "this permanent"
		if ability is EnchantAbility:
			return "this Aura"  # CR 303.4: an Aura is the permanent with enchant.
	for kind: MmCardTypes.CardType in [MmCardTypes.CardType.CREATURE, MmCardTypes.CardType.ARTIFACT,
			MmCardTypes.CardType.ENCHANTMENT, MmCardTypes.CardType.LAND]:
		if card_types.has(kind):
			return "this " + _type_word(kind)
	return card_name


## A card's whole rules text, one ability to a line. Keywords that stand next to each other
## share a line, and a basic land's text is all reminder text, so it is in parentheses. A
## keyword whose instances are redundant, as a Mod's flying is on a card that flies, is
## printed only where it first appears.
static func of_card(abilities: Array[MmAbility], card_types: Array[MmCardTypes.CardType],
		supertypes: Array[MmCardTypes.Supertype], card_name: String) -> String:
	var noun: String = self_noun(card_types, card_name, abilities)
	var lines: PackedStringArray = []
	var was_keyword: bool = false
	var printed: Dictionary[String, bool] = {}
	for ability: MmAbility in abilities:
		if ability is ReconfigureAbility and (ability as ReconfigureAbility).unattaches:
			continue  # CR 702.151a: the keyword's second ability, printed with its first.
		var keyword: String = _keyword(ability)
		if keyword != "" and _is_redundant(ability):
			if printed.has(keyword):
				continue
			printed[keyword] = true
		if keyword != "" and was_keyword:
			lines[lines.size() - 1] += ", " + keyword.to_lower()
		else:
			lines.append(of_ability(ability, noun, enchanted_words(abilities)))
		was_keyword = keyword != ""
	if supertypes.has(MmCardTypes.Supertype.BASIC):
		for index: int in lines.size():
			lines[index] = "(%s)" % lines[index]
	return "\n".join(lines)


## Each of [param abilities] as of_ability() prints it, one to an entry, so that one of them
## can be drawn apart from the others, as a Spent ability is.
static func lines_of(abilities: Array[MmAbility], noun: String) -> Array[String]:
	var lines: Array[String] = []
	for ability: MmAbility in abilities:
		lines.append(of_ability(ability, noun))
	return lines


## [param ability] as a card prints it, with its cost or its trigger. [param noun] is what
## its source calls itself (see self_noun()), and [param enchanted] what an Aura's
## "enchanted" names (see enchanted_words()).
static func of_ability(ability: MmAbility, noun: String, enchanted: String = "") -> String:
	var writer: AbilityText = AbilityText.new(noun)
	writer._enchanted = enchanted
	return writer._ability(ability)


## What "enchanted" names on a card with [param abilities]: "enchanted land" for one with
## "Enchant land" (CR 303.4), or "" for a card with no enchant ability.
static func enchanted_words(abilities: Array[MmAbility]) -> String:
	for ability: MmAbility in abilities:
		if ability is EnchantAbility:
			var writer: AbilityText = AbilityText.new("")
			return "enchanted " + writer._noun_phrase((ability as EnchantAbility).filter, false)
		if ability is BestowAbility:
			return "enchanted creature"  # CR 702.103b: bestowed, it has enchant creature.
	return ""


## [param ability] as a row of the Option Menu reads it: as the card prints it, except that
## each of reconfigure's two abilities says which it is, "Reconfigure {2}: attach" and
## "Reconfigure {2}: unattach", and that an activation of mana of any color for
## [param mana_type], an MmMana.Type, adds that color: "{T}, Sacrifice this token: Add {W}."
## (ADR 0072). An ActivateAbilityAction's mana_type is the one to pass.
static func option_of(ability: MmAbility, noun: String, mana_type: int = MmMana.NO_TYPE) -> String:
	var writer: AbilityText = AbilityText.new(noun)
	writer._chosen_mana_type = mana_type
	var text: String = writer._ability(ability)
	if ability is ReconfigureAbility:
		return text + (": unattach" if (ability as ReconfigureAbility).unattaches else ": attach")
	return text


## How a cast pays one choice of [param ability]'s "[costs] or [the other costs]", the other
## with [param other] (engine ADR 0086's second addendum), as the user worded Bayou Groff's
## casts: "sacrificing a creature", "paying {3}".
static func additional_cost_choice_words(ability: AdditionalCostAbility, other: bool) -> String:
	var writer: AbilityText = AbilityText.new("this spell")
	var words: PackedStringArray = []
	for part: String in writer._cost_parts(ability.mana_for(other), ability.costs_for(other)):
		words.append(_paying_part(part))
	return " and ".join(words)


## [param part] of a cost said as it is paid: "{3}" is "paying {3}", "Sacrifice a creature"
## "sacrificing a creature".
static func _paying_part(part: String) -> String:
	if part.begins_with("{"):
		return "paying " + part
	var space: int = part.find(" ")
	var verb: String = (part if space == -1 else part.left(space)).to_lower()
	var rest: String = "" if space == -1 else part.substr(space)
	if verb == "tap":
		return "tapping" + rest
	if verb.ends_with("e") and not verb.ends_with("ee"):
		return verb.left(verb.length() - 1) + "ing" + rest
	return verb + "ing" + rest


## Only what [param ability] does, for a spell or ability on the stack: without the cost
## that was paid or the trigger and condition that were met. A modal spell or triggered
## ability whose [param mode_index] is chosen does only what that mode does; before then it
## says every mode.
static func effect_of(ability: MmAbility, noun: String, mode_index: int = SpellAbility.NO_MODE) -> String:
	var writer: AbilityText = AbilityText.new(noun)
	if not ability.modes_or_none().is_empty():
		return writer._choose_one(ability) if mode_index == SpellAbility.NO_MODE else mode_text(ability, mode_index, noun)
	if ability is SpellAbility:
		writer._targets = (ability as SpellAbility).targets
		writer._overloaded = (ability as SpellAbility).overloaded_targets
		return writer._sentences((ability as SpellAbility).effects, true)
	if ability is ActivatedAbility:
		writer._targets = (ability as ActivatedAbility).targets
		writer._read_where_it_works(ability as ActivatedAbility)
		return writer._sentences((ability as ActivatedAbility).effects, true)
	if ability is TriggeredAbility:
		var triggered: TriggeredAbility = ability as TriggeredAbility
		writer._targets = triggered.targets
		writer._trigger = triggered.trigger
		writer._read_where_triggered_works(triggered)
		return writer._sentences(triggered.effects, true)
	return writer._ability(ability)


## What [param effect], one of [param ability]'s, does, alone and in lower case, as a
## "you may" asks it (game ADR 0060): "tap target creature". [param mode_index] is the
## chosen mode of a modal one.
static func offered_words(ability: MmAbility, effect: MmEffect, noun: String, mode_index: int = SpellAbility.NO_MODE) -> String:
	var writer: AbilityText = AbilityText.new(noun)
	if not ability.modes_or_none().is_empty() and mode_index != SpellAbility.NO_MODE:
		writer._targets = ability.modes_or_none()[mode_index].targets
		writer._overloaded = ability.modes_or_none()[mode_index].overloaded_targets
	elif ability is SpellAbility:
		writer._targets = (ability as SpellAbility).targets
		writer._overloaded = (ability as SpellAbility).overloaded_targets
	elif ability is ActivatedAbility:
		writer._targets = (ability as ActivatedAbility).targets
	elif ability is TriggeredAbility:
		writer._targets = (ability as TriggeredAbility).targets
	if ability is TriggeredAbility:
		writer._trigger = (ability as TriggeredAbility).trigger
	return writer._effect(effect)


## What mode [param mode_index] of the modal spell or triggered ability [param ability]
## does, as its "•" line says it, without the bullet.
static func mode_text(ability: MmAbility, mode_index: int, noun: String) -> String:
	var writer: AbilityText = AbilityText.new(noun)
	var mode: AbilityMode = ability.modes_or_none()[mode_index]
	writer._targets = mode.targets
	writer._overloaded = mode.overloaded_targets
	if ability is TriggeredAbility:
		writer._trigger = (ability as TriggeredAbility).trigger  # "that creature" and the like.
	return writer._sentences(mode.effects, true)


## [param ability] as of_ability() prints it, with each "of the chosen type" in it read as
## [param creature_type] ("Each Cat creature you control gets +1/+1"), or "" when it does
## not read a chosen type (game ADR 0053).
static func with_chosen_type(ability: MmAbility, creature_type: String, noun: String) -> String:
	var static_ability: ContinuousStaticAbility = ability as ContinuousStaticAbility
	if static_ability == null:
		return ""
	var reads_it: bool = false
	var named: ContinuousStaticAbility = static_ability.duplicate() as ContinuousStaticAbility
	named.effects = []
	for continuous: MmContinuousEffect in static_ability.effects:
		var each: EachSelection = continuous.affected as EachSelection
		var filter: MmFilter = _naming_chosen_type(each.filter, creature_type) if each != null else null
		if filter == null or filter == each.filter:
			named.effects.append(continuous)
			continue
		reads_it = true
		var copy: MmContinuousEffect = continuous.duplicate() as MmContinuousEffect
		var selection: EachSelection = EachSelection.new()
		selection.filter = filter
		copy.affected = selection
		named.effects.append(copy)
	return of_ability(named, noun) if reads_it else ""


## [param filter] with each IsOfChosenTypeFilter in it made "a [param creature_type]", or
## [param filter] itself when it has none. Card data is never changed: what differs is new.
static func _naming_chosen_type(filter: MmFilter, creature_type: String) -> MmFilter:
	if filter is IsOfChosenTypeFilter:
		var subtype: HasSubtypeFilter = HasSubtypeFilter.new()
		subtype.subtype = creature_type
		return subtype
	if filter is AllOfFilter or filter is AnyOfFilter:
		var parts: Array[MmFilter] = (filter as AllOfFilter).filters if filter is AllOfFilter else (filter as AnyOfFilter).filters
		var named: Array[MmFilter] = []
		var changed: bool = false
		for part: MmFilter in parts:
			var made: MmFilter = _naming_chosen_type(part, creature_type)
			changed = changed or made != part
			named.append(made)
		if not changed:
			return filter
		var copy: MmFilter = filter.duplicate() as MmFilter
		if copy is AllOfFilter:
			(copy as AllOfFilter).filters = named
		else:
			(copy as AnyOfFilter).filters = named
		return copy
	if filter is NotFilter:
		var inner: MmFilter = _naming_chosen_type((filter as NotFilter).filter, creature_type)
		if inner == (filter as NotFilter).filter:
			return filter
		var negated: NotFilter = NotFilter.new()
		negated.filter = inner
		return negated
	return filter


## Everything [param filter] matches, in the plural: "black permanents", "creatures you
## control".
static func things(filter: MmFilter) -> String:
	return AbilityText.new("it")._noun_phrase(filter, true)


## What a choice made on resolution asks for, such as "a creature you control", in the
## words a prompt uses.
static func chosen_words(filter: MmFilter) -> String:
	return _with_article(AbilityText.new("this")._noun_phrase(filter, false))


## What a choice among cards that are not permanents asks for, such as the cards just
## milled (engine ADR 0080): "an instant or sorcery card".
static func chosen_card_words(filter: MmFilter) -> String:
	return chosen_words(filter) + " card"


## The cards a cost exiles from a graveyard (ExileFromGraveyardCost): "a creature card",
## "three cards"; with [param exiled_before] of them exiled already, those still to exile,
## "two more cards", "one more card", as its prompt says once a pick is made.
static func exiled_card_words(count: int, filter: MmFilter, exiled_before: int = 0) -> String:
	if count == 1:
		return chosen_card_words(filter)
	var left: int = count - exiled_before
	var phrase: String = AbilityText.new("this")._card_phrase(filter, left != 1)
	if exiled_before == 0:
		return "%s %s" % [_number_word(left), phrase]
	return "%s more %s" % [_number_word(left), phrase]


## [param count] of what [param filter] matches, as a cost says it: "an untapped creature
## you control", "three untapped creatures you control".
static func how_many_words(count: int, filter: MmFilter) -> String:
	return AbilityText.new("it")._how_many(count, filter)


## What a search asks for, as its prompt says it: "a basic land card", or with
## [param is_up_to] "up to one Plains card" (ADR 0057).
static func searched_words(most: int, is_up_to: bool, filter: MmFilter) -> String:
	var words: AbilityText = AbilityText.new("it")
	if not is_up_to:
		return _with_article(words._card_phrase(filter, false))
	return "up to %s %s" % [_number_word(most), words._card_phrase(filter, most != 1)]


## How many targets an "up to" choice asks for, as its prompt says it: "up to two targets",
## "up to one target".
static func up_to_targets_words(most: int) -> String:
	return "up to %s target%s" % [_number_word(most), "" if most == 1 else "s"]


## The words of [param cost], as a cost of an ability of [param noun] reads them: "Pay 2
## life". The Info Panel's Pay answer for a land that may pay to enter untapped (game
## ADR 0067).
static func cost_words(cost: MmCost, noun: String) -> String:
	return ", ".join(AbilityText.new(noun)._cost_parts(null, [cost] as Array[MmCost]))


## Whether [param text] has something in it there were no words for.
static func has_fallback(text: String) -> bool:
	return text.contains("[")


func _init(noun: String) -> void:
	_noun = noun


# --- Abilities -----------------------------------------------------------------------

func _ability(ability: MmAbility) -> String:
	var keyword: String = _keyword(ability)
	if keyword != "":
		return keyword
	if ability is ProtectionAbility:
		return "Protection from " + _protection((ability as ProtectionAbility).from)
	if ability is EnchantAbility:
		return "Enchant " + _noun_phrase((ability as EnchantAbility).filter, false)  # CR 702.5a
	if ability is SpellAbility and (ability as SpellAbility).is_modal():
		return _choose_one(ability)
	if ability is SpellAbility:
		_targets = (ability as SpellAbility).targets
		_overloaded = (ability as SpellAbility).overloaded_targets
		return _sentences((ability as SpellAbility).effects, true)
	if ability is EquipAbility:
		# A keyword prints its cost and nothing else (CR 702.6); what it does is its Reminder.
		return "Equip " + _costs(ability as EquipAbility)
	if ability is ReconfigureAbility:
		# CR 702.151a: as equip does, it prints its cost alone.
		return "Reconfigure " + _costs(ability as ReconfigureAbility)
	if ability is CyclingAbility:
		# CR 702.29a: as equip does, it prints its cost alone.
		var cycling: PackedStringArray = _cost_parts((ability as CyclingAbility).mana_cost, [])
		return _capitalized(_cycling_word((ability as CyclingAbility).search)) + " " \
			+ (", ".join(cycling) if not cycling.is_empty() else "{0}")
	if ability is FlashbackAbility:
		return _flashback(ability as FlashbackAbility)
	if ability is AdditionalCostAbility:
		# CR 601.2f: "As an additional cost to cast this spell, return a permanent you control
		# to its owner's hand."
		var additional: AdditionalCostAbility = ability as AdditionalCostAbility
		var parts: PackedStringArray = _cost_parts(null, additional.costs)
		var words: String = _uncapitalized(" and ".join(parts))
		if additional.has_choice():
			# Engine ADR 0086's second addendum, as Bayou Groff words it: "sacrifice a creature
			# or pay {3}".
			var other: PackedStringArray = []
			for part: String in _cost_parts(additional.or_mana_cost, additional.or_costs):
				other.append("pay " + part if part.begins_with("{") else _uncapitalized(part))
			words += " or " + " and ".join(other)
		return "As an additional cost to cast this spell, %s." % words
	if ability is AlternativeCostAbility:
		# CR 118.9, engine ADR 0093, as Zahid words it: "You may pay {3}{U} and tap an untapped
		# artifact you control rather than pay this spell's mana cost."
		var alternative: AlternativeCostAbility = ability as AlternativeCostAbility
		var paid: PackedStringArray = []
		for part: String in _cost_parts(alternative.mana_cost, alternative.costs):
			paid.append(_uncapitalized(part))
		var what: String = " and ".join(paid) if not paid.is_empty() else "{0}"
		var verb: String = "pay " if alternative.mana_cost != null else ""
		return "You may %s%s rather than pay this spell's mana cost." % [verb, what]
	if ability is WardAbility:
		# CR 702.21a: as equip does, it prints its cost alone.
		var ward: MmManaCost = (ability as WardAbility).mana_cost
		return "Ward " + (ward.describe() if ward != null else "{0}")
	if ability is BestowAbility:
		# CR 702.103a: as ward does, it prints its cost alone, without its reminder text.
		var bestow: MmManaCost = (ability as BestowAbility).mana_cost
		return "Bestow " + (bestow.describe() if bestow != null else "{0}")
	if ability is AffinityAbility:
		# CR 702.41a: what it counts, in the plural, with "you control" left to the keyword.
		return "Affinity for " + _noun_phrase((ability as AffinityAbility).filter, true)
	if ability is CostReductionAbility:
		var reducing: CostReductionAbility = ability as CostReductionAbility
		if reducing.condition != null and reducing.amount is ConstantValue:
			# Engine ADR 0050's addendum, as Gigastorm Titan words it.
			return "This spell costs {%d} less to cast if %s." % [(reducing.amount as ConstantValue).value,
				_condition(reducing.condition)]
		return _costs_less("This spell", "cast", reducing.amount)
	if ability is SpellsCostLessAbility:
		# Engine ADR 0050's addendum: "The second spell you cast each turn costs {1} less to cast."
		var cheaper: SpellsCostLessAbility = ability as SpellsCostLessAbility
		if cheaper.nth_each_turn > 0:
			return "The %s spell you cast each turn costs {%d} less to cast." % [
				_ordinal(cheaper.nth_each_turn), cheaper.amount]
		return "Spells you cast cost {%d} less to cast." % cheaper.amount
	if ability is ActivatedAbility:
		var activated: ActivatedAbility = ability as ActivatedAbility
		_targets = activated.targets
		_read_where_it_works(activated)
		_sacrificed_noun = _sacrificed_noun_of(activated.costs, activated.effects)
		_sacrifices_itself = _sacrifices_only_itself(activated.costs, activated.effects)
		var does: String = _sentences(activated.effects, true) + _reduction(activated) + _restrictions(activated)
		# A Potion prints only what it does: using it up is what a Potion is (ADR 0036).
		return does if _uses_up_its_source(activated) else "%s: %s" % [_costs(activated), does]
	if ability is TriggeredAbility:
		return _triggered(ability as TriggeredAbility)
	if ability is CharacteristicDefiningAbility:
		return _characteristic_defining(ability as CharacteristicDefiningAbility)
	if ability is ContinuousStaticAbility:
		return _static(ability as ContinuousStaticAbility)
	if ability is AdditionalLandPlaysAbility:
		return "You may play %s on each of your turns." % _additional((ability as AdditionalLandPlaysAbility).count, "land")
	if ability is BlockAdditionalAbility:
		return "%s can block %s each combat." % [_capitalized(_noun), _additional((ability as BlockAdditionalAbility).count, "creature")]
	if ability is DamageStaysAbility:
		return "Damage isn't removed from %s during cleanup steps." % _noun
	if ability is AssignsCombatDamageByToughnessAbility:
		return _by_toughness(ability as AssignsCombatDamageByToughnessAbility)
	if ability is AsEntersChooseCreatureTypeAbility:
		return "As %s enters, choose a creature type." % _noun
	if ability is EntersTappedAbility:
		return "%s enters tapped." % _capitalized(_noun)
	if ability is CantBeBlockedAbility:
		return "%s can't be blocked." % _capitalized(_noun)
	if ability is CantBlockAbility:
		return "%s can't block." % _capitalized(_noun)  # Phoenix Chick's (CR 509.1a).
	if ability is CantBeCounteredAbility:
		return "This spell can't be countered."  # Only ever said of the card as a spell.
	if ability is SpellsCantBeCounteredAbility:
		return _spells_cant_be_countered(ability as SpellsCantBeCounteredAbility)
	if ability is EntersWithCountersAbility:
		var entering: EntersWithCountersAbility = ability as EntersWithCountersAbility
		_where = ""
		var enters: String = "%s enters with %s on it" % [_capitalized(_noun), _counters(entering.amount, entering.kind)]
		if _where != "":
			# Voracious Wurm's "where X is the amount of life you've gained this turn".
			enters += ", where X is " + _where
			_where = ""
		return enters + "."
	if ability is AsEntersPayOrEntersTappedAbility:
		var unless_paid: AsEntersPayOrEntersTappedAbility = ability as AsEntersPayOrEntersTappedAbility
		return "As %s enters, you may %s. If you don't, it enters tapped." % [_noun,
			", ".join(_cost_parts(null, [unless_paid.cost] as Array[MmCost])).to_lower()]
	if ability is DrawReplacementAbility:
		return _draw_replacement(ability as DrawReplacementAbility)
	if ability is LookAtTopOfLibraryAbility:
		return "You may look at the top card of your library any time."
	if ability is InstantSpeedEquipAbility:
		return "You may activate equip abilities any time you could cast an instant."
	if ability is CastFromTopOfLibraryAbility:
		return "Once each turn, you may cast %s from the top of your library." \
			% _with_article(_spell_phrase((ability as CastFromTopOfLibraryAbility).filter))
	return _fallback(ability, "_ability")


## Blood Scrivener's "If you would draw a card while you have no cards in hand, instead you
## draw two cards and you lose 1 life." (engine ADR 0097): what happens instead is joined by
## "and", each with its subject, as Oracle words it.
func _draw_replacement(replacing: DrawReplacementAbility) -> String:
	var clauses: PackedStringArray = PackedStringArray()
	for effect: MmEffect in replacing.instead:
		var clause: String = _effect(effect)
		var draw: DrawCardsEffect = effect as DrawCardsEffect
		if draw != null and draw.players is YouSelection:
			clause = "you " + clause
		clauses.append(clause)
	var while_text: String = "" if replacing.condition == null else " while " + _condition(replacing.condition)
	return "If you would draw a card%s, instead %s." % [while_text, " and ".join(clauses)]


## "cycling", or for typecycling the card it searches for with "card" left out and
## "cycling" attached (CR 702.29e): "basic landcycling", "Plainscycling".
func _cycling_word(search: MmFilter) -> String:
	if search == null:
		return "cycling"
	var words: FilterWords = _filter_words(search)
	var parts: PackedStringArray = PackedStringArray(words.adjectives)
	if words.noun != "":
		parts.append(words.noun)
	if parts.is_empty():
		parts.append("card")
	parts[parts.size() - 1] += "cycling"
	parts.append_array(PackedStringArray(words.after))
	return " ".join(parts)


## Whether [param ability] is a keyword, protection included: an ability a sentence names
## in lower case and without quotation marks.
static func is_keyword(ability: MmAbility) -> bool:
	return _keyword(ability) != "" or ability is ProtectionAbility or ability is EquipAbility or ability is FlashbackAbility \
		or ability is AffinityAbility or ability is CyclingAbility or ability is ReconfigureAbility or ability is WardAbility \
		or ability is EnchantAbility or ability is BestowAbility


## Whether a second instance of [param ability] on an object does nothing more, as a
## second flying does (CR 702.9c). A keyword that triggers does more each time (CR 702.83b,
## 702.91b, 702.100d, 702.108b, 702.134b), and so is not; nor is undying, each instance of which
## triggers (CR 603.2).
static func _is_redundant(ability: MmAbility) -> bool:
	return not (ability is ExaltedAbility or ability is BattleCryAbility or ability is EvolveAbility or ability is ProwessAbility
		or ability is UndyingAbility or ability is MentorAbility)


## The name of a keyword ability that needs no other words, or "".
static func _keyword(ability: MmAbility) -> String:
	if ability is FlyingAbility:
		return "Flying"
	if ability is FirstStrikeAbility:
		return "First strike"
	if ability is DoubleStrikeAbility:
		return "Double strike"
	if ability is VigilanceAbility:
		return "Vigilance"
	if ability is ReachAbility:
		return "Reach"
	if ability is DefenderAbility:
		return "Defender"
	if ability is HasteAbility:
		return "Haste"
	if ability is TrampleAbility:
		return "Trample"
	if ability is DeathtouchAbility:
		return "Deathtouch"
	if ability is MenaceAbility:
		return "Menace"
	if ability is SkulkAbility:
		return "Skulk"
	if ability is ImproviseAbility:
		return "Improvise"  # CR 702.126a, without its reminder text (engine ADR 0099).
	if ability is LifelinkAbility:
		return "Lifelink"
	if ability is IndestructibleAbility:
		return "Indestructible"
	if ability is HexproofAbility:
		return "Hexproof"
	if ability is FlashAbility:
		return "Flash"
	if ability is ExaltedAbility:
		return "Exalted"
	if ability is BattleCryAbility:
		return "Battle cry"
	if ability is MentorAbility:
		return "Mentor"  # CR 702.134a.
	if ability is EvolveAbility:
		return "Evolve"
	if ability is ProwessAbility:
		return "Prowess"
	if ability is UndyingAbility:
		return "Undying"
	if ability is ChangelingAbility:
		return "Changeling"
	return ""


func _protection(from: MmFilter) -> String:
	var color: HasColorFilter = from as HasColorFilter
	if color != null:
		return _color_word(color.color)
	return _noun_phrase(from, true)


## Whether paying for [param ability] uses its source up, as a Potion's cost does.
static func _uses_up_its_source(ability: ActivatedAbility) -> bool:
	for cost: MmCost in ability.costs:
		if cost is UseUpCost:
			return true
	return false


## The sentence after what [param ability] does that says how much less it costs to
## activate (CR 602.2b, ADR 0050), or "".
func _reduction(ability: ActivatedAbility) -> String:
	var value: MmValue = ability.generic_reduction
	if value == null:
		return ""
	return " " + _costs_less("This ability", "activate", value)


## "[param subject] costs {1} less to [param verb] for each" a basic land type, as Domain
## says it, or "... costs {X} less to [param verb], where X is" any other [param value]
## (CR 601.2f, ADR 0050).
func _costs_less(subject: String, verb: String, value: MmValue) -> String:
	var among: EachSelection = (value as BasicLandTypeCountValue).selection as EachSelection \
		if value is BasicLandTypeCountValue else null
	if among != null:
		return "%s costs {1} less to %s for each basic land type among %s." % [subject, verb, _noun_phrase(among.filter, true)]
	if value is CardsInZoneValue:
		# Chitin Gravestalker's "for each artifact and/or creature card in your graveyard".
		return "%s costs {1} less to %s for each %s." % [subject, verb, _cards_in_zone(value as CardsInZoneValue, false)]
	return "%s costs {X} less to %s, where X is %s." % [subject, verb, _value_phrase(value)]


## The sentence after what [param ability] does that says when it may be activated
## (CR 602.5), or "".
func _restrictions(ability: ActivatedAbility) -> String:
	var limits: PackedStringArray = []
	if ability.is_sorcery_speed:
		limits.append("only as a sorcery")
	if ability.is_once_each_game:
		limits.append("only once each game")
	if ability.is_once_each_turn:
		limits.append("only once each turn")  # CR 602.5b, engine ADR 0036's addendum
	if ability.condition != null:
		limits.append("only if " + _condition(ability.condition))  # CR 602.5b, engine ADR 0095
	return "" if limits.is_empty() else " Activate %s." % " and ".join(limits)


func _costs(ability: ActivatedAbility) -> String:
	var costs: PackedStringArray = _cost_parts(ability.mana_cost, ability.costs)
	return ", ".join(costs) if not costs.is_empty() else "{0}"


## Oracle's flashback (CR 702.34a): "Flashback {2}{W}" for a mana cost alone, and with a
## dash otherwise, "Flashback—{1}{U}, Pay 3 life".
func _flashback(ability: FlashbackAbility) -> String:
	var parts: PackedStringArray = _cost_parts(ability.mana_cost, ability.costs)
	if ability.costs.is_empty():
		return "Flashback " + (", ".join(parts) if not parts.is_empty() else "{0}")
	return "Flashback—" + ", ".join(parts)


## The words of each part of a cost, its mana first. Using up a Potion has none (ADR 0036).
func _cost_parts(mana: MmManaCost, costs: Array[MmCost]) -> PackedStringArray:
	var parts: PackedStringArray = []
	if mana != null:
		parts.append(mana.describe())
	for cost: MmCost in costs:
		if cost is UseUpCost:
			continue
		if cost is DiscardThisCardCost:
			parts.append("Discard this card")  # CR 702.29a: in any zone's words, a card.
			continue
		if cost is TapCost:
			parts.append("{T}")
		elif cost is ExertCost:
			parts.append("Exert " + _noun)  # CR 701.43, without its reminder text.
		elif cost is PayLifeCost:
			parts.append("Pay %d life" % (cost as PayLifeCost).amount)
		elif cost is SacrificeThisCost:
			parts.append("Sacrifice " + _noun)  # CR 701.21a: "Sacrifice this artifact".
		elif cost is RemoveCountersCost:
			var removing: RemoveCountersCost = cost as RemoveCountersCost
			var how_many: ConstantValue = ConstantValue.new()
			how_many.value = removing.amount
			parts.append("Remove %s from %s" % [_counters(how_many, removing.kind), _noun])  # CR 118.3.
		elif cost is TapCreaturesCost:
			parts.append("Tap " + _how_many((cost as TapCreaturesCost).count, (cost as TapCreaturesCost).filter))
		elif cost is ReturnPermanentsCost:
			var returning: ReturnPermanentsCost = cost as ReturnPermanentsCost
			parts.append("Return %s to %s owner's hand" % [_how_many(returning.count, returning.filter),
				"its" if returning.count == 1 else "their"])
		elif cost is SacrificePermanentsCost:
			# Selfcraft Mechan's "sacrifice an artifact" (CR 701.21a).
			var sacrificing: SacrificePermanentsCost = cost as SacrificePermanentsCost
			parts.append("Sacrifice " + _how_many(sacrificing.count, sacrificing.filter))
		elif cost is DiscardCardsCost:
			var how_many: ConstantValue = ConstantValue.new()
			how_many.value = (cost as DiscardCardsCost).count
			parts.append("Discard " + _cards(how_many))  # CR 701.9a.
		elif cost is ExileFromGraveyardCost:
			# Kishla Trawlers's "exile a creature card from your graveyard", Kessig
			# Wolfrider's "exile three cards from your graveyard".
			var exiling: ExileFromGraveyardCost = cost as ExileFromGraveyardCost
			parts.append("Exile %s from your graveyard" % exiled_card_words(exiling.count, exiling.filter))
		else:
			parts.append(_fallback(cost, "_cost"))
	return parts


## What a reflexive ability does, with its own targets, as one clause without its full
## stop (engine ADR 0088): "return target instant or sorcery card from your graveyard to
## your hand".
func _reflexive_words(reflexive: ReflexiveTriggerEffect) -> String:
	var outer: Array[TargetRequirement] = _targets
	_targets = reflexive.ability.targets
	# Selfcraft Mechan's "put a +1/+1 counter on target creature and draw a card": what it
	# does is one clause after "When you do", so a later effect never reads as a sentence of
	# its own, which would happen whether or not you did.
	var clauses: PackedStringArray = []
	for effect: MmEffect in reflexive.ability.effects:
		var one: Array[MmEffect] = [effect]
		clauses.append(_sentences(one, false).trim_suffix("."))
	_targets = outer
	return _listed(clauses)


## What a delayed triggered ability does, then when, as one clause without its full stop
## (engine ADR 0103), as Harried Dronesmith words it: "sacrifice it at the beginning of your
## next end step".
func _delayed_words(delayed: CreateDelayedTriggerEffect) -> String:
	var clauses: PackedStringArray = []
	for effect: MmEffect in delayed.ability.effects:
		var one: Array[MmEffect] = [effect]
		clauses.append(_sentences(one, false).trim_suffix("."))
	var step: StepBeganTrigger = delayed.ability.trigger as StepBeganTrigger
	if step == null:
		return "%s %s" % [_listed(clauses), _fallback(delayed.ability.trigger, "_trigger")]
	var whose: String = "your next"
	if step.whose == MmTrigger.Whose.ANY:
		whose = "the next"
	elif step.whose == MmTrigger.Whose.OPPONENT:
		whose = "an opponent's next"
	return "%s at the beginning of %s %s" % [_listed(clauses), whose, STEP_NAMES.get(step.step, "step")]


## Whether [param costs] sacrifice the ability's own source and nothing else does, in them
## or in [param effects].
static func _sacrifices_only_itself(costs: Array[MmCost], effects: Array[MmEffect]) -> bool:
	var itself: bool = false
	for cost: MmCost in costs:
		if cost is SacrificePermanentsCost:
			return false
		itself = itself or cost is SacrificeThisCost
	for effect: MmEffect in effects:
		if effect is SacrificeEffect:
			return false
	return itself


## The noun of the first thing [param costs] or [param effects] sacrifice, "creature" for
## "another creature", or "permanent" when nothing names one.
func _sacrificed_noun_of(costs: Array[MmCost], effects: Array[MmEffect]) -> String:
	var filter: MmFilter = null
	for cost: MmCost in costs:
		if filter == null and cost is SacrificePermanentsCost:
			filter = (cost as SacrificePermanentsCost).filter
	for effect: MmEffect in effects:
		if filter == null and effect is SacrificeEffect:
			filter = (effect as SacrificeEffect).filter
	var noun: String = "" if filter == null else _filter_words(filter).noun
	return noun if noun != "" else "permanent"


## "an untapped creature you control" or "three untapped creatures you control".
func _how_many(count: int, filter: MmFilter) -> String:
	if count == 1:
		return _with_article(_noun_phrase(filter, false))
	return "%s %s" % [_number_word(count), _noun_phrase(filter, true)]


func _triggered(ability: TriggeredAbility) -> String:
	_read_where_triggered_works(ability)
	_targets = ability.targets
	_trigger = ability.trigger
	_says_triggering_object = false
	_sacrificed_noun = _sacrificed_noun_of([], ability.effects)
	_sacrifices_itself = false
	var condition: String = "" if ability.condition == null else "if %s, " % _condition(ability.condition)
	if ability.is_modal():
		# Later: "one or more" for a modal one, whose modes are worded apart.
		var modal: String = _capitalized(_trigger_text(ability.trigger) + ", " + condition + "choose one —") + _bullets(ability)
		return modal + ("\n" + ONCE_EACH_TURN if ability.is_once_each_turn else "")
	# Worded before the trigger, which says "one or more" only when they never say "that
	# creature".
	var does: String = ""
	var only: IfEffect = ability.effects[0] as IfEffect if ability.effects.size() == 1 else null
	if only != null and not only.is_unless:
		# CR 608.2c against 603.4: an "if" right after the trigger would read as an
		# intervening "if", so one asked only as it resolves comes after what it does, as
		# Poisoner's Apprentice words it.
		var effects: Array[MmEffect] = [only.effect]
		does = "%s if %s." % [_sentences(effects, false).trim_suffix("."), _condition(only.condition)]
	else:
		does = _sentences(ability.effects, false)
	var is_one_or_more: bool = ability.is_once_each_turn and not _says_triggering_object
	var text: String = _capitalized(_trigger_text(ability.trigger, is_one_or_more) + ", " + condition + does)
	return text + (" " + ONCE_EACH_TURN if ability.is_once_each_turn else "")


## CR 700.2: "Choose one —", then a bullet for each mode of [param ability].
func _choose_one(ability: MmAbility) -> String:
	return "Choose one —" + _bullets(ability)


## A new line and a "•" for each mode of [param ability].
func _bullets(ability: MmAbility) -> String:
	var text: String = ""
	for mode_index: int in ability.modes_or_none().size():
		text += "\n• " + mode_text(ability, mode_index, _noun)
	return text


## [param trigger] in words. With [param is_one_or_more], a zone change of anything but the
## source reads "whenever one or more creatures enter": once each turn, triggering for each
## object plays as triggering once for all of them does (engine ADR 0054's addendum).
func _trigger_text(trigger: MmTrigger, is_one_or_more: bool = false) -> String:
	if trigger == null:
		return "when you do"  # CR 603.12: a reflexive ability, shown alone as on the stack.
	var step: StepBeganTrigger = trigger as StepBeganTrigger
	if step != null and step.step == MmTurn.Step.BEGINNING_OF_COMBAT:
		# As Oracle words it: "At the beginning of combat on your turn".
		if step.whose == MmTrigger.Whose.ANY:
			return "at the beginning of each combat"
		return "at the beginning of combat on %s turn" % ("your" if step.whose == MmTrigger.Whose.YOU else "each opponent's")
	if step != null:
		var whose: String = "your"
		if step.whose == MmTrigger.Whose.ANY:
			whose = "each player's"
		elif step.whose == MmTrigger.Whose.OPPONENT:
			whose = "each opponent's"
		return "at the beginning of %s %s" % [whose, STEP_NAMES.get(step.step, "step")]
	var cast: SpellCastTrigger = trigger as SpellCastTrigger
	if cast != null and cast.filter is IsSourceFilter:
		# CR 113.6k, as Sage of the Skies words it: the spell itself, so "spell", whatever it is.
		return "when you cast this spell"
	if cast != null and cast.nth_each_turn > 0:
		# Clarion Spirit's "Whenever you cast your second spell each turn".
		# Later: an Nth spell that must also match a Filter, once a card has one.
		var whose_spell: String = "a player casts their"
		if cast.whose == MmTrigger.Whose.YOU:
			whose_spell = "you cast your"
		elif cast.whose == MmTrigger.Whose.OPPONENT:
			whose_spell = "an opponent casts their"
		return "whenever %s %s spell each turn%s" % [whose_spell, _ordinal(cast.nth_each_turn), _during_turn(cast)]
	var drawn: CardDrawnTrigger = trigger as CardDrawnTrigger
	if drawn != null:
		# Faerie Vandal's "Whenever you draw your second card each turn".
		var whose_card: String = "a player draws"
		var their: String = "their"
		if drawn.whose == MmTrigger.Whose.YOU:
			whose_card = "you draw"
			their = "your"
		elif drawn.whose == MmTrigger.Whose.OPPONENT:
			whose_card = "an opponent draws"
		if drawn.nth_each_turn > 0:
			return "whenever %s %s %s card each turn" % [whose_card, their, _ordinal(drawn.nth_each_turn)]
		return "whenever %s a card" % whose_card
	if cast != null:
		var caster: String = "a player casts"
		if cast.whose == MmTrigger.Whose.YOU:
			caster = "you cast"
		elif cast.whose == MmTrigger.Whose.OPPONENT:
			caster = "an opponent casts"
		return "whenever %s %s%s" % [caster, _with_article(_spell_phrase(cast.filter)), _during_turn(cast)]
	var attack: AttackersDeclaredTrigger = trigger as AttackersDeclaredTrigger
	if attack != null:
		if attack.alone:
			# CR 506.5, as exalted's reminder words it (CR 702.83a).
			var attacker: String = "a creature" if attack.filter == null else _with_article(_noun_phrase(attack.filter, false))
			var whose_alone: String = " a player controls"
			if attack.whose == MmTrigger.Whose.YOU:
				whose_alone = " you control"
			elif attack.whose == MmTrigger.Whose.OPPONENT:
				whose_alone = " an opponent controls"
			return "whenever %s%s attacks alone" % [attacker, whose_alone]
		if attack.filter is IsSourceFilter:
			return "whenever %s attacks" % _noun
		if attack.at_least > 1:
			# Phoenix Chick's "Whenever you attack with three or more creatures".
			var attackers: String = "creatures" if attack.filter == null else _noun_phrase(attack.filter, true)
			var attacker_player: String = "you attack" if attack.whose == MmTrigger.Whose.YOU \
				else ("an opponent attacks" if attack.whose == MmTrigger.Whose.OPPONENT else "a player attacks")
			return "whenever %s with %s or more %s" % [attacker_player, _number_word(attack.at_least), attackers]
		if attack.filter != null:
			return "whenever one or more %s attack" % _noun_phrase(attack.filter, true, attack.whose)
		var whose: String = "a player controls"
		if attack.whose == MmTrigger.Whose.YOU:
			whose = "you control"
		elif attack.whose == MmTrigger.Whose.OPPONENT:
			whose = "an opponent controls"
		return "whenever one or more creatures %s attack" % whose
	var block: BlockersDeclaredTrigger = trigger as BlockersDeclaredTrigger
	if block != null:
		var blocker: String = "a creature"
		if block.filter is IsSourceFilter:
			blocker = _noun
		elif block.filter != null:
			blocker = _with_article(_noun_phrase(block.filter, false))
		return "whenever %s blocks a creature" % blocker  # CR 509.3b
	var aimed_at: BecomesTargetTrigger = trigger as BecomesTargetTrigger
	if aimed_at != null:
		var whose: String = ""
		if aimed_at.whose == MmTrigger.Whose.YOU:
			whose = " you control"
		elif aimed_at.whose == MmTrigger.Whose.OPPONENT:
			whose = " an opponent controls"
		var is_this: bool = aimed_at.filter is IsSourceFilter
		var subject: String = _noun if is_this else _with_article(_noun_phrase(aimed_at.filter, false))
		var of_what: String = "a spell" if aimed_at.is_spells_only else "a spell or ability"
		return "whenever %s becomes the target of %s%s" % [subject, of_what, whose]
	var tapped: BecomesTappedTrigger = trigger as BecomesTappedTrigger
	if tapped != null:
		var is_this: bool = tapped.filter is IsSourceFilter
		var subject: String = _noun if is_this else _with_article(_noun_phrase(tapped.filter, false, tapped.whose))
		return "whenever %s becomes tapped" % subject
	var gained: LifeGainedTrigger = trigger as LifeGainedTrigger
	if gained != null:
		# CR 119.9, ADR 0082: "Whenever you gain life".
		if gained.whose == MmTrigger.Whose.YOU:
			return "whenever you gain life"
		return "whenever %s gains life" % ("an opponent" if gained.whose == MmTrigger.Whose.OPPONENT else "a player")
	var countered_on: CountersPutTrigger = trigger as CountersPutTrigger
	if countered_on != null:
		# CR 122.6: "Whenever one or more +1/+1 counters are put on this creature".
		var is_this: bool = countered_on.filter is IsSourceFilter
		var subject: String = _noun if is_this else _with_article(_noun_phrase(countered_on.filter, false, countered_on.whose))
		var counters: String = "one or more %s counters" % MmCounter.label(countered_on.kind)
		# Exemplar of Light: "Whenever you put one or more +1/+1 counters on this creature".
		if countered_on.by_whose == MmTrigger.Whose.YOU:
			return "whenever you put %s on %s" % [counters, subject]
		if countered_on.by_whose == MmTrigger.Whose.OPPONENT:
			return "whenever an opponent puts %s on %s" % [counters, subject]
		return "whenever %s are put on %s" % [counters, subject]
	var moved: ZoneChangeTrigger = trigger as ZoneChangeTrigger
	if moved != null:
		var is_self: bool = moved.filter is IsSourceFilter
		if (is_one_or_more or moved.is_one_or_more) and not is_self:
			return "whenever one or more %s %s" % [_noun_phrase(moved.filter, true, moved.whose), _move_verb(moved, true)]
		var either: AnyOfFilter = moved.filter as AnyOfFilter
		if either != null and either.filters.size() == 2 and either.filters[0] is IsSourceFilter:
			# Constellation's "Whenever this creature or another enchantment you control enters".
			return "whenever %s or another %s %s" % [_noun, _noun_phrase(either.filters[1], false, moved.whose),
				_move_verb(moved)]
		var subject: String = _noun if is_self else _with_article(_noun_phrase(moved.filter, false, moved.whose))
		var verb: String = _move_verb(moved)
		if verb == "dies" and (_noun != "this creature" if is_self else _names_only_noncreature_types(moved.filter)):
			# CR 700.4: "dies" is said of creatures; anything else, as the Wicked Role or Ashiok's
			# Reaper's "an enchantment you control", is put into a graveyard from the battlefield.
			verb = "is put into a graveyard from the battlefield"
		return "%s %s %s" % ["when" if is_self else "whenever", subject, verb]
	return _fallback(trigger, "_trigger")


## " during an opponent's turn", as Brineborn Cutthroat words it, or "" for any turn.
static func _during_turn(cast: SpellCastTrigger) -> String:
	if cast.during_whose_turn == MmTrigger.Whose.YOU:
		return " during your turn"
	if cast.during_whose_turn == MmTrigger.Whose.OPPONENT:
		return " during an opponent's turn"
	return ""


## Whether [param filter] names a card type, as "an enchantment" does, and none of the types
## it names is creature, so what it matches is not said to die (CR 700.4). A subtype alone,
## as "Zombie", names no card type.
static func _names_only_noncreature_types(filter: MmFilter) -> bool:
	var types: Array[MmCardTypes.CardType] = []
	var parts: Array[MmFilter] = [filter]
	if filter is AllOfFilter:
		parts = (filter as AllOfFilter).filters
	for part: MmFilter in parts:
		if part is HasCardTypeFilter:
			types.append((part as HasCardTypeFilter).card_type)
	return not types.is_empty() and not types.has(MmCardTypes.CardType.CREATURE)


## The verb of [param moved]: "enters", or with [param is_plural] "enter".
func _move_verb(moved: ZoneChangeTrigger, is_plural: bool = false) -> String:
	var from_battlefield: bool = not moved.any_from_zone and moved.from_zone == MmZone.Kind.BATTLEFIELD
	if moved.is_except_to_zone and not moved.any_to_zone:
		if from_battlefield and moved.to_zone == MmZone.Kind.GRAVEYARD:
			# CR 700.4, as Dour Port-Mage words it.
			return ("leave " if is_plural else "leaves ") + (ZONE_NAMES[moved.from_zone] as String) + " without dying"
		var from_zone: String = "anywhere" if moved.any_from_zone else (ZONE_NAMES[moved.from_zone] as String)
		return "%s put into anywhere but %s from %s" % ["are" if is_plural else "is", ZONE_NAMES[moved.to_zone], from_zone]
	if moved.any_to_zone:
		if moved.any_from_zone:
			return "change zones" if is_plural else "changes zones"
		return ("leave " if is_plural else "leaves ") + (ZONE_NAMES[moved.from_zone] as String)
	if moved.to_zone == MmZone.Kind.BATTLEFIELD and moved.any_from_zone:
		return "enter" if is_plural else "enters"
	if not moved.any_from_zone and moved.from_zone == MmZone.Kind.BATTLEFIELD and moved.to_zone == MmZone.Kind.GRAVEYARD:
		return "die" if is_plural else "dies"
	var from: String = "anywhere" if moved.any_from_zone else (ZONE_NAMES[moved.from_zone] as String)
	return "%s put into %s from %s" % ["are" if is_plural else "is", ZONE_NAMES[moved.to_zone], from]


func _condition(condition: MmCondition) -> String:
	var at_least: ValueAtLeastCondition = condition as ValueAtLeastCondition
	if at_least != null and at_least.value is CardsInZoneValue:
		# Threshold's "there are seven or more cards in your graveyard" (engine ADR 0080).
		return "there are %s or more %s" % [_number_word(at_least.amount),
			_cards_in_zone(at_least.value as CardsInZoneValue, true)]
	if at_least != null and at_least.value is CardsDrawnThisTurnValue:
		# Spinehorn Minotaur's "you've drawn two or more cards this turn".
		return "%s drawn %s or more cards this turn" % [_drawers((at_least.value as CardsDrawnThisTurnValue).players),
			_number_word(at_least.amount)]
	var at_most: ValueAtMostCondition = condition as ValueAtMostCondition
	if at_most != null and at_most.value is HandSizeValue and at_most.amount == 0:
		# Blood Scrivener's "you have no cards in hand" (engine ADR 0097).
		var holder: MmSelection = (at_most.value as HandSizeValue).players
		return "%s %s no cards in hand" % [_selection(holder), "have" if holder is YouSelection else "has"]
	if at_most != null:
		return "%s is %s or less" % [_value_phrase(at_most.value), _number_word(at_most.amount)]
	var controlled: String = "" if at_least == null else _you_control_condition(at_least)
	if controlled != "":
		return controlled
	if condition is LifeAtLeastStartingCondition:
		return "your life total is greater than or equal to your starting life total"
	if condition is LostLifeThisTurnCondition:
		# Bat Whisperer's "an opponent lost life this turn" (engine ADR 0082's second addendum).
		var whose: MmTrigger.Whose = (condition as LostLifeThisTurnCondition).whose
		var loser: String = "a player"
		if whose != MmTrigger.Whose.ANY:
			loser = "you" if whose == MmTrigger.Whose.YOU else "an opponent"
		return loser + " lost life this turn"
	if condition is CastAnotherSpellThisTurnCondition:
		return "you've cast another spell this turn"
	if condition is AttackedThisTurnCondition:
		return "you attacked this turn"  # Raid's (engine ADR 0095's addendum).
	if condition is GainedLifeThisTurnCondition:
		return "you gained life this turn"  # Infusion's (engine ADR 0082's addendum).
	if condition is DiedThisTurnCondition:
		# Engine ADR 0095, as Cult Conscript words it: "a non-Skeleton creature died under your
		# control this turn".
		var died: DiedThisTurnCondition = condition as DiedThisTurnCondition
		var what: String = _noun_phrase(died.filter, false) if died.filter != null else "permanent"
		var under: String = {MmTrigger.Whose.ANY: "", MmTrigger.Whose.YOU: " under your control",
			MmTrigger.Whose.OPPONENT: " under an opponent's control"}[died.whose]
		return "%s died%s this turn" % [_with_article(what), under]
	if condition is YouDidCondition:
		return "you do"
	if condition is TimesResolvedThisTurnCondition:
		return "this is the %s time this ability has resolved this turn" % _ordinal((condition as TimesResolvedThisTurnCondition).times)
	var matches: SelectionMatchesCondition = condition as SelectionMatchesCondition
	if matches == null:
		return _fallback(condition, "_condition")
	var subject: String = _selection(matches.selection)
	var greater: String = _greater_condition(subject, matches.filter)
	if greater != "":
		return greater
	var toughness: String = _toughness_condition(subject, matches.filter)
	if toughness != "":
		return toughness
	if matches.filter is HasCountersFilter:
		return "%s has %s" % [subject, _counters_on(matches.filter as HasCountersFilter)]
	if matches.filter is IsPermanentFilter:
		return "%s is a permanent card" % subject
	var words: FilterWords = _filter_words(matches.filter)
	var is_what: String = ", ".join(PackedStringArray(words.adjectives))
	if words.noun != "" or is_what == "":
		is_what = _with_article(_noun_phrase(matches.filter, false))
	return "%s %s %s" % [subject, "are" if subject == "you" else "is", is_what]


## "You control an artifact", or "you control three or more artifacts", as Gearsmith
## Prodigy's condition: [param at_least] over the number of [filter] you control, counted by
## an EachSelection whose Filter is that and a ControlledByFilter of yours. Otherwise "".
## "you've" or "[players] has", before "drawn ... this turn".
func _drawers(players: MmSelection) -> String:
	return "you've" if players is YouSelection else _selection(players) + " has"


func _you_control_condition(at_least: ValueAtLeastCondition) -> String:
	var count: CountValue = at_least.value as CountValue
	var each: EachSelection = null if count == null else count.selection as EachSelection
	var all: AllOfFilter = null if each == null else each.filter as AllOfFilter
	if all == null or at_least.amount < 1:
		return ""
	var rest: Array[MmFilter] = []
	var is_yours: bool = false
	for part: MmFilter in all.filters:
		var by: ControlledByFilter = part as ControlledByFilter
		if by != null and by.whose == MmTrigger.Whose.YOU and not is_yours:
			is_yours = true
		else:
			rest.append(part)
	if not is_yours or rest.is_empty():
		return ""
	var what: MmFilter = rest[0]
	if rest.size() > 1:
		var others: AllOfFilter = AllOfFilter.new()
		others.filters = rest
		what = others
	if at_least.amount == 1:
		return "you control " + _with_article(_noun_phrase(what, false))
	return "you control %s or more %s" % [_number_word(at_least.amount), _noun_phrase(what, true)]


## "[subject] has greater power or toughness than this creature", as evolve's reminder says
## (CR 702.100a): a PowerFilter, a ToughnessFilter, or an AnyOfFilter of one of each, each
## "[the other's power, or toughness] plus 1 or greater", of the same other. Otherwise "".
func _greater_condition(subject: String, filter: MmFilter) -> String:
	var parts: Array[MmFilter] = [filter]
	var any: AnyOfFilter = filter as AnyOfFilter
	if any != null:
		parts = any.filters
	var kinds: PackedStringArray = []
	var than: String = ""
	for part: MmFilter in parts:
		var kind: String = "power" if part is PowerFilter else ("toughness" if part is ToughnessFilter else "")
		var other: MmSelection = _greater_than_whom(part)
		if kind == "" or other == null or kinds.has(kind) or (than != "" and _selection(other) != than):
			return ""
		kinds.append(kind)
		than = _selection(other)
	if kinds.is_empty():
		return ""
	return "%s has greater %s than %s" % [subject, " or ".join(kinds), than]


## Whose power a PowerFilter of "[its power] plus 1 or greater" is greater than, or whose
## toughness a ToughnessFilter of the same is; null for any other Filter.
static func _greater_than_whom(filter: MmFilter) -> MmSelection:
	var bound: SumValue = null
	var compared: MmValue = null
	if filter is PowerFilter and (filter as PowerFilter).comparison == PowerFilter.Comparison.OR_GREATER:
		bound = (filter as PowerFilter).amount_value as SumValue
	elif filter is ToughnessFilter and (filter as ToughnessFilter).comparison == ToughnessFilter.Comparison.OR_GREATER:
		bound = (filter as ToughnessFilter).amount_value as SumValue
	if bound == null or bound.addends.size() != 2:
		return null
	var one: ConstantValue = bound.addends[1] as ConstantValue
	if one == null or one.value != 1:
		return null
	compared = bound.addends[0]
	if filter is PowerFilter and compared is PowerValue:
		return (compared as PowerValue).selection
	if filter is ToughnessFilter and compared is ToughnessValue:
		return (compared as ToughnessValue).selection
	return null


## "[subject]'s toughness is 4 or greater": a condition on toughness alone, a ToughnessFilter
## or a NotFilter around one, says whose toughness it is, and a power of that same subject in
## its bound is "its power", as Bark of Doran's "equipped creature's toughness is greater than
## its power". Otherwise "".
func _toughness_condition(subject: String, filter: MmFilter) -> String:
	var is_negated: bool = filter is NotFilter
	var toughness: ToughnessFilter = ((filter as NotFilter).filter if is_negated else filter) as ToughnessFilter
	if toughness == null:
		return ""
	var bound: String = _toughness_bound(toughness, is_negated)
	return "%s toughness is %s" % [_possessive(subject), bound.replace(_possessive(subject) + " power", "its power")]


## "Equipped creature assigns combat damage equal to its toughness rather than its power."; with
## a condition, "As long as [condition], it assigns ...", "it" when the condition was said of
## what assigns.
func _by_toughness(ability: AssignsCombatDamageByToughnessAbility) -> String:
	var affected: String = _selection(ability.affected)
	var assigns: String = " assigns combat damage equal to its toughness rather than its power."
	if ability.condition == null:
		return _capitalized(affected) + assigns
	var matches: SelectionMatchesCondition = ability.condition as SelectionMatchesCondition
	var subject: String = "it" if matches != null and _selection(matches.selection) == affected else affected
	return "As long as %s, %s%s" % [_condition(ability.condition), subject, assigns]


## A sentence for each effect, "Each white creature gets +1/+1."; or, with a condition, one
## sentence that names the source in the condition and calls it "it" after: "As long as
## this creature has a +1/+1 counter on it, it has flying and is a Knight in addition to
## its other types."
func _static(ability: ContinuousStaticAbility) -> String:
	var clauses: PackedStringArray = []
	if ability.condition == null:
		for continuous: MmContinuousEffect in ability.effects:
			_where = ""
			_for_each = ""
			var clause: String = _continuous(continuous, true)
			if _for_each != "":
				clause += " for each " + _for_each
			if _where != "":
				clause += ", where X is " + _where
			clauses.append(_ended(_capitalized(clause)))
		return " ".join(clauses)
	var condition: String = _condition(ability.condition)
	if ability.condition is ValueAtLeastCondition:
		# Threshold, as Oracle words it: "This creature gets +1/+1 as long as there are seven
		# or more cards in your graveyard." The condition names nothing for "it" to stand for.
		for continuous: MmContinuousEffect in ability.effects:
			clauses.append(_continuous(continuous, true))
		return _ended(_capitalized(_listed(clauses)) + " as long as " + condition)
	var noun: String = _noun
	_noun = "it"
	var subject: String = ""
	for continuous: MmContinuousEffect in ability.effects:
		var clause: String = _continuous(continuous, true)
		# "It has flying and is a Knight": a subject already said is not said again.
		var affected: String = "" if continuous.affected == null or continuous.affected.is_targeted() \
			else _selection(continuous.affected)
		if clauses.is_empty():
			subject = affected
		elif affected != "" and affected == subject and clause.begins_with(subject + " "):
			clause = clause.substr(subject.length() + 1)
		clauses.append(clause)
	_noun = noun
	return _ended("As long as %s, %s" % [condition, _listed(clauses)])


## [param sentence] with its period, unless it ends in a quoted ability whose own period
## closes it, as Oracle prints "have \"{1}, {T}: Tap target creature.\"".
static func _ended(sentence: String) -> String:
	return sentence if sentence.ends_with(".\"") else sentence + "."


## "A and B", or "A, B, and C".
static func _listed(parts: PackedStringArray) -> String:
	if parts.size() <= 2:
		return " and ".join(parts)
	return ", ".join(parts.slice(0, -1)) + ", and " + parts[parts.size() - 1]


func _characteristic_defining(ability: CharacteristicDefiningAbility) -> String:
	var owner: String = _capitalized(_possessive(_noun))
	if ability.toughness == null:
		return "%s power is equal to %s." % [owner, _value_phrase(ability.power)]
	if ability.power == null:
		return "%s toughness is equal to %s." % [owner, _value_phrase(ability.toughness)]
	var power: String = _value_phrase(ability.power)
	var toughness: String = _value_phrase(ability.toughness)
	if power == toughness:
		return "%s power and toughness are each equal to %s." % [owner, power]
	return "%s power is equal to %s and its toughness is equal to %s." % [owner, power, toughness]


func _additional(count: int, thing: String) -> String:
	if count == 1:
		return "an additional " + thing
	return "%s additional %ss" % [_number_word(count), thing]


# --- Effects -------------------------------------------------------------------------

## One sentence for each effect. With [param starts_sentence] false the first begins in
## lower case, to follow a trigger.
func _sentences(effects: Array[MmEffect], starts_sentence: bool) -> String:
	var sentences: PackedStringArray = []
	var index: int = 0
	while index < effects.size():
		var effect: MmEffect = effects[index]
		index += 1
		_where = ""
		_for_each = ""
		_for_each_of = ""
		var clause: String = ""
		var becoming: int = _becomes_run(effects, index - 1)
		if becoming > 0:
			clause = _becomes(effects.slice(index - 1, index - 1 + becoming))
			index += becoming - 1  # The rest of the run is said in the same clause.
		elif index < effects.size():
			clause = _gets_and_gains(effect, effects[index])
			if clause != "":
				index += 1  # The second effect is said in the same clause.
		if clause == "":
			clause = _effect(effect)
		if _for_each != "":
			clause += " for each " + _for_each
		if _where != "":
			clause += ", where X is " + _where
		if _for_each_of != "":
			clause = "for each of %s, %s" % [_for_each_of, clause]
		var is_first: bool = sentences.is_empty()
		sentences.append((clause if is_first and not starts_sentence else _capitalized(clause)) + ".")
		var destroy: DestroyEffect = effect as DestroyEffect
		if destroy != null and not destroy.can_be_regenerated:
			sentences.append("They can't be regenerated." if destroy.selection is OverloadedSelection else "It can't be regenerated.")
	return " ".join(sentences)


func _effect(effect: MmEffect) -> String:
	if effect is DealDamageEffect:
		var damage: DealDamageEffect = effect as DealDamageEffect
		var dealer: String = _noun
		if damage.source is TriggeringObjectSelection:
			dealer = "it"  # Oracle wording: "Whenever a creature you control enters, it deals ...".
		elif damage.source != null:
			dealer = _selection(damage.source)
		if not damage.amount is ConstantValue:
			# Oracle wording: "deals damage to target creature equal to the number of ...".
			return "%s deals damage to %s equal to %s" % [dealer, _selection(damage.recipients), _value_phrase(damage.amount)]
		return "%s deals %s damage to %s" % [dealer, _amount(damage.amount), _selection(damage.recipients)]
	if effect is DrawCardsEffect:
		var draw: DrawCardsEffect = effect as DrawCardsEffect
		if draw.players is YouSelection:
			# Oracle wording: you are told to "draw two cards", not that "you draw" them.
			return "draw " + _cards(draw.amount)
		return "%s %s %s" % [_selection(draw.players), _verb(draw.players, "draw"), _cards(draw.amount)]
	if effect is DiscardEffect:
		# CR 701.9a: as drawing is, "discard a card" for you, "each opponent discards a card".
		var discarding: DiscardEffect = effect as DiscardEffect
		if discarding.players is YouSelection:
			return "discard " + _cards(discarding.amount)
		return "%s %s %s" % [_selection(discarding.players), _verb(discarding.players, "discard"), _cards(discarding.amount)]
	if effect is SacrificeEffect:
		# CR 701.21a, as Agent of the Fates words it: "each opponent sacrifices a creature".
		var sacrificing: SacrificeEffect = effect as SacrificeEffect
		var what: String = _how_many(sacrificing.count, sacrificing.filter)
		if sacrificing.players is YouSelection:
			return "sacrifice " + what
		return "%s %s %s" % [_selection(sacrificing.players), _verb(sacrificing.players, "sacrifice"), what]
	if effect is GainLifeEffect:
		var gain: GainLifeEffect = effect as GainLifeEffect
		return "%s %s %s life" % [_selection(gain.players), _verb(gain.players, "gain"), _amount(gain.amount)]
	if effect is LoseLifeEffect:
		var lose: LoseLifeEffect = effect as LoseLifeEffect
		return "%s %s %s life" % [_selection(lose.players), _verb(lose.players, "lose"), _amount(lose.amount)]
	if effect is AdditionalLandPlaysEffect:
		var lands: AdditionalLandPlaysEffect = effect as AdditionalLandPlaysEffect
		return "%s may play %s this turn" % [_selection(lands.players), _additional_lands(lands.count)]
	if effect is AddManaEffect:
		return "add " + _mana(effect as AddManaEffect)
	if effect is DestroyEffect:
		return "destroy " + _selection((effect as DestroyEffect).selection)
	if effect is CounterEffect:
		var countering: CounterEffect = effect as CounterEffect
		var unless: String = "" if countering.unless_paid == null \
			else " unless its controller pays " + countering.unless_paid.describe()  # CR 118.12
		return "counter " + _selection(countering.selection) + unless
	if effect is ExileEffect:
		var exiling: ExileEffect = effect as ExileEffect
		# CR 610.3: "until" its source leaves, as Leyline Binding's.
		var until: String = " until %s leaves the battlefield" % _noun if exiling.until_source_leaves else ""
		_exiles_several = _exiles_several or exiling.selection is OverloadedSelection
		return "exile " + _selection(exiling.selection) + until
	if effect is ReturnToBattlefieldEffect:
		var back: ReturnToBattlefieldEffect = effect as ReturnToBattlefieldEffect
		# A card that can only be your own returns under your control, so Oracle leaves out
		# "under its owner's control", as Helping Hand does.
		var is_several: bool = _is_several(back.selection)
		var arriving: String = " tapped and attacking" if back.tapped and back.attacking \
			else (" tapped" if back.tapped else (" attacking" if back.attacking else ""))
		var text: String = "return %s to the battlefield%s%s" % [_returned(back.selection), arriving,
			"" if _is_yours(back.selection) else (" under their owners' control" if is_several else " under its owner's control")]
		return text if back.counters == null else text + " with %s on %s" % [_counters(back.counters, back.counter_kind),
			"each of them" if is_several else "it"]
	if effect is ExileTopOfLibraryEffect:
		# Clockwork Percussionist's "exile the top card of your library" (engine ADR 0100).
		var exiling: ExileTopOfLibraryEffect = effect as ExileTopOfLibraryEffect
		var constant: ConstantValue = exiling.amount as ConstantValue
		var top: String = "the top card" if constant != null and constant.value == 1 \
			else "the top %s" % _cards(exiling.amount)
		if exiling.players is YouSelection:
			return "exile %s of your library" % top
		return "%s %s %s of %s library" % [_selection(exiling.players), _verb(exiling.players, "exile"), top,
			"their" if _is_several(exiling.players) else "its owner's"]
	if effect is MayPlayExiledEffect:
		# Engine ADR 0100: "You may play it until the end of your next turn", or "this turn".
		var playing: MayPlayExiledEffect = effect as MayPlayExiledEffect
		var it: String = "it" if playing.selection is MovedCardsSelection else _selection(playing.selection)
		if playing.duration == MayPlayExiledEffect.Duration.THIS_TURN:
			return "you may play %s this turn" % it
		return "you may play %s until the end of your next turn" % it
	if effect is MillEffect:
		# CR 701.17a, as Oracle words it: "mill four cards", "each opponent mills four cards".
		var milling: MillEffect = effect as MillEffect
		if milling.players is YouSelection:
			return "mill " + _cards(milling.amount)
		return "%s %s %s" % [_selection(milling.players), _verb(milling.players, "mill"), _cards(milling.amount)]
	var from_among: ChosenSelection = (effect as ReturnToHandEffect).selection as ChosenSelection if effect is ReturnToHandEffect else null
	if from_among != null and from_among.from_among is MovedCardsSelection:
		# Engine ADR 0080: "put an instant or sorcery card from among them into your hand".
		return "put %s card from among them into your hand" % _with_article(_noun_phrase(from_among.filter, false))
	if effect is ReturnToHandEffect:
		var returned: MmSelection = (effect as ReturnToHandEffect).selection
		return "return %s to %s hand" % [_returned(returned), "your" if _is_yours(returned) else "its owner's"]
	if effect is PutOnBottomOfLibraryEffect:
		# Landscaper Colos's "put target card from an opponent's graveyard on the bottom of
		# their library", where "their" is its owner.
		var bottomed: MmSelection = (effect as PutOnBottomOfLibraryEffect).selection
		return "put %s on the bottom of %s library" % [_selection(bottomed), "your" if _is_yours(bottomed) else "its owner's"]
	if effect is TapEffect:
		return "tap " + _selection((effect as TapEffect).selection)
	if effect is ExploreEffect:
		# CR 701.44a, engine ADR 0090: "target creature you control explores".
		return _selection((effect as ExploreEffect).selection) + " explores"
	if effect is DoesntUntapEffect:
		# CR 502.3, as Niblis of Frost says it: "That creature doesn't untap during its
		# controller's next untap step", naming again what was just tapped.
		_names_again_with_that = true
		var frozen: String = _selection((effect as DoesntUntapEffect).selection)
		_names_again_with_that = false
		return frozen + " doesn't untap during its controller's next untap step"
	if effect is CantBlockThisTurnEffect:
		# CR 509.1a, Arena Athlete's "target creature an opponent controls can't block this turn".
		return _selection((effect as CantBlockThisTurnEffect).selection) + " can't block this turn"
	if effect is DamageCantBePreventedEffect:
		return "damage can't be prevented this turn"  # CR 615.12, Stomp's.
	if effect is UntapEffect:
		return "untap " + _selection((effect as UntapEffect).selection)
	if effect is IfEffect and (effect as IfEffect).is_unless:
		# CR 608.2c, Splitskin Doll's "discard a card unless you control another creature ...".
		var unless: IfEffect = effect as IfEffect
		return "%s unless %s" % [_effect(unless.effect), _condition(unless.condition)]
	if effect is IfEffect:
		var conditional: IfEffect = effect as IfEffect
		# CR 608.2c, a sentence of its own: "If it is a permanent card, put ...".
		return "if %s, %s" % [_condition(conditional.condition), _effect(conditional.effect)]
	if effect is UnattachEffect:
		return "unattach " + _selection((effect as UnattachEffect).selection)
	if effect is AttachEffect:
		return "attach %s to %s" % [_selection((effect as AttachEffect).attachment), _selection((effect as AttachEffect).to)]
	if effect is RegenerateEffect:
		return "regenerate " + _selection((effect as RegenerateEffect).selection)
	if effect is PreventDamageEffect:
		return _prevention(effect as PreventDamageEffect)
	if effect is PutCountersEffect:
		var put: PutCountersEffect = effect as PutCountersEffect
		# "On each of up to two target creatures": the counters go on every one chosen.
		var each_of: String = "each of " if _is_several_targets(put.recipients) else ""
		return "put %s on %s%s" % [_counters(put.amount, put.kind), each_of, _selection(put.recipients)]
	if effect is FightEffect:
		# CR 701.14a, without its reminder text.
		var fight: FightEffect = effect as FightEffect
		return "%s fights %s" % [_selection(fight.creature), _selection(fight.other)]
	if effect is DoubleCountersEffect:
		var doubled: DoubleCountersEffect = effect as DoubleCountersEffect
		return "double the number of %s counters on %s" % [MmCounter.label(doubled.kind), _selection(doubled.recipients)]
	if effect is InsteadEffect:
		return _instead(effect as InsteadEffect)
	if effect is MayEffect:
		var maybe: MmEffect = (effect as MayEffect).effect
		var created_maybe: CreateContinuousEffect = maybe as CreateContinuousEffect
		if created_maybe != null and not created_maybe.continuous.affected is YouSelection:
			# Blightcaster: "you may have target creature get -2/-2 until end of turn".
			return "you may have %s%s" % [_continuous(created_maybe.continuous, false, true),
				_duration_words(created_maybe.duration)]
		if maybe is DealDamageEffect:
			# Igneous Elemental: "you may have this creature deal 2 damage to target creature".
			return "you may have " + _effect(maybe).replace(" deals ", " deal ")
		# CR 603.5: "you may tap target creature".
		return "you may " + _effect(maybe)
	if effect is MayPayEffect:
		# ADR 0076: "you may remove a +1/+1 counter from this creature. If you do, ..."
		var paying: MayPayEffect = effect as MayPayEffect
		if paying.mana_cost != null:
			# Myrsmith's "you may pay {1}. If you do, create ...".
			return "you may pay %s. If you do, %s" % [paying.mana_cost.describe(), _effect(paying.effect)]
		var cost: String = ", ".join(_cost_parts(null, [paying.cost] as Array[MmCost]))
		var uncapitalized: String = cost.left(1).to_lower() + cost.substr(1)
		if paying.effect is ReflexiveTriggerEffect:
			# CR 603.12, engine ADR 0088: "you may exile ... When you do, return ...".
			return "you may %s. When you do, %s" % [uncapitalized,
				_reflexive_words(paying.effect as ReflexiveTriggerEffect)]
		var done: String = "you may %s. If you do, %s" % [uncapitalized, _effect(paying.effect)]
		# Engine ADR 0054's second addendum: Irreverent Gremlin's, a sentence of its own.
		return done + (". Do this only once each turn" if paying.is_once_each_turn else "")
	if effect is ReflexiveTriggerEffect:
		return "when you do, " + _reflexive_words(effect as ReflexiveTriggerEffect)
	if effect is CreateDelayedTriggerEffect:
		return _delayed_words(effect as CreateDelayedTriggerEffect)
	if effect is SacrificeSelectedEffect:
		return "sacrifice " + _selection((effect as SacrificeSelectedEffect).selection)
	if effect is MayPayXEffect:
		var paying_x: MayPayXEffect = effect as MayPayXEffect
		if paying_x.effect is ReflexiveTriggerEffect:
			# Engine ADR 0088's fifth addendum, as Wildborn Preserver words it: "you may pay
			# {X}. When you do, put X +1/+1 counters on this creature."
			return "you may pay {X}. When you do, " + _reflexive_words(paying_x.effect as ReflexiveTriggerEffect)
		# ADR 0061: "you may pay {X}. If you do, search your library for ...".
		return "you may pay {X}. If you do, " + _effect(paying_x.effect)
	if effect is CreateContinuousEffect:
		# CR 611.2a: one with no duration says none (engine ADR 0091).
		var created: CreateContinuousEffect = effect as CreateContinuousEffect
		return _continuous(created.continuous, false) + _duration_words(created.duration)
	if effect is CastWithoutPayingEffect:
		# Engine ADR 0104, Goblin Dark-Dwellers: "cast target instant or sorcery card with mana
		# value 3 or less from your graveyard without paying its mana cost".
		var casting: CastWithoutPayingEffect = effect as CastWithoutPayingEffect
		var words: String = "cast %s without paying its mana cost" % _selection(casting.selection)
		if casting.is_exiled_instead_of_graveyard:
			words += ". If that spell would be put into your graveyard, exile it instead"
		return words
	if effect is CreateTokenEffect:
		return "create " + _tokens(effect as CreateTokenEffect)
	if effect is CopySpellEffect:
		# CR 707.10: "copy this spell", the spell itself whatever it is, or "copy target spell".
		var copied: MmSelection = (effect as CopySpellEffect).selection
		return "copy this spell" if copied is SourceSelection else "copy " + _selection(copied)
	if effect is CreateTokenCopyEffect:
		# CR 707.2, as Oltec Matterweaver words it.
		var copy: CreateTokenCopyEffect = effect as CreateTokenCopyEffect
		if copy.amount == 1:
			return "create a token that's a copy of " + _selection(copy.selection)
		return "create %s tokens that are copies of %s" % [_number_word(copy.amount), _selection(copy.selection)]
	if effect is SearchLibraryEffect:
		return _search(effect as SearchLibraryEffect)
	if effect is LookAtTopCardsEffect:
		return _look(effect as LookAtTopCardsEffect)
	if effect is SurveilEffect:
		# CR 701.25a, with its number as digits, as Oracle words it ("surveil 1").
		return "surveil " + _amount((effect as SurveilEffect).amount)
	if effect is ScryEffect:
		# CR 701.22a, with its number as digits, as Oracle words it ("scry 1").
		return "scry " + _amount((effect as ScryEffect).amount)
	return _fallback(effect, "_effect")


## CR 701.23, as Oracle words it: "search your library for a basic land card, reveal it,
## put it into your hand, then shuffle", or "up to two Plains cards ... reveal them".
func _search(effect: SearchLibraryEffect) -> String:
	var constant: ConstantValue = effect.amount as ConstantValue
	var is_one: bool = constant != null and constant.value == 1
	var found: String = ""
	if is_one:
		found = _with_article(_card_phrase(effect.filter, false))
	else:
		var how_many: String = _number_word(constant.value) if constant != null else _amount(effect.amount)
		found = "up to %s %s" % [how_many, _card_phrase(effect.filter, true)]
	var them: String = "it" if is_one else "them"
	var put: String = ""
	match effect.destination:
		MmZone.Kind.HAND:
			put = "put %s into your hand" % them
		MmZone.Kind.BATTLEFIELD:
			put = "put %s onto the battlefield%s" % [them, " tapped" if effect.tapped else ""]
		MmZone.Kind.GRAVEYARD:
			put = "put %s into your graveyard" % them
		MmZone.Kind.EXILE:
			put = "exile " + them
	var reveal: String = ("reveal %s, " % them) if effect.reveal else ""
	return "search your library for %s, %s%s, then shuffle" % [found, reveal, put]


## CR 701.20e, as Militia Bugler words it: "look at the top four cards of your library. You
## may reveal a creature card with power 2 or less from among them and put it into your hand.
## Put the rest on the bottom of your library in a random order". Three sentences in one
## effect, the caller ending the last.
# Later: more than one taken ("up to two"), once a card says so.
func _look(effect: LookAtTopCardsEffect) -> String:
	var constant: ConstantValue = effect.amount as ConstantValue
	var how_many: String = _number_word(constant.value) if constant != null else _amount(effect.amount)
	var looked: String = "look at the top %s cards of your library" % how_many
	var taken: String = _with_article(_card_phrase(effect.filter, false))
	var take: String = ("You may reveal %s from among them and put it into your hand" % taken) if effect.reveal \
		else ("You may put %s from among them into your hand" % taken)
	var order: String = "any order" if effect.is_rest_in_any_order else "a random order"  # Faerie Mechanist's, Militia Bugler's.
	return "%s. %s. Put the rest on the bottom of your library in %s" % [looked, take, order]


## "Basic land card" or "Plains cards": a Filter's words as cards in a hidden zone.
func _card_phrase(filter: MmFilter, is_plural: bool) -> String:
	var words: FilterWords = _filter_words(filter)
	var parts: PackedStringArray = PackedStringArray(words.adjectives)
	if words.noun != "":
		parts.append(words.noun)
	parts.append("cards" if is_plural else "card")
	var after: PackedStringArray = PackedStringArray(words.after)
	return " ".join(parts) if after.is_empty() else " ".join(parts) + " " + " ".join(after)



## CR 608.2c, as Oracle words it: "[effect]. If [condition], [other effect] instead", one
## sentence and the start of the next, which _sentences() ends.
func _instead(effect: InsteadEffect) -> String:
	var usual: String = _effect(effect.effect)
	var condition: String = _condition(effect.condition)
	_names_again_with_that = true
	var other: String = _effect(effect.instead)
	_names_again_with_that = false
	return "%s. If %s, %s instead" % [usual, condition, other]


## Oracle's token wording (CR 111.4): "a 1/1 white Cat creature token", "two ... tokens",
## and a token's keywords after "with": "a 1/1 white Cat Soldier creature token with vigilance",
## then "that's attacking" (or "that are attacking") last, as Brimaz, King of Oreskos says,
## or "that's blocking that creature" (or "that are blocking"), or "attached to target
## creature you control". A predefined token is named alone: "a Treasure token", "a Wicked
## Role token" (CR 111.10).
func _tokens(effect: CreateTokenEffect) -> String:
	if effect.token == null:
		return _fallback(effect, "_tokens")
	var predefined: String = effect.token.name.trim_suffix(" Token")
	var phrase: String = predefined
	var with: String = ""
	# CR 111.10: a Role token is predefined too, and named by its name, as the Wicked Role is;
	# it calls itself "this Aura" all the same, so it is not among PREDEFINED_TOKENS.
	if not PREDEFINED_TOKENS.has(predefined) and not effect.token.subtypes.has(AttachmentRules.ROLE):
		var keywords: PackedStringArray = PackedStringArray()
		for ability: MmAbility in effect.token.abilities:
			var keyword: String = _keyword(ability)
			if keyword == "":
				# Later: a token's other abilities, in quotation marks (CR 111.4).
				return _fallback(effect, "_tokens")
			keywords.append(keyword.to_lower())
		with = "" if keywords.is_empty() else " with " + _listed(keywords)
		phrase = _token_phrase(MmCharacteristics.printed(effect.token))
	var combat: String = ""
	if effect.attacking:
		combat = " that's attacking" if effect.amount == 1 else " that are attacking"
	elif effect.blocking != null:
		combat = (" that's blocking " if effect.amount == 1 else " that are blocking ") + _selection(effect.blocking)
	elif effect.attached_to != null:
		combat = " attached to " + _selection(effect.attached_to)  # Price of Beauty's (CR 303.4).
	if effect.amount == 1:
		return _with_article(phrase + " token") + with + combat
	return "%s %s tokens%s%s" % [_number_word(effect.amount), phrase, with, combat]


## What a token with [param printed] is, before "token": "1/1 white Cat creature".
func _token_phrase(printed: MmCharacteristics) -> String:
	var words: PackedStringArray = PackedStringArray()
	if printed.has_card_type(MmCardTypes.CardType.CREATURE):
		words.append("%d/%d" % [printed.base_power, printed.base_toughness])
	var colors: PackedStringArray = PackedStringArray()
	for color: MmCardTypes.CardColor in printed.colors:
		colors.append(_color_word(color))
	words.append(" and ".join(colors) if not colors.is_empty() else "colorless")
	for subtype: String in printed.subtypes:
		words.append(subtype)
	for card_type: MmCardTypes.CardType in printed.card_types:
		words.append(_type_word(card_type))
	return " ".join(words)


## "{G}", "{B}{B}{B}", for mana of any color "one mana of any color" (CR 106.1a), for mana
## of one of some colors "{U}, {B}, or {R}" in the order printed, or the symbol of the color
## an Option Menu row's activation makes (ADR 0072).
func _mana(effect: AddManaEffect) -> String:
	var constant: ConstantValue = effect.amount as ConstantValue
	var is_chosen: bool = not effect.colors_to_choose().is_empty()
	if is_chosen and _chosen_mana_type == MmMana.NO_TYPE:
		if constant == null or constant.value != 1:
			return _fallback(effect, "_mana")  # Later: "two mana of any one color".
		if effect.is_any_color:
			return "one mana of any color"
		var symbols: Array[String] = []
		for color: MmMana.Type in effect.color_choices:
			symbols.append("{%s}" % MmMana.SYMBOLS[color])
		if symbols.size() <= 2:
			return " or ".join(symbols)
		return ", ".join(symbols.slice(0, -1)) + ", or " + symbols.back()
	var type: MmMana.Type = _chosen_mana_type as MmMana.Type if is_chosen else effect.mana_type
	var symbol: String = "{%s}" % MmMana.SYMBOLS[type]
	if constant != null and constant.value >= 1 and constant.value <= 10:
		return symbol.repeat(constant.value)
	return "%s %s" % [_amount(effect.amount), symbol]


func _prevention(effect: PreventDamageEffect) -> String:
	var to_whom: String = "" if effect.recipients == null else " to " + _selection(effect.recipients)
	if effect.uses == PreventDamageEffect.Uses.NEXT_AMOUNT:
		return "prevent the next %s damage that would be dealt%s this turn" % [_amount(effect.amount), to_whom]
	var by_whom: String = "" if effect.sources == null else " by " + _noun_phrase(effect.sources, true)
	return "prevent all %sdamage that would be dealt%s%s this turn" % ["combat " if effect.combat_only else "", to_whom, by_whom]


## What [param continuous] does. A static ability's says "has" and "is" where a resolved
## effect's says "gains" and "becomes" ([param is_static]). With [param is_bare] its verb is
## as it is after "have": "target creature get -2/-2".
func _continuous(continuous: MmContinuousEffect, is_static: bool, is_bare: bool = false) -> String:
	var affected: String = _selection(continuous.affected)
	if continuous is ModifyPowerToughnessContinuousEffect:
		var modify: ModifyPowerToughnessContinuousEffect = continuous as ModifyPowerToughnessContinuousEffect
		return "%s %s %s" % [affected, _bare_or_verb(continuous.affected, is_bare, "get"), _change(modify.power, modify.toughness)]
	if continuous is SetPowerToughnessContinuousEffect:
		var set_to: SetPowerToughnessContinuousEffect = continuous as SetPowerToughnessContinuousEffect
		return "%s %s base power and toughness %s/%s" % [affected, "have" if affected == "you" or is_bare else "has",
			_value_phrase(set_to.power), _value_phrase(set_to.toughness)]
	if continuous is GainAbilitiesContinuousEffect:
		var gained: PackedStringArray = []
		for ability: MmAbility in (continuous as GainAbilitiesContinuousEffect).abilities:
			var text: String = _ability(ability)
			gained.append(text.to_lower() if is_keyword(ability) else "\"%s\"" % text)
		var gains: String = _bare_or_verb(continuous.affected, is_bare, "gain")
		if is_static:
			gains = "have" if continuous.affected is YouSelection else "has"
		return "%s %s %s" % [affected, gains, " and ".join(gained)]
	if continuous is AddSubtypesContinuousEffect:
		var subtypes: PackedStringArray = PackedStringArray((continuous as AddSubtypesContinuousEffect).subtypes)
		var added: String = _with_article(" ".join(subtypes))
		if _is_every_basic_land_type(subtypes):
			added = "every basic land type"
		return "%s %s %s in addition to its other types" % [affected,
			"is" if is_static else _bare_or_verb(continuous.affected, is_bare, "become"), added]
	if continuous is SetCreatureTypesContinuousEffect:
		# CR 205.1a, as Mild-Mannered Librarian words it: "This creature becomes a Werewolf."
		var creature_types: PackedStringArray = PackedStringArray((continuous as SetCreatureTypesContinuousEffect).creature_types)
		return "%s %s %s" % [affected, "is" if is_static else _bare_or_verb(continuous.affected, is_bare, "become"),
			_with_article(" ".join(creature_types))]
	if continuous is LoseAllAbilitiesContinuousEffect:
		return "%s %s all abilities" % [affected, _bare_or_verb(continuous.affected, is_bare, "lose")]
	if continuous is AddCardTypesContinuousEffect:
		# CR 205.1b, engine ADR 0091: "becomes an artifact creature", keeping its other types.
		return "%s %s %s" % [affected, "is" if is_static else _bare_or_verb(continuous.affected, is_bare, "become"),
			_with_article(_card_type_words((continuous as AddCardTypesContinuousEffect).card_types))]
	return _fallback(continuous, "_continuous_effect")


## Destiny Spinner's "Creature and enchantment spells you control can't be countered."
## (engine ADR 0062's second addendum): each kind of spell its filter allows, joined by "and".
func _spells_cant_be_countered(ability: SpellsCantBeCounteredAbility) -> String:
	if ability.filter == null:
		return "Spells you control can't be countered."
	var kinds: PackedStringArray = []
	var either: AnyOfFilter = ability.filter as AnyOfFilter
	if either != null:
		for part: MmFilter in either.filters:
			kinds.append(_noun_phrase(part, false))
	else:
		kinds.append(_noun_phrase(ability.filter, false))
	return _capitalized(" and ".join(kinds)) + " spells you control can't be countered."


## " until end of turn", or nothing for an effect with no duration (CR 611.2a).
static func _duration_words(duration: CreateContinuousEffect.Duration) -> String:
	return " until end of turn" if duration == CreateContinuousEffect.Duration.UNTIL_END_OF_TURN else ""


## "artifact creature": [param card_types] in lower case, in their order.
static func _card_type_words(card_types: Array[MmCardTypes.CardType]) -> String:
	var words: PackedStringArray = []
	for card_type: MmCardTypes.CardType in card_types:
		words.append(String(MmCardTypes.CardType.find_key(card_type)).to_lower())
	return " ".join(words)


## How many of [param effects] from [param start] say one "becomes" clause, as Bring to
## Life's "target noncreature artifact you control becomes a 0/0 artifact creature" (engine
## ADR 0091) and Destiny Spinner's "target land you control becomes an X/X Elemental creature
## with trample and haste until end of turn": card types added, then any subtypes added, then
## base power and toughness set, then any abilities gained, each of the same object for as
## long. 0 when they say no such clause.
func _becomes_run(effects: Array[MmEffect], start: int) -> int:
	var first: CreateContinuousEffect = effects[start] as CreateContinuousEffect
	if first == null or not first.continuous is AddCardTypesContinuousEffect:
		return 0
	var at: int = start + 1
	if _continues(effects, at, first, AddSubtypesContinuousEffect):
		at += 1
	if not _continues(effects, at, first, SetPowerToughnessContinuousEffect):
		return 0
	at += 1
	if _continues(effects, at, first, GainAbilitiesContinuousEffect):
		at += 1
	return at - start


## Whether [param effects] at [param at] creates a continuous effect of [param kind] for the
## same object as [param first], and for as long.
func _continues(effects: Array[MmEffect], at: int, first: CreateContinuousEffect, kind: Script) -> bool:
	if at >= effects.size():
		return false
	var next: CreateContinuousEffect = effects[at] as CreateContinuousEffect
	return next != null and next.duration == first.duration and next.continuous.get_script() == kind \
		and _same_selection(first.continuous.affected, next.continuous.affected)


## The "becomes" clause [param run] says (_becomes_run()): "becomes a 4/4 artifact creature",
## or with an X for power and toughness alike "becomes an X/X Elemental creature with trample
## and haste", what X is kept for the end of the sentence. The object keeps its other types
## (CR 205.1b), as "It's still a land." says, so that is not said.
func _becomes(run: Array[MmEffect]) -> String:
	var types: CreateContinuousEffect = run[0] as CreateContinuousEffect
	var adding: AddCardTypesContinuousEffect = types.continuous as AddCardTypesContinuousEffect
	var made: PackedStringArray = []
	var with: PackedStringArray = []
	for effect: MmEffect in run.slice(1):
		var continuous: MmContinuousEffect = (effect as CreateContinuousEffect).continuous
		if continuous is SetPowerToughnessContinuousEffect:
			made.insert(0, _base_words(continuous as SetPowerToughnessContinuousEffect))
		elif continuous is AddSubtypesContinuousEffect:
			made.append(" ".join(PackedStringArray((continuous as AddSubtypesContinuousEffect).subtypes)))
		elif continuous is GainAbilitiesContinuousEffect:
			for ability: MmAbility in (continuous as GainAbilitiesContinuousEffect).abilities:
				var text: String = _ability(ability)
				with.append(text.to_lower() if is_keyword(ability) else "\"%s\"" % text)
	made.append(_card_type_words(adding.card_types))
	var becomes: String = "%s %s %s" % [_selection(adding.affected), _verb(adding.affected, "become"),
		_with_article(" ".join(made))]
	if not with.is_empty():
		becomes += " with " + " and ".join(with)
	return becomes + _duration_words(types.duration)


## "4/4", or "X/X" with what X is kept for the end of the sentence when power and toughness
## are one number that is not a constant.
func _base_words(set_to: SetPowerToughnessContinuousEffect) -> String:
	var power: String = _value_phrase(set_to.power)
	var toughness: String = _value_phrase(set_to.toughness)
	if set_to.power is ConstantValue or power != toughness:
		return "%s/%s" % [power, toughness]
	_where = power
	return "X/X"


## Faerie Guidemother's "target creature gets +2/+1 and gains flying until end of turn":
## [param first] changing power and toughness and [param second] giving abilities, of the
## same object for as long, as one clause; "" for any other pair. Several targets each get
## and gain, as Karfell Kennel-Master's "up to two target creatures each get +1/+0 and gain
## indestructible until end of turn".
func _gets_and_gains(first: MmEffect, second: MmEffect) -> String:
	var pump: CreateContinuousEffect = first as CreateContinuousEffect
	var gain: CreateContinuousEffect = second as CreateContinuousEffect
	if pump == null or gain == null or pump.duration != gain.duration:
		return ""
	var modify: ModifyPowerToughnessContinuousEffect = pump.continuous as ModifyPowerToughnessContinuousEffect
	var gaining: GainAbilitiesContinuousEffect = gain.continuous as GainAbilitiesContinuousEffect
	if modify == null or gaining == null or not _same_selection(modify.affected, gaining.affected):
		return ""
	var gets: String = _continuous(modify, false)
	# The object is named once, in the first half; the second says only what it gains.
	var gained: String = _continuous(gaining, false)
	var gains: String = gained.substr(gained.find(" gain") + 1)
	if _is_several_targets(modify.affected):
		gets = gets.replace(" gets ", " each get ")
		gains = "gain " + gains.trim_prefix("gains ")
	return gets + " and " + gains + _duration_words(pump.duration)


## Whether [param first] and [param second] find the same object: the same target, or both
## "this".
static func _same_selection(first: MmSelection, second: MmSelection) -> bool:
	if first is TargetSelection and second is TargetSelection:
		return (first as TargetSelection).target_index == (second as TargetSelection).target_index
	return first is SourceSelection and second is SourceSelection


## Whether [param subtypes] are the five basic land types, each once, in any order: what
## Nylea's Presence calls "every basic land type".
static func _is_every_basic_land_type(subtypes: PackedStringArray) -> bool:
	if subtypes.size() != MmCardTypes.BASIC_LAND_TYPES.size():
		return false
	for land_type: String in MmCardTypes.BASIC_LAND_TYPES:
		if not subtypes.has(land_type):
			return false
	return true


## "+3/+3", "-2/-0": a zero takes the other number's sign, as cards print it. "-0/-X" is a
## change by 0 minus an amount, as Monoist Circuit-Feeder's "-0/-X, where X is the number of
## artifacts you control".
func _change(power: MmValue, toughness: MmValue) -> String:
	var power_constant: ConstantValue = power as ConstantValue
	var toughness_constant: ConstantValue = toughness as ConstantValue
	var lowered_power: MmValue = _lowered_by(power)
	var lowered_toughness: MmValue = _lowered_by(toughness)
	if lowered_power != null or lowered_toughness != null:
		var is_zero_power: bool = power_constant != null and power_constant.value == 0
		var is_zero_toughness: bool = toughness_constant != null and toughness_constant.value == 0
		if (lowered_power != null or is_zero_power) and (lowered_toughness != null or is_zero_toughness):
			return "-%s/-%s" % [_amount(lowered_power) if lowered_power != null else "0",
				_amount(lowered_toughness) if lowered_toughness != null else "0"]
	if power_constant == null or toughness_constant == null:
		return "+%s/+%s" % [_amount(power), _amount(toughness)]
	var is_lowering: bool = power_constant.value < 0 or toughness_constant.value < 0
	return "%s/%s" % [_signed(power_constant.value, is_lowering), _signed(toughness_constant.value, is_lowering)]


## What [param value] takes away when it is 0 minus that amount, or null.
static func _lowered_by(value: MmValue) -> MmValue:
	var difference: DifferenceValue = value as DifferenceValue
	if difference == null:
		return null
	var minuend: ConstantValue = difference.minuend as ConstantValue
	return difference.subtrahend if minuend != null and minuend.value == 0 else null


func _signed(number: int, zero_is_minus: bool) -> String:
	if number < 0 or (number == 0 and zero_is_minus):
		return "-%d" % absi(number)
	return "+%d" % number


# --- Who and what --------------------------------------------------------------------

## Who or what [param selection] finds, as the words of a sentence.
func _selection(selection: MmSelection) -> String:
	if selection is YouSelection:
		return "you"
	if selection is EachOpponentSelection:
		return "each opponent"
	if selection is SourceSelection:
		return _noun
	if selection is TriggeringPlayerSelection:
		return "that player"
	if selection is TriggeringObjectSelection:
		_says_triggering_object = true
		return "that " + _triggering_noun()
	if selection is TriggeringCardSelection:
		return "it"  # Undying's "return it to the battlefield" (engine ADR 0096).
	if selection is MovedCardsSelection:
		# Harried Dronesmith's "It gains haste", the token just created (engine ADR 0080's
		# third addendum), and its "sacrifice it" later (engine ADR 0103).
		# Later: "them" for several, once a card creates several and goes on to say so.
		return "it"
	if selection is SacrificedSelection:
		if _sacrifices_itself:
			return "it"  # Heartfire Immolator's "its power" (engine ADR 0098's addendum).
		return "the sacrificed " + _sacrificed_noun  # Bushmeat Poacher's (engine ADR 0098).
	if selection is ControllerOfSelection:
		var controller: ControllerOfSelection = selection as ControllerOfSelection
		var overloaded: OverloadedSelection = controller.selection as OverloadedSelection
		if overloaded != null and controller.is_once_for_each and _named_overloaded.has(overloaded.overloaded_index):
			_for_each_of = _overloaded_words(overloaded.overloaded_index)
			return "its controller"
		return _possessive(_selection(controller.selection)) + " controller"
	if selection is EachSelection:
		return "each " + _noun_phrase((selection as EachSelection).filter, false)
	if selection is ChosenSelection:
		return _with_article(_noun_phrase((selection as ChosenSelection).filter, false))
	if selection is TargetSelection:
		return _target((selection as TargetSelection).target_index)
	if selection is OverloadedSelection:
		return _overloaded_words((selection as OverloadedSelection).overloaded_index)
	if selection is ExiledWithSourceSelection:
		return "the exiled cards" if _exiles_several else "the exiled card"
	if selection is AttachedToSelection:
		# An Aura's is what it enchants (CR 303.4), and an Equipment's a creature (CR 301.5).
		if _enchanted != "":
			return _enchanted
		return "enchanted permanent" if _noun == "this Aura" else "equipped creature"
	return _fallback(selection, "_selection")


func _target(index: int) -> String:
	if index >= _targets.size():
		return "that target"
	var spec: TargetRequirement = _targets[index]
	if _named.has(index):
		if spec.filter is IsPlayerFilter:
			return "that player"
		var noun: String = _filter_words(spec.filter).noun if _names_again_with_that else ""
		return "that " + noun if noun != "" else "it"
	_named[index] = true
	if spec.is_up_to:
		return _up_to_targets(spec)
	if spec.among == TargetRequirement.Among.SPELLS:
		return "target " + _spell_phrase(spec.filter)
	if spec.among == TargetRequirement.Among.ABILITIES:
		return "target activated or triggered ability"
	if spec.among == TargetRequirement.Among.GRAVEYARD_CARDS:
		var card_phrase: String = _graveyard_phrase(spec.filter)
		# Gixian Puppeteer's "another target creature card", which can't be its own card.
		if card_phrase.begins_with(OTHER + " "):
			return "another target " + card_phrase.trim_prefix(OTHER + " ")
		return "target " + card_phrase
	if _is_any_target(spec.filter):
		return "any target"
	var phrase: String = _noun_phrase(spec.filter, false)
	# "Another target creature": a target that can't be the source.
	if phrase.begins_with(OTHER + " "):
		return "another target " + phrase.trim_prefix(OTHER + " ")
	return "target " + phrase


## What an overloaded "target" says (CR 702.96b): "each creature", "each creature and each
## player" for "any target", "each other spell" (it can't find itself, CR 115.5), "each
## creature card from your graveyard"; then "those creatures" once it has been named.
func _overloaded_words(index: int) -> String:
	if index >= _overloaded.size():
		return "each of them"
	var spec: TargetRequirement = _overloaded[index]
	if _named_overloaded.has(index):
		if spec.among != TargetRequirement.Among.PLAYERS_AND_PERMANENTS:
			return "them"
		var noun: String = "player" if spec.filter is IsPlayerFilter else _filter_words(spec.filter).noun
		noun = noun if noun != "" else "permanent"
		return "those " + (noun if PLURAL_AS_SINGULAR.has(noun) else noun + "s")
	_named_overloaded[index] = true
	if spec.among == TargetRequirement.Among.SPELLS:
		return "each other " + _spell_phrase(spec.filter)
	if spec.among == TargetRequirement.Among.ABILITIES:
		return "each activated or triggered ability"
	if spec.among == TargetRequirement.Among.GRAVEYARD_CARDS:
		return "each " + _graveyard_phrase(spec.filter)
	if _is_any_target(spec.filter):
		return "each creature and each player"
	return "each " + _noun_phrase(spec.filter, false)


## Whether [param selection] finds several things: what an overload found, or the cards
## exiled by one.
func _is_several(selection: MmSelection) -> bool:
	return selection is OverloadedSelection or (selection is ExiledWithSourceSelection and _exiles_several)


## "Up to two target creatures", "up to two other target creatures you control": "other"
## comes before "target", as "another" does.
func _up_to_targets(spec: TargetRequirement) -> String:
	var phrase: String = _noun_phrase(spec.filter, spec.most != 1)
	var target: String = "target " + phrase
	if phrase.begins_with(OTHER + " "):
		target = "other target " + phrase.trim_prefix(OTHER + " ")
	return "up to %s %s" % [_number_word(spec.most), target]


## Whether [param selection] is the targets of an "up to" requirement that may choose more
## than one.
func _is_several_targets(selection: MmSelection) -> bool:
	var targeted: TargetSelection = selection as TargetSelection
	if targeted == null or targeted.target_index >= _targets.size():
		return false
	return _targets[targeted.target_index].is_up_to and _targets[targeted.target_index].most > 1


## Whether [param selection] is a targeted card that can only be one its controller owns,
## as in "target creature card from your graveyard", which goes back "to your hand".
func _is_yours(selection: MmSelection) -> bool:
	if selection is SourceSelection and _is_from_graveyard:
		return true  # Only a card's owner activates its ability in their graveyard.
	var overloaded: OverloadedSelection = selection as OverloadedSelection
	if overloaded != null:
		return overloaded.overloaded_index < _overloaded.size() \
			and _filter_words(_overloaded[overloaded.overloaded_index].filter).after.has(YOU_OWN)
	var targeted: TargetSelection = selection as TargetSelection
	if targeted == null or targeted.target_index >= _targets.size():
		return false
	return _filter_words(_targets[targeted.target_index].filter).after.has(YOU_OWN)


## What a return effect names as it returns [param selection]: "this card from your
## graveyard" for its own card, from an ability that works there (engine ADR 0094).
func _returned(selection: MmSelection) -> String:
	if selection is SourceSelection and _is_from_graveyard:
		return _selection(selection) + " from your graveyard"
	return _selection(selection)


## Readies the writer for [param triggered]: one that works from the graveyard calls its
## source "this card" (engine ADR 0094's addendum), as an activated one does.
func _read_where_triggered_works(triggered: TriggeredAbility) -> void:
	if triggered.is_triggered_from_graveyard:
		_is_from_graveyard = true
		_noun = "this card"


## Readies the writer for [param activated]: one that works from the graveyard calls its
## source "this card" (engine ADR 0094), whatever card it is.
func _read_where_it_works(activated: ActivatedAbility) -> void:
	_is_from_graveyard = activated.is_activated_from_graveyard
	if _is_from_graveyard:
		_noun = "this card"


## "Any target" is a creature or a player (there are no planeswalkers, ADR 0001).
func _is_any_target(filter: MmFilter) -> bool:
	var either: AnyOfFilter = filter as AnyOfFilter
	if either == null or either.filters.size() != 2:
		return false
	var has_player: bool = false
	var has_creature: bool = false
	for part: MmFilter in either.filters:
		has_player = has_player or part is IsPlayerFilter
		var kind: HasCardTypeFilter = part as HasCardTypeFilter
		has_creature = has_creature or (kind != null and kind.card_type == MmCardTypes.CardType.CREATURE)
	return has_player and has_creature


func _triggering_noun() -> String:
	if _trigger is SpellCastTrigger:
		return "spell"
	if _trigger is BecomesTargetTrigger:
		return "spell" if (_trigger as BecomesTargetTrigger).is_spells_only else "spell or ability"
	if _trigger is BlockersDeclaredTrigger:
		return "creature"  # The attacker it blocks.
	if _trigger is AttackersDeclaredTrigger:
		return "creature"  # The one attacking alone (CR 506.5).
	var moved: ZoneChangeTrigger = _trigger as ZoneChangeTrigger
	if moved != null:
		var noun: String = _filter_words(moved.filter).noun
		return noun if noun != "" else "permanent"
	var tapped: BecomesTappedTrigger = _trigger as BecomesTappedTrigger
	if tapped != null:
		var tapped_noun: String = _filter_words(tapped.filter).noun
		return tapped_noun if tapped_noun != "" else "permanent"
	return "permanent"


## The verb for what [param selection] does: "you draw", but "target player draws".
func _verb(selection: MmSelection, verb: String) -> String:
	return verb if selection is YouSelection else verb + "s"


## [param verb] as it is after "have", as in "you may have target creature get", with
## [param is_bare]; otherwise as _verb() says it.
func _bare_or_verb(selection: MmSelection, is_bare: bool, verb: String) -> String:
	return verb if is_bare else _verb(selection, verb)


func _possessive(words: String) -> String:
	if words == "you":
		return "your"
	if words == "it":
		return "its"
	return words + "'s"


# --- Filters -------------------------------------------------------------------------

## [param filter] as a noun with its adjectives, such as "nonartifact, nonblack creature"
## or "non-Wall creatures you control". [param whose] adds who controls it.
func _noun_phrase(filter: MmFilter, is_plural: bool, whose: MmTrigger.Whose = MmTrigger.Whose.ANY) -> String:
	if filter is IsSourceFilter:
		return _noun
	var either: AnyOfFilter = filter as AnyOfFilter
	if either != null:
		var choices: PackedStringArray = []
		for part: MmFilter in either.filters:
			choices.append(_noun_phrase(part, is_plural))
		return " or ".join(choices)
	var words: FilterWords = _filter_words(filter)
	# "Each other white creature": "other" comes before the adjectives, with no comma.
	var is_other: bool = words.adjectives.has(OTHER)
	words.adjectives.erase(OTHER)
	# "Nontoken Cat creature": a subtype stands next to its noun, with no comma, after the
	# other adjectives.
	var adjectives: PackedStringArray = []
	var subtypes: PackedStringArray = []
	# "Nontoken modified creature": "modified" stands next to its noun too (CR 700.9), with
	# no comma, as Akki Ember-Keeper's words have it.
	var beside_noun: PackedStringArray = []
	for adjective: String in words.adjectives:
		if _is_subtype_word(adjective):
			subtypes.append(adjective)
		elif adjective == MODIFIED or adjective == UNMODIFIED:
			beside_noun.append(adjective)
		else:
			adjectives.append(adjective)
	var noun: String = words.noun
	var after: PackedStringArray = PackedStringArray(words.after)
	if noun == "" and not subtypes.is_empty():
		# "Cats", not "Cat permanents": a subtype alone is its own noun (CR 205.3).
		noun = subtypes[subtypes.size() - 1]
		subtypes.remove_at(subtypes.size() - 1)
	if noun == "":
		noun = "permanent"
	if is_plural:
		noun = _plural(noun)
	else:
		# "A player who controls", against "players who control".
		for index: int in after.size():
			after[index] = after[index].replace(WHO_CONTROL, "who controls").replace(WHO_DONT_CONTROL, "who doesn't control")
	if not subtypes.is_empty():
		noun = " ".join(subtypes) + " " + noun
	if not beside_noun.is_empty():
		noun = " ".join(beside_noun) + " " + noun
	# Oracle names who controls it before what it has: "another creature you control with
	# power 2 or less", as Irreverent Gremlin's.
	if whose == MmTrigger.Whose.YOU:
		after.insert(0, "you control")
	elif whose == MmTrigger.Whose.OPPONENT:
		after.insert(0, "an opponent controls")
	var phrase: String = noun
	if not adjectives.is_empty():
		phrase = ", ".join(adjectives) + " " + phrase
	if is_other:
		phrase = OTHER + " " + phrase
	if not after.is_empty():
		phrase += " " + " ".join(after)
	return phrase


## "Creature spell", "white spell", or just "spell" for no filter.
func _spell_phrase(filter: MmFilter) -> String:
	var words: FilterWords = _filter_words(filter)
	var parts: PackedStringArray = PackedStringArray(words.adjectives)
	if words.noun != "":
		parts.append(words.noun)
	parts.append("spell")
	var phrase: String = " ".join(parts)
	var after: PackedStringArray = PackedStringArray(words.after)
	return phrase if after.is_empty() else phrase + " " + " ".join(after)


## "Creature card from your graveyard", or "card from a graveyard" for no filter. What
## else follows the noun comes before the graveyard: "creature card with mana value 3 or
## less from your graveyard".
func _graveyard_phrase(filter: MmFilter) -> String:
	var words: FilterWords = _filter_words(filter)
	var parts: PackedStringArray = PackedStringArray(words.adjectives)
	if words.noun != "":
		parts.append(words.noun)
	parts.append("card")
	var after: Array[String] = words.after.duplicate()
	var whose: String = "a graveyard"
	if after.has(YOU_OWN):
		whose = "your graveyard"
	elif after.has(OPPONENT_OWNS):
		whose = "an opponent's graveyard"
	after.erase(YOU_OWN)
	after.erase(OPPONENT_OWNS)
	parts.append_array(PackedStringArray(after))
	parts.append("from " + whose)
	return " ".join(parts)


## Whether [param word], one of a filter's adjectives, is a subtype: the only adjectives
## written with a capital, as _collect() writes them ("non-Wall" is not one).
static func _is_subtype_word(word: String) -> bool:
	var first: String = word.left(1)
	return first != "" and first != first.to_lower()


## The words of [param filter]: its adjectives, its noun ("" for none) and what follows
## the noun.
func _filter_words(filter: MmFilter) -> FilterWords:
	var words: FilterWords = FilterWords.new()
	var nouns: Array[String] = []
	_collect(filter, false, words.adjectives, nouns, words.after)
	if nouns.has(TOKEN_NOUN):
		# "Artifact token", "creature tokens": a token is named after its kind, as Oracle words it.
		nouns.erase(TOKEN_NOUN)
		nouns.append(TOKEN_NOUN)
	if not nouns.is_empty():
		# "Artifact creature": the last kind named is the noun, and the others describe it.
		words.adjectives.append_array(nouns.slice(0, -1))
		words.noun = nouns.back()
	return words


func _collect(filter: MmFilter, is_negated: bool, adjectives: Array[String], nouns: Array[String], after: Array[String]) -> void:
	if filter == null:
		return
	if filter is AllOfFilter:
		for part: MmFilter in (filter as AllOfFilter).filters:
			_collect(part, is_negated, adjectives, nouns, after)
	elif filter is NotFilter:
		_collect((filter as NotFilter).filter, not is_negated, adjectives, nouns, after)
	elif filter is HasCardTypeFilter:
		var type_word: String = _type_word((filter as HasCardTypeFilter).card_type)
		if is_negated:
			adjectives.append("non" + type_word)
		else:
			nouns.append(type_word)
	elif filter is IsPermanentFilter:
		# CR 110.4a: "permanent card", where a graveyard phrase adds "card".
		if is_negated:
			adjectives.append("nonpermanent")
		else:
			nouns.append("permanent")
	elif filter is HasColorFilter:
		var color_word: String = _color_word((filter as HasColorFilter).color)
		adjectives.append("non" + color_word if is_negated else color_word)
	elif filter is HasSubtypeFilter:
		var subtype: String = (filter as HasSubtypeFilter).subtype
		adjectives.append("non-" + subtype if is_negated else subtype)
	elif filter is HasSupertypeFilter:
		var supertype: String = str(MmCardTypes.Supertype.find_key((filter as HasSupertypeFilter).supertype)).to_lower()
		adjectives.append("non" + supertype if is_negated else supertype)
	elif filter is IsTappedFilter:
		adjectives.append("untapped" if is_negated else "tapped")
	elif filter is IsTokenFilter:
		if is_negated:
			adjectives.append("nontoken")
		else:
			nouns.append(TOKEN_NOUN)
	elif filter is IsAttackingFilter:
		adjectives.append("nonattacking" if is_negated else "attacking")
	elif filter is IsBlockingFilter:
		adjectives.append("nonblocking" if is_negated else "blocking")
	elif filter is IsEquippedFilter:
		adjectives.append("unequipped" if is_negated else "equipped")
	elif filter is ModifiedFilter:
		adjectives.append(UNMODIFIED if is_negated else MODIFIED)  # CR 700.9, engine ADR 0102.
	elif filter is IsAttachedToFilter:
		# Goblin Gaveleer's "Equipment attached to it": the source, named already.
		var attached_to: MmSelection = (filter as IsAttachedToFilter).selection
		var to_what: String = "it" if attached_to is SourceSelection else _selection(attached_to)
		after.append(("not attached to " if is_negated else "attached to ") + to_what)
	elif filter is AnyOfFilter and _is_historic(filter as AnyOfFilter):
		# CR 700.6, as Artificer's Assistant words it: "a historic spell".
		adjectives.append("nonhistoric" if is_negated else "historic")
	elif filter is AnyOfFilter and not is_negated and _either_adjective(filter as AnyOfFilter) != "":
		adjectives.append(_either_adjective(filter as AnyOfFilter))
	elif filter is AnyOfFilter and not is_negated and _either_noun(filter as AnyOfFilter) != "":
		nouns.append(_either_noun(filter as AnyOfFilter))
	elif filter is IsSourceFilter:
		# "Each other creature": anything but the source.
		if is_negated:
			adjectives.append(OTHER)
	elif filter is TargetsFilter:
		# Heroic: "a spell that targets this creature".
		var targeted: MmFilter = (filter as TargetsFilter).filter
		var words: String = _noun if targeted is IsSourceFilter else _with_article(_noun_phrase(targeted, false))
		after.append(("that doesn't target " if is_negated else "that targets ") + words)
	elif filter is HasAdventureFilter:
		# CR 715.2, as Edgewall Innkeeper words it: "a creature spell that has an Adventure".
		after.append("that doesn't have an Adventure" if is_negated else "that has an Adventure")
	elif filter is IsOfChosenTypeFilter:
		after.append("not of the chosen type" if is_negated else "of the chosen type")
	elif filter is HasOriginalNameFilter:
		# A printed "named" reads "originally named" here (ADR 0023's exception).
		var original_name: String = (filter as HasOriginalNameFilter).original_name
		after.append("not originally named " + original_name if is_negated else "originally named " + original_name)
	elif filter is ControlledByFilter:
		var whose: MmTrigger.Whose = (filter as ControlledByFilter).whose
		if whose == MmTrigger.Whose.YOU:
			after.append("you don't control" if is_negated else "you control")
		elif whose == MmTrigger.Whose.OPPONENT:
			after.append("an opponent doesn't control" if is_negated else "an opponent controls")
	elif filter is OwnedByFilter:
		var owner: MmTrigger.Whose = (filter as OwnedByFilter).whose
		if owner == MmTrigger.Whose.YOU:
			after.append("you don't own" if is_negated else YOU_OWN)
		elif owner == MmTrigger.Whose.OPPONENT:
			after.append("an opponent doesn't own" if is_negated else OPPONENT_OWNS)
	elif filter is HasAbilityFilter:
		var kind: Script = (filter as HasAbilityFilter).ability_kind
		var keyword: String = _keyword(kind.new() as MmAbility) if kind != null else ""
		after.append("%s %s" % ["without" if is_negated else "with", keyword.to_lower() if keyword != "" else _fallback(filter, "_filter")])
	elif filter is HasCountersFilter:
		var counted: HasCountersFilter = filter as HasCountersFilter
		if not is_negated:
			after.append("with " + _counters_on(counted))
		elif counted.at_least <= 1:
			after.append("without " + _counters_on(counted))
		else:
			after.append("with fewer than %s %s counters on it" % [_number_word(counted.at_least), MmCounter.label(counted.kind)])
	elif filter is ManaValueFilter:
		after.append("with mana value " + _mana_value_bound(filter as ManaValueFilter, is_negated))
	elif filter is PowerFilter:
		after.append("with power " + _power_bound(filter as PowerFilter, is_negated))
	elif filter is ToughnessFilter:
		after.append("with toughness " + _toughness_bound(filter as ToughnessFilter, is_negated))
	elif filter is ControlsMoreFilter:
		# "Players who control more lands than you"; _noun_phrase() makes the verb agree.
		nouns.append("player")
		var counted: String = _noun_phrase((filter as ControlsMoreFilter).filter, true)
		after.append(("%s more %s than you" % [WHO_DONT_CONTROL if is_negated else WHO_CONTROL, counted]))
	elif filter is IsPlayerFilter:
		# Anything that is not a player is a permanent, the noun when none is named.
		if not is_negated:
			nouns.append("opponent" if (filter as IsPlayerFilter).whose == MmTrigger.Whose.OPPONENT else "player")
	else:
		adjectives.append(_fallback(filter, "_filter"))


## Whether [param either] is "historic" (CR 700.6): artifact, legendary or Saga, each once,
## in any order.
static func _is_historic(either: AnyOfFilter) -> bool:
	var found: Dictionary[String, bool] = {}
	for part: MmFilter in either.filters:
		if part is HasCardTypeFilter and (part as HasCardTypeFilter).card_type == MmCardTypes.CardType.ARTIFACT:
			found["artifact"] = true
		elif part is HasSupertypeFilter and (part as HasSupertypeFilter).supertype == MmCardTypes.Supertype.LEGENDARY:
			found["legendary"] = true
		elif part is HasSubtypeFilter and (part as HasSubtypeFilter).subtype == "Saga":
			found["Saga"] = true
		else:
			return false
	return either.filters.size() == 3 and found.size() == 3


## "Attacking or blocking": [param either] as one adjective, when each of its filters is
## worded by adjectives alone. Otherwise "".
func _either_adjective(either: AnyOfFilter) -> String:
	var choices: PackedStringArray = []
	for part: MmFilter in either.filters:
		var words: FilterWords = _filter_words(part)
		if words.noun != "" or not words.after.is_empty() or words.adjectives.is_empty():
			return ""
		choices.append(", ".join(PackedStringArray(words.adjectives)))
	return " or ".join(choices)


## "Artifact or creature": [param either] as one noun, when each of its filters is worded by
## a noun alone, as Adaptive Gemguard's "untapped artifacts and/or creatures you control" is.
## Otherwise "".
func _either_noun(either: AnyOfFilter) -> String:
	var choices: PackedStringArray = []
	for part: MmFilter in either.filters:
		var words: FilterWords = _filter_words(part)
		if words.noun == "" or not words.after.is_empty() or not words.adjectives.is_empty():
			return ""
		choices.append(words.noun)
	return EITHER.join(choices)


## The plural of [param noun]: "creatures", "Equipment", or for a noun of either kind
## "artifacts and/or creatures".
func _plural(noun: String) -> String:
	var kinds: PackedStringArray = []
	for kind: String in noun.split(EITHER):
		kinds.append(kind if PLURAL_AS_SINGULAR.has(kind) else kind + "s")
	return EITHER_PLURAL.join(kinds)


# --- Numbers -------------------------------------------------------------------------

## A number as digits, or "X" with what X is kept for the end of the sentence.
func _amount(value: MmValue) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant != null:
		return str(constant.value)
	var product: ProductValue = value as ProductValue
	if product != null and product.value is CountValue and (product.value as CountValue).selection is EachSelection:
		# Goblin Gaveleer's "+2/+0 for each Equipment attached to it".
		_for_each = _noun_phrase(((product.value as CountValue).selection as EachSelection).filter, false)
		return str(product.factor)
	# ADR 0061: "pay {X}" says what X is already, as {X} in a mana cost does (ADR 0076).
	if not value is PaidXValue and not value is ChosenXValue:
		_where = _value_phrase(value)
	return "X"


## "an additional land", "two additional lands" or "X additional lands".
func _additional_lands(value: MmValue) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant == null:
		return _amount(value) + " additional lands"
	return _additional(constant.value, "land")


func _cards(value: MmValue) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant == null:
		return _amount(value) + " cards"
	return "a card" if constant.value == 1 else _number_word(constant.value) + " cards"


## "a +1/+1 counter", "two -1/-1 counters" or "X +1/+1 counters".
func _counters(value: MmValue, kind: MmCounter.Kind) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant == null:
		return "%s %s counters" % [_amount(value), MmCounter.label(kind)]
	if constant.value == 1:
		return "a %s counter" % MmCounter.label(kind)
	return "%s %s counters" % [_number_word(constant.value), MmCounter.label(kind)]


func _mana_value_bound(filter: ManaValueFilter, is_negated: bool) -> String:
	return _bound(filter.amount, filter.amount_value, filter.comparison == ManaValueFilter.Comparison.OR_LESS, is_negated)


func _power_bound(filter: PowerFilter, is_negated: bool) -> String:
	return _bound(filter.amount, filter.amount_value, filter.comparison == PowerFilter.Comparison.OR_LESS, is_negated)


func _toughness_bound(filter: ToughnessFilter, is_negated: bool) -> String:
	return _bound(filter.amount, filter.amount_value, filter.comparison == ToughnessFilter.Comparison.OR_LESS, is_negated)


## A Filter's bound: "3 or less" or "4 or greater"; negated, the other side: not 4 or
## greater is 3 or less. From the X paid, "X or less", or negated "greater than X", as X
## less 1 has no words. From any other Value, its number in words, inline: "less than the
## number of basic land types among lands you control", or "less than or equal to" it.
func _bound(amount: int, value: MmValue, is_or_less: bool, is_negated: bool) -> String:
	var or_less: bool = is_or_less != is_negated
	var constant: ConstantValue = value as ConstantValue
	if value is PaidXValue:
		if not is_negated:
			return "X %s" % ("or less" if or_less else "or greater")
		return "less than X" if or_less else "greater than X"
	var sum: SumValue = value as SumValue
	if sum != null and not or_less and not is_negated and sum.addends.size() == 2 and sum.addends[1] is ConstantValue \
			and (sum.addends[1] as ConstantValue).value == 1:
		return "greater than " + _value_phrase(sum.addends[0])  # "[X] plus 1 or greater".
	if value != null and constant == null:
		var number: String = _value_phrase(value)
		if is_negated:
			return ("less than " if or_less else "greater than ") + number
		return ("less than or equal to " if or_less else "greater than or equal to ") + number
	var bound: int = constant.value if constant != null else amount
	if not is_negated:
		return "%d %s" % [bound, "or less" if or_less else "or greater"]
	return "%d or less" % (bound - 1) if or_less else "%d or greater" % (bound + 1)


## "a +1/+1 counter on it" or "three or more -1/-1 counters on it".
static func _counters_on(filter: HasCountersFilter) -> String:
	if filter.at_least <= 1:
		return "a %s counter on it" % MmCounter.label(filter.kind)
	return "%s or more %s counters on it" % [_number_word(filter.at_least), MmCounter.label(filter.kind)]


func _value_phrase(value: MmValue) -> String:
	if value is ConstantValue:
		return str((value as ConstantValue).value)
	if value is CountValue:
		var counted: EachSelection = (value as CountValue).selection as EachSelection
		if counted != null:
			return "the number of " + _noun_phrase(counted.filter, true)
	if value is BasicLandTypeCountValue:
		var among: EachSelection = (value as BasicLandTypeCountValue).selection as EachSelection
		if among != null:
			return "the number of basic land types among " + _noun_phrase(among.filter, true)
	if value is HandSizeValue:
		return "the number of cards in %s hand" % _possessive(_selection((value as HandSizeValue).players))
	if value is CardsDrawnThisTurnValue:
		return "the number of cards %s drawn this turn" % _drawers((value as CardsDrawnThisTurnValue).players)
	if value is LifeGainedThisTurnValue:
		# Engine ADR 0082's fourth addendum.
		return "the amount of life %s gained this turn" % _drawers((value as LifeGainedThisTurnValue).players)
	if value is CardsInZoneValue:
		return "the number of " + _cards_in_zone(value as CardsInZoneValue, true)
	if value is DifferenceValue:
		var difference: DifferenceValue = value as DifferenceValue
		return "%s minus %s" % [_value_phrase(difference.minuend), _value_phrase(difference.subtrahend)]
	if value is ProductValue:
		var product: ProductValue = value as ProductValue
		return "%d times %s" % [product.factor, _value_phrase(product.value)]
	if value is SumValue:
		var addends: PackedStringArray = []
		for addend: MmValue in (value as SumValue).addends:
			addends.append(_value_phrase(addend))
		return " plus ".join(addends)
	if value is PowerValue:
		return _possessive(_selection((value as PowerValue).selection)) + " power"
	if value is ToughnessValue:
		return _possessive(_selection((value as ToughnessValue).selection)) + " toughness"
	if value is CounterCountValue:
		var counted: CounterCountValue = value as CounterCountValue
		return "the number of %s counters on %s" % [MmCounter.label(counted.kind), _selection(counted.selection)]
	return _fallback(value, "_value")


## "cards in your graveyard", or with a filter "artifact or creature cards in your
## graveyard" (engine ADR 0080): what [param counted] counts, plural with [param is_plural].
func _cards_in_zone(counted: CardsInZoneValue, is_plural: bool) -> String:
	var cards: String = "cards" if is_plural else "card"
	if counted.filter != null:
		cards = _noun_phrase(counted.filter, false) + " " + cards
	return "%s in %s %s" % [cards, _whose_words(counted.whose), (ZONE_NAMES[counted.zone] as String).trim_prefix("a ")]


## "your" or "an opponent's", for [param whose] zone.
static func _whose_words(whose: MmTrigger.Whose) -> String:
	return "an opponent's" if whose == MmTrigger.Whose.OPPONENT else "your"


static func _number_word(number: int) -> String:
	return NUMBER_WORDS[number] if number >= 0 and number < NUMBER_WORDS.size() else str(number)


## "first", "second", ..., "tenth", then "11th", "21st", "22nd".
static func _ordinal(number: int) -> String:
	if number >= 0 and number < ORDINAL_WORDS.size():
		return ORDINAL_WORDS[number]
	var suffix: String = "th"
	if number % 100 < 11 or number % 100 > 13:
		suffix = ORDINAL_SUFFIXES[number % 10] if number % 10 < ORDINAL_SUFFIXES.size() else "th"
	return "%d%s" % [number, suffix]


# --- Words ---------------------------------------------------------------------------

static func _type_word(card_type: MmCardTypes.CardType) -> String:
	return (MmCardTypes.CardType.find_key(card_type) as String).to_lower()


static func _color_word(color: MmCardTypes.CardColor) -> String:
	return (MmCardTypes.CardColor.find_key(color) as String).to_lower()


static func _with_article(words: String) -> String:
	# "Another creature", never "an other creature".
	if words.begins_with(OTHER + " "):
		return "an" + words
	# Said aloud: "an X/X", "an 8/8", "an 11/11", "an 18/18".
	for sounded: String in ["X/", "8", "11/", "18/"]:
		if words.begins_with(sounded):
			return "an " + words
	return ("an " if "aeiou".contains(words.left(1).to_lower()) else "a ") + words


static func _capitalized(words: String) -> String:
	return words.left(1).to_upper() + words.substr(1)


## [param words] with its first letter in lower case, as a cost reads inside a sentence.
static func _uncapitalized(words: String) -> String:
	return words.left(1).to_lower() + words.substr(1)


## What stands in for [param thing] when there are no words for it: its class, in brackets.
static func _fallback(thing: Resource, suffix: String) -> String:
	var script: Script = thing.get_script() as Script
	var file: String = script.resource_path.get_file().get_basename() if script != null else "unknown"
	return "[%s]" % file.trim_suffix(suffix).replace("_", " ")
