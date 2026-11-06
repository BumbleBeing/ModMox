class_name MmReplacementEffect
extends Resource
## What a replacement or prevention effect does to an event that would happen (CR 614,
## 615). Each subclass describes one kind, such as preventing damage or regenerating. The
## effect itself is plain data; what it applies to and how much it has left live in the
## ActiveReplacementEffect that holds it (ADR 0019).


## Whether this effect, as [param active], applies to [param event], which is about to be
## performed.
func applies_to(_state: MmGameState, _event: MmEvent, _active: ActiveReplacementEffect) -> bool:
	assert(false, "%s must override applies_to()." % get_script().resource_path)
	return false


## The events that happen instead of [param event]: none, one or several. Using up a shield
## is itself one of them, so every change still goes through an event (ADR 0007).
func replace(_state: MmGameState, _event: MmEvent, _active: ActiveReplacementEffect) -> Array[MmEvent]:
	assert(false, "%s must override replace()." % get_script().resource_path)
	return []


## Whether [param active] prevents all of any event it applies to and is never used up.
## When every effect that applies is like that, the order cannot matter (A146).
func prevents_everything(_active: ActiveReplacementEffect) -> bool:
	return false


## Everything this effect is made of, so two effects that would do exactly the same thing
## can be recognized as interchangeable (A146).
func content_key() -> String:
	return MmReplacementEffect.content_of(self)


## A text that is the same for two values exactly when their content is the same, following
## Resources through their stored properties.
static func content_of(value: Variant) -> String:
	if value is Resource:
		var resource: Resource = value as Resource
		var script: Script = resource.get_script() as Script
		var parts: PackedStringArray = PackedStringArray()
		parts.append(resource.get_class() if script == null else script.resource_path)
		for property: Dictionary in resource.get_property_list():
			var usage: int = property["usage"]
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
				parts.append("%s=%s" % [property["name"], content_of(resource.get(property["name"]))])
		return "(%s)" % " ".join(parts)
	if value is Array:
		var items: PackedStringArray = PackedStringArray()
		for item: Variant in value as Array:
			items.append(content_of(item))
		return "[%s]" % ", ".join(items)
	return str(value)


## A short human-readable description for logs and debugging.
func describe() -> String:
	return "replacement effect"
