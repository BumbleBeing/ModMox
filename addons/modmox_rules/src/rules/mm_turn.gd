class_name MmTurn
extends RefCounted
## The fixed structure of a turn (CR 500): its phases and steps, in order. Main phases
## have no steps by rule (CR 505); each is treated as a single step of the same name so
## that every point in a turn can be named the same way.

enum Phase { BEGINNING, PRECOMBAT_MAIN, COMBAT, POSTCOMBAT_MAIN, ENDING }
enum Step {
	NONE = -1,
	UNTAP, UPKEEP, DRAW,
	PRECOMBAT_MAIN,
	BEGINNING_OF_COMBAT, DECLARE_ATTACKERS, DECLARE_BLOCKERS, COMBAT_DAMAGE, END_OF_COMBAT,
	POSTCOMBAT_MAIN,
	END, CLEANUP,
}

## Every step of a turn in order, before any are skipped.
const STEPS: Array[Step] = [
	Step.UNTAP, Step.UPKEEP, Step.DRAW,
	Step.PRECOMBAT_MAIN,
	Step.BEGINNING_OF_COMBAT, Step.DECLARE_ATTACKERS, Step.DECLARE_BLOCKERS, Step.COMBAT_DAMAGE, Step.END_OF_COMBAT,
	Step.POSTCOMBAT_MAIN,
	Step.END, Step.CLEANUP,
]


## The phase [param step] belongs to.
static func phase_of(step: Step) -> Phase:
	match step:
		Step.UNTAP, Step.UPKEEP, Step.DRAW:
			return Phase.BEGINNING
		Step.PRECOMBAT_MAIN:
			return Phase.PRECOMBAT_MAIN
		Step.POSTCOMBAT_MAIN:
			return Phase.POSTCOMBAT_MAIN
		Step.END, Step.CLEANUP:
			return Phase.ENDING
	return Phase.COMBAT


## Whether players normally receive priority in [param step] (CR 502.4, 514.3).
static func grants_priority(step: Step) -> bool:
	return step != Step.UNTAP and step != Step.CLEANUP
