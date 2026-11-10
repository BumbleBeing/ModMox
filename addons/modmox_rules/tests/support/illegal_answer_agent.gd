extends MmAgent
## A test Agent whose every answer is illegal.


func answer(_decision: MmPendingDecision, _view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	return "not an answer"
