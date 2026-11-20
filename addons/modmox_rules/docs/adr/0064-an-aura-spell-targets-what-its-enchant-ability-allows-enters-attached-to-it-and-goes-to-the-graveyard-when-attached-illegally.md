# An Aura spell targets what its enchant ability allows, enters attached to it, and goes to the graveyard when attached illegally

Auras came for Nylea's Presence, a card of the Villain deck `zar_ojanen_scion_of_efrava`: "Enchant land. When this Aura enters, draw a card. Enchanted land is every basic land type in addition to its other types." ADR 0041 had left Auras out until a card needed them. Its second and third sentences are ordinary abilities. Its land's new mana abilities are a primitive of their own (CR 305.7).

**Enchant is a static ability with a Filter.** `EnchantAbility` ("Enchant [quality]", CR 702.5) is authored with one field, `filter`, which says what the Aura may be attached to: `HasCardTypeFilter` LAND for "Enchant land". It is matched against permanents only. "Enchant player" waits for a card (ADR 0001).

**An Aura spell's target is read from one place.** An Aura spell targets what it may enchant (CR 303.4a).
- `EnchantAbility.aura_spell()` makes, once and unsaved, a `SpellAbility` with one `TargetRequirement` ("target [permanent the filter matches]") and no effects.
- `CastProcedure.spell_ability_of()` hands that out for a card with enchant and no spell ability of its own.
- So everything that already reads a spell's targets reads the Aura's, with nothing new in each:
  - casting chooses the target (CR 601.2c);
  - the turn procedure offers no cast with nothing to target;
  - resolution rechecks it (CR 608.2b), and an Aura spell whose target is gone does not resolve and goes to its owner's graveyard (CR 608.3b);
  - the AI's target lists see it;
  - protection from the Aura keeps it from being targeted (CR 702.16b).
- Two alternatives were rejected:
  - Authoring a `SpellAbility` beside the enchant. It writes the filter twice, and the two could disagree.
  - Asking for the enchant's target in every one of those places.

**It enters attached.** As an Aura spell resolves, the `ZoneChangeEvent` that puts it onto the battlefield carries `attached_to_on_arrival`, the target's ID, and the new object is attached as it arrives, as ADR 0052's chosen type is.
- So its static abilities apply at once, and its own "enters" abilities find "enchanted land".
- ADR 0041's rule that a new object is attached to nothing holds for every other way onto the battlefield.

**What it may stay attached to is asked where an Equipment's is.** `AttachmentRules.can_be_attached()` now also refuses a permanent the Aura's enchant filter does not match, and its protection check already covers "enchanted" (CR 702.16d).

**An Aura attached illegally goes to the graveyard.** State-based actions have a second rule beside CR 704.5n's:
- An Aura (subtype "Aura") attached to something it may not be attached to, to something that is gone, or to nothing, is put into its owner's graveyard (CR 704.5m). This is the new `ZoneChangeEvent.Reason.UNATTACHED_AURA`.
- An Equipment is still only unattached.
- An Aura is told by its subtype, as the rule says, and what it may enchant by its enchant ability.

**"Enchanted land" is the Selection "equipped creature" already was.** `AttachedToSelection` selects what the ability's source is attached to, so "Enchanted land is every basic land type" is an ordinary `ContinuousStaticAbility` with an `AddSubtypesContinuousEffect` over it, in layer 4 with the Aura's timestamp, and it ends as the Aura leaves.

**The words.** `AbilityText` prints "Enchant land", a keyword with the filter's noun and no article. A card with enchant calls itself "this Aura" (current Oracle wording). `AttachedToSelection` reads "enchanted land" on a card with "Enchant land", and still "equipped creature" otherwise. Enchant has no Keyword Chip: its own line says it, and the board shows what it enchants.

**The AI.** An Aura is a permanent spell, so its Timing Tag is NONE and simulation decides when to cast it.
- The Board Evaluator values an enchanted land as any land, so a land's new types score the same on either side.
- Every Aura so far helps what it enchants, so an Aura spell is aimed only at its controller's own permanents. A FULL Agent simulates only those, and a CHEAP one prefers an untapped one, whose new types or bonus can be used this turn.
- An Aura that harms what it enchants waits for a card.

**On the screen** (game ADR 0042): an Aura on a land lies sideways behind it in that land's row, whoever controls the land, and the row gives the land the room of its name strip.

Left out until a card needs them (ADR 0001):
- choosing what an Aura put onto the battlefield other than by resolving is attached to (CR 303.4f). Such an Aura enters attached to nothing and the state-based action puts it into the graveyard;
- "Enchant player";
- an Aura that is also a creature (CR 303.4d);
- "enchanted" as a Filter beside `IsEquippedFilter`;
- an effect that moves an Aura;
- the new timestamp an Aura gets as it becomes attached (CR 613.7e).
