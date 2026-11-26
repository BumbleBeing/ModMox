class_name MmPlayer
extends RefCounted
## A player in an encounter, with a life total and their own library, hand and graveyard.
## Rules code identifies players only by ID and relationship, never as Hero or Villain.

## Why a player lost (CR 104.3). It only describes what happened, for the GUI; rules never
## branch on it.
enum LossReason { NONE = -1, ZERO_LIFE, EMPTY_LIBRARY, CONCEDED }

var id: int
var life: int
## The life this player began the encounter with (CR 103.4).
var starting_life: int
var opening_hand_size: int
## MmPlayerSetup.NO_MAXIMUM_HAND_SIZE when there is no maximum.
var maximum_hand_size: int
var free_mulligans: int
var mulligans_taken: int = 0
## How many turns this player has begun. 0 until their first turn.
var turn_number: int = 0
## The Game Turn in which this player's most recent turn began; 0 before their first turn.
var latest_turn_game_turn: int = 0
var lands_played_this_turn: int = 0
## The spells this player has cast this turn (CR 601.2i), wherever they were cast from, for
## "your second spell each turn".
var spells_cast_this_turn: int = 0
## The cards this player has drawn this turn (CR 121.1), one at a time (CR 121.2), the draw
## step's card among them, for "your second card each turn".
var cards_drawn_this_turn: int = 0
## Whether this player declared one or more attackers this turn (CR 508.1), for "if you
## attacked this turn" (engine ADR 0095's addendum). Never set by a creature put onto the
## battlefield attacking (CR 508.4).
var has_attacked_this_turn: bool = false
## The life this player has gained this turn, from effects and from lifelink damage alike
## (CR 119.3, 120.3f), for "if you gained life this turn" (engine ADR 0082's addendum).
var life_gained_this_turn: int = 0
## The life this player has lost this turn, from damage, effects and paying life alike
## (CR 119.3, 119.4, 120.3a), for "if an opponent lost life this turn" (engine ADR 0082's
## second addendum).
var life_lost_this_turn: int = 0
## Land plays this player may make this turn beyond their one, from resolved spells and
## abilities (CR 305.2). Ones from static abilities are counted where land plays are offered.
var additional_land_plays_this_turn: int = 0
## CR 704.5b: tried to draw from an empty library since state-based actions were last checked.
var has_drawn_from_empty_library: bool = false
var has_lost: bool = false
var loss_reason: LossReason = LossReason.NONE
var library: MmZone
var hand: MmZone
var graveyard: MmZone
var _mana_pool: Array[MmMana] = []


func _init(player_id: int, setup: MmPlayerSetup) -> void:
	id = player_id
	life = setup.starting_life
	starting_life = setup.starting_life
	opening_hand_size = setup.opening_hand_size
	maximum_hand_size = setup.maximum_hand_size
	free_mulligans = setup.free_mulligans
	library = MmZone.new(MmZone.Kind.LIBRARY, player_id)
	hand = MmZone.new(MmZone.Kind.HAND, player_id)
	graveyard = MmZone.new(MmZone.Kind.GRAVEYARD, player_id)


## A copy of this player with empty zones of their own. MmGameState.duplicate_state()
## fills the zones with copies of their objects.
func duplicate_without_objects() -> MmPlayer:
	var setup: MmPlayerSetup = MmPlayerSetup.new()
	var copy: MmPlayer = MmPlayer.new(id, setup)
	copy.life = life
	copy.starting_life = starting_life
	copy.opening_hand_size = opening_hand_size
	copy.maximum_hand_size = maximum_hand_size
	copy.free_mulligans = free_mulligans
	copy.mulligans_taken = mulligans_taken
	copy.turn_number = turn_number
	copy.latest_turn_game_turn = latest_turn_game_turn
	copy.lands_played_this_turn = lands_played_this_turn
	copy.spells_cast_this_turn = spells_cast_this_turn
	copy.cards_drawn_this_turn = cards_drawn_this_turn
	copy.has_attacked_this_turn = has_attacked_this_turn
	copy.life_gained_this_turn = life_gained_this_turn
	copy.life_lost_this_turn = life_lost_this_turn
	copy.additional_land_plays_this_turn = additional_land_plays_this_turn
	copy.has_drawn_from_empty_library = has_drawn_from_empty_library
	copy.has_lost = has_lost
	copy.loss_reason = loss_reason
	copy._mana_pool = _mana_pool.duplicate()  # MmMana units never change, so sharing them is safe.
	return copy


