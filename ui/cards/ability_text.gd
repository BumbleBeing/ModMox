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

## What the ability's source calls itself.
var _noun: String
var _targets: Array[TargetRequirement] = []
var _trigger: MmTrigger = null
## The target requirements already named, which are "it" from then on.
var _named: Dictionary[int, bool] = {}
## Whether a target already named is "that creature" rather than "it", as it is in what an
## InsteadEffect does instead: "double the number of +1/+1 counters on that creature
## instead".
var _names_again_with_that: bool = false
## What "X" stands for in the sentence being written, or "".
var _where: String = ""


## The words of a Filter: what goes before its noun, the noun, and what follows it.
class FilterWords:
	extends RefCounted
	var adjectives: Array[String] = []
	## The last kind named, such as "creature" in "artifact creature", or "" for none.
	var noun: String = ""
	var after: Array[String] = []


## What a card with [param card_types] named [param card_name] calls itself in its own
## text.
static func self_noun(card_types: Array[MmCardTypes.CardType], card_name: String) -> String:
	for kind: MmCardTypes.CardType in [MmCardTypes.CardType.CREATURE, MmCardTypes.CardType.ARTIFACT,
			MmCardTypes.CardType.ENCHANTMENT, MmCardTypes.CardType.LAND]:
		if card_types.has(kind):
			return "this " + _type_word(kind)
	return card_name


## A card's whole rules text, one ability to a line. Keywords that stand next to each other
## share a line, and a basic land's text is all reminder text, so it is in parentheses.
static func of_card(abilities: Array[MmAbility], card_types: Array[MmCardTypes.CardType],
		supertypes: Array[MmCardTypes.Supertype], card_name: String) -> String:
	var noun: String = self_noun(card_types, card_name)
	var lines: PackedStringArray = []
	var was_keyword: bool = false
	for ability: MmAbility in abilities:
		var keyword: String = _keyword(ability)
		if keyword != "" and was_keyword:
			lines[lines.size() - 1] += ", " + keyword.to_lower()
		else:
			lines.append(of_ability(ability, noun))
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
## its source calls itself (see self_noun()).
static func of_ability(ability: MmAbility, noun: String) -> String:
	var writer: AbilityText = AbilityText.new(noun)
	return writer._ability(ability)


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
		return writer._sentences((ability as SpellAbility).effects, true)
	if ability is ActivatedAbility:
		writer._targets = (ability as ActivatedAbility).targets
		return writer._sentences((ability as ActivatedAbility).effects, true)
	if ability is TriggeredAbility:
		var triggered: TriggeredAbility = ability as TriggeredAbility
		writer._targets = triggered.targets
		writer._trigger = triggered.trigger
		return writer._sentences(triggered.effects, true)
	return writer._ability(ability)


## What [param effect], one of [param ability]'s, does, alone and in lower case, as a
## "you may" asks it (game ADR 0060): "tap target creature". [param mode_index] is the
## chosen mode of a modal one.
static func offered_words(ability: MmAbility, effect: MmEffect, noun: String, mode_index: int = SpellAbility.NO_MODE) -> String:
	var writer: AbilityText = AbilityText.new(noun)
	if not ability.modes_or_none().is_empty() and mode_index != SpellAbility.NO_MODE:
		writer._targets = ability.modes_or_none()[mode_index].targets
	elif ability is SpellAbility:
		writer._targets = (ability as SpellAbility).targets
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
	if ability is SpellAbility and (ability as SpellAbility).is_modal():
		return _choose_one(ability)
	if ability is SpellAbility:
		_targets = (ability as SpellAbility).targets
		return _sentences((ability as SpellAbility).effects, true)
	if ability is EquipAbility:
		# A keyword prints its cost and nothing else (CR 702.6); what it does is its Reminder.
		return "Equip " + _costs(ability as EquipAbility)
	if ability is CyclingAbility:
		# CR 702.29a: as equip does, it prints its cost alone.
		var cycling: PackedStringArray = _cost_parts((ability as CyclingAbility).mana_cost, [])
		return _capitalized(_cycling_word((ability as CyclingAbility).search)) + " " \
			+ (", ".join(cycling) if not cycling.is_empty() else "{0}")
	if ability is FlashbackAbility:
		return _flashback(ability as FlashbackAbility)
	if ability is AffinityAbility:
		# CR 702.41a: what it counts, in the plural, with "you control" left to the keyword.
		return "Affinity for " + _noun_phrase((ability as AffinityAbility).filter, true)
	if ability is ActivatedAbility:
		var activated: ActivatedAbility = ability as ActivatedAbility
		_targets = activated.targets
		var does: String = _sentences(activated.effects, true) + _restrictions(activated)
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
	if ability is AsEntersChooseCreatureTypeAbility:
		return "As %s enters, choose a creature type." % _noun
	if ability is LookAtTopOfLibraryAbility:
		return "You may look at the top card of your library any time."
	if ability is CastFromTopOfLibraryAbility:
		return "Once each turn, you may cast %s from the top of your library." \
			% _with_article(_spell_phrase((ability as CastFromTopOfLibraryAbility).filter))
	return _fallback(ability, "_ability")


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
		or ability is AffinityAbility or ability is CyclingAbility


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
	if ability is LifelinkAbility:
		return "Lifelink"
	if ability is IndestructibleAbility:
		return "Indestructible"
	if ability is FlashAbility:
		return "Flash"
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


