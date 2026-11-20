extends CostReductionAbility
## A test-only cost reduction that always takes [member mana] off, colored symbols
## included, to test what the cast does with a reduction of any kind (CR 118.7).

@export var mana: MmManaCost


func reduction(_state: MmGameState, _spell: MmGameObject, _player_id: int) -> MmManaCost:
	return mana
