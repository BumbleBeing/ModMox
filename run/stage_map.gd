class_name StageMap
extends RefCounted
## A Stage Map (game glossary): the Nodes of one Stage and the links between them, as
## StageMapGenerator built them (ADR 0026). It only answers questions; nothing changes it
## once it is built.

## The kinds of Node. Never saved, so their numbers may change.
enum Kind { NONE, START, STORE, WORKSHOP, TROVE, LESSER, ELITE, BOSS, CHAOS }

const ROWS: int = 10
const COLUMNS: int = 9

## Every Node, its id its place in this list.
var nodes: Array[MapNode] = []
## How many maps were built and thrown away before this one, plus one.
var attempts: int = 0


## The Nodes with a forward link to the Node [param id], in id order.
func parents_of(id: int) -> Array[MapNode]:
	var found: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.forward.has(id):
			found.append(node)
	return found


## The Nodes of [param row], left to right.
func in_row(row: int) -> Array[MapNode]:
	var found: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.row == row:
			found.append(node)
	found.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.column < b.column)
	return found


## The Start Node.
func start() -> MapNode:
	return in_row(1)[0]


## The Boss Encounter.
func boss() -> MapNode:
	return in_row(ROWS)[0]


## Whether [param node] is a Lesser, Elite or Boss Encounter, the Nodes that are played.
static func is_encounter(node: MapNode) -> bool:
	return node.kind in [Kind.LESSER, Kind.ELITE, Kind.BOSS]