## The sentence after what [param ability] does that says when it may be activated
## (CR 602.5), or "".
static func _restrictions(ability: ActivatedAbility) -> String:
	var limits: PackedStringArray = []
	if ability.is_sorcery_speed:
		limits.append("only as a sorcery")
	if ability.is_once_each_game:
		limits.append("only once each game")
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
		elif cost is PayLifeCost:
			parts.append("Pay %d life" % (cost as PayLifeCost).amount)
		elif cost is TapCreaturesCost:
			parts.append("Tap " + _how_many((cost as TapCreaturesCost).count, (cost as TapCreaturesCost).filter))
		else:
			parts.append(_fallback(cost, "_cost"))
	return parts


## "an untapped creature you control" or "three untapped creatures you control".
func _how_many(count: int, filter: MmFilter) -> String:
	if count == 1:
		return _with_article(_noun_phrase(filter, false))
	return "%s %s" % [_number_word(count), _noun_phrase(filter, true)]


func _triggered(ability: TriggeredAbility) -> String:
	_targets = ability.targets
	_trigger = ability.trigger
	var text: String = _trigger_text(ability.trigger) + ", "
	if ability.condition != null:
		text += "if %s, " % _condition(ability.condition)
	if ability.is_modal():
		return _capitalized(text + "choose one —") + _bullets(ability)
	return _capitalized(text + _sentences(ability.effects, false))


## CR 700.2: "Choose one —", then a bullet for each mode of [param ability].
func _choose_one(ability: MmAbility) -> String:
	return "Choose one —" + _bullets(ability)


## A new line and a "•" for each mode of [param ability].
func _bullets(ability: MmAbility) -> String:
	var text: String = ""
	for mode_index: int in ability.modes_or_none().size():
		text += "\n• " + mode_text(ability, mode_index, _noun)
	return text


func _trigger_text(trigger: MmTrigger) -> String:
	var step: StepBeganTrigger = trigger as StepBeganTrigger
	if step != null:
		var whose: String = "your"
		if step.whose == MmTrigger.Whose.ANY:
			whose = "each player's"
		elif step.whose == MmTrigger.Whose.OPPONENT:
			whose = "each opponent's"
		return "at the beginning of %s %s" % [whose, STEP_NAMES.get(step.step, "step")]
	var cast: SpellCastTrigger = trigger as SpellCastTrigger
	if cast != null:
		var caster: String = "a player casts"
		if cast.whose == MmTrigger.Whose.YOU:
			caster = "you cast"
		elif cast.whose == MmTrigger.Whose.OPPONENT:
			caster = "an opponent casts"
		return "whenever %s %s" % [caster, _with_article(_spell_phrase(cast.filter))]
	var attack: AttackersDeclaredTrigger = trigger as AttackersDeclaredTrigger
	if attack != null:
		var whose: String = "a player controls"
		if attack.whose == MmTrigger.Whose.YOU:
			whose = "you control"
		elif attack.whose == MmTrigger.Whose.OPPONENT:
			whose = "an opponent controls"
		return "whenever one or more creatures %s attack" % whose
	var moved: ZoneChangeTrigger = trigger as ZoneChangeTrigger
	if moved != null:
		var is_self: bool = moved.filter is IsSourceFilter
		var subject: String = _noun if is_self else _with_article(_noun_phrase(moved.filter, false, moved.whose))
		return "%s %s %s" % ["when" if is_self else "whenever", subject, _move_verb(moved)]
	return _fallback(trigger, "_trigger")


