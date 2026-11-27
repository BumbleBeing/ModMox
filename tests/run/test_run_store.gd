extends GutTest
## SR5 to SR7 and SR10 (milestone 24, ADRs 0070 and 0071): the Store in a run. Arriving at a
## Store's Node rolls its stock from Content: the Tier's Store Pool, every Potion, Armor and
## Mod. A purchase takes the price off the gold and puts the good in the Collection, as it
## is and in no Deck, or in the Satchel; a sale pays a third of a card's Store price and takes
## it out of the Collection and every Deck. The stock and what was bought are run state while
## the Hero stands on the Node, saved and restored exactly, and forgotten once they move on.

const Sample := preload("res://tests/support/store_sample.gd")
const ANCESTRAL_RECALL: String = "res://content/cards/alpha/ancestral_recall.tres"
const FOREST: String = "res://content/cards/alpha/forest.tres"
const LOTS: int = 5000


func before_each() -> void:
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()


## SR1 in a run: arriving at a Store rolls nine goods, the same for the same Run Seed, its
## cards from the Tier's Store Pool.
func test_arriving_at_a_store_rolls_its_stock() -> void:
	var run: Run = _at_a_store(4)
	var again: Run = _at_a_store(4)

	var stock: StoreStock = run.store_stock()
	assert_not_null(stock)
	assert_eq(stock.goods().size(), StoreStock.GOODS)
	assert_eq(_names_of(stock), _names_of(again.store_stock()))
	var pool: Array[MmCardDefinition] = ContentStorePools.pool(1)
	for good: StoreGood in stock.goods():
		if good.kind == StoreGood.Kind.CARD:
			assert_true(pool.has(good.card.run_card.base), "%s is in the Tier 1 Store Pool" % good.name())


## Away from a Store there is no stock.
func test_there_is_no_stock_away_from_a_store() -> void:
	var run: Run = Run.debug(4)

	assert_null(run.store_stock(), "on the Start Node")
	for id: int in run.stage_visit.choices():
		if run.stage_visit.map.nodes[id].kind == StageMap.Kind.WORKSHOP:
			run.move_to(id)
	assert_eq(run.stage_visit.node().kind, StageMap.Kind.WORKSHOP)
	assert_null(run.store_stock(), "at the Workshop")


## SR5: buying a card takes its price off the gold and puts it in the Collection as it is,
## Mods and Hexes included, in no Deck; the good is Sold.
func test_buying_a_card_puts_it_in_the_collection_as_it_is() -> void:
	var run: Run = _at_a_store(4)
	run.gold = LOTS
	var good: StoreGood = _first(run, StoreGood.Kind.CARD)
	var price: int = good.price()
	var owned: int = run.collection.cards().size()

	assert_eq(run.buy(good), "")

	assert_eq(run.gold, LOTS - price)
	assert_true(good.is_sold)
	assert_eq(run.collection.cards().size(), owned + 1)
	var bought: DeckbuilderCard = run.collection.cards()[-1]
	assert_eq(bought.card_name(), good.name())
	assert_eq(bought.mods, good.card.mods)
	assert_ne(bought.run_card, good.card.run_card, "the Collection's own Run Card")
	for deck: Deck in run.deckbox.decks():
		assert_false(deck.card_ids.has(bought.id), "in no Deck")


## SR5: a bought Potion joins the Potions held.
func test_buying_a_potion_puts_it_in_the_satchel() -> void:
	var run: Run = _at_a_store_with(StoreGood.Kind.POTION)
	run.gold = LOTS
	var good: StoreGood = _first(run, StoreGood.Kind.POTION)
	var held: int = run.held_potions.count_of(good.potion)

	assert_eq(run.buy(good), "")

	assert_eq(run.held_potions.count_of(good.potion), held + 1)
	assert_eq(run.gold, LOTS - Prices.of_potion(good.potion))


## SR5, agreed at the milestone's start: a bought Armor is held, and not put on.
func test_buying_an_armor_holds_it_without_putting_it_on() -> void:
	var run: Run = _at_a_store_with(StoreGood.Kind.ARMOR)
	run.gold = LOTS
	var good: StoreGood = _first(run, StoreGood.Kind.ARMOR)
	var held: int = run.held_armor.count_of(good.armor)

	assert_eq(run.buy(good), "")

	assert_eq(run.held_armor.count_of(good.armor), held + 1)
	assert_null(run.held_armor.worn_in(good.armor.slot), "nothing was Worn, and nothing is")
	assert_eq(run.gold, LOTS - good.armor.price)


