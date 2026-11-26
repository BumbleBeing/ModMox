# An additional cost is a static ability of its spell, and its choice is asked once the mana is paid

Fear of Isolation says "As an additional cost to cast this spell, return a permanent you control to its owner's hand." It is the first additional cost (CR 601.2f, 118.8), and the first cost that returns a permanent.

**`AdditionalCostAbility` is a static ability of the spell, holding `costs`: the `MmCost` list an activated ability and a flashback cost use.** It does nothing on the battlefield. A cost kind is still written once and serves all three. `CastProcedure.additional_costs_of()` reads every one a spell has, its Adventure's when it is cast as one, and `TurnProcedure` offers the cast only while each of them can be paid, beside any flashback cost (CR 601.2f). A cast from the graveyard pays both, as the rules have it.

**`ReturnPermanentsCost` is "Return [count] [filter] to its owner's hand"**, as `TapCreaturesCost` is "Tap [count] [filter]". It asks the same `ChoosePermanentsDecision`, which now says what paying does with its `purpose` (`TAP` or `RETURN_TO_HAND`), so the Info Prompt can say "Return a permanent you control to its owner's hand for Fear of Isolation", the user's words. The permanents go to their owners' hands together, as new objects (ADR 0008), so a "leaves the battlefield" ability sees them leave as one batch. A cost paid stays paid whatever becomes of the spell.

**An additional cost's choice is asked once the mana is paid, not before it as ADR 0048 asks the rest.** CR 601.2g lets mana abilities be activated before the costs are paid, and CR 601.2h lets the costs be paid in any order, so the usual play is to tap a land for {1}{U} and then return that land to cast Fear of Isolation. Asked before the mana, a land returned for the cost could no longer pay, and the cast would be stuck and rewound. ADR 0048 asks a cost's choice before the mana so that creatures tapped for a cost cannot also be tapped for mana; returning has no such double use, since a permanent tapped for mana may still be returned. `CastProcedure` keeps one list of costs, the ability's or the flashback cost's first, and asks the first `_costs_before_mana` of them before the mana (ADR 0048) and the rest, the spell's additional costs, in a stage of their own once it is paid. A cost that can no longer be paid then makes the cast stuck, as before.

The AI needs nothing of its own: its pick of the permanents simulates each choice at FULL and takes the least valuable at CHEAP, as for a tapping cost, and the simulation weighs what casting costs.

Left out until a card needs them (ADR 0001): additional costs that are optional (kicker, CR 702.33) or chosen from ("sacrifice a creature or discard a card"), cost increases, and additional costs of activated abilities.

## Addendum: a cost that asks which card, and sacrificing, as additional costs

Makeshift Mauler says "As an additional cost to cast this spell, exile a creature card from your graveyard." `ExileFromGraveyardCost` had been paid only as a "you may" resolved (ADR 0088), and its choice is a `ChooseObjectDecision`, which the turn procedure always handed to a resolution; asked during a cast, there was none, and the answer was lost. **A `ChooseObjectDecision` asked while a cast is under way is now the cast's to answer**, and `CastProcedure` pays the cost being chosen with the card chosen, as it pays a `ChoosePermanentsDecision` with the permanents. It is asked once the mana is paid, as every additional cost's choice is here.

**Canceling the cast takes the choice back**, as it does Fear of Isolation's pick. The Info Prompt says "Exile a creature card from your graveyard for Makeshift Mauler", the words ADR 0088 gave Kishla Trawlers's cost, with Cancel while the cost is a spell's or an activated ability's, and none while a triggered ability pays it as it resolves.

`SacrificePermanentsCost` (ADR 0088's addendum) can be an additional cost too, "As an additional cost to cast this spell, sacrifice a creature", asked as the others are; no card says so yet.

The AI exiles the creature card with the least mana value, as it does for Kishla Trawlers, since no simulation sees a graveyard.
