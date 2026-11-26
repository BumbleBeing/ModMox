# A look at the top cards asks for the cards taken from among them, and the rest go to the bottom in a random order

Militia Bugler says "Vigilance" and "When this creature enters, look at the top four cards of your library. You may reveal a creature card with power 2 or less from among them and put it into your hand. Put the rest on the bottom of your library in a random order." Engine ADR 0080 left "from among them" after a look at the top cards out; this is that.

**It is one effect, `LookAtTopCardsEffect`, as a search is one.** Its fields are `amount` (a Value, how many are looked at), `filter` (what may be taken, null for any card), `most` (how many may be taken, 1) and `reveal`. Three sentences of Oracle make one effect because they are one act: the cards looked at are the cards chosen from and the cards put on the bottom, and no other effect stands between them. Building it from parts, a look that remembers its cards as `MillEffect` does (engine ADR 0080), a `ChosenSelection` from among them, a move from the library to the hand and a move to the bottom, was considered: `ChosenSelection` chooses exactly one with no "may", the moves would each need a library to come from, and the parts would only ever be used together. `SearchLibraryEffect` set the pattern (engine ADR 0057).

**As it begins its controller is asked a `ChooseLookedAtCardsDecision`.** It names the cards looked at (`card_ids`), the top of the library down, as many as there are when the library holds fewer, and those that match the Filter (`candidate_ids`); the answer is from none up to `most` of the candidates. It is asked even when none matches, since the player still looks, and with nothing to look at nothing is asked and nothing happens. While it is pending, that player's own Player View shows those cards (CR 701.20e) and no one else's does, as a surveil's (engine ADR 0068), and a Simulation Copy re-deals none of them. Answering it is an undo barrier: the player has seen the cards.

**The cards taken go to the hand revealed; the rest go to the bottom in an order from the Game RNG.** Each card taken moves with `ZoneChangeEvent.Reason.LOOK`, revealed (CR 701.20a), so the other player knows it in the hand, as a searched card is (engine ADR 0057). Then a `LibraryBottomRandomizedEvent` puts the rest on the bottom, shuffled among themselves by the Game RNG as it is applied (ADR 0006); the order is recorded on the event, so a replay is exact. Those cards never leave the library, so they stay the same objects. Oracle's "in a random order" is the card's own: CR 401.4 would let the owner choose.

**The AI takes as many as it may.** A card in the hand is worth more than one on the bottom of the library. `AiAgent` answers it as it answers a search: CHEAP ranks the candidates with `_search_rank()`, and FULL simulates taking one card of each name and keeps the best (`_found_among()`).

`AbilityText` says it as Oracle does: "look at the top four cards of your library. You may reveal a creature card with power 2 or less from among them and put it into your hand. Put the rest on the bottom of your library in a random order". Without `reveal` it is "You may put a card from among them into your hand".

The Hero answers it in the Look window (game ADR 0085).

Left out until a card needs them (ADR 0001): the rest put on the bottom "in any order" or into the graveyard, more than one taken ("up to two"), the cards taken going anywhere but the hand, a look at another player's library, and the owner knowing which cards lie at the bottom of their library.

## Addendum: the rest on the bottom in any order

Faerie Mechanist says "When this creature enters, look at the top three cards of your library. You may reveal an artifact card from among them and put it into your hand. Put the rest on the bottom of your library in any order." **`LookAtTopCardsEffect.is_rest_in_any_order`** says so; off, as Militia Bugler's is, nothing changes. On, the `ChooseLookedAtCardsDecision` has `orders_rest` set, and its answer is two lists, `[taken, rest]`: the cards taken, as before, then every other card looked at, each exactly once, in the order they go to the bottom, the last the deepest, as a scry's bottom list is (ADR 0087). `answer_taking()` makes the answer that takes some cards and leaves the rest in the order looked at, for whatever answers without choosing an order. The rest go with a `LibraryBottomOrderedEvent` instead of a `LibraryBottomRandomizedEvent`, so they become Known Cards to their owner, who put them there.

The answer's shape depends on the decision, as a surveil's always has two lists: one shape for both cards would have made every Militia Bugler answer change.

**The AI puts the rest on the bottom in the order it looked at them**, CHEAP and FULL: what lies under a library of thirty cards hardly matters in an encounter, and no simulation sees it. Autoplay does the same.

`AbilityText` says "Put the rest on the bottom of your library in any order". The Hero orders the rest in the Look window (game ADR 0085's addendum).
