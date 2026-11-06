# Cards are data composed from engine primitives

Card Definitions are Godot Resources built from a fixed library of engine primitives (costs, effects, triggers, static abilities), not per-card GDScript. Players modify cards between encounters, so a modification must be a data operation ("cost 2 → 0", "add an effect") rather than a code change. A card that cannot be expressed means a primitive is missing, and the fix is to add that primitive, not to script the card.