func _move_verb(moved: ZoneChangeTrigger) -> String:
	if moved.any_to_zone:
		return "changes zones" if moved.any_from_zone else "leaves " + (ZONE_NAMES[moved.from_zone] as String)
	if moved.to_zone == MmZone.Kind.BATTLEFIELD and moved.any_from_zone:
		return "enters"
	if not moved.any_from_zone and moved.from_zone == MmZone.Kind.BATTLEFIELD and moved.to_zone == MmZone.Kind.GRAVEYARD:
		return "dies"
	var from: String = "anywhere" if moved.any_from_zone else (ZONE_NAMES[moved.from_zone] as String)
	return "is put into %s from %s" % [ZONE_NAMES[moved.to_zone], from]


func _condition(condition: MmCondition) -> String:
	if condition is LifeAtLeastStartingCondition:
		return "your life total is greater than or equal to your starting life total"
	if condition is TimesResolvedThisTurnCondition:
		return "this is the %s time this ability has resolved this turn" % _ordinal((condition as TimesResolvedThisTurnCondition).times)
	var matches: SelectionMatchesCondition = condition as SelectionMatchesCondition
	if matches == null:
		return _fallback(condition, "_condition")
	var subject: String = _selection(matches.selection)
	if matches.filter is HasCountersFilter:
		return "%s has %s" % [subject, _counters_on(matches.filter as HasCountersFilter)]
	var words: FilterWords = _filter_words(matches.filter)
	var is_what: String = ", ".join(PackedStringArray(words.adjectives))
	if words.noun != "" or is_what == "":
		is_what = _with_article(_noun_phrase(matches.filter, false))
	return "%s %s %s" % [subject, "are" if subject == "you" else "is", is_what]


## A sentence for each effect, "Each white creature gets +1/+1."; or, with a condition, one
## sentence that names the source in the condition and calls it "it" after: "As long as
## this creature has a +1/+1 counter on it, it has flying and is a Knight in addition to
## its other types."
func _static(ability: ContinuousStaticAbility) -> String:
	var clauses: PackedStringArray = []
	if ability.condition == null:
		for continuous: MmContinuousEffect in ability.effects:
			clauses.append(_capitalized(_continuous(continuous, true)) + ".")
		return " ".join(clauses)
	var condition: String = _condition(ability.condition)
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
	return "As long as %s, %s." % [condition, _listed(clauses)]


## "A and B", or "A, B, and C".
static func _listed(parts: PackedStringArray) -> String:
	if parts.size() <= 2:
		return " and ".join(parts)
	return ", ".join(parts.slice(0, -1)) + ", and " + parts[parts.size() - 1]


func _characteristic_defining(ability: CharacteristicDefiningAbility) -> String:
	var power: String = _value_phrase(ability.power)
	var toughness: String = _value_phrase(ability.toughness)
	var owner: String = _capitalized(_possessive(_noun))
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
	for effect: MmEffect in effects:
		_where = ""
		var clause: String = _effect(effect)
		if _where != "":
			clause += ", where X is " + _where
		var is_first: bool = sentences.is_empty()
		sentences.append((clause if is_first and not starts_sentence else _capitalized(clause)) + ".")
		var destroy: DestroyEffect = effect as DestroyEffect
		if destroy != null and not destroy.can_be_regenerated:
			sentences.append("It can't be regenerated.")
	return " ".join(sentences)


