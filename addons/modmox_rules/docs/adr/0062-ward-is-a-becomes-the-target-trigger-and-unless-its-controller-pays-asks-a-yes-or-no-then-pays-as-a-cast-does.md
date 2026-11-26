# Ward is a becomes-the-target trigger, and "unless its controller pays" asks a yes or no, then pays as a cast does

Ward came on the card track with Leonin Lightbringer, a card of the Villain deck `kemba_kha_enduring`: "Ward {2}" (CR 702.21a), "Whenever this permanent becomes the target of a spell or ability an opponent controls, counter it unless that player pays {2}." It was Set Aside until the Hero could pay a cost while something resolves. ADR 0061 built that payment loop, and the user judged that Ward then needed no GUI prototype.

**Ward is a triggered ability built from three general parts.** `WardAbility` extends `TriggeredAbility` and is authored with its `mana_cost` alone. As `CyclingAbility` does, it makes its own trigger and effect, and they are saved with it, so a Modification changes them the same way.
- **The trigger.** A `BecomesTargetTrigger` with `IsSourceFilter` ("this permanent") and `whose = OPPONENT`, compared with the controller of the spell or ability. It matches a `TargetChosenEvent`, so it triggers as each target is chosen (CR 601.2c, 603.3d) and goes on the stack once the spell or ability is (CR 603.3).
- **What the trigger points at.** "That player" is the controller of the spell or ability and "it" is the stack object. Ward refers to the spell; it does not target it, so it never fizzles and nothing can make it target something else.
- **The effect.** A `CounterEffect` with `TriggeringObjectSelection` and its new field `unless_paid`.

Rewinding a cast also takes back the trigger it made. A spell with several targets triggers ward once for each warded permanent it targets, and declining any one of them counters the whole spell.

**"Counter it unless its controller pays [cost]" asks a yes or no, then pays as a cast does** (CR 118.12).
- As the effect begins, the controller of the stack object it would counter is asked a `ChooseYesOrNoDecision`. That decision gained `cost`, which is null for a plain "you may". Its `effect` is now "what the question is about".
- Nothing is asked if that object has already left the stack, or if `ManaPayment.can_afford()` says the payer could not pay. In the second case the object is countered (CR 118.3).
- A yes starts a `ManaPaymentProgress` for the cost in `ResolutionProcedure`, as an X does. Once it is paid, the effect gets its yes and counters nothing. A no counters.
- Because `can_afford()` is exact, a payment that is begun always finishes. The procedure copies `_is_paying_for_yes` in `copy_for()`, so a Simulation Copy made mid-payment carries on alike. The yes and each payment are plain ints in the decision log (ADR 0010).
- A separate decision kind with a decline built into `PayManaDecision` was rejected: the yes or no and the payment loop already existed and already had inputs.

**The AI.**
- **Paying.** A CHEAP Agent pays a cost it is asked about. It is asked only when it can pay, and the spell was worth casting. A FULL Agent simulates paying and declining, with paying as the default the other must beat.
- **Choosing targets.** A CHEAP Agent skips an opponent's warded candidate when it could not pay both the spell's mana cost and the ward cost together. A FULL Agent simulates each target, ward trigger and payment included, so it needs nothing new.
- No Timing Tag changes: nobody casts ward.

**The words.** `AbilityText` prints "Ward {2}" as a keyword, with its cost alone, as equip does. On the stack it reads "Counter that spell or ability unless its controller pays {2}." The trigger reads "whenever [this creature] becomes the target of a spell or ability an opponent controls".

Left out until a card needs them (ADR 0001):
- a ward cost that is not mana ("Ward—Pay 3 life");
- "unless [a player] pays" for several spells at once, or by a player other than the controller of what is countered;
- one permanent made the target of one spell twice. Through two "target" words it becomes the target once, but triggers twice here.

## Addendum: the same question asks "you may pay {1}"

A `ChooseYesOrNoDecision` with a `cost` is also asked by a `MayPayEffect` with a mana cost, as Myrsmith's "you may pay {1}" (ADR 0076's addendum): yes is paid the same way, and then what the effect offers happens instead of nothing being countered. The Encounter Screen marks what ward would counter only for a ward trigger.

## Addendum: spells a permanent keeps from being countered

Destiny Spinner says "Creature and enchantment spells you control can't be countered." `CantBeCounteredAbility` is said only of the spell itself; this one is a permanent's, and reaches its controller's other spells.

**`SpellsCantBeCounteredAbility` is a static ability with a `filter`**, "[filter] spells you control can't be countered", working while its permanent is on the battlefield. "You control" is part of the words, so the filter leaves it out, and a spell an opponent controls is never reached.

**Whether a spell can be countered is asked of `CounterRules.can_be_countered()`**, which `CounterEffect` asks for each spell it would counter, and the Agent asks before it aims a counter or casts a cheap one: a spell can't be while it has `CantBeCounteredAbility`, or while a permanent its controller controls has a `SpellsCantBeCounteredAbility` whose filter it matches. An ability can always be countered. As before (CR 101.2), a counter may still target such a spell and resolves doing nothing to it, and ward's "unless that player pays" asks no one to pay for it.

`AbilityText` joins the kinds of spell with "and": "Creature and enchantment spells you control can't be countered."

Left out until a card needs them (ADR 0001): "can't be countered" for abilities, and for an opponent's spells.
