# Mill remembers the cards it milled, and a card is chosen from among them

Most Decrepit Old Bird // Speak Secrets brings three things. The creature has threshold, "This creature gets +1/+1 as long as there are seven or more cards in your graveyard". Its Adventure says "Mill four cards, then put an instant or sorcery card from among them into your hand."

**Mill is `MillEffect`** (`amount`, `players`; CR 701.17a). Each selected player puts the top cards of their library into their graveyard, all at once, top card first, with `ZoneChangeEvent.Reason.MILL`. A library that holds fewer gives all it has (CR 701.17b), and losing nothing: milling is not drawing. "Mill four cards" for you, "Each opponent mills two cards" for others.

**A spell remembers what it milled, and "them" finds it.** An effect that says so (`MmEffect.remembers_moved_cards()`, true for `MillEffect`) has the new objects of the cards it moved added to the resolution's context as `moved_ids`, once its batch is performed; `MovedCardsSelection` selects those still where they went, so a card that has moved again is a new object and not among them (ADR 0008). It lives in the context, as a chosen object does, so it is copied and replayed with it and nothing on the cards needs to remember it.

**"From among them" is a `ChosenSelection` with `from_among`.** The card is chosen as the effect that uses it begins, not targeted (CR 608.2d), from what `from_among` finds that matches its filter, so the existing `ChooseObjectDecision`, its candidates now cards in a graveyard, asks it. With no candidate, nothing is asked and nothing happens; with one it is still asked, since the player chooses. Putting it into the hand is `ReturnToHandEffect`, which already moved a card from a graveyard, and `AbilityText` says "put an instant or sorcery card from among them into your hand". The Info Panel asks "Choose an instant or sorcery card for Speak Secrets", "card" since the candidates are not permanents, and the Graveyard window takes the click, its pile glowing, as for a target there (game ADR 0032). A CHEAP Agent takes the candidate with the greatest mana value; a FULL one simulates each, as for any choice.

**Threshold is a `ContinuousStaticAbility` with a `ValueAtLeastCondition`** ("[value] is [amount] or more") over `CardsInZoneValue` ("the number of cards in [whose] [zone]"), counted as they are now, so the layer engine applies it whenever the count reaches seven and stops when it falls. Its text is Oracle's order, "This creature gets +1/+1 as long as there are seven or more cards in your graveyard." The ability word "Threshold —" has no rules meaning (CR 207.2c), so it is not generated, as reminder text is not.

Left out until a card needs them (ADR 0001): "whenever you mill", a replacement effect on a milled card, "from among them" after an effect other than mill (a reveal, a look at the top cards), choosing more than one from among them, and ability words in generated text.

## Addendum: "If you do" reads the answer to the "you may" before it

Riddlesmith says "you may draw a card. If you do, discard a card." The discard asks a decision of its own, which a `MayEffect` cannot wrap, so the sentence is two effects, a `MayEffect` and then an `IfEffect` whose condition is a `YouDidCondition`. The context remembers the answer as it remembers the cards milled: `ResolutionProcedure` sets `MmEffectContext.answered_yes` as each `MayEffect` or `MayPayEffect` begins, true only on a yes, its cost paid, and every context made from it after keeps it. A "you may pay" that could not be paid was never asked, which is no yes. `IfEffect` already asks its effect's own decision only when the effect will happen, so the discard is asked only after a yes. `AbilityText` says "If you do, discard a card." `MayPayEffect` keeps its own "If you do", which pays as it asks. "If you don't" is left out until a card needs it (ADR 0001).

## Second addendum: counting only the cards of a kind in a zone

Chitin Gravestalker says "This spell costs {1} less to cast for each artifact and/or creature card in your graveyard."

**`CardsInZoneValue` takes a `filter`**, null by default, which counts every card as before. With one it is "the number of [filter] cards in [whose] [zone]": each card of the zone that matches counts once, so an artifact creature card is one card however many of the filter's card types it has. The filter is asked of the card where it is, as a search's or a graveyard target's is. A `CostReductionAbility` with it takes off {1} for each, and `AbilityText` says so as Domain's reduction is said: "This spell costs {1} less to cast for each artifact or creature card in your graveyard." "Or" means what "and/or" does, since a card is counted once either way (ADR 0023). Threshold with a filter reads "there are seven or more creature cards in your graveyard".


## Third addendum: the tokens an effect created are remembered too

Harried Dronesmith says "create a 1/1 colorless Thopter artifact creature token with flying. It gains haste until end of turn. Sacrifice it at the beginning of your next end step."

**`CreateTokenEffect` remembers the tokens it creates.** Its `remembers_moved_cards()` is true, and `ResolutionProcedure` adds the new object of each `TokenCreatedEvent` of its batch to the context's `moved_ids`, as it adds a moved card's. So `MovedCardsSelection` is "it", the token just created, for the effects after it: "It gains haste until end of turn" is a continuous effect on it. A token that leaves the battlefield ceases to exist, so it is no longer among them. `AbilityText` calls them "it". No card yet both creates a token and says "them" of cards an effect of its own moved, which would find both. Engine ADR 0103 carries what the ability remembered into the delayed trigger it creates, whose "sacrifice it" is that token.