func _effect(effect: MmEffect) -> String:
	if effect is DealDamageEffect:
		var damage: DealDamageEffect = effect as DealDamageEffect
		if not damage.amount is ConstantValue:
			# Oracle wording: "deals damage to target creature equal to the number of ...".
			return "%s deals damage to %s equal to %s" % [_noun, _selection(damage.recipients), _value_phrase(damage.amount)]
		return "%s deals %s damage to %s" % [_noun, _amount(damage.amount), _selection(damage.recipients)]
	if effect is DrawCardsEffect:
		var draw: DrawCardsEffect = effect as DrawCardsEffect
		if draw.players is YouSelection:
			# Oracle wording: you are told to "draw two cards", not that "you draw" them.
			return "draw " + _cards(draw.amount)
		return "%s %s %s" % [_selection(draw.players), _verb(draw.players, "draw"), _cards(draw.amount)]
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
		return "counter " + _selection((effect as CounterEffect).selection)
	if effect is ExileEffect:
		return "exile " + _selection((effect as ExileEffect).selection)
	if effect is ReturnToBattlefieldEffect:
		var back: ReturnToBattlefieldEffect = effect as ReturnToBattlefieldEffect
		# A card that can only be your own returns under your control, so Oracle leaves out
		# "under its owner's control", as Helping Hand does.
		var text: String = "return %s to the battlefield%s%s" % [_selection(back.selection), " tapped" if back.tapped else "",
			"" if _is_yours(back.selection) else " under its owner's control"]
		return text if back.counters == null else text + " with %s on it" % _counters(back.counters, back.counter_kind)
	if effect is ReturnToHandEffect:
		var returned: MmSelection = (effect as ReturnToHandEffect).selection
		return "return %s to %s hand" % [_selection(returned), "your" if _is_yours(returned) else "its owner's"]
	if effect is TapEffect:
		return "tap " + _selection((effect as TapEffect).selection)
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
	if effect is DoubleCountersEffect:
		var doubled: DoubleCountersEffect = effect as DoubleCountersEffect
		return "double the number of %s counters on %s" % [MmCounter.label(doubled.kind), _selection(doubled.recipients)]
	if effect is InsteadEffect:
		return _instead(effect as InsteadEffect)
	if effect is MayEffect:
		# CR 603.5: "you may tap target creature".
		return "you may " + _effect((effect as MayEffect).effect)
	if effect is CreateContinuousEffect:
		return _continuous((effect as CreateContinuousEffect).continuous, false) + " until end of turn"
	if effect is CreateTokenEffect:
		return "create " + _tokens(effect as CreateTokenEffect)
	if effect is SearchLibraryEffect:
		return _search(effect as SearchLibraryEffect)
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
## and a token's keywords after "with": "a 1/1 white Cat Soldier creature token with vigilance".
func _tokens(effect: CreateTokenEffect) -> String:
	if effect.token == null:
		return _fallback(effect, "_tokens")
	var keywords: PackedStringArray = PackedStringArray()
	for ability: MmAbility in effect.token.abilities:
		var keyword: String = _keyword(ability)
		if keyword == "":
			# Later: a token's other abilities, in quotation marks (CR 111.4).
			return _fallback(effect, "_tokens")
		keywords.append(keyword.to_lower())
	var with: String = "" if keywords.is_empty() else " with " + _listed(keywords)
	var printed: MmCharacteristics = MmCharacteristics.printed(effect.token)
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
	var phrase: String = " ".join(words)
	if effect.amount == 1:
		return _with_article(phrase + " token") + with
	return "%s %s tokens%s" % [_number_word(effect.amount), phrase, with]


