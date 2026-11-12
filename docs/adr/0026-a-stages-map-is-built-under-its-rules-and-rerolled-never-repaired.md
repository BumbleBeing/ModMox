# A Stage's map is built under its rules and rerolled, never repaired

A Stage's map is generated in stages, each rolling only from what is legal where it stands. The finished map is then checked whole, and a map that fails is thrown away and generated again from the next number in the map's stream of the Run Seed (ADR 0025). After 1,000 failed attempts generation stops with an error. A slow test generates maps for a few thousand Run Seeds, proves every one valid and reports how many attempts they took.

## The grid

The map is 10 rows by 9 columns, row 1 at the bottom. Four rows are always the same:

- Row 1: the Start Node, in column 5.
- Row 2: a Store in column 4 and a Workshop in column 6.
- Row 9: a Workshop in column 4 and a Store in column 6.
- Row 10: the Boss Encounter, in column 5.

Rows 3 to 8 are generated.

## The stages of generation

1. **Row sizes.** Each generated row is given a number of Nodes, so the map widens and then narrows: 3–4 in row 3, 4–6 in rows 4 and 5, 3–5 in row 6, 2–3 in row 7 and 2 in row 8. Their columns are picked at random from a span that makes the map a diamond (columns 3–7 in row 3, 2–8 in row 4, 1–9 in row 5, 2–8 in row 6, 3–7 in rows 7 and 8), such that every Node has one within a column of it in the row below and in the row above.
2. **Forward links.** Each Node gets 1 to 3 links to Nodes in the next row (1 at 40%, 2 at 45%, 3 at 15%), and any Node left without a parent is given one. A link moves at most one column sideways for each row it advances, and links may cross. The Start Node links to both Nodes of row 2, and every Node of row 8 links to both Nodes of row 9, so the two halves can merge as early as row 3 and the last choice is always a real one. Links into row 9 are exempt from the one-column rule, since only column 5 is within a column of both final Nodes.
3. **Skip links.** A Node in rows 2 to 7 has a 10% chance of a link that skips a row, landing in rows 4 to 9 and moving at most two columns. It replaces one of the Node's forward links if that child has another parent, and is otherwise added if the Node has fewer than three. A skip link is never drawn through a Node: if one stands at the halfway point of its line, straight or diagonal, the skip link would lie on top of that Node's own links and is not made.
4. **Horizontal links.** Two Nodes of a generated row with no Node between them have a 15% chance of being linked, and a Node has at most one such link. It can be walked either way. The fixed rows have none.
5. **Elite Encounters and Troves.** Each Node in rows 3 to 6 has a 30% chance of trying to become an Elite Encounter. It succeeds if links can be cut to make room: one child in the next row becomes its Trove and loses its other parents and its horizontal link, and the Elite Encounter loses its other forward links, skip links included. Nothing is cut that would leave a Node without a parent or a forward link, or would force an Elite Encounter. About half of the tries succeed, giving about two Elite Encounters a map. A Trove is made no other way.
6. **The other kinds.** Each remaining generated Node rolls its kind: Lesser Encounter 35, Chaos Node 30, Store 10, Workshop 10. A Store or Workshop is not legal in rows 3 and 8, nor where any link, forward, skip or horizontal, would join it to another of its kind; its share is then spread over the legal kinds in proportion.

## A valid map

- Every Node can be reached from the Start Node and can reach the Boss Encounter.
- Every path has at least 2 and at most 5 Lesser and Elite Encounters. The Boss Encounter and Chaos Nodes do not count.
- No Store links to a Store, and no Workshop to a Workshop.
- Elite Encounters are in rows 3 to 6 only.
- An Elite Encounter's only forward link is to its Trove, and a Trove's only arriving link is from its Elite Encounter.
- No Elite Encounter is forced: a Node with a forward link to one has a forward link to something else.
- Every path passes through the Store or the Workshop of row 9.
- No skip link is drawn through a Node.

A path is any walk the Hero could take: forward and skip links onward, horizontal links either way, never back to a Node already visited. The Hero may leave an Elite Encounter by its horizontal link and give up the Trove.

A lost encounter costs a Heart and gives no Spoils, and the Hero moves on as if it were cleared, so a Trove is reached whether its Elite Encounter was won or lost. The Boss Encounter is the exception (ADR 0025).

## What was rejected

Rolling every Node freely and then tweaking the map until it is valid was the first idea. It was rejected because a repair is hard to prove will finish, and each fix quietly bends the percentages toward whatever the repair prefers. Rerolling keeps the generator simple and the map exactly replayable. If the slow test shows many attempts, the answer is to tune the percentages or to build the encounter count in directly.

Growing the map by letting each Node branch to one or two new Nodes was also rejected: from two Nodes it reaches sixteen by row 5, which nine columns cannot hold. Row sizes are chosen first instead.

Rolling Elite Encounter alongside the other kinds, at 15% and legal only where a child already had no other parent, was built first in the prototype. Such a spot is rare, and it gave 0.8 Elite Encounters a map. Placing them first and cutting links to make room gives about two.

## What the prototype measured

Over 2,000 Run Seeds every one got a valid map, in 3.6 attempts on average and 25 at worst, at about a millisecond an attempt. Four attempts in five that fail have a path with fewer than 2 encounters. Because such maps are thrown away, the kinds that survive are not the kinds that were rolled: Lesser Encounters are 41% of generated Nodes, Chaos Nodes 29%, Elite Encounters and Troves 9% each, Stores and Workshops 6% each. The prototype is in `prototypes/stage_map/`.

The percentages are the same at every Tier. Difficulty already rises with the Tier through the Villains' decks, so the map's shape stays constant until play shows otherwise. All the numbers here are first values to tune.
