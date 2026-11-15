class_name MapNode
extends RefCounted
## One Node (game glossary) of a Stage Map: where it stands, its kind, and its links. Row 1
## is the Start Node's and row 10 the Boss Encounter's; columns run 1 to 9 (ADR 0026).

var id: int = 0
var row: int = 0
var column: int = 0
var kind: StageMap.Kind = StageMap.Kind.NONE
## The ids of the Nodes ahead this one links to. A link two rows ahead is a skip link.
var forward: Array[int] = []
## The id of the Node of the same row this one is linked to, either way, or -1.
var side: int = -1
