class_name MmAgent
extends RefCounted
## Whatever answers Pending Decisions for a player (glossary "Agent"): an AI, or a test
## script. A human answers through the GUI instead, where the Encounter Driver has no Agent
## for that player and stops.
##
## An Agent reads only what it is handed (ADR 0020): the decision, its player's view, and a
## Simulation Source. It keeps nothing between decisions, so it can run on any thread and
## gives the same answer after a save and reload.


## Returns a legal answer to [param decision]. The answer is a Variant because each kind of
## decision takes a different shape (ADR 0016). [param view] may be null inside a
## Simulation Copy, where no player is watching.
func answer(_decision: MmPendingDecision, _view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	assert(false, "%s must override answer()." % get_script().resource_path)
	return null
