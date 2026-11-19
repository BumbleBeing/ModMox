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
