class_name PileWindows
extends RefCounted
## Which pile windows are open only to answer a target, and so close once it is answered.
## A window opens by itself when every card that answers is in a pile; when something on
## the board answers too, the pile glows and its window waits for a click on it (A443). One
## opened either way closes when the target is chosen or the cast is canceled, and one the
## Hero already had open is left as it was (A450). Kept on the screen, outside what a
## redraw rebuilds.

## The windows to open and to close now, as the Regions of their piles, set by follow().
var to_open: Array[String] = []
var to_close: Array[String] = []

## The windows that close with the target, and the decision the windows last opened by
## themselves for: the Hero may close one, and it then stays closed while that is asked.
var _for_target: Array[String] = []
var _opened_for: MmPendingDecision = null


## Takes in what is asked now: [param clicks] of [param decision], with the windows in
## [param open] open already.
func follow(decision: MmPendingDecision, clicks: DecisionClicks, open: Array[String]) -> void:
	to_open.clear()
	to_close.clear()
	if clicks.piles().is_empty():
		for key: String in _for_target:
			if open.has(key):
				to_close.append(key)
		_for_target.clear()
		_opened_for = null
		return
	if not clicks.is_only_in_piles() or decision == _opened_for:
		return
	_opened_for = decision
	for key: String in clicks.piles():
		if not open.has(key):
			to_open.append(key)
			_for_target.append(key)


## The Hero clicked the pile [param key], and its window [param is_open] now. Opened while
## its cards answer, it closes with the target; closed by hand, it is forgotten.
func toggled(key: String, is_open: bool, clicks: DecisionClicks) -> void:
	_for_target.erase(key)
	if is_open and clicks.piles().has(key):
		_for_target.append(key)


## Whether the window of [param key] closes once the target is chosen.
func closes_with_target(key: String) -> bool:
	return _for_target.has(key)
