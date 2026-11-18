class_name TokenArt
extends RefCounted
## Finds which tokens a card makes and which Scryfall token has their art (game ADR 0045). A
## token's art is the art of the token its creating card's first printing names among its
## related parts, so Prideful Parent's Cat is Foundations' own Cat token.


## The Token Definitions, each loaded from its file, that [param definition]'s abilities
## create, in the order they are written and each once.
static func tokens_made_by(definition: MmCardDefinition) -> Array[MmCardDefinition]:
	var found: Array[MmCardDefinition] = []
	for ability: MmAbility in definition.abilities:
		var effects: Array[MmEffect] = []
		if ability is SpellAbility:
			effects = (ability as SpellAbility).effects
		elif ability is TriggeredAbility:
			effects = (ability as TriggeredAbility).effects
		elif ability is ActivatedAbility:
			effects = (ability as ActivatedAbility).effects
		for effect: MmEffect in effects:
			var create: CreateTokenEffect = effect as CreateTokenEffect
			if create != null and create.token != null and create.token.resource_path != "" and not found.has(create.token):
				found.append(create.token)
	return found


## The art key of [param token]: "tokens/" and its file's name.
static func key_of(token: MmCardDefinition) -> String:
	return ArtLibrary.token_key(token.resource_path.get_file().get_basename())


## The related part of [param printing], a Scryfall card object, that is the token named as
## [param token] is, less its word "Token" (CR 111.4); an empty Dictionary when it has none.
static func part_for(printing: Dictionary, token: MmCardDefinition) -> Dictionary:
	var wanted: String = token.name.trim_suffix(" Token")
	# Array of Variants: parsed Scryfall JSON is open-ended until checked.
	for part: Variant in printing.get("all_parts", []) as Array:
		if not part is Dictionary:
			continue
		var related: Dictionary = part
		if related.get("component", "") == "token" and related.get("name", "") == wanted:
			return related
	return {}
