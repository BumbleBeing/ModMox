extends GutTest
## A mana cost is drawn one pip image to a symbol (ManaSymbols). Each symbol a card or a Mod
## Cost may hold needs its image, a hybrid symbol's drawn by tools/art/hybrid_pip.py
## (engine ADR 0077), or its pip is left blank.

## The ten hybrid symbols, each pair of colors in the order printed: {W/U} to {G/U}.
const HYBRID_PAIRS: Array[String] = ["wu", "ub", "br", "rg", "gw", "wb", "ur", "bg", "rw", "gu"]


func test_every_hybrid_symbol_has_a_pip_image() -> void:
	for pair: String in HYBRID_PAIRS:
		assert_true(ResourceLoader.exists(ManaSymbols.FOLDER + pair + ".svg"), pair)
		if ResourceLoader.exists(ManaSymbols.FOLDER + pair + ".svg"):
			assert_not_null(ManaSymbols.texture(pair), pair)


func test_a_red_green_hybrid_mod_cost_is_drawn_with_its_own_pip() -> void:
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = 1
	cost.symbols = [MmMana.Type.GREEN] as Array[MmMana.Type]
	cost.hybrid_symbols = [Vector2i(MmMana.Type.RED, MmMana.Type.GREEN)] as Array[Vector2i]

	assert_eq(ManaSymbols.pip_names(cost), ["1", "g", "rg"] as Array[String])


func test_every_pip_of_every_card_and_mod_cost_in_content_has_an_image() -> void:
	var costs: Array[MmManaCost] = []
	for definition: MmCardDefinition in ContentCards.all():
		costs.append(definition.mana_cost)
	for mod: Mod in ContentMods.all():
		if mod.mod_cost != null:
			costs.append(mod.mod_cost.cost)
	for cost: MmManaCost in costs:
		for pip: String in ManaSymbols.pip_names(cost):
			assert_true(ResourceLoader.exists(ManaSymbols.FOLDER + pip + ".svg"), "%s in %s" % [pip, cost.describe()])