## How many cards this player must discard to reach their maximum hand size (CR 514.1).
func cards_over_maximum_hand_size() -> int:
	if maximum_hand_size == MmPlayerSetup.NO_MAXIMUM_HAND_SIZE:
		return 0
	return maxi(0, hand.size() - maximum_hand_size)


## A copy of the mana in this player's pool, oldest first (ADR 0013).
func mana_pool() -> Array[MmMana]:
	return _mana_pool.duplicate()


## Event-only: counts one more mulligan taken.
func record_mulligan() -> void:
	mulligans_taken += 1


## Event-only: counts the start of one of this player's turns, which begins in
## [param game_turn].
func begin_turn(game_turn: int) -> void:
	turn_number += 1
	latest_turn_game_turn = game_turn


## Event-only: clears the counts that last for one turn, at the start of every turn.
func reset_turn_counters() -> void:
	lands_played_this_turn = 0
	spells_cast_this_turn = 0
	cards_drawn_this_turn = 0
	has_attacked_this_turn = false
	life_gained_this_turn = 0
	life_lost_this_turn = 0
	# CR 514.2 ends "this turn" effects in the cleanup step. Ending them as the next turn
	# begins is the same, since no land can be played in between.
	additional_land_plays_this_turn = 0


## Event-only: counts a land played this turn (CR 305.2).
func record_land_play() -> void:
	lands_played_this_turn += 1


## Event-only: counts a spell this player cast this turn (CR 601.2i).
func record_spell_cast() -> void:
	spells_cast_this_turn += 1


## Event-only: counts a card this player drew this turn (CR 121.1).
func record_card_drawn() -> void:
	cards_drawn_this_turn += 1


## Event-only: records that this player declared attackers this turn (CR 508.1).
func record_attack() -> void:
	has_attacked_this_turn = true


## Event-only: allows [param count] more land plays this turn (CR 305.2).
func grant_land_plays(count: int) -> void:
	additional_land_plays_this_turn += count


## Event-only: adds mana to the pool.
func add_mana(units: Array[MmMana]) -> void:
	_mana_pool.append_array(units)


## Event-only: removes and returns the mana unit at [param index] of the pool.
func remove_mana_at(index: int) -> MmMana:
	return _mana_pool.pop_at(index)


## Event-only: empties the pool and returns how much mana was lost.
func empty_mana_pool() -> int:
	var lost: int = _mana_pool.size()
	_mana_pool.clear()
	return lost


## Event-only: records an attempt to draw from an empty library (CR 121.4).
func record_empty_library_draw() -> void:
	has_drawn_from_empty_library = true


## Event-only: this player loses the game for [param reason].
func lose(reason: LossReason) -> void:
	has_lost = true
	loss_reason = reason
	has_drawn_from_empty_library = false


## Event-only: changes the life total by [param amount], which may be negative (CR 119.3).
func change_life(amount: int) -> void:
	life += amount


## Event-only: this player gains [param amount] life (CR 119.3), counted toward the life
## gained this turn. Gaining no life is no life gain (CR 119.9).
func gain_life(amount: int) -> void:
	assert(amount >= 0, "A gain of %d life is a loss." % amount)
	change_life(amount)
	life_gained_this_turn += amount


## Event-only: this player loses [param amount] life (CR 119.3), counted toward the life
## lost this turn. Losing no life is no life loss.
func lose_life(amount: int) -> void:
	assert(amount >= 0, "A loss of %d life is a gain." % amount)
	change_life(-amount)
	life_lost_this_turn += amount
