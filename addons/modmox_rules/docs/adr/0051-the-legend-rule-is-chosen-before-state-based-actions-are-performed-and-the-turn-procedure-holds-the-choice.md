# The legend rule is chosen before state-based actions are performed, and the turn procedure holds the choice

The legend rule arrived with Arahbo, the First Fang, the first legendary card, for the Villain whose deck runs two copies: "If a player controls two or more legendary permanents with the same name, that player chooses one of them, and the rest are put into their owners' graveyards" (CR 704.5j). The Legendary supertype was already read from Oracle Data and drawn as a crown, but no rule looked at it. It is the first state-based action that asks a player anything.

**The choice comes first, and everything is then performed at once.** State-based actions are performed simultaneously (CR 704.3), so "dies" triggers see everything that died together and a creature kept alive only by the legend that goes still dies with it (ADR 0017). So `StateBasedActions.check()` finds every group of legends one player controls with one name, in ID order, the active player's first (CR 101.4) and each player's in the order of their lowest IDs. While a group has no kept legend it returns a `ChooseLegendToKeepDecision` for it before anything is performed. Once every group has one, the other members go to their owners' graveyards in the same batch as every other state-based action that applies. Asking group by group means one click answers each choice, where one decision per player would need a list (ADR 0016) and a confirm. `any_apply()` counts a group, so a cleanup step with one gives priority (CR 514.3a).

**The legends kept so far are held by `TurnProcedure`, not by the game state.** They are progress through one check, as the passes in succession are, so they need no event (ADR 0007). They are copied in `copy_for()`, because a FULL Agent copies the encounter while the choice is pending (ADR 0020), and they are used up as the batch is built. Replay and undo work from the Decision Log as for any answer (ADR 0010, 0015).

**The legend rule's move has a reason of its own, `ZoneChangeEvent.Reason.LEGEND_RULE`.** It is neither destruction nor a sacrifice. So indestructible does not stop it and a regeneration shield does not replace it (CR 702.12b, 701.19), and it is still a death (CR 700.4).

**The name and the supertype are read through the characteristics query (ADR 0009),** so a Modification that renames a card changes which legends share a name.

**The Hero clicks the one to keep.** Every candidate glows as a target does and offers one "Keep" option, so a single click answers (game ADR 0022). The Info Panel says "Choose which [name] to keep". The user agreed that this needed no GUI prototype, since nothing new is drawn.

**The AI Agent is not told to avoid a second copy of a legend.** A FULL Agent simulates keeping each legend, as it does any choice, and its simulations of casting a second copy see the one that is lost. That is sometimes worth it: both copies of Arahbo trigger as the second enters. A CHEAP Agent keeps its most valuable legend, which keeps one that can attack over one with summoning sickness.

Left out until a card needs it (ADR 0001): an owner's graveyard other than the controller's, since nothing changes control yet; and the world rule and planeswalker uniqueness, which are not in the game.
