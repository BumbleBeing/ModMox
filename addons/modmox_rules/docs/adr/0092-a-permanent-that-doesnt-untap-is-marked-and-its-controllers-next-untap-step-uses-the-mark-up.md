# A permanent that doesn't untap is marked, and its controller's next untap step uses the mark up

Niblis of Frost says "Whenever you cast an instant or sorcery spell, tap target creature an opponent controls. That creature doesn't untap during its controller's next untap step." CR 502.3: in the untap step the active player untaps all their permanents, but an effect can keep one from untapping.

**"[selection] doesn't untap during its controller's next untap step" is a `DoesntUntapEffect`**, with a Selection as every effect has (ADR 0014). It marks each selected permanent on the battlefield, all at once, with a `NextUntapSkippedEvent`, which sets `MmGameObject.skips_next_untap`. Niblis of Frost's trigger is a `TapEffect` and then this, both selecting its one target.

**The next untap step of whoever controls the permanent uses the mark up.** That untap step leaves the permanent tapped and performs an `UntapSkippedEvent`, which clears the mark, whether the permanent was tapped then or not; the other player's untap steps leave the mark alone. It is asked of the controller as each untap step begins, so a creature that changed hands waits for its new controller's. A permanent that changes zones is a new object without it (ADR 0008). The mark is copied with the Game Object and is in the fingerprint, so a Simulation Copy and a replay keep it, and the Object View shows it to both players (`MmObjectView.skips_next_untap`): it is as public as the permanent.

**It is not exert**, though both keep a permanent from untapping once. An exerted permanent remembers the player who exerted it, whose next untap step it skips (CR 701.43a), and exerting is a cost; this one follows the permanent's controller, as the words say, and is an effect. A permanent may be both, and its controller's next untap step then ends both.

The Agent needed nothing new: Niblis of Frost's trigger taps, so `AiTiming.taps()` makes it harmful and it is aimed at the other player's creatures, and the simulation sees the creature stay tapped through their untap step. It taps the one worth most.

`AbilityText` says it as Oracle does, naming again what was just tapped: "That creature doesn't untap during its controller's next untap step." The permanent's State Information says "Won't untap: Won't untap during its controller's next untap step." (the user's words).

Left out until a card needs them (ADR 0001): "doesn't untap during its controller's untap step" for as long as something lasts, "for as long as you control this", skipping more than one untap step, and a permanent that doesn't untap as a static ability of its own.