func _mana(effect: AddManaEffect) -> String:
	var symbol: String = "{%s}" % MmMana.SYMBOLS[effect.mana_type]
	var constant: ConstantValue = effect.amount as ConstantValue
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
## effect's says "gains" and "becomes" ([param is_static]).
func _continuous(continuous: MmContinuousEffect, is_static: bool) -> String:
	var affected: String = _selection(continuous.affected)
	if continuous is ModifyPowerToughnessContinuousEffect:
		var modify: ModifyPowerToughnessContinuousEffect = continuous as ModifyPowerToughnessContinuousEffect
		return "%s %s %s" % [affected, _verb(continuous.affected, "get"), _change(modify.power, modify.toughness)]
	if continuous is SetPowerToughnessContinuousEffect:
		var set_to: SetPowerToughnessContinuousEffect = continuous as SetPowerToughnessContinuousEffect
		return "%s %s base power and toughness %s/%s" % [affected, "have" if affected == "you" else "has",
			_value_phrase(set_to.power), _value_phrase(set_to.toughness)]
	if continuous is GainAbilitiesContinuousEffect:
		var gained: PackedStringArray = []
		for ability: MmAbility in (continuous as GainAbilitiesContinuousEffect).abilities:
			var text: String = _ability(ability)
			gained.append(text.to_lower() if _keyword(ability) != "" or ability is ProtectionAbility else "\"%s\"" % text)
		var gains: String = _verb(continuous.affected, "gain")
		if is_static:
			gains = "have" if continuous.affected is YouSelection else "has"
		return "%s %s %s" % [affected, gains, " and ".join(gained)]
	if continuous is AddSubtypesContinuousEffect:
		var subtypes: PackedStringArray = PackedStringArray((continuous as AddSubtypesContinuousEffect).subtypes)
		return "%s %s %s in addition to its other types" % [affected,
			"is" if is_static else _verb(continuous.affected, "become"), _with_article(" ".join(subtypes))]
	if continuous is LoseAllAbilitiesContinuousEffect:
		return "%s %s all abilities" % [affected, _verb(continuous.affected, "lose")]
	return _fallback(continuous, "_continuous_effect")


## "+3/+3", "-2/-0": a zero takes the other number's sign, as cards print it.
func _change(power: MmValue, toughness: MmValue) -> String:
	var power_constant: ConstantValue = power as ConstantValue
	var toughness_constant: ConstantValue = toughness as ConstantValue
	if power_constant == null or toughness_constant == null:
		return "+%s/+%s" % [_amount(power), _amount(toughness)]
	var is_lowering: bool = power_constant.value < 0 or toughness_constant.value < 0
	return "%s/%s" % [_signed(power_constant.value, is_lowering), _signed(toughness_constant.value, is_lowering)]


func _signed(number: int, zero_is_minus: bool) -> String:
	if number < 0 or (number == 0 and zero_is_minus):
		return "-%d" % absi(number)
	return "+%d" % number


# --- Who and what --------------------------------------------------------------------

## Who or what [param selection] finds, as the words of a sentence.
func _selection(selection: MmSelection) -> String:
	if selection is YouSelection:
		return "you"
	if selection is SourceSelection:
		return _noun
	if selection is TriggeringPlayerSelection:
		return "that player"
	if selection is TriggeringObjectSelection:
		return "that " + _triggering_noun()
	if selection is ControllerOfSelection:
		return _possessive(_selection((selection as ControllerOfSelection).selection)) + " controller"
	if selection is EachSelection:
		return "each " + _noun_phrase((selection as EachSelection).filter, false)
	if selection is ChosenSelection:
		return _with_article(_noun_phrase((selection as ChosenSelection).filter, false))
	if selection is TargetSelection:
		return _target((selection as TargetSelection).target_index)
	if selection is ExiledWithSourceSelection:
		return "the exiled card"
	if selection is AttachedToSelection:
		# Later: "enchanted creature", once an Aura is what is attached.
		return "equipped creature"
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
		return "target " + _graveyard_phrase(spec.filter)
	if _is_any_target(spec.filter):
		return "any target"
	var phrase: String = _noun_phrase(spec.filter, false)
	# "Another target creature": a target that can't be the source.
	if phrase.begins_with(OTHER + " "):
		return "another target " + phrase.trim_prefix(OTHER + " ")
	return "target " + phrase


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
	var targeted: TargetSelection = selection as TargetSelection
	if targeted == null or targeted.target_index >= _targets.size():
		return false
	return _filter_words(_targets[targeted.target_index].filter).after.has(YOU_OWN)


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
	var moved: ZoneChangeTrigger = _trigger as ZoneChangeTrigger
	if moved != null:
		var noun: String = _filter_words(moved.filter).noun
		return noun if noun != "" else "permanent"
	return "permanent"


