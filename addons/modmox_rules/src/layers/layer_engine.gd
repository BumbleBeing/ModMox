class_name LayerEngine
extends RefCounted
## Works out the characteristics of everything on the battlefield and in the command zone
## by applying continuous effects layer by layer (CR 613, ADR 0018). Each layer is applied
## to every object before the next begins, and while it runs the characteristics query
## answers with these in-progress results, so a Filter in a later layer sees what earlier
## layers did, and nothing recurses. Within a layer, effects apply in timestamp order.
##
## Later: layers 1-5 (copy, control, text, type, color), and dependencies (CR 613.8), which
## override timestamp order.


## The characteristics of every object on the battlefield and in the command zone, by ID.
static func compute(state: MmGameState) -> Dictionary[int, MmCharacteristics]:
	var objects: Array[MmGameObject] = TriggerDetection.observers(state)
	var current: Dictionary[int, MmCharacteristics] = {}
	for game_object: MmGameObject in objects:
		current[game_object.id] = MmCharacteristics.printed(game_object.definition)
	state.begin_layer_computation(current)
	# CR 613.6: the static abilities whose effects have started applying, by source.
	var started: Dictionary[int, Array] = {}
	# Later: layers 1-5.
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.ABILITY)
	for game_object: MmGameObject in objects:
		_apply_defining_abilities(state, game_object, current[game_object.id])
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.SETTING_POWER_TOUGHNESS)
	_apply_layer(state, objects, current, started, MmContinuousEffect.Layer.MODIFYING_POWER_TOUGHNESS)
	state.end_layer_computation()
	return current


## The characteristics of an object in any other zone: its printed ones with its
## characteristic-defining abilities applied (CR 604.3).
static func outside_the_battlefield(state: MmGameState, game_object: MmGameObject) -> MmCharacteristics:
	var characteristics: MmCharacteristics = MmCharacteristics.printed(game_object.definition)
	_apply_defining_abilities(state, game_object, characteristics)
	return characteristics


## Layer 7a.
static func _apply_defining_abilities(state: MmGameState, game_object: MmGameObject, characteristics: MmCharacteristics) -> void:
	for ability: MmAbility in characteristics.abilities:
		var defining: CharacteristicDefiningAbility = ability as CharacteristicDefiningAbility
		if defining != null:
			var context: MmEffectContext = MmEffectContext.new(game_object.controller_id, game_object.id)
			characteristics.power = defining.power.evaluate(state, context)
			characteristics.toughness = defining.toughness.evaluate(state, context)


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
