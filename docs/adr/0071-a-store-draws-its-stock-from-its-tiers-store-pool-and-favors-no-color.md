# A Store draws its stock from its Tier's Store Pool and favors no color

A Store's cards come from a Store Pool: one authored list for each Tier, kept apart from the Starting Pool and not divided by color. Nothing weights the draw toward the Hero Color or the Stage's color, so a Store's cards are entirely random. Each Tier's list is its own, not the lists below it added together, and a card may be on several. So a Tier 5 list can leave weak cards out rather than carry them along.

Three other sources were considered and rejected:
- The Starting Pool and the Bazaar's unlocks, weighted toward the Hero Color as the first deal is, which would have made the Store the place to build the Hero's own colors.
- The same pool weighted toward the Stage's color.
- The Stage's Villains' decks, as the Spoils are drawn.

**How a card is drawn.** Each card in stock first rolls its Rarity from the Tier's odds, one table that Potions and Mods share, then draws a card of that Rarity from the Tier's Store Pool. When the pool holds none of that Rarity, it falls back to the nearest lower Rarity it does hold. No card appears twice in one Store. Basic lands are never in a Store Pool. Potions, Mods and Armor have no pools by Tier: they are drawn from everything authored and unlocked, and a Unique Mod is never stocked.

**The Bazaar adds to the Store Pool, and Achievements to the Starting Pool.** A card unlocked in the Bazaar joins the Store Pool of each Tier it is unlocked for and never the Starting Pool, which only Achievements add to. So the Bazaar's cards are bought in a run, and the Achievements' cards are dealt at its start.

**Stock is fixed for the visit.** A shop's stock is rolled when the Hero arrives, from a stream of its own of the Run Seed (ADR 0025), and never restocked. A bought good leaves its place empty, and there is no paid reroll, so each visit is a choice among what is there. A reroll can be added later if shops prove too swingy. While the Hero stands on the shop's Node, the stock and what has been bought there are run state, so a save restores the shop exactly, rather than rolling it again from the seed and replaying the purchases. ADR 0039 keeps the Spoils out of half-paid states for the same reason.