## The verb for what [param selection] does: "you draw", but "target player draws".
func _verb(selection: MmSelection, verb: String) -> String:
	return verb if selection is YouSelection else verb + "s"


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
	for adjective: String in words.adjectives:
		if _is_subtype_word(adjective):
			subtypes.append(adjective)
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
		noun += "s"
	if not subtypes.is_empty():
		noun = " ".join(subtypes) + " " + noun
	if whose == MmTrigger.Whose.YOU:
		after.append("you control")
	elif whose == MmTrigger.Whose.OPPONENT:
		after.append("an opponent controls")
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
		adjectives.append("nontoken" if is_negated else "token")
	elif filter is IsAttackingFilter:
		adjectives.append("nonattacking" if is_negated else "attacking")
	elif filter is IsBlockingFilter:
		adjectives.append("nonblocking" if is_negated else "blocking")
	elif filter is AnyOfFilter and not is_negated and _either_adjective(filter as AnyOfFilter) != "":
		adjectives.append(_either_adjective(filter as AnyOfFilter))
	elif filter is IsSourceFilter:
		# "Each other creature": anything but the source.
		if is_negated:
			adjectives.append(OTHER)
	elif filter is TargetsFilter:
		# Heroic: "a spell that targets this creature".
		var targeted: MmFilter = (filter as TargetsFilter).filter
		var words: String = _noun if targeted is IsSourceFilter else _with_article(_noun_phrase(targeted, false))
		after.append(("that doesn't target " if is_negated else "that targets ") + words)
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
	elif filter is IsPlayerFilter:
		# Anything that is not a player is a permanent, the noun when none is named.
		if not is_negated:
			nouns.append("player")
	else:
		adjectives.append(_fallback(filter, "_filter"))


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


# --- Numbers -------------------------------------------------------------------------

## A number as digits, or "X" with what X is kept for the end of the sentence.
func _amount(value: MmValue) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant != null:
		return str(constant.value)
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


## "3 or less" or "4 or greater"; negated, the other side: not 4 or greater is 3 or less.
static func _mana_value_bound(filter: ManaValueFilter, is_negated: bool) -> String:
	var or_less: bool = (filter.comparison == ManaValueFilter.Comparison.OR_LESS) != is_negated
	if not is_negated:
		return "%d %s" % [filter.amount, "or less" if or_less else "or greater"]
	return "%d or less" % (filter.amount - 1) if or_less else "%d or greater" % (filter.amount + 1)


## "2 or less" or "3 or greater"; negated, the other side, as _mana_value_bound() does.
static func _power_bound(filter: PowerFilter, is_negated: bool) -> String:
	var or_less: bool = (filter.comparison == PowerFilter.Comparison.OR_LESS) != is_negated
	if not is_negated:
		return "%d %s" % [filter.amount, "or less" if or_less else "or greater"]
	return "%d or less" % (filter.amount - 1) if or_less else "%d or greater" % (filter.amount + 1)


## "2 or less" or "4 or greater"; negated, the other side, as _mana_value_bound() does.
static func _toughness_bound(filter: ToughnessFilter, is_negated: bool) -> String:
	var or_less: bool = (filter.comparison == ToughnessFilter.Comparison.OR_LESS) != is_negated
	if not is_negated:
		return "%d %s" % [filter.amount, "or less" if or_less else "or greater"]
	return "%d or less" % (filter.amount - 1) if or_less else "%d or greater" % (filter.amount + 1)


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
	if value is HandSizeValue:
		return "the number of cards in %s hand" % _possessive(_selection((value as HandSizeValue).players))
	if value is DifferenceValue:
		var difference: DifferenceValue = value as DifferenceValue
		return "%s minus %s" % [_value_phrase(difference.minuend), _value_phrase(difference.subtrahend)]
	if value is PowerValue:
		return _possessive(_selection((value as PowerValue).selection)) + " power"
	return _fallback(value, "_value")


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
	return ("an " if "aeiou".contains(words.left(1).to_lower()) else "a ") + words


static func _capitalized(words: String) -> String:
	return words.left(1).to_upper() + words.substr(1)


## What stands in for [param thing] when there are no words for it: its class, in brackets.
static func _fallback(thing: Resource, suffix: String) -> String:
	var script: Script = thing.get_script() as Script
	var file: String = script.resource_path.get_file().get_basename() if script != null else "unknown"
	return "[%s]" % file.trim_suffix(suffix).replace("_", " ")
