# A card that changes zones becomes a new Game Object

Following Comprehensive Rules 400.7, whenever a card changes zones it becomes a new Game Object with a new identity and no memory of its previous existence. Anything that refers to a Game Object refers to one specific identity, never to "the card", so "exile that creature at end of turn" correctly fails if the creature left and returned, and counters and attachments are lost. This is in place from the first milestone because making references identity-aware after the fact is notoriously painful.
