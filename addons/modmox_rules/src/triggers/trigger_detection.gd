class_name TriggerDetection
extends RefCounted
## Finds the triggered abilities a batch of events triggers, right after the batch is
## applied (CR 603.2, ADR 0017), and records each as a pending trigger. Leaves-the-
## battlefield triggers look back in time: they check what was on the battlefield just
## before the batch, using last-known information for what left (CR 603.10a). Every other
## trigger looks at the game after the batch, so things entering together see each other
## (CR 603.6a). Abilities work from the battlefield and, for Emblems, the command zone.
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
	for event: MmEvent in events:
		if event is AbilityTriggeredEvent:
			continue
		for observer: MmGameObject in everyone:
			var characteristics: MmCharacteristics = state.characteristics_of(observer)
			for ability: MmAbility in characteristics.abilities:
				var triggered: TriggeredAbility = ability as TriggeredAbility
				if triggered == null or triggered.trigger == null:
					continue
				var watching: bool = before_ids.has(observer.id) if triggered.trigger.looks_back() else after_ids.has(observer.id)
				if not watching:
					continue
				var context: MmEffectContext = MmEffectContext.new(observer.controller_id, observer.id)
				if not triggered.trigger.matches(state, event, context):
					continue
				var pending: PendingTrigger = PendingTrigger.new(triggered, observer, characteristics,
					triggered.trigger.triggering_player_id(state, event), triggered.trigger.triggering_object_id(event))
				# CR 603.4: an intervening "if" must hold for the ability to trigger at all.
				if triggered.condition_holds(state, pending.context()):
					found.append(pending)
	for pending: PendingTrigger in found:
		state.perform(AbilityTriggeredEvent.new(pending))
