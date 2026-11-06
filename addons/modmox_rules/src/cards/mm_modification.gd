class_name MmModification
extends Resource
## A single permanent change to a Run Card, earned outside an encounter (ADR 0004).
## Subclasses describe one kind of change each, such as ChangeNameModification.


## Applies this change to [param definition], a private copy being flattened.
## Never called on a base Card Definition.
func apply_to(_definition: MmCardDefinition) -> void:
	assert(false, "%s must override apply_to()." % get_script().resource_path)
