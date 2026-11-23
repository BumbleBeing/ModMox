class_name OverloadModification
extends MmModification
## "Change its text by replacing all instances of the word 'target' with the word 'each'"
## (CR 702.96b, ADR 0014). The card's spell ability, and each mode of a modal one, keeps no
## target requirements: each moves to its overloaded_targets, keeping its number, and every
## TargetSelection of it becomes an OverloadedSelection of the same number however deep it
## lies, so the spell affects everything it could have targeted. An "its controller" of one
## then names a controller once for each object found.
##
## Nothing else is changed. An Adventure is a card of its own, an ability the spell grants
## and a token it creates have targets of their own, and a resource in a file of its own is
## shared as it was loaded and never changed (ADR 0004).


func apply_to(definition: MmCardDefinition) -> void:
	for ability: MmAbility in definition.abilities:
		var spell: SpellAbility = ability as SpellAbility
		if spell == null:
			continue
		_overload(spell.targets, spell.overloaded_targets, spell.effects)
		for mode: AbilityMode in spell.modes:
			_overload(mode.targets, mode.overloaded_targets, mode.effects)


## Moves [param targets] to the end of [param overloaded] and points every TargetSelection
## among [param effects] at its new place there.
func _overload(targets: Array[TargetRequirement], overloaded: Array[TargetRequirement], effects: Array[MmEffect]) -> void:
	if targets.is_empty():
		return
	var first: int = overloaded.size()
	overloaded.append_array(targets)
	targets.clear()
	for effect: MmEffect in effects:
		_rewrite(effect, first)


## Changes every TargetSelection held anywhere under [param resource] into the
## OverloadedSelection of the requirement [param first] places later, and returns whether it
## changed any.
func _rewrite(resource: Resource, first: int) -> bool:
	var changed: bool = false
	for property: Dictionary in resource.get_property_list():
		var usage: int = property["usage"] as int
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name: StringName = property["name"] as StringName
		# Variant: a property of any part of an effect, a Resource, a list or plain data.
		var value: Variant = resource.get(property_name)
		if value is Array:
			var list: Array = value as Array
			for index: int in list.size():
				var element: Resource = list[index] as Resource
				var replacement: OverloadedSelection = _replacement(element, first)
				if replacement != null:
					list[index] = replacement
					changed = true
				elif _is_its_own(element):
					changed = _rewrite(element, first) or changed
		elif value is Resource:
			var part: Resource = value as Resource
			var replacement: OverloadedSelection = _replacement(part, first)
			if replacement != null:
				resource.set(property_name, replacement)
				changed = true
			elif _is_its_own(part):
				changed = _rewrite(part, first) or changed
	var controller: ControllerOfSelection = resource as ControllerOfSelection
	if changed and controller != null:
		controller.is_once_for_each = true
	return changed


## The OverloadedSelection that takes the place of [param part], or null when it is not a
## TargetSelection.
func _replacement(part: Resource, first: int) -> OverloadedSelection:
	var targeted: TargetSelection = part as TargetSelection
	if targeted == null:
		return null
	var overloaded: OverloadedSelection = OverloadedSelection.new()
	overloaded.overloaded_index = first + targeted.target_index
	return overloaded


## Whether [param part] belongs to the spell's own text: not an ability or card of its own,
## and not a file of its own, shared as it was loaded (ADR 0004).
func _is_its_own(part: Resource) -> bool:
	return part != null and part.resource_path.is_empty() and not part is MmAbility and not part is MmCardDefinition
