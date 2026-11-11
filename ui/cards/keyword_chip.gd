class_name KeywordChip
extends RefCounted
## One Keyword Chip on a Battlefield Face. It shows its Keyword Icon, or its letters when
## it has none (a keyword whose icon is not drawn yet, and the "+N" chip).

var letters: String = ""
## The file name of its Keyword Icon in ui/sprites/keywords/, or "" for the "+N" chip.
var icon: String = ""
## Protection's chip shows the color it protects from, when it is a color.
var has_protection_color: bool = false
var protection_color: MmCardTypes.CardColor = MmCardTypes.CardColor.WHITE
