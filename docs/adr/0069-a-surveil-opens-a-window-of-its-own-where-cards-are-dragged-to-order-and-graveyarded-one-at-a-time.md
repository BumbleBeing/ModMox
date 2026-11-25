# A surveil opens a window of its own, where cards are dragged to order and graveyarded one at a time

Surveil (engine ADR 0068) came with Wary Thespian, "When this creature enters or dies, surveil 1.", a card of the Villain deck `zar_ojanen_scion_of_efrava` that the Hero can own through Spoils (ADR 0039). As its effect begins, the engine asks its controller a `SurveilDecision` naming the top cards of their library, answered once with the cards put into the graveyard and the order of the rest. A throwaway prototype on a mock board, built on the Info Panel of ADR 0066 and kept on the branch `prototype/surveil` (7a779d8), showed three ways for the Hero to surveil 1: A, the top card face up on the Library pile with the Seen Eye (ADR 0055), and "Graveyard" | "No" in the Answer Row; B, the Library window with the card face up on the left, a click sliding it onto the Graveyard pile and back, and "Done" on the Pass Button; C, the card drawn large in the middle of the board over a scrim, with "Keep on top" and "Graveyard" under it. The user turned all three down: "None of the above for surveil. I'd prefer a new window with all of the cards being surveiled in a row, where the player can drag them to rearrange, click to select one, then graveyard the selected card." D was built to that, and changed on their word: "Option D shouldn't have the lower section, just put the card directly into the graveyard with a flight. Also, the button gets cut off on the left side", then "cap the height of the window to just under the graveyard button", and a fix so the window keeps its size and place when a card is clicked. They signed it off: "Build it as shown".

**A surveil opens the Surveil window by itself.** It is a Zone Window (`SurveilWindow`) placed as the Library window is, left of the piles over the Hero's side, three cards wide, and ending just under its Graveyard button. It has no close button. It keeps its place and size, moved or resized by hand or not, until the surveil is answered, and then it closes. It holds the surveilled cards face up in one row, left to right from the top of the library.

**A drag orders the row; a click selects; Graveyard sends the selected card.** A card pressed and moved more than 3 pixels is dragged, and the row makes room where it is held. A press let go where it began selects that card, with a white Glow, and a second click lets it go. Every card that can be clicked glows green. "Graveyard", a steel-framed button centered under the cards left in the row (never past the row's left edge), is grayed out while nothing is selected. Pressed, it flies the selected card out of the window straight onto the Hero's Graveyard pile with a Card Flight, and the pile counts it as it lands, while the Library pile's count goes down by it. The Graveyard window shows it too. Nothing is answered until Done: the half-made answer is a `SurveilChoice`, kept on the screen as a `TriggerOrder` is. A card cannot be taken back but by Undo, which takes back the last Graveyard press or the last drag, one at a time. The "lower section" of D's first build, which kept graveyarded cards in the window, was removed. On Done, a card already sent does not fly again.

**The words are the user's**, checked before they were built:
- the window's title is "Surveil 2": the number is how many cards are surveilled;
- the Info Panel reads "Surveil: graveyard any of these, and order the rest. The leftmost will be on top.", or with one card "Surveil: graveyard any of these.";
- the button under the row reads "Graveyard";
- the Pass Button reads "Done" over "SPACE" and can always be pressed. It and Space give the answer: the cards graveyarded, in the order sent, and the row's order, leftmost on top. Space through priority therefore keeps every card in the order shown, which the user accepted with "always pressable".

**The cards kept on top are Known Cards to the Hero** (engine ADR 0068), so the Library window draws them face up afterwards, as it draws a card the Hero put on the bottom.

**The Villain's surveil shows only in its result.** Each card it puts into its graveyard flies from its Library pile to its Graveyard pile, face up as it lands. The cards it keeps show nothing, and the Info Panel says nothing.

Left out until a card needs them: surveilling more than three cards (the window is three wide), any text under the cursor on a surveilled card, a Keyword Chip for surveil (the user chose none), and a "whenever you surveil" trigger.

## Addendum: Graveyard is baked into the window's bottom edge

When the Look window was signed off (game ADR 0085), the user asked that the Surveil window take its structure. "Graveyard" is no longer under the cards, centered under those left in the row: it is baked into the window's bottom edge, in a strip along the bottom as the title bar runs along the top, exactly as tall as the button, and anchored to the strip's middle, so it stays at the middle of the bottom however the window is resized or however many cards are left. The window opens with room for the row and the strip (`ZoneWindow.size_around()`), and the row scrolls above the strip. Everything else here stands.

## Addendum: a scry opens the Surveil window, its button reading "Bottom"

Scry came with Artificer's Assistant (engine ADR 0087). The user asked for it to be built "like surveil, with rearrangeable draggable cards, except the button says 'bottom' and puts the selected card on the bottom of the library when clicked." So a scry of the Hero's opens the Surveil window in the same place and of the same size, with the same row, drags, clicks, Glows, Undo and Done; only its words and where a card goes differ. The words are the user's, checked before they were built:
- the window's title is "Scry 2": the number is how many cards are scried;
- the Info Panel reads "Scry: put any of these on the bottom, and order the rest. The leftmost will be on top.", or with one card "Scry: put any of these on the bottom.";
- the button baked into the bottom edge reads "Bottom";
- the Pass Button reads "Done", as for a surveil.

Pressed, "Bottom" flies the selected card out of the window onto the Hero's Library pile, whose count stays as it was, since the card never leaves the library; the Graveyard pile does not change. Each card sent goes under everything, so with several the last sent is the deepest, the user's choice. Done gives the cards sent, in the order sent, and the row's order, leftmost on top. Afterwards every card scried is a Known Card to the Hero, so the Library window draws the ones kept on top and the ones put on the bottom face up where they are.

The Villain's scry shows nothing: no card leaves its library, and the Info Panel says nothing.
