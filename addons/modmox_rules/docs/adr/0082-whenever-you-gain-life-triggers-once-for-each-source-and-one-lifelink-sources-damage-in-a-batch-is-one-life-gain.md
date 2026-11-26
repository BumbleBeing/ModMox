# "Whenever you gain life" triggers once for each source, and one lifelink source's damage in a batch is one life gain

Unflinching Hortimancer says "Whenever you gain life, put a +1/+1 counter on this creature." Such an ability reads "whenever a source causes you to gain life" (CR 119.9): gaining life from two sources at once triggers it twice, and gaining 0 life triggers nothing.

**Life is gained in two places, and `LifeGainedTrigger` hears both.** A `GainLifeEffect` performs a `LifeGainedEvent`, one for each player it reaches, so an overloaded "its controller gains 3 life" that finds a player twice is still one life gain. Lifelink is not a trigger: its gain is part of the damage (CR 120.3f), so `DamageEvent` changes the life itself and marks `is_lifelink`. The trigger matches a `LifeGainedEvent` of more than 0, and a `DamageEvent` with `is_lifelink` and an amount, for the source's controller. Splitting lifelink's gain into an event of its own would have made two events of one rule and changed what every damage test reads, for nothing a card needs.

**One source's damage in one batch is one occasion.** Two lifelink creatures dealing combat damage at once are two life gains (CR 119.9), and they are two `DamageEvent`s, so that falls out. But one lifelink creature dealing damage to two creatures at once, as an attacker blocked by two or an ability that deals damage to each creature, is one life gain, and it is two `DamageEvent`s in the same batch (A144). So a trigger may say what an event is an occasion of (`MmTrigger.occasion_of()`, "" for most, each event its own), and `TriggerDetection` lets the events of one batch that one ability calls the same occasion trigger it once, for the first of them, as once each turn does (ADR 0054's addendum). `LifeGainedTrigger` calls a lifelink `DamageEvent` an occasion of its source.

"That player" is the player who gains the life; there is no "that creature". `AbilityText` says "Whenever you gain life", "Whenever an opponent gains life" and "Whenever a player gains life".

Left out until a card needs them (ADR 0001): the amount gained ("you gain that much life", "whenever you gain 3 or more life"), "whenever you gain life for the first time each turn", and replacing or preventing a life gain.

## Addendum: "one or more" zone changes are one occasion for each batch

Dour Port-Mage says "Whenever one or more other creatures you control leave the battlefield without dying, draw a card." `ZoneChangeTrigger.is_one_or_more` calls every move of a batch one occasion, so two creatures returned together trigger it once and two returned apart trigger it twice; "that creature" is the first. `is_except_to_zone` turns `to_zone` into the one zone it does not wait for: from the battlefield to anywhere but the graveyard is "leaves the battlefield without dying" (CR 700.4), so a creature returned to its owner's hand or exiled, a token too, triggers it and one that dies does not. It still looks back (ADR 0017), so the creatures are seen as they were on the battlefield, and an ability leaving with them still sees them go.

## Addendum: whether a player gained life this turn

Poisoner's Apprentice says "Infusion — When this creature enters, target creature an opponent controls gets -4/-4 until end of turn if you gained life this turn." Infusion is an ability word, with no rules meaning (CR 207.2c).

**"If you gained life this turn" is a Condition, `GainedLifeThisTurnCondition`**, with no fields, as raid's is (engine ADR 0095's addendum). It is true while the controller of the spell or ability that asks has gained more than 0 life this turn.

**The life each player gained this turn is kept on the player**: `MmPlayer.life_gained_this_turn`, added to by `MmPlayer.gain_life()`, which both `LifeGainedEvent` and a lifelink `DamageEvent` call, so a gain from an effect and lifelink's gain count alike (CR 119.3, 120.3f); a loss still goes through `change_life()`. It is cleared with the player's other counts as each turn begins, and copied with the player and in the fingerprint. It is a number rather than a yes or no, since "if you gained 3 or more life this turn" would read the same number.

**The Apprentice's "if" is asked as the ability resolves, not as it triggers**: it comes at the end of the sentence, so the ability is an `IfEffect` (CR 608.2c), not an intervening "if" (CR 603.4). It triggers and targets whatever the player gained, and a gain in response still counts. `AbilityText` would word an `IfEffect` first in a triggered ability as "When this creature enters, if you gained life this turn, …", which a player reads as an intervening "if". So a triggered ability whose only effect is an `IfEffect` (not an "unless") puts the "if" after what it does: "… gets -4/-4 until end of turn if you gained life this turn."

The Agent needs nothing of its own: the simulation sees a -4/-4 that does nothing without a gain, and a Rollout that gains life first sees it kill.

Left out until a card needs them (ADR 0001): an amount ("if you gained 3 or more life this turn"), and the other player's gains ("if an opponent gained life this turn").


## Addendum: whether a player lost life this turn

Bat Whisperer says "When this creature enters, if an opponent lost life this turn, create a 1/1 black Bat creature token with flying."

**"If an opponent lost life this turn" is a Condition, `LostLifeThisTurnCondition`**, with a `whose` that says whose loss counts relative to the controller of the spell or ability that asks: "you", "an opponent", or "a player". It is true while a player it names has lost more than 0 life this turn. The Whisperer's is an intervening "if" (CR 603.4), the trigger's own condition, so with no life lost it never triggers.

**The life each player lost this turn is kept on the player**, as the life gained is: `MmPlayer.life_lost_this_turn`, added to by `MmPlayer.lose_life()`, which both `LifeLostEvent` and a `DamageEvent` to a player call, so damage (CR 120.3a), an effect and paying life (CR 119.4, which performs a `LifeLostEvent`) count alike. Nothing changes a life total down through `change_life()` any more. It is cleared with the player's other counts as each turn begins, and copied with the player and in the fingerprint.

The Agent's Timing Tags give a permanent spell whose own "enters" ability waits for an opponent's life loss AFTER_ATTACKING, as raid's does (engine ADR 0095's addendum): it is cast in the postcombat main phase, once an attack has had its chance to deal damage. One that waits for its own controller's loss is not held.

Left out until a card needs them (ADR 0001): an amount ("if an opponent lost 3 or more life this turn"), and "for each opponent who lost life this turn".
