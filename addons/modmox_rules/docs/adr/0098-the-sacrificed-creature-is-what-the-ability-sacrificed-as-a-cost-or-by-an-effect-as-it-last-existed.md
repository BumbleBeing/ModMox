# "The sacrificed creature" is what the ability sacrificed, as a cost or by an effect, as it last existed

Bushmeat Poacher says "{1}, {T}, Sacrifice another creature: You gain life equal to the sacrificed creature's toughness. Draw a card." Disciple of Bolas says "When this creature enters, sacrifice another creature. You gain X life and draw X cards, where X is that creature's power." Both read the creature they sacrificed after it has gone.

**"The sacrificed creature" is `SacrificedSelection`, with no fields.** It finds each permanent the spell or ability sacrificed, in the order sacrificed, by the ID it had on the battlefield, so a `PowerValue` or `ToughnessValue` reads it as it last existed (CR 608.2h): a pump until end of turn counts, and a token that has ceased to exist still has its last-known information. It never finds the card in the graveyard: `MovedCardsSelection` finds the new objects an effect moved, which is right for "put one of them into your hand" (engine ADR 0080) and wrong here, since the card has only its printed power and toughness. Last-known information lasts the turn (`MmGameState`'s departed objects, cleared as each turn begins), and a sacrifice and the effect that reads it happen in the same turn.

**What it finds is kept in the context the ability resolves in**: `MmEffectContext.sacrificed_ids`, filled from two places.

- **A cost.** As a `SacrificePermanentsCost` is paid, `CastProcedure` performs a `SacrificedForCostEvent`, which records the IDs on the spell's or ability's object on the stack (`MmGameObject.sacrificed_object_ids`, copied with the object and in the fingerprint). `MmEffectContext.of_stack_object()` carries them into the context. It is an event, as the X chosen is (ADR 0007), so a copy of the game and a replay keep it.
- **An earlier effect.** After each batch an effect performs, `ResolutionProcedure` adds the permanents the batch sacrificed (zone changes whose reason is `SACRIFICE`) to the context, as it remembers milled cards, so every effect after a `SacrificeEffect` reads them. Disciple's "that creature" is the same Selection.

`AbilityText` calls it "the sacrificed [noun]", the noun from the first thing the ability sacrifices ("creature" for "another creature"), or "permanent". Poacher reads "You gain X life, where X is the sacrificed creature's toughness", and Disciple "You gain X life, where X is the sacrificed creature's power. Draw X cards, where X is the sacrificed creature's power.", both plainly the cards' meaning (ADR 0023).

The Agent needs nothing of its own: its simulations run the engine, so what a sacrifice gives back is scored, and it already chooses what to sacrifice for a cost or an effect.

Left out until a card needs them (ADR 0001): what a "you may sacrifice" resolution cost sacrificed (Selfcraft Mechan's, engine ADR 0088), and "life equal to" worded as Oracle words it.

## Addendum: a source that sacrifices itself

Heartfire Immolator says "{R}, Sacrifice this creature: It deals damage equal to its power to target creature or planeswalker." "This creature" does not find it: `SourceSelection` selects nothing once its object has left, so its power would be 0. It deals the damage as it last existed, which `DealDamageEffect` already does for a source that has gone (CR 608.2h), and "its power" is the power it had as it was sacrificed, a pump until end of turn and prowess included.

**A source sacrificed by `SacrificeThisCost` is what the ability sacrificed.** As `CastProcedure` pays the cost, it performs the same `SacrificedForCostEvent` a `SacrificePermanentsCost` does, with the source's ID, so `PowerValue` of `SacrificedSelection` reads it as it last existed. `SourceSelection` is left as it is: an effect that changes "this creature" must find nothing once it has gone.

`AbilityText` calls what an ability sacrificed "it" when its only sacrifice is its own source, so Heartfire Immolator reads "{R}, Sacrifice this creature: This creature deals damage to target creature equal to its power.", plainly the card's meaning (ADR 0023). The Agent needs nothing of its own: the ability is Removal by its effects, and its simulation reads the damage from the power as it was.
