class_name MmCost
extends Resource
## One part of a cost (CR 118), such as tapping the source. Subclasses describe one kind each.


## Whether this cost can be paid right now for an ability of [param source].
func can_pay(_state: MmGameState, _source: MmGameObject) -> bool:
	assert(false, "%s must override can_pay()." % get_script().resource_path)
	return false


## Pays this cost through events. Only called after can_pay() returned true.
func pay(_state: MmGameState, _source: MmGameObject) -> void:
	assert(false, "%s must override pay()." % get_script().resource_path)
