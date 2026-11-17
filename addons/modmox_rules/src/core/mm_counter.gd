class_name MmCounter
extends RefCounted
## The kinds of counter a permanent can have (CR 122), and what each does. A counter is a
## marker on a Game Object, not a characteristic: a permanent keeps how many of each kind
## it has, and loses them all when it changes zones (CR 122.2, ADR 0008).
##
## Later: counters that do not change power and toughness, and counters on players.

## Saved in card files, so append-only.
enum Kind {
	PLUS_ONE_PLUS_ONE = 0,
	MINUS_ONE_MINUS_ONE = 1,
}

## Every kind, in the order anything that lists counters goes through them.
const KINDS: Array[Kind] = [Kind.PLUS_ONE_PLUS_ONE, Kind.MINUS_ONE_MINUS_ONE]


## What one counter of [param kind] adds to power and to toughness (CR 122.1a).
static func power_toughness_change(kind: Kind) -> int:
	return 1 if kind == Kind.PLUS_ONE_PLUS_ONE else -1


## The kind as it is written on a card: "+1/+1" or "-1/-1".
static func label(kind: Kind) -> String:
	return "+1/+1" if kind == Kind.PLUS_ONE_PLUS_ONE else "-1/-1"
