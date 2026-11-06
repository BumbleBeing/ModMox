# Rules Engine Roadmap

The engine is built one milestone at a time. Each milestone is test-first and fully green before the next one begins, and no milestone adds a mechanic before it is needed (ADR 0001). The exact card list and test scenarios for a milestone are agreed at the start of that milestone, not in advance.

1. ✅ **Skeleton**: the addon folder, GUT 9.7.1, a headless test command (`tools/test.sh`), and enforced static typing.
2. **Core state**: players, zones, Game Objects with zone-change identity (ADR 0008), Encounter Setup, the Game RNG and AI RNG (ADR 0006), opening hands and London mulligans with Free Mulligans.
3. **Turn structure and priority**: every phase and step, priority passing, an empty stack, and the turn passing. No cards yet.
4. **Lands and mana**: playing a land, mana abilities, and the mana pool emptying between steps.
5. **Casting and the stack**: costs, Values, Filters, targets, resolution, and spells fizzling when their targets become illegal. The first real cards are simple burn and draw spells.
6. **Creatures and combat**: summoning sickness, declaring attackers and blockers, combat damage, and first strike.
7. **State-based actions**: dying, reaching 0 life, and drawing from an empty library.
8. **Triggered abilities.**
9. **Static abilities and layers.**
10. **Replacement and prevention effects.**
11. **First playable Alpha subset** against a simple AI Agent.

The GUI is game-side work that can start after milestone 6 at the earliest.
