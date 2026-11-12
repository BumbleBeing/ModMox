# A Villain's Rank comes from the Stage that lists it

A Stage holds three lists of Villains: its Lesser Villains, its Elite Villains and its Bosses. A Villain holds no Rank of its own. Its Rank in a meeting is the list the Stage took it from, and that Rank, with the Stage's Tier, decides the Spoils. The same Villain may be listed in several Stages, at different Ranks if wanted, so a Villain that is Elite at Tier 1 can be Lesser at Tier 4 and pays out as whichever it was met as. A Villain may not be in two lists of the same Stage, which keeps "what Rank was this?" answerable from the Stage alone.

Bosses are a list although a Stage has one today, because Stages will have several later. The Boss is picked once when the Hero enters the Stage and stays the same through every rematch, so a loss never swaps it.

Unique Villains are in no Stage. They are met through Chaos Nodes at any Stage, and being one is a matter of where the Chaos Node finds them, which waits for Chaos Nodes to be designed.

A Villain holds its name, its 32 × 32 sprite, a list of setups, an optional AI Profile and a placeholder list for Spoils only it gives. Each setup is an `MmPlayerSetup`, the same resource a deck file already is, so a Villain's starting life and Emblems need no fields of their own (ADR 0011). One setup means the Villain plays it at every Tier; five means one for each Tier, which is how a Unique Villain grows stronger; any other number is invalid.

How hard a Villain thinks is not part of Rank. AI Difficulty stays the one global setting, and a Villain that should think harder has an AI Profile with a larger search budget (ADR 0020).

Two alternatives were rejected. A fixed Rank field on the Villain, checked against the Stage's lists by a test, would have said the same thing in two places and forbidden reusing a Villain at another Rank. Having each Villain name the Stages it appears in, with the pools found by scanning the Villains folder, made adding a Villain a single file but left no one place to read or balance a Stage.