## SR5: what cannot be afforded is not bought, and nothing changes.
func test_a_good_that_cannot_be_afforded_is_not_bought() -> void:
	var run: Run = _at_a_store(4)
	var good: StoreGood = _first(run, StoreGood.Kind.CARD)
	run.gold = good.price() - 1
	var owned: int = run.collection.cards().size()

	assert_ne(run.buy(good), "")

	assert_eq(run.gold, good.price() - 1)
	assert_false(good.is_sold)
	assert_eq(run.collection.cards().size(), owned)


## SR5: a Sold good cannot be bought again, and nothing can be bought away from a Store.
func test_a_sold_good_or_one_from_another_store_cannot_be_bought() -> void:
	var run: Run = _at_a_store(4)
	run.gold = LOTS
	var good: StoreGood = _first(run, StoreGood.Kind.CARD)
	run.buy(good)
	var gold: int = run.gold

	assert_ne(run.buy(good), "", "already Sold")
	_move_on(run)
	assert_ne(run.buy(_first_of(run, good)), "", "away from the Store")
	assert_eq(run.gold, gold)


## SR6: selling a card pays a third of its Store price as it is and takes it out of the
## Collection and every Deck, which may leave a Deck under 40 cards.
func test_selling_a_card_pays_a_third_and_takes_it_out_of_every_deck() -> void:
	var run: Run = _at_a_store(4)
	var deck: Deck = run.deckbox.active()
	var card: DeckbuilderCard = run.collection.card(deck.card_ids[0])
	var other: Deck = run.deckbox.duplicate_deck(deck)
	var gold: int = run.gold
	var paid: int = Prices.of_card(card) / 3

	assert_eq(run.sell(card), "")

	assert_eq(run.gold, gold + paid)
	assert_false(run.collection.owns(card))
	assert_false(deck.card_ids.has(card.id))
	assert_false(other.card_ids.has(card.id))


## SR6: a Power-9 card and a basic land cannot be sold, and nothing is sold away from a Store.
func test_some_cards_cannot_be_sold_and_none_away_from_a_store() -> void:
	var run: Run = _at_a_store(4)
	var power_nine: DeckbuilderCard = run.collection.add(_run_card(ANCESTRAL_RECALL))
	var forest: DeckbuilderCard = run.collection.add(_run_card(FOREST), [Sample.land_mod("Land Mod")])
	var plain: DeckbuilderCard = run.collection.cards()[0]
	var gold: int = run.gold

	assert_false(run.can_sell(power_nine))
	assert_ne(run.sell(power_nine), "")
	assert_false(run.can_sell(forest))
	assert_ne(run.sell(forest), "")
	assert_true(run.can_sell(plain))
	_move_on(run)
	assert_ne(run.sell(plain), "", "away from the Store")
	assert_eq(run.gold, gold)
	assert_true(run.collection.owns(power_nine) and run.collection.owns(forest) and run.collection.owns(plain))


## SR7: moving on forgets the Store; the next Store rolls a stock of its own.
func test_moving_on_forgets_the_stock() -> void:
	var run: Run = _at_a_store(4)
	var first: Array[String] = _names_of(run.store_stock())

	_move_on(run)
	assert_null(run.store_stock())
	while run.stage_visit.node().kind not in [StageMap.Kind.STORE, StageMap.Kind.BOSS]:
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(_a_store_if_offered(run))

	assert_eq(run.stage_visit.node().kind, StageMap.Kind.STORE, "the Stage's last Store")
	assert_not_null(run.store_stock())
	assert_ne(_names_of(run.store_stock()), first)


## SR7: a run saved at a Store comes back with the same stock, what was bought Sold, each
## card with its Mods and Hexes, and the shop's gold.
func test_a_run_saved_at_a_store_comes_back_with_the_store_as_it_was() -> void:
	var run: Run = _modded_store()
	run.gold = LOTS
	run.buy(_first(run, StoreGood.Kind.CARD))

	var loaded: Run = Run.from_data(JSON.parse_string(JSON.stringify(run.to_data())) as Dictionary)

	assert_eq(_described(loaded.store_stock()), _described(run.store_stock()))
	assert_eq(loaded.gold, run.gold)
	var other: StoreGood = loaded.store_stock().goods().filter(func(good: StoreGood) -> bool: return not good.is_sold)[0]
	assert_eq(loaded.buy(other), "", "the loaded Store still sells")


## SR10: arriving at a Store opens the Store; Leave returns to the Stage Map, and a click on
## the Node reopens it until the Hero moves on.
func test_the_store_opens_on_arrival_and_reopens_from_the_map() -> void:
	var run: Run = _on_the_map(4)
	run.move_to(run.stage_visit.choices()[0])

	assert_eq(RunFlow.arrive(), RunFlow.Screen.STORE)
	assert_eq(RunFlow.leave_store(), RunFlow.Screen.STAGE_MAP)
	assert_eq(RunFlow.open_store(), RunFlow.Screen.STORE)
	RunFlow.leave_store()
	_move_on(run)
	assert_eq(RunFlow.open_store(), RunFlow.Screen.NONE, "no Store here")


