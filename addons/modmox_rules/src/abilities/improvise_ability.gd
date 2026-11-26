class_name ImproviseAbility
extends StaticAbility
## The keyword improvise (CR 702.126a, engine ADR 0099): "Your artifacts can help cast this
## spell. Each artifact you tap after you're done activating mana abilities pays for {1}." It
## works only as its card is cast: while the spell's mana is paid, each untapped artifact its
## caster controls may be tapped to pay one generic mana (ImproviseAction), never a colored
## or hybrid symbol (CR 702.126b). Tapping one is not its {T}, so an artifact creature with
## summoning sickness may (CR 302.6). Cost reductions are taken off first (CR 601.2f), and the
## spell's mana value never changes (CR 202.3). A second instance changes nothing
## (CR 702.126c). It does nothing on the battlefield.


func describe() -> String:
	return "improvise"
