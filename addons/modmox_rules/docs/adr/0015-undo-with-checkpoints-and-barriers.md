# Undo restores a checkpoint and replays the short window since it

Recent decisions can be undone back to the last undo barrier. A barrier is set whenever something cannot fairly be taken back: hidden information was revealed or randomness used (a card drawn from a library, a shuffle), something left the stack, or the other player now has a decision. Inside the window, mana abilities, land plays and every step of a cast in progress can be undone. Canceling a cast is undoing back to the decision that began it, and a payment that can no longer be finished rewinds the same way (CR 728).

At each barrier the engine keeps a checkpoint copy of the game state and its procedures. Undo restores that copy and replays the decisions made since, minus the undone ones, so it costs a handful of decisions however long the encounter has run. Undone decisions are removed from the decision log, so saves and replays never see them. The rewinding is invisible: callers read the views again after an undo rather than animating anything.

Two alternatives were rejected. Replaying the whole encounter from its setup was simpler but repeats all the work for every undo, and players undo several times in a row when untapping lands. Writing an exact reverse for every event type would have to stay correct for every event added from now on, which is the kind of hand-written logic that quietly drifts.

Once the encounter is over, whether by a state-based action or a concession, nothing can be undone.

The checkpoint copy is the same state copying the AI will use to look ahead.
