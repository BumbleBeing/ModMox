class_name OpeningHand
extends RefCounted
## What the opening-hand overlay (game glossary) says through the pregame (13e-2): who
## chooses to play or draw, who plays first, how many mulligans have cost the Hero a card,
## what the buttons read, and what the Villain has decided. It reads each snapshot once and
## remembers what the pregame has said so far, so it is kept by the Encounter Screen outside
## the nodes it redraws.

enum Frame { CLOSED, PLAY_OR_DRAW, KEEP_OR_MULLIGAN, BOTTOM, WAITING }

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const ORDER_REMINDER: String = "The last card clicked -> bottom of library"
const NO_HAND: int = -1

var _frame: Frame = Frame.CLOSED
var _decision: MmPendingDecision = null
var _hand_size: int = 0
var _starts: String = ""
## How many cards the Hero's hand owed when they were last asked to keep it.
var _owed: int = 0
var _is_villain_thinking: bool = false
var _villain_mulligans: int = 0
var _villain_kept: int = NO_HAND
var _is_new_hand: bool = false
var _has_shown_a_hand: bool = false


## Whether [param decision] is answered in the overlay.
static func covers(decision: MmPendingDecision) -> bool:
	return decision is ChoosePlayOrDrawDecision or decision is KeepOrMulliganDecision \
			or decision is ChooseCardsToBottomDecision


## Takes in [param snapshot]: what it asks, and what its events say has been decided.
func read(snapshot: EncounterSnapshot) -> void:
	_decision = snapshot.decision
	_hand_size = snapshot.view.hand.size()
	_is_villain_thinking = snapshot.is_villain_thinking
	_is_new_hand = not _has_shown_a_hand and _hand_size > 0
	for event: MmEvent in snapshot.events:
		var starting: StartingPlayerEvent = event as StartingPlayerEvent
		if starting != null:
			_starts = "You play first" if starting.starting_player_id == HERO \
					else "The %s plays first" % StackItem.player_name(starting.starting_player_id)
		var choice: KeepOrMulliganEvent = event as KeepOrMulliganEvent
		if choice != null and choice.player_id == VILLAIN:
			if choice.is_keeping:
				_villain_kept = snapshot.view.hand_sizes.get(VILLAIN, 0) - choice.cards_to_bottom
			else:
				_villain_mulligans += 1
		var mulligan: MulliganEvent = event as MulliganEvent
		if mulligan != null and mulligan.player_id == HERO:
			_is_new_hand = true
	_has_shown_a_hand = _has_shown_a_hand or _hand_size > 0
	var keep: KeepOrMulliganDecision = _decision as KeepOrMulliganDecision
	if keep != null:
		_owed = keep.cards_to_bottom_if_kept
	if snapshot.view.game_turn > 0 or snapshot.is_over():
		_frame = Frame.CLOSED
	elif _decision is ChoosePlayOrDrawDecision:
		_frame = Frame.PLAY_OR_DRAW
	elif keep != null:
		_frame = Frame.KEEP_OR_MULLIGAN
	elif _decision is ChooseCardsToBottomDecision:
		_frame = Frame.BOTTOM
	else:
		_frame = Frame.WAITING


func frame() -> Frame:
	return _frame


func is_open() -> bool:
	return _frame != Frame.CLOSED


## Whether the last snapshot read dealt the Hero a hand they have not seen: their first, or
## one after a mulligan.
func is_new_hand() -> bool:
	return _is_new_hand


## The new hand has been shown: a redraw of the same snapshot does not show it as new again.
func forget_new_hand() -> void:
	_is_new_hand = false


## The line across the top: how the Hero came to choose, how many cards to put down, or how
## many mulligans have cost a card (A396). Empty when there is nothing to say.
func heading() -> String:
	match _frame:
		Frame.PLAY_OR_DRAW:
			return "You won the coin flip" if (_decision as ChoosePlayOrDrawDecision).is_chooser_random else "You choose"
		Frame.BOTTOM:
			return CardPicks.new(_decision).prompt()
	return "Mulligans taken: %d" % _owed if _owed > 0 else ""


## The line under the heading: who plays first, or while several cards are put down, how
## their order is read.
func under_heading() -> String:
	if _frame == Frame.BOTTOM and CardPicks.new(_decision).is_ordered():
		return ORDER_REMINDER
	return _starts


## What the keep button reads: the size the hand will be once it has put down what it owes.
func keep_text() -> String:
	return "Keep %d" % (_hand_size - _owed)


func mulligan_text() -> String:
	var keep: KeepOrMulliganDecision = _decision as KeepOrMulliganDecision
	return "Free Mulligan" if keep != null and keep.is_next_mulligan_free else "Mulligan"


## What the Villain is doing or has decided, or "" before they have been asked.
func villain_text() -> String:
	var who: String = StackItem.player_name(VILLAIN)
	if _is_villain_thinking:
		return "%s is deciding…" % who
	if _villain_kept != NO_HAND:
		var article: String = "an" if _villain_kept == 8 or _villain_kept == 11 or _villain_kept == 18 else "a"
		return "%s has kept %s %d card hand" % [who, article, _villain_kept]
	if _villain_mulligans > 0:
		return "%s has taken %d mulligan%s" % [who, _villain_mulligans, "" if _villain_mulligans == 1 else "s"]
	return ""
