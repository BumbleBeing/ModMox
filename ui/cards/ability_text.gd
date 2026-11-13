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

## What the ability's source calls itself.
var _noun: String
var _targets: Array[TargetSpec] = []
var _trigger: MmTrigger = null
## The target requirements already named, which are "it" from then on.
var _named: Dictionary[int, bool] = {}
## What "X" stands for in the sentence being written, or "".
var _where: String = ""


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
## that was paid or the trigger and condition that were met.
static func effect_of(ability: MmAbility, noun: String) -> String:
	var writer: AbilityText = AbilityText.new(noun)
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


## Everything [param filter] matches, in the plural: "black permanents", "creatures you
## control".
static func things(filter: MmFilter) -> String:
	return AbilityText.new("it")._noun_phrase(filter, true)


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
	if ability is SpellAbility:
		_targets = (ability as SpellAbility).targets
		return _sentences((ability as SpellAbility).effects, true)
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
		var clauses: PackedStringArray = []
		for continuous: MmContinuousEffect in (ability as ContinuousStaticAbility).effects:
			clauses.append(_capitalized(_continuous(continuous)) + ".")
		return " ".join(clauses)
	if ability is AdditionalLandPlaysAbility:
		return "You may play %s on each of your turns." % _additional((ability as AdditionalLandPlaysAbility).count, "land")
	if ability is BlockAdditionalAbility:
		return "%s can block %s each combat." % [_capitalized(_noun), _additional((ability as BlockAdditionalAbility).count, "creature")]
	if ability is DamageStaysAbility:
		return "Damage isn't removed from %s during cleanup steps." % _noun
	return _fallback(ability, "_ability")


## Whether [param ability] is a keyword, protection included: an ability a sentence names
## in lower case and without quotation marks.
static func is_keyword(ability: MmAbility) -> bool:
	return _keyword(ability) != "" or ability is ProtectionAbility


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
	var costs: PackedStringArray = []
	if ability.mana_cost != null:
		costs.append(ability.mana_cost.describe())
	for cost: MmCost in ability.costs:
		if not cost is UseUpCost:
			costs.append("{T}" if cost is TapCost else _fallback(cost, "_cost"))
	return ", ".join(costs) if not costs.is_empty() else "{0}"


func _triggered(ability: TriggeredAbility) -> String:
	_targets = ability.targets
	_trigger = ability.trigger
	var text: String = _trigger_text(ability.trigger) + ", "
	if ability.condition != null:
		text += "if %s, " % _condition(ability.condition)
	return _capitalized(text + _sentences(ability.effects, false))


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
	var moved: ZoneChangeTrigger = trigger as ZoneChangeTrigger
	if moved != null:
		var is_self: bool = moved.filter is IsSourceFilter
		var subject: String = _noun if is_self else _with_article(_noun_phrase(moved.filter, false, moved.whose))
		return "%s %s %s" % ["when" if is_self else "whenever", subject, _move_verb(moved)]
	return _fallback(trigger, "_trigger")


func _move_verb(moved: ZoneChangeTrigger) -> String:
	if moved.to_zone == MmZone.Kind.BATTLEFIELD and moved.any_from_zone:
		return "enters"
	if not moved.any_from_zone and moved.from_zone == MmZone.Kind.BATTLEFIELD and moved.to_zone == MmZone.Kind.GRAVEYARD:
		return "dies"
	var from: String = "anywhere" if moved.any_from_zone else (ZONE_NAMES[moved.from_zone] as String)
	return "is put into %s from %s" % [ZONE_NAMES[moved.to_zone], from]


func _condition(condition: MmCondition) -> String:
	var matches: SelectionMatchesCondition = condition as SelectionMatchesCondition
	if matches == null:
		return _fallback(condition, "_condition")
	var subject: String = _selection(matches.selection)
	var words: Array = _filter_words(matches.filter)
	var is_what: String = ", ".join(PackedStringArray(words[0] as Array))
	if (words[1] as String) != "" or is_what == "":
		is_what = _with_article(_noun_phrase(matches.filter, false))
	return "%s %s %s" % [subject, "are" if subject == "you" else "is", is_what]


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
	if effect is AddManaEffect:
		return "add " + _mana(effect as AddManaEffect)
	if effect is DestroyEffect:
		return "destroy " + _selection((effect as DestroyEffect).selection)
	if effect is CounterEffect:
		return "counter " + _selection((effect as CounterEffect).selection)
	if effect is ReturnToHandEffect:
		var returned: MmSelection = (effect as ReturnToHandEffect).selection
		return "return %s to %s hand" % [_selection(returned), "your" if _is_yours(returned) else "its owner's"]
	if effect is RegenerateEffect:
		return "regenerate " + _selection((effect as RegenerateEffect).selection)
	if effect is PreventDamageEffect:
		return _prevention(effect as PreventDamageEffect)
	if effect is CreateContinuousEffect:
		return _continuous((effect as CreateContinuousEffect).continuous) + " until end of turn"
	return _fallback(effect, "_effect")


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


func _continuous(continuous: MmContinuousEffect) -> String:
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
		return "%s %s %s" % [affected, _verb(continuous.affected, "gain"), " and ".join(gained)]
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
	if selection is TargetSelection:
		return _target((selection as TargetSelection).target_index)
	return _fallback(selection, "_selection")


