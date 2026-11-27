# An Armor holds Starting Conditions, and only what is Worn reaches an encounter

An Armor is a resource on the game's side of the boundary (`Armor`, in `run/`), one file for each in `content/armor/`. It holds a name, its Armor Slot (Helm, Cuirass or Greaves), one or more Starting Conditions, its Armor Icon and a price of its own. It has no Rarity, so its price is not worked out by ADR 0070's formula: each Armor is given one, usually 150 to 300, which the Store reads from milestone 24. `Armor.problems()` checks its shape: a name, a Starting Condition, an Armor Icon of 32 × 32, a price, and each Starting Condition's own shape.

**A Starting Condition is a small resource that changes the Hero's `MmPlayerSetup`** (`StartingCondition`, one subclass for each kind): more or less starting life, a smaller opening hand, extra free mulligans, or an Emblem. Nothing in one names Armor, so a Status holds the same ones when Statuses arrive (milestone 33), as the glossary says the two share one system. The engine never learns where a Starting Condition came from: it is handed final numbers and a list of Emblems (ADR 0011). `StartingCondition.apply_all()` applies a list of them to a setup in order and then holds the numbers in bounds: starting life never below 1 and the opening hand never below 0, so the order of a gain and a loss does not matter.

**An Armor's Emblem is a file in `content/emblems/` named after the Armor**, with the Armor's name, as an Emblem a Status brings is (Diviner's Boon). It is found, drawn and given art as every other Emblem is (ADR 0032), and its ability is composed from the engine's primitives like a card's.

**What the Hero holds and wears is `HeldArmor`**, held by the `Run`. Each Armor is held as often as it was gained, and each Armor Slot holds one Worn Armor or none. Putting an Armor on fills its own slot in place of whatever was Worn there, which stays held; taking one off empties its slot, and it is still held. Both are choices, logged in the Run Log (`armor_put_on`, `armor_taken_off`) and replayed, and what is held and Worn is saved with the run by path (ADR 0074). Held but not Worn, an Armor does nothing.

**A Worn Armor's Starting Conditions are applied in `Run.hero_setup()`**, Helm, then Cuirass, then Greaves, each Armor's in the order authored, after the Emblems the run holds. A debug encounter wears Armor from Content with `--armor=<file>[,<file>]`, so an Armor can be seen in play before the Satchel puts one on.

**An Armor's words are written from its Starting Conditions** by `StartingConditionText`, one sentence for each, never by hand, as a Mod's are by `ModText` (ADR 0029):

- "You start each encounter with 3 more life." and "… with 2 less life."
- "Your opening hand has one fewer card." and "… two fewer cards."
- "You start each encounter with an extra free mulligan." and "… two extra free mulligans."
- "You get an emblem with "{2}{U}: Draw a card. Activate only as a sorcery and only once each game."", the quoted part `AbilityText`'s.

Armor is added to Content with `/add-armor` (`.claude/skills/add-armor/`), which composes the Emblem, saves both files, and checks the words against the user's.

Left for later: Barred Armor Slots, which come with Statuses (milestone 33); the Satchel that puts Armor on and takes it off (milestone 24); and the Store, Spoils and Trove handing Armor out (milestones 24 and 26).

The alternative was a Starting Condition that is one resource with a kind and an amount. It was rejected for the engine's own way of composing: each kind applies itself, so a new kind is a new class with its words, and nothing that applies them has to change.
