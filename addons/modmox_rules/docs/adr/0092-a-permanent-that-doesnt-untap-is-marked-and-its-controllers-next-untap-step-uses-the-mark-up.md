# A permanent that doesn't untap is marked, and its controller's next untap step uses the mark up

Niblis of Frost says "Whenever you cast an instant or sorcery spell, tap target creature an opponent controls. That creature doesn't untap during its controller's next untap step." CR 502.3: in the untap step the active player untaps all their permanents, but an effect can keep one from untapping.

**"[selection] doesn't untap during its controller's next untap step" is a `DoesntUntapEffect`**, with a Selection as every effect has (ADR 0014). It marks each selected permanent on the battlefield, all at once, with a `NextUntapSkippedEvent`, which sets `MmGameObject.skips_next_untap`. Niblis of Frost's trigger is a `TapEffect` and then this, both selecting its one target.

**The next untap step of whoever controls the permanent uses the mark up.** That untap step leaves the permanent tapped and performs an `UntapSkippedEvent`, which clears the mark, whether the permanent was tapped then or not; the other player's untap steps leave the mark alone. It is asked of the controller as each untap step begins, so a creature that changed hands waits for its new controller's. A permanent that changes zones is a new object without it (ADR 0008). The mark is copied with the Game Object and is in the fingerprint, so a Simulation Copy and a replay keep it, and the Object View shows it to both players (`MmObjectView.skips_next_untap`): it is as public as the permanent.

**It is not exert**, though both keep a permanent from untapping once. An exerted permanent remembers the player who exerted it, whose next untap step it skips (CR 701.43a), and exerting is a cost; this one follows the permanent's controller, as the words say, and is an effect. A permanent may be both, and its controller's next untap step then ends both.

The Agent needed nothing new: Niblis of Frost's trigger taps, so `AiTiming.taps()` makes it harmful and it is aimed at the other player's creatures, and the simulation sees the creature stay tapped through their untap step. It taps the one worth most.

`AbilityText` says it as Oracle does, naming again what was just tapped: "That creature doesn't untap during its controller's next untap step." The permanent's State Information says "Won't untap: Won't untap during its controller's next untap step." (the user's words).

Left out until a card needs them (ADR 0001): "doesn't untap during its controller's untap step" for as long as something lasts, "for as long as you control this", skipping more than one untap step, and a permanent that doesn't untap as a static ability of its own.

## Addendum: a permanent that can't block this turn is marked the same way

Arena Athlete says "Heroic — Whenever you cast a spell that targets this creature, target creature an opponent controls can't block this turn." It is a rule of the turn (CR 509.1a), not an ability: granting "This creature can't block" until end of turn would be lifted by an effect that makes it lose all abilities, which "can't block this turn" is not.

**It is `CantBlockThisTurnEffect`**, with a Selection, and it marks each selected permanent with the Game Turn it is in (`MmGameObject.cant_block_in_game_turn`, set by a `CantBlockMarkedEvent`), as `DoesntUntapEffect` marks a Skipped Untap. `CombatProcedure` leaves a permanent marked with the current Game Turn out of its controller's blocker candidates, beside one with `CantBlockAbility`. Nothing ends the mark: once its turn has passed it forbids nothing. A zone change leaves it behind with the old object (ADR 0008). The mark is copied, in the fingerprint, and public in the Object View (`cant_block_this_turn`, true only in its own Game Turn).

`AbilityText` says it as Oracle does: "target creature an opponent controls can't block this turn". The permanent's State Information says "Can't block: Can't block this turn." (the user's words).

**The AI aims it as it aims a tap** (`AiTiming.taps()`): it harms what it reaches, so it is aimed at the other player's creatures, its targets are scored once the turn is over, and one already tapped is a waste of it. Its guess at who could block leaves a marked creature out.

