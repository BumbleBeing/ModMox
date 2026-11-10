class_name KeywordChip
extends RefCounted
## One keyword chip on a Battlefield Face. Letters stand in until the user's 16 × 16 icons
## arrive (A230).

var letters: String = ""
## Protection's chip shows the color it protects from, when it is a color.
var has_protection_color: bool = false
var protection_color: MmCardTypes.CardColor = MmCardTypes.CardColor.WHITE
