# Multi-part decisions are answered with plain lists

Some decisions choose a subset or divide an amount, so their answers cannot be listed as options and picked by index the way ADR 0012 does for priority, targets and payment. Declaring attackers would need an option for every subset of creatures, and dividing 5 damage among three blockers would need one for every split. These decisions are answered with plain lists of integers instead, which keeps answers plain data for the decision log (ADR 0010):

- Discarding and putting cards on the bottom: a list of object IDs taken from the candidates.
- Declaring attackers: a list of distinct object IDs from the candidates, of any length. An empty list declares no attackers.
- Declaring blockers: a list of [blocker ID, attacker ID] pairs. Several blockers may block one attacker.
- Dividing combat damage: one amount per recipient, in the decision's order (blockers by ID, then the player being attacked if the attacker has trample), adding up to the attacker's power.

Each decision lists its candidates, and validation checks every entry against them, so an answer still cannot describe something illegal. This costs a second set of checks for each decision kind, which is the price ADR 0012 avoided for Actions. A decision with only one possible answer is never asked, so a creature blocked by one creature assigns its damage without asking.

The shapes leave room for planned additions without changing any existing answer. A creature that may block an additional attacker appears in more than one pair. Attacks on more than one player or object would add a target to each attacker. A blocker blocking several attackers would get a division decision of its own.
