extends Resource
## The run's spawn timeline. Phases are sorted by start time.
@export var phases: Array[Resource] = []

func index_at(elapsed: float) -> int:
	var found: int = 0
	for i: int in phases.size():
		if phases[i].start <= elapsed:
			found = i
	return found
