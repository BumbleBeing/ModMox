# Mid-encounter saves are the Encounter Setup plus the decision log

A mid-encounter save stores the Encounter Setup and the ordered list of decisions made, tagged with the engine version, and loading replays them, which determinism (ADR 0006) makes exact. Serializing the full game state was rejected because every new class would have to stay in sync with the save format. The cost is that an engine update that changes rules behavior can invalidate a mid-encounter save. When the version does not match, the encounter restarts from its setup, which is acceptable for a roguelike.

A concession is not an answer to a Pending Decision, since a player may concede at any time (CR 104.3a), but it still changes the encounter, so it goes into the decision log as `["concede", player ID]`. No answer ever has that shape, and replaying recognizes it.
