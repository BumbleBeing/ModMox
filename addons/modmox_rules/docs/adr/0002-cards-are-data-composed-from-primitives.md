# Cards are data composed from engine primitives

Card Definitions are Godot Resources built from a fixed library of engine primitives (costs, effects, triggers, static abilities), not per-card GDScript. Players modify cards between encounters, so a modification must be a data operation ("cost 2 → 0", "add an effect") rather than a code change. A card that cannot be expressed means a primitive is missing, and the fix is to add that primitive, not to script the card.

Every number in an ability is a composable Value (a constant, X, a count of objects matching a filter, the power of a target, and so on), and every selection of objects or players is a composable Filter. Effects never use fixed fields such as a plain damage integer, so a Modification can turn "deal 3 damage" into "deal damage equal to the number of Goblins you control" without new code, and one Filter vocabulary serves targeting, static abilities, and searches alike.

Rules classifications are worked out from a card's content, never set by hand. For example, whether an activated ability is a mana ability follows CR 605.1a (it could add mana and has no target), so a Modification that adds a target to "{T}: Add {R}" correctly turns it into an ability that uses the stack. A designer-set flag would silently get this wrong.

All five ability kinds (spell, activated, mana, triggered and static) exist in the data model from the start, so early cards do not lock in a shape that later abilities cannot fit. Each kind is only implemented when a milestone needs it.

Resources are the format the engine runs, and they are authored in the Godot Inspector for now. A text format or custom card-editor plugin that generates the same Resources is deferred until the card count makes Inspector editing painful. Because copied sub-resources can silently end up shared between two cards, a validation test checks that no two Card Definitions share a sub-resource.
