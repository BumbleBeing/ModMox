# Rules Engine Roadmap

The engine is built one milestone at a time. Each milestone is test-first and fully green before the next one begins, and no milestone adds a mechanic before it is needed (ADR 0001). The exact card list and test scenarios for a milestone are agreed at the start of that milestone, not in advance.

1. ✅ **Skeleton**: the addon folder, GUT 9.7.1, a headless test command (`tools/test.sh`), and enforced static typing.
2. ✅ **Core state**: players, zones, Game Objects with zone-change identity (ADR 0008), Encounter Setup, the Game RNG and AI RNG (ADR 0006), opening hands and London mulligans with Free Mulligans.
3. ✅ **Turn structure and priority**: every phase and step, priority passing, an empty stack, and the turn passing. No cards yet.
4. ✅ **Lands and mana**: playing a land, mana abilities, and the mana pool emptying between steps.
5. ✅ **Casting and the stack**: costs, Values, Filters, targets, resolution, and spells fizzling when their targets become illegal. The first real cards are simple burn and draw spells. Mana costs bring color, derived from the cost (CR 202.2). The game will choose each card's frame (color category × creature/noncreature/land) from its characteristics, so the characteristics query must also work on a Run Card outside any encounter, giving deck and reward screens the same answer as the battlefield.
6. ✅ **Creatures and combat**: permanent spells, including flash, power and toughness, summoning sickness, declaring attackers and blockers, combat damage divided freely among blockers, and first strike, double strike and trample. The first creatures are Grizzly Bears, Hill Giant and Elvish Archers.
7. **State-based actions**: dying, reaching 0 life, and drawing from an empty library. Until then a creature with lethal damage only has the damage marked on it and stays on the battlefield.
8. **Triggered abilities.**
9. **Static abilities and layers.** This includes haste, vigilance and deathtouch, which lethal damage must count. It also includes letting a creature block an additional attacker (ADR 0016's blocker pairs already allow it), and a static ability or Modification that stops damage from being removed in the cleanup step. Cleanup already removes damage one event per permanent, so that check has a single place to go.
10. **Replacement and prevention effects.**
11. **First playable Alpha subset** against a simple AI Agent. The AI's lookahead engines should be able to skip undo checkpoints, which copy the state at every undo barrier. By default the AI Agent chooses to play first whenever it gets the play/draw choice, unless a particular Villain is coded otherwise.

The GUI is game-side work that can start after milestone 6 at the earliest.
