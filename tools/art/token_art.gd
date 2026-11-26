class_name TokenArt
extends RefCounted
## Finds which tokens a card makes and which Scryfall token has their art (game ADR 0045). A
## token's art is the art of the token its creating card's first printing names among its
## related parts, so Prideful Parent's Cat is Foundations' own Cat token.


## The Token Definitions, each loaded from its file, that [param definition]'s abilities
## create, its Adventure's after its own (engine ADR 0078), in the order they are written
## and each once.
static func tokens_made_by(definition: MmCardDefinition) -> Array[MmCardDefinition]:
	var found: Array[MmCardDefinition] = []
	var abilities: Array[MmAbility] = definition.abilities.duplicate()
	if definition.adventure != null:
		abilities.append_array(definition.adventure.abilities)
	for ability: MmAbility in abilities:
		var effects: Array[MmEffect] = []
		if ability is SpellAbility:
			effects.append_array((ability as SpellAbility).effects)
		elif ability is TriggeredAbility:
			effects.append_array((ability as TriggeredAbility).effects)
		elif ability is ActivatedAbility:
			effects.append_array((ability as ActivatedAbility).effects)
		for mode: AbilityMode in ability.modes_or_none():
			effects.append_array(mode.effects)  # A modal spell's or triggered ability's (ADR 0046).
		for wrapped: MmEffect in effects:
			var effect: MmEffect = _offered(wrapped)
			var create: CreateTokenEffect = effect as CreateTokenEffect
			if create != null and create.token != null and create.token.resource_path != "" and not found.has(create.token):
				found.append(create.token)
	return found


## Where the picture of a flip token's upper face lies in Scryfall's art crop of it, as
## fractions of its width and height: the panel at its left, below the type line, measured
## from the Wicked Role's (684 × 570). Scryfall prints Role tokens two to a flip card.
const FLIP_ART_PANEL: Rect2 = Rect2(0.0, 0.116, 0.346, 0.535)


## The art in [param image], the art crop of [param token_card], a Scryfall card object: for
## a flip token, its upper face's art panel (FLIP_ART_PANEL), since its art crop is the whole
## face, rules text and all; for any other token, the art crop itself.
static func art_of(token_card: Dictionary, image: Image) -> Image:
	if token_card.get("layout", "") != "flip":
		return image
	var size: Vector2 = Vector2(image.get_size())
	var panel: Rect2i = Rect2i(Vector2i((FLIP_ART_PANEL.position * size).round()),
		Vector2i((FLIP_ART_PANEL.size * size).round()))
	return image.get_region(panel)


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
		if related.get("component", "") != "token":
			continue
		var part_name: String = related.get("name", "")
		if part_name == wanted:
			return related
		# Scryfall prints Role tokens two to a flip card, each face named without "Role", as
		# "Wicked // Cursed" for the Wicked Role and the Cursed Role.
		if token.subtypes.has(AttachmentRules.ROLE) and part_name.split(" // ").has(wanted.trim_suffix(" Role")):
			return related
	return {}


## What [param effect] does once every "you may", "you may pay" and "if" around it is
## taken away, as Myrsmith's "you may pay {1}. If you do, create ...".
static func _offered(effect: MmEffect) -> MmEffect:
	var offered: MmEffect = effect
	while true:
		if offered is MayEffect:
			offered = (offered as MayEffect).effect
		elif offered is MayPayEffect:
			offered = (offered as MayPayEffect).effect
		elif offered is MayPayXEffect:
			offered = (offered as MayPayXEffect).effect
		elif offered is IfEffect:
			offered = (offered as IfEffect).effect
		else:
			return offered
	return offered