func _target(index: int) -> String:
	if index >= _targets.size():
		return "that target"
	var spec: TargetSpec = _targets[index]
	if _named.has(index):
		return "that player" if spec.filter is IsPlayerFilter else "it"
	_named[index] = true
	if spec.among == TargetSpec.Among.SPELLS:
		return "target " + _spell_phrase(spec.filter)
	if spec.among == TargetSpec.Among.ABILITIES:
		return "target activated or triggered ability"
	if spec.among == TargetSpec.Among.GRAVEYARD_CARDS:
		return "target " + _graveyard_phrase(spec.filter)
	if _is_any_target(spec.filter):
		return "any target"
	return "target " + _noun_phrase(spec.filter, false)


## Whether [param selection] is a targeted card that can only be one its controller owns,
## as in "target creature card from your graveyard", which goes back "to your hand".
func _is_yours(selection: MmSelection) -> bool:
	var targeted: TargetSelection = selection as TargetSelection
	if targeted == null or targeted.target_index >= _targets.size():
		return false
	return (_filter_words(_targets[targeted.target_index].filter)[2] as Array).has(YOU_OWN)


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
		var noun: String = _filter_words(moved.filter)[1] as String
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
	var words: Array = _filter_words(filter)
	var adjectives: PackedStringArray = PackedStringArray(words[0] as Array)
	var noun: String = words[1] as String
	var after: PackedStringArray = PackedStringArray(words[2] as Array)
	if noun == "":
		noun = "permanent"
	if is_plural:
		noun += "s"
	if whose == MmTrigger.Whose.YOU:
		after.append("you control")
	elif whose == MmTrigger.Whose.OPPONENT:
		after.append("an opponent controls")
	var phrase: String = noun
	if not adjectives.is_empty():
		phrase = ", ".join(adjectives) + " " + phrase
	if not after.is_empty():
		phrase += " " + " ".join(after)
	return phrase


## "Creature spell", "white spell", or just "spell" for no filter.
func _spell_phrase(filter: MmFilter) -> String:
	var words: Array = _filter_words(filter)
	var parts: PackedStringArray = PackedStringArray(words[0] as Array)
	if (words[1] as String) != "":
		parts.append(words[1] as String)
	parts.append("spell")
	var phrase: String = " ".join(parts)
	var after: PackedStringArray = PackedStringArray(words[2] as Array)
	return phrase if after.is_empty() else phrase + " " + " ".join(after)


## "Creature card from your graveyard", or "card from a graveyard" for no filter.
func _graveyard_phrase(filter: MmFilter) -> String:
	var words: Array = _filter_words(filter)
	var parts: PackedStringArray = PackedStringArray(words[0] as Array)
	if (words[1] as String) != "":
		parts.append(words[1] as String)
	parts.append("card")
	var after: Array = (words[2] as Array).duplicate()
	var whose: String = "a graveyard"
	if after.has(YOU_OWN):
		whose = "your graveyard"
	elif after.has(OPPONENT_OWNS):
		whose = "an opponent's graveyard"
	after.erase(YOU_OWN)
	after.erase(OPPONENT_OWNS)
	parts.append("from " + whose)
	parts.append_array(PackedStringArray(after))
	return " ".join(parts)


## The words of [param filter]: its adjectives, its noun ("" for none) and what follows
## the noun, as [adjectives, noun, after].
func _filter_words(filter: MmFilter) -> Array:
	var adjectives: Array[String] = []
	var after: Array[String] = []
	var nouns: Array[String] = []
	_collect(filter, false, adjectives, nouns, after)
	if nouns.is_empty():
		return [adjectives, "", after]
	# "Artifact creature": the last kind named is the noun, and the others describe it.
	return [adjectives + nouns.slice(0, -1), nouns.back(), after]


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
	elif filter is IsTappedFilter:
		adjectives.append("untapped" if is_negated else "tapped")
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
	elif filter is IsPlayerFilter:
		nouns.append("player")
	else:
		adjectives.append(_fallback(filter, "_filter"))


# --- Numbers -------------------------------------------------------------------------

## A number as digits, or "X" with what X is kept for the end of the sentence.
func _amount(value: MmValue) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant != null:
		return str(constant.value)
	_where = _value_phrase(value)
	return "X"


func _cards(value: MmValue) -> String:
	var constant: ConstantValue = value as ConstantValue
	if constant == null:
		return _amount(value) + " cards"
	return "a card" if constant.value == 1 else _number_word(constant.value) + " cards"


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


# --- Words ---------------------------------------------------------------------------

static func _type_word(card_type: MmCardTypes.CardType) -> String:
	return (MmCardTypes.CardType.find_key(card_type) as String).to_lower()


static func _color_word(color: MmCardTypes.CardColor) -> String:
	return (MmCardTypes.CardColor.find_key(color) as String).to_lower()


static func _with_article(words: String) -> String:
	return ("an " if "aeiou".contains(words.left(1).to_lower()) else "a ") + words


static func _capitalized(words: String) -> String:
	return words.left(1).to_upper() + words.substr(1)


## What stands in for [param thing] when there are no words for it: its class, in brackets.
static func _fallback(thing: Resource, suffix: String) -> String:
	var script: Script = thing.get_script() as Script
	var file: String = script.resource_path.get_file().get_basename() if script != null else "unknown"
	return "[%s]" % file.trim_suffix(suffix).replace("_", " ")
