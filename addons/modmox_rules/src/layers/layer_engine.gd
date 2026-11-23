class_name LayerEngine
extends RefCounted
## Works out the characteristics of everything on the battlefield and in the command zone
## by applying continuous effects layer by layer (CR 613, ADR 0018). Each layer is applied
## to every object before the next begins, and while it runs the characteristics query
## answers with these in-progress results, so a Filter in a later layer sees what earlier
## layers did, and nothing recurses. Within a layer, effects apply in timestamp order.
##
## Later: layers 1-3 and 5 (copy, control, text, color), and dependencies (CR 613.8), which
## override timestamp order; and setting a land's subtype, which takes away the mana
## abilities of the basic land types it loses (CR 305.7).


## The characteristics of every object on the battlefield and in the command zone, by ID.
static func compute(state: MmGameState) -> Dictionary[int, MmCharacteristics]:
	var objects: Array[MmGameObject] = TriggerDetection.observers(state)
	var current: Dictionary[int, MmCharacteristics] = {}
	for game_object: MmGameObject in objects:
		current[game_object.id] = MmCharacteristics.printed(game_object.definition)
	state.begin_layer_computation(current)
	# CR 613.6: the static abilities whose effects have started applying, by source.
	var started: Dictionary[int, Array] = {}
	# Later: layers 1-3 and 5.
	for game_object: MmGameObject in objects:
		_apply_reconfigure(game_object, current[game_object.id])
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.TYPE)
	# CR 305.7: a land that gained a basic land type in layer 4 has its mana ability, which
	# layer 6 may then take away.
	for game_object: MmGameObject in objects:
		current[game_object.id].add_basic_land_abilities()
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.ABILITY)
	for game_object: MmGameObject in objects:
		_apply_defining_abilities(state, game_object, current[game_object.id])
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.SETTING_POWER_TOUGHNESS)
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.MODIFYING_POWER_TOUGHNESS)
	for game_object: MmGameObject in objects:
		_apply_counters(game_object, current[game_object.id])
	state.end_layer_computation()
	return current


## The characteristics of an object in any other zone: its printed ones with its
## characteristic-defining abilities applied (CR 604.3).
static func outside_the_battlefield(state: MmGameState, game_object: MmGameObject) -> MmCharacteristics:
	var characteristics: MmCharacteristics = MmCharacteristics.printed(game_object.definition)
	_apply_defining_abilities(state, game_object, characteristics)
	if game_object.zone() == state.stack:
		characteristics.chosen_x = game_object.chosen_x  # CR 202.3e.
	return characteristics


## Layer 4 (CR 702.151b): an Equipment with reconfigure attached to something isn't a
## creature, and so has no creature types (CR 205.1b, 205.3d). It applies before the
## layer's continuous effects, as if its timestamp were earlier than all of theirs.
# Later: the timestamp it gets as it becomes attached (CR 613.7e), once a card's type
# change could meet it.
static func _apply_reconfigure(game_object: MmGameObject, characteristics: MmCharacteristics) -> void:
	if game_object.attached_to_object_id == 0 or not characteristics.has_ability(ReconfigureAbility):
		return
	characteristics.card_types.erase(MmCardTypes.CardType.CREATURE)
	var kept: Array[String] = []
	for subtype: String in characteristics.subtypes:
		if not CreatureTypes.is_creature_type(subtype):
			kept.append(subtype)
	characteristics.subtypes = kept
	characteristics.is_every_creature_type = false


## Layer 7a.
static func _apply_defining_abilities(state: MmGameState, game_object: MmGameObject, characteristics: MmCharacteristics) -> void:
	for ability: MmAbility in characteristics.abilities:
		var defining: CharacteristicDefiningAbility = ability as CharacteristicDefiningAbility
		if defining != null:
			var context: MmEffectContext = MmEffectContext.new(game_object.controller_id, game_object.id)
			if defining.power != null:
				characteristics.power = defining.power.evaluate(state, context)
			if defining.toughness != null:
				characteristics.toughness = defining.toughness.evaluate(state, context)


## Layer 7c (CR 613.4c): +1/+1 and -1/-1 counters change power and toughness along with
## the effects that modify them. Everything in this layer adds, so the order among them
## cannot matter and counters need no timestamp.
static func _apply_counters(game_object: MmGameObject, characteristics: MmCharacteristics) -> void:
	for kind: MmCounter.Kind in MmCounter.KINDS:
		var change: int = MmCounter.power_toughness_change(kind) * game_object.counters_of(kind)
		characteristics.power += change
		characteristics.toughness += change


static func _apply_layer(state: MmGameState, objects: Array[MmGameObject], current: Dictionary[int, MmCharacteristics],
		started: Dictionary[int, Array], layer: MmContinuousEffect.Layer) -> void:
	var entries: Array[ActiveContinuousEffect] = []
	for game_object: MmGameObject in objects:
		var abilities: Array = current[game_object.id].abilities.duplicate()
		for already: Variant in started.get(game_object.id, []):
			if not abilities.has(already):
				abilities.append(already)
		for ability: Variant in abilities:
			var generating: ContinuousStaticAbility = ability as ContinuousStaticAbility
			if generating == null:
				continue
			# CR 613.6: one that has started applying keeps applying, so only one that has not
			# yet is asked its condition.
			var has_started: bool = (started.get(game_object.id, []) as Array).has(generating)
			if not has_started and generating.condition != null and not generating.condition.is_true(
					state, MmEffectContext.new(game_object.controller_id, game_object.id)):
				continue
			for continuous: MmContinuousEffect in generating.effects:
				if continuous.layer() == layer:
					entries.append(ActiveContinuousEffect.of_static(continuous, generating, game_object))
	for active: ActiveContinuousEffect in state.continuous_effects:
		if active.effect.layer() == layer:
			entries.append(active)
	# CR 613.7: timestamp order. Effects sharing a timestamp keep the order they were listed.
	var order: Array[int] = []
	order.assign(range(entries.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		return entries[a].timestamp < entries[b].timestamp or (entries[a].timestamp == entries[b].timestamp and a < b))
	for index: int in order:
		var entry: ActiveContinuousEffect = entries[index]
		var context: MmEffectContext = MmEffectContext.new(entry.controller_id, entry.source_object_id)
		var ids: Array[int] = entry.affected_ids
		var amounts: Array[int] = entry.amounts
		if not entry.is_locked:
			ids = []
			for found: MmReference in entry.effect.affected.select(state, context):
				if found.is_object():
					ids.append(found.id)
			amounts = entry.effect.numbers(state, context)
			var source_started: Array = started.get(entry.source_object_id, [])
			if not source_started.has(entry.static_ability):
				source_started.append(entry.static_ability)
				started[entry.source_object_id] = source_started
		for id: int in ids:
			if current.has(id):
				entry.effect.apply_to(current[id], amounts)
