class_name TriggerDetection
extends RefCounted
## Finds the triggered abilities a batch of events triggers, right after the batch is
## applied (CR 603.2, ADR 0017), and records each as a pending trigger. Leaves-the-
## battlefield triggers look back in time: they check what was on the battlefield just
## before the batch, using last-known information for what left (CR 603.10a). Every other
## trigger looks at the game after the batch, so things entering together see each other
## (CR 603.6a). Abilities work from the battlefield and, for Emblems, the command zone; a
## spell's ability whose trigger can't trigger from the battlefield works on the stack
## instead, as "When you cast this spell" does (CR 113.6k). One
## event may trigger an ability several times, once for each object it is about (ADR 0017's
## addendum). One that triggers only once each turn triggers for the first match of a
## batch, and for none once its source has marked it Spent this turn (ADR 0054's addendum).
## Events of a batch its trigger calls one occasion trigger it once, for the first of them
## (MmTrigger.occasion_of(), ADR 0082).
##
## Later: abilities that trigger from other zones, such as a graveyard.


## The objects whose triggered abilities are working right now, in ID order.
static func observers(state: MmGameState) -> Array[MmGameObject]:
	var result: Array[MmGameObject] = state.battlefield.objects() + state.command.objects()
	result.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return result


## Records every trigger of [param events], which were just applied together.
## [param before] is what observers() returned just before they were.
static func detect(state: MmGameState, events: Array[MmEvent], before: Array[MmGameObject]) -> void:
	var after: Array[MmGameObject] = observers(state)
	# CR 113.6k: spells on the stack watch only with the triggers that work there.
	var spells: Array[MmGameObject] = _spells_on_the_stack(state)
	var spell_ids: Dictionary[int, bool] = {}
	for spell: MmGameObject in spells:
		spell_ids[spell.id] = true
	after.append_array(spells)
	var after_ids: Dictionary[int, bool] = {}
	for observer: MmGameObject in after:
		after_ids[observer.id] = true
	var before_ids: Dictionary[int, bool] = {}
	var everyone: Array[MmGameObject] = after.duplicate()
	for observer: MmGameObject in before:
		before_ids[observer.id] = true
		if not after_ids.has(observer.id):
			everyone.append(observer)
	everyone.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	var found: Array[PendingTrigger] = []
	# ADR 0082: the occasions each ability has triggered for in this batch, by source and index.
	var occasions: Dictionary[String, bool] = {}
	for event: MmEvent in events:
		if event is AbilityTriggeredEvent:
			continue
		for observer: MmGameObject in everyone:
			var characteristics: MmCharacteristics = state.characteristics_of(observer)
			for ability_index: int in characteristics.abilities.size():
				var triggered: TriggeredAbility = characteristics.abilities[ability_index] as TriggeredAbility
				if triggered == null or triggered.trigger == null:
					continue
				if spell_ids.has(observer.id) != triggered.trigger.functions_on_the_stack():
					continue
				var watching: bool = before_ids.has(observer.id) if triggered.trigger.looks_back() else after_ids.has(observer.id)
				if not watching:
					continue
				var context: MmEffectContext = MmEffectContext.new(observer.controller_id, observer.id)
				var occasion: String = triggered.trigger.occasion_of(state, event)
				var occasion_key: String = "%d %d %s" % [observer.id, ability_index, occasion]
				if occasion != "" and occasions.has(occasion_key):
					continue
				# ADR 0017's addendum: one event may trigger it several times, once for each
				# object it is about, as "blocks a creature" does (CR 509.3b).
				for object_id: int in triggered.trigger.triggering_object_ids(state, event, context):
					var pending: PendingTrigger = PendingTrigger.new(triggered, ability_index, observer, characteristics,
						triggered.trigger.triggering_player_id(state, event), object_id)
					# CR 603.4: an intervening "if" must hold for the ability to trigger at all.
					if not triggered.condition_holds(state, pending.context()):
						continue
					# ADR 0054's addendum: once each turn, so of several events in one batch, or
					# of the several times one event triggers it, only the first that matches
					# triggers it, and its "that creature" is that one's.
					if triggered.is_once_each_turn and (observer.has_triggered_in(ability_index, state.game_turn)
							or _has_triggered_among(found, observer.id, ability_index)):
						continue
					found.append(pending)
					if occasion != "":
						occasions[occasion_key] = true
	for pending: PendingTrigger in found:
		state.perform(AbilityTriggeredEvent.new(pending))


## The spells on the stack, in ID order: cards and copies, not abilities.
static func _spells_on_the_stack(state: MmGameState) -> Array[MmGameObject]:
	var found: Array[MmGameObject] = []
	for item: MmGameObject in state.stack.objects():
		if item.is_card_or_copy():
			found.append(item)
	found.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return found


## Whether ability [param ability_index] of the object [param source_id] is among
## [param found].
static func _has_triggered_among(found: Array[PendingTrigger], source_id: int, ability_index: int) -> bool:
	for pending: PendingTrigger in found:
		if pending.source_object_id == source_id and pending.ability_index == ability_index:
			return true
	return false
