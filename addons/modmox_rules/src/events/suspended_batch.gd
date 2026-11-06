class_name SuspendedBatch
extends RefCounted
## A batch of events being performed together (ADR 0017), with what is left of it. When an
## event needs a replacement choice, the batch stops and is kept in the game state until
## the choice is answered (A143), so undo checkpoints, copies and fingerprints include it.

var number: int
## What observers() returned just before the batch, for triggers that look back (ADR 0017).
var before: Array[MmGameObject]
## The events applied so far.
var performed: Array[MmEvent] = []
## The options while it waits for a replacement choice.
var choices: Array[ActiveReplacementEffect] = []
## The events still to perform, first one next, each with the keys of the replacement
## effects that already applied to it (CR 616.2). Events are shared with copies: one that
## has not been applied yet holds nothing a copy could disagree about, and applying it
## always sets the same results.
var _events: Array[MmEvent] = []
var _applied_keys: Array[PackedStringArray] = []


func _init(batch_number: int, observers_before: Array[MmGameObject], events: Array[MmEvent]) -> void:
	number = batch_number
	before = observers_before
	_events = events.duplicate()
	for _event: MmEvent in events:
		_applied_keys.append(PackedStringArray())


## A copy working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> SuspendedBatch:
	var observers: Array[MmGameObject] = []
	for observer: MmGameObject in before:
		observers.append(state.object_or_last_known(observer.id))
	var copy: SuspendedBatch = SuspendedBatch.new(number, observers, _events)
	copy._applied_keys = _applied_keys.duplicate()
	copy.performed = performed.duplicate()
	copy.choices = choices.duplicate()  # Active effects never change.
	return copy


func has_next_event() -> bool:
	return not _events.is_empty()


func next_event() -> MmEvent:
	return _events[0]


## The replacement effects that already applied to the next event.
func next_applied_keys() -> PackedStringArray:
	return _applied_keys[0]


## Removes the next event, which is about to be applied.
func take_next_event() -> void:
	_events.remove_at(0)
	_applied_keys.remove_at(0)


## Puts [param replacing] in place of the next event. The effect with [param applied_key]
## has now applied to each of them (CR 616.2).
func replace_next_event(replacing: Array[MmEvent], applied_key: String) -> void:
	var keys: PackedStringArray = _applied_keys[0].duplicate()
	keys.append(applied_key)
	take_next_event()
	for index: int in replacing.size():
		_events.insert(index, replacing[index])
		_applied_keys.insert(index, keys)


func describe() -> String:
	var events: PackedStringArray = PackedStringArray()
	for index: int in _events.size():
		events.append("%s %s" % [_events[index].describe(), ",".join(_applied_keys[index])])
	var options: PackedStringArray = PackedStringArray()
	for active: ActiveReplacementEffect in choices:
		options.append(active.key())
	return "batch %d performed %d next [%s] choices [%s] before %d" % [number, performed.size(), "; ".join(events),
		", ".join(options), before.size()]
