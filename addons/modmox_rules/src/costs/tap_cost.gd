class_name TapCost
extends MmCost
## {T}: tap the ability's source (CR 107.5). Payable only by an untapped permanent.


func can_pay(state: MmGameState, source: MmGameObject) -> bool:
	# CR 302.6: a creature with summoning sickness cannot pay {T}.
	return source.zone() == state.battlefield and not source.is_tapped and not state.is_summoning_sick(source)


func pay(state: MmGameState, source: MmGameObject) -> void:
	state.perform(TapEvent.new(source.id))