## SR10: the Deckbox opened from the Store closes back to it, and after Leave the Run Bar's
## Deckbox closes back to the Stage Map.
func test_the_deckbox_from_the_store_closes_back_to_it() -> void:
	var run: Run = _on_the_map(4)
	run.move_to(run.stage_visit.choices()[0])
	RunFlow.arrive()

	assert_eq(RunFlow.open_deckbox(RunFlow.Screen.STORE), RunFlow.Screen.DECKBOX)
	assert_null(RunFlow.villain)
	assert_eq(RunFlow.close_deckbox(), RunFlow.Screen.STORE)
	RunFlow.leave_store()
	RunFlow.open_deckbox()
	assert_eq(RunFlow.close_deckbox(), RunFlow.Screen.STAGE_MAP)


## SR7 and SR10: Continue on a run saved at the Store reopens the Store as it was left.
func test_continue_at_a_store_reopens_it_as_it_was_left() -> void:
	RunFlow.remembers_saves = true
	var run: Run = _on_the_map(4)
	run.move_to(run.stage_visit.choices()[0])
	run.gold = LOTS
	RunFlow.arrive()
	run.buy(_first(run, StoreGood.Kind.CARD))
	var shown: Array[String] = _described(run.store_stock())
	RunFlow.quit()

	var screen: RunFlow.Screen = RunFlow.continue_run(JSON.parse_string(JSON.stringify(RunFlow.last_save())) as Dictionary)
	RunFlow.remembers_saves = false

	assert_eq(screen, RunFlow.Screen.STORE)
	assert_eq(_described(RunFlow.run.store_stock()), shown)


## A debug run that has walked onto its Stage's first Store, with Run Seed [param run_seed].
func _at_a_store(run_seed: int) -> Run:
	var run: Run = Run.debug(run_seed)
	while run.stage_visit.node().kind != StageMap.Kind.STORE:
		run.move_to(run.stage_visit.choices()[0])
	return run


## A run at its first Store whose stock has a good of [param kind], the first Run Seed that
## rolls one.
func _at_a_store_with(kind: StoreGood.Kind) -> Run:
	for run_seed: int in 200:
		var run: Run = _at_a_store(run_seed)
		if _first(run, kind) != null:
			return run
	assert_true(false, "no Store of the first 200 Run Seeds has a %s" % StoreGood.Kind.keys()[kind])
	return null


## A run at its first Store with a card that carries a Mod in its stock.
func _modded_store() -> Run:
	for run_seed: int in 200:
		var run: Run = _at_a_store(run_seed)
		if run.store_stock().goods().any(func(good: StoreGood) -> bool: return good.card != null and good.card.is_modified()):
			return run
	assert_true(false, "no Store of the first 200 Run Seeds has a Modded card")
	return null


func _on_the_map(run_seed: int) -> Run:
	var run: Run = Run.debug(run_seed)
	RunFlow.start(run)
	RunFlow.finish_intro()
	return run


## Moves the Hero on from where they stand, to the first Node offered.
func _move_on(run: Run) -> void:
	assert_eq(run.move_to(run.stage_visit.choices()[0]), "")


## The Node to move to next: a Store if one is offered, and otherwise the first offered.
func _a_store_if_offered(run: Run) -> int:
	for id: int in run.stage_visit.choices():
		if run.stage_visit.map.nodes[id].kind == StageMap.Kind.STORE:
			return id
	return run.stage_visit.choices()[0]


func _first(run: Run, kind: StoreGood.Kind) -> StoreGood:
	for good: StoreGood in run.store_stock().goods():
		if good.kind == kind and not good.is_sold:
			return good
	return null


## The good of [param run]'s stock in [param good]'s place, or [param good] itself when the
## Hero is at no Store.
func _first_of(run: Run, good: StoreGood) -> StoreGood:
	return good if run.store_stock() == null else run.store_stock().goods()[0]


func _run_card(path: String) -> MmRunCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load(path) as MmCardDefinition
	return run_card


func _names_of(stock: StoreStock) -> Array[String]:
	var names: Array[String] = []
	for good: StoreGood in stock.goods():
		names.append(good.name())
	return names


## Each good of [param stock] as words: what it is, its name, its Mods, its price and whether
## it is Sold.
func _described(stock: StoreStock) -> Array[String]:
	var described: Array[String] = []
	for good: StoreGood in stock.goods():
		var mods: Array[String] = []
		if good.card != null:
			for mod: Mod in good.card.mods:
				mods.append(mod.resource_path)
		described.append("%s %s %s %d %s" % [StoreGood.Kind.keys()[good.kind], good.name(), mods, good.price(), good.is_sold])
	return described
